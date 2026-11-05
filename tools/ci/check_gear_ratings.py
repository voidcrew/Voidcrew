"""Catch gear entering the economy badly: on sale with no rating, below its tier's reputation, or priced outside its band.

Run: python -m tools.ci.check_gear_ratings [--github] [--json]
Reads the game's source through load_static and the tracked files in tools/gear_catalog. It needs no dump and no generated files.

Crew reputation gates what crews buy, research and get offered; exploration and looting may bypass it on purpose. So only the routes in
tools/gear_catalog/policy.json count, and a recipe with an ingredient none of them sells must be found in the field, so it's exempt, unless the
policy calls that ingredient ordinary. A design only a hidden research node grants is a find too.
Items made by using parts count when the policy lists made_by_use. That route is read from `new` in use procs, so it only sees the item used, not any other part a step asks for.
Errors fail the check:
    unrated             gear with a checked route and no entry in items or unrated, or with a word in unrated that says it has no route
    below_reputation    a checked route lets a crew get it below its tier's reputation
    above_on_route      a tier of above with any checked route
    price_out_of_band   a shop price outside its category's band for its tier
    stale_exception     an entry in tools/gear_catalog/exceptions.json that no longer matches a violation, or names a path that no longer exists
Warnings don't: unrated gear with no checked route, and a rating for a path that no longer exists.
"""

import argparse
import collections
import json
from pathlib import Path
import re
import time

from tools.gear_catalog.categories import REP_ORDER, category_of, is_gear
from tools.gear_catalog.ratings import EXCEPTIONS_FILE, POLICY_FILE, RATINGS_FOLDER, exception_problems, load_docs, policy_problems
from tools.gear_catalog.recipes import covering_types, fixture_needs, is_ordinary, item_needs, recipe_step, settle, use_recipe
from tools.gear_catalog.static_sources import load_static


REPO_ROOT = Path(__file__).resolve().parents[2]
PUBLIC = 0
# Words that say nobody can get the thing, so a checked route means the word is out of date. Sync gives every routeless item a word, so without this
# an existing item could go on sale unrated. The others stand: a toy can be on a shelf, and a real tool can be the plain base of its family.
ROUTELESS_WORDS = ("no route", "literal only", "admin", "leftover")
# Barter with an exploration drone is exploration, however it's stored.
FIELD_SELLERS = ("/datum/exploration_event",)


def step_index(step):
    return REP_ORDER.index(step) if step in REP_ORDER else PUBLIC


def rep_words(step):
    return "no reputation" if step == PUBLIC else f"{REP_ORDER[step]} reputation"


def design_offer(design):
    """How a design is printed, as (step, how), or None when points can't unlock it: it comes from a disk, an experiment, an emag or some other find. A hidden node is one of those."""
    if design.get("roundstart"):
        return PUBLIC, "at round start"
    if design.get("unlock") == "hacked autolathe":
        return PUBLIC, "on a hacked autolathe"
    nodes = [node for node in design.get("nodes") or [] if node.get("rep_step_with_prereqs") in REP_ORDER and not node.get("hidden_with_prereqs", node.get("hidden"))]
    if not nodes:
        return None
    node = min(nodes, key=lambda found: step_index(found["rep_step_with_prereqs"]))
    return step_index(node["rep_step_with_prereqs"]), f"from research node {node['id']}"


def bought_offers(routes, checked):
    """Every checked way to get an item that isn't crafting, as dicts of kind, route, step, how, fix and source."""
    offers = []
    if "shops" in checked:
        for row in routes.get("shops") or []:
            step = step_index(row.get("rep_step"))
            offers.append(dict(kind="shops", route=row["sku"], step=step, row=row, source=row.get("source"), how=f"sold at {rep_words(step)} by {row['sku']}",
                               fix="Raise the SKU's zone_permission"))
    if "cargo" in checked:
        for row in routes.get("cargo") or []:
            offers.append(dict(kind="cargo", route=row["pack"], step=PUBLIC, row=row, source=row.get("source"), how=f"sold at no reputation by cargo pack {row['pack']}",
                               fix="Take it out of the pack"))
    for kind, label in (("order_consoles", "order console offer"), ("other_sellers", "seller offer")):
        if kind in checked:
            for row in routes.get(kind) or []:
                if not str(row["offer"]).startswith(FIELD_SELLERS):
                    offers.append(dict(kind=kind, route=row["offer"], step=PUBLIC, row=row, source=row.get("source"), how=f"sold at no reputation by {label} {row['offer']}",
                                       fix="Take the offer off sale"))
    if "printing" in checked:
        for row in routes.get("printing") or []:
            found = design_offer(row)
            if found:
                step, where = found
                offers.append(dict(kind="printing", route=row["design"], step=step, row=row, source=row.get("source"), how=f"printed at {rep_words(step)} by {row['design']} {where}",
                                   fix="Move the design behind a research node with a higher zone_permission"))
    return offers


def crafted_offers(routes, steps, covers):
    """Every recipe a crew can make from checked routes. One with an ingredient they don't sell isn't an offer at all: that ingredient is the gate."""
    offers = []
    for entry in routes.get("crafting") or []:
        step = recipe_step(entry, steps, covers)
        if step is None:
            continue
        route = entry.get("recipe") or f"stack recipe: {entry.get('stack_recipe')}"
        offers.append(dict(kind="crafting", route=route, step=step, row=entry, source=entry.get("source"), how=f"crafted at {rep_words(step)} by {route}",
                           fix="Raise the reputation of what the recipe needs, or make it need something found in the field"))
    return offers


def used_offers(routes, steps, covers):
    """Every item a crew can get that turns into this one when used."""
    offers = []
    for row in routes.get("made_by_use") or []:
        step = recipe_step(use_recipe(row), steps, covers)
        if step is not None:
            offers.append(dict(kind="made_by_use", route=row["from_item"], step=step, row=row, source=row.get("source"), how=f"made at {rep_words(step)} by using {row['from_item']}",
                               fix="Raise the reputation of what it's made from"))
    return offers


def reachable(static, paths, checked, ordinary=()):
    """The lowest step that reaches each item through checked routes, and which paths count as each recipe ingredient.

    Ordinary ingredients count as public: any crew can pick them up, so a recipe's gate comes from the rest of what it asks for. A machine a recipe needs is reached like any item.
    """
    start, recipes = {}, {}

    def read(path, routes):
        offers = bought_offers(routes, checked)
        if offers:
            start[path] = min(offer["step"] for offer in offers)
        found = list(routes.get("crafting") or []) if "crafting" in checked else []
        if "made_by_use" in checked:
            found += [use_recipe(row) for row in routes.get("made_by_use") or []]
        if found:
            recipes[path] = found

    for path in paths:
        read(path, static.routes(path))
    for path in paths:
        if is_ordinary(path, ordinary):
            start[path] = PUBLIC
    fixtures = {}
    while True:  # A machine's own recipe can ask for another machine.
        found = static.fixtures_for({need for entries in recipes.values() for entry in entries for need in fixture_needs(entry)})
        fresh = {fixture: routes for fixture, routes in found.items() if fixture not in fixtures}
        if not fresh:
            break
        fixtures.update(fresh)
        for fixture, routes in fresh.items():
            read(fixture, routes)
    needed = {need for entries in recipes.values() for entry in entries for need in item_needs(entry) + fixture_needs(entry)}
    covers = covering_types([*paths, *fixtures], needed, static.dm.parent)
    return settle(start, recipes, covers), covers


def rating_file(category):
    return f"{RATINGS_FOLDER}/{category}.json"


def split_source(source):
    """(file, line) from a file:line citation."""
    file, _, line = str(source or "").rpartition(":")
    return (file, int(line)) if file and line.isdigit() else (str(source or "") or None, None)


def violation(rule, path, route, offer_source, message, **extra):
    file, line = split_source(offer_source)
    return dict(rule=rule, path=path, route=route, file=file, line=line, message=message, **extra)


def judge_item(path, category, entry, offers, policy, voucher_value):
    """What this one rated or word-listed item does wrong on its checked routes."""
    file = rating_file(category)
    tail = f"change the rating in {file}, or add it to {EXCEPTIONS_FILE} with a reason."
    found = []
    if "tier" not in entry:
        word = entry.get("word")
        if word not in ROUTELESS_WORDS:
            return found
        for offer in offers:
            found.append(violation("unrated", path, offer["route"], offer["source"],
                                   f"{path} is {offer['how']} but {file} lists it as \"{word}\". Give it a rating under items in that file (leave hash empty if you have no catalog), "
                                   f"take the offer away, or add it to {EXCEPTIONS_FILE} with a reason."))
        return found
    tier = entry["tier"]
    for offer in offers:
        if tier == "above":
            found.append(violation("above_on_route", path, offer["route"], offer["source"],
                                   f"{path} is {offer['how']} but is rated above, which means it shouldn't be on any shelf. {offer['fix']}, {tail}"))
            continue
        needs = policy["min_reputation"].get(tier)
        if needs is not None and offer["step"] < step_index(needs):
            found.append(violation("below_reputation", path, offer["route"], offer["source"], f"{path} is {offer['how']} but is rated {tier} (needs {needs}). {offer['fix']}, {tail}"))
        if offer["kind"] != "shops":
            continue
        band = (policy["price_bands"].get(category) or {}).get(tier)
        row = offer["row"]
        credits, vouchers = row.get("credits") or 0, row.get("vouchers") or 0
        price = credits + vouchers * voucher_value
        if band and price > 0 and not band[0] <= price <= band[1]:
            found.append(violation("price_out_of_band", path, offer["route"], offer["source"],
                                   f"{path} sells for {price:g} cr ({credits:g} cr and {vouchers:g} vouchers at {voucher_value:g} each) by {offer['route']}, outside the {band[0]:g} to {band[1]:g} cr "
                                   f"band for a {tier} item in {category}. Change the SKU's price, change the band in {POLICY_FILE}, {tail}", price=price))
    return found


def exception_line(text, path):
    for number, line in enumerate(text.splitlines(), 1):
        if f'"{path}"' in line:
            return number
    return None


def apply_exceptions(found, exceptions, known_type, exceptions_text):
    """Drop the violations an exception excuses, and turn exceptions that excuse nothing into violations of their own."""
    excused = {(row["path"], row["rule"], row["route"]) for row in exceptions}
    used = {(row["path"], row["rule"], row["route"]) for row in found}
    kept = [row for row in found if (row["path"], row["rule"], row["route"]) not in excused]
    for row in exceptions:
        key = (row["path"], row["rule"], row["route"])
        if key in used:
            continue
        why = "names a path that no longer exists" if not known_type(row["path"]) else f"no longer matches a {row['rule']} violation by {row['route']}"
        kept.append(dict(rule="stale_exception", path=row["path"], route=row["route"], file=EXCEPTIONS_FILE, line=exception_line(exceptions_text, row["path"]),
                         message=f"The exception for {row['path']} {why}. Remove it from {EXCEPTIONS_FILE}."))
    return kept


def find_problems(static, docs, policy, exceptions, exceptions_text=""):
    """All errors and warnings for a checkout, as lists of dicts. Pure apart from what static reads."""
    dm = static.dm
    checked = policy["checked_routes"]
    voucher_value = dm.eval("VOUCHER_CREDIT_VALUE")
    if not isinstance(voucher_value, (int, float)):
        raise ValueError(f"VOUCHER_CREDIT_VALUE should be a plain number, not {voucher_value!r}")
    paths = sorted({*dm.compiled_types("/obj/item"), *(path for path in static.routed_types() if path.startswith("/obj/item"))})
    ordinary = [row["path"] for row in policy.get("ordinary_ingredients") or []]
    steps, covers = reachable(static, paths, checked, ordinary)
    entries = {}
    for category, doc in docs.items():
        for path, item in doc["items"].items():
            entries[path] = item
        for path, word in doc["unrated"].items():
            entries[path] = dict(word=word)

    found, warnings = [], []
    for path in paths:
        category = category_of(path)[0]
        if not is_gear(category):
            continue
        routes = static.routes(path)
        offers = bought_offers(routes, checked) + (crafted_offers(routes, steps, covers) if "crafting" in checked else []) + (used_offers(routes, steps, covers) if "made_by_use" in checked else [])
        # A stack counts as whatever it merges into, so a rating of the 1-stack covers the 50-stack.
        entry = entries.get(path) or entries.get(static.merge_key(path))
        if entry:
            found += judge_item(path, category, entry, offers, policy, voucher_value)
        elif offers:
            for offer in offers:
                found.append(violation("unrated", path, offer["route"], offer["source"],
                                       f"{path} is {offer['how']} but has no rating. Add it under items in {rating_file(category)} (leave hash empty if you have no catalog), "
                                       f"give it a word under unrated in that file if it isn't real gear, take the offer away, or add it to {EXCEPTIONS_FILE} with a reason."))
        else:
            warnings.append(dict(rule="unrated", path=path, file=rating_file(category), line=None,
                                 message=f"{path} has no rating and no checked route, so nothing fails yet. It needs an entry in {rating_file(category)} before it's sold."))
    for category, doc in sorted(docs.items()):
        for path in sorted([*doc["items"], *doc["unrated"]]):
            if not dm.known_type(path):
                warnings.append(dict(rule="missing_type", path=path, file=rating_file(category), line=None,
                                     message=f"{path} no longer exists but {rating_file(category)} still lists it. Remove it from that file."))
    for path in ordinary:
        if not dm.known_type(path):
            warnings.append(dict(rule="missing_type", path=path, file=POLICY_FILE, line=None,
                                 message=f"{path} no longer exists but ordinary_ingredients in {POLICY_FILE} still lists it. Remove it from that file."))

    found = apply_exceptions(found, exceptions, dm.known_type, exceptions_text)
    key = lambda row: (row["rule"], row["path"], str(row.get("route")))
    return sorted(found, key=key), sorted(warnings, key=key)


def escape_annotation(text, property_value=False):
    text = str(text).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    return text.replace(":", "%3A").replace(",", "%2C") if property_value else text


def annotation(level, row):
    fields = []
    if row.get("file"):
        fields.append(f"file={escape_annotation(row['file'], True)}")
    if row.get("line"):
        fields.append(f"line={row['line']}")
    return f"::{level} {','.join(fields)}::{escape_annotation(row['message'])}" if fields else f"::{level}::{escape_annotation(row['message'])}"


def plain_line(level, row):
    where = f"{row['file']}:{row['line']}" if row.get("line") else (row.get("file") or "")
    return f"{where}: {level}: {row['rule']}: {row['message']}"


def load_tracked(root):
    """The policy, the exceptions and their raw text, and every ratings file. Bad files come back as problems, each with the file to fix."""
    problems = []
    docs, rating_problems = load_docs(root)
    problems += rating_problems
    policy, exceptions, exceptions_text = None, [], ""
    try:
        policy = json.loads((root / POLICY_FILE).read_text(encoding="utf-8"))
        problems += [(POLICY_FILE, sentence) for sentence in policy_problems(policy)]
    except (OSError, ValueError) as error:
        problems.append((POLICY_FILE, f"cannot read it: {error}"))
    try:
        exceptions_text = (root / EXCEPTIONS_FILE).read_text(encoding="utf-8")
        exceptions = json.loads(exceptions_text)
        found = exception_problems(exceptions)
        problems += [(EXCEPTIONS_FILE, sentence) for sentence in found]
        if found:
            exceptions = []
    except (OSError, ValueError) as error:
        problems.append((EXCEPTIONS_FILE, f"cannot read it: {error}"))
    return docs, policy, exceptions, exceptions_text, problems


def report(errors, warnings, args, seconds):
    if args.json:
        print(json.dumps(dict(violations=errors, warnings=warnings), ensure_ascii=False, sort_keys=True, indent=1))
        return
    for row in warnings:
        print(annotation("warning", row) if args.github else plain_line("warning", row))
    for row in errors:
        print(annotation("error", row) if args.github else plain_line("error", row))
    counts = collections.Counter(row["rule"] for row in errors)
    detail = f" ({', '.join(f'{count} {rule}' for rule, count in sorted(counts.items()))})" if counts else ""
    print(f"Gear ratings: {len(errors)} errors{detail}, {len(warnings)} warnings, {seconds:.1f}s.")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Catch gear entering the economy badly: on sale with no rating, below its tier's reputation, or priced outside its band.")
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="the checkout to read (default: this one)")
    parser.add_argument("--github", action="store_true", help="Emit GitHub error and warning annotations")
    parser.add_argument("--json", action="store_true", help="Print every violation and warning as JSON")
    args = parser.parse_args(argv)
    started = time.time()
    root = args.root.resolve()

    docs, policy, exceptions, exceptions_text, problems = load_tracked(root)
    errors = [dict(rule="bad_file", path=None, route=None, file=file, line=None, message=f"{file}: {sentence}") for file, sentence in problems]
    if errors:
        report(errors, [], args, time.time() - started)
        return 1
    try:
        errors, warnings = find_problems(load_static(root), docs, policy, exceptions, exceptions_text)
    except Exception as error:  # The reader asserts on malformed shops and packs. Say so, rather than a stack trace with no file.
        errors = [dict(rule="bad_source", path=None, route=None, file=None, line=None, message=f"Cannot read the game's shops, research and crafting from source: {error!r}")]
        report(errors, [], args, time.time() - started)
        return 1
    report(errors, warnings, args, time.time() - started)
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
