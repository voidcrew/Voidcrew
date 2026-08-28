#!/usr/bin/env python3
"""
check_bt_returns.py - static guard against non-terminating behavior-tree leaves.

WHY THIS EXISTS
---------------
2026-08 BT port incident, fatal #1: `/datum/bt_node/ai_behavior/exploration_hold/perform()`
returned a bare `AI_BEHAVIOR_INSTANT`.  `AI_BEHAVIOR_INSTANT` is `NONE` (0) - a *modifier*,
not a result - so `/datum/bt_node/ai_behavior/tick()` saw neither the SUCCEEDED nor the
FAILED bit and fell through to `BT_RUNNING`.  A stateless leaf that can never complete then
returns BT_RUNNING forever.  That latch is self-sealing twice over:

  * `/datum/bt_node/composite/selector/tick()` resumes at `running_child_index`, so *every*
    sibling - higher and lower priority alike - is skipped while the latch holds, and
  * `/datum/bt_node/decorator/tick()` skips `check_condition()` entirely while `child_active`,
    so the gate that would release the branch is never re-evaluated.

Result: every boarding pirate on the ship stopped moving for the rest of the round, with
zero runtimes and a compile-clean tree.  Nothing but a static check or a live tick could
have caught it.

WHAT IT CHECKS
--------------
For every `/datum/bt_node/.../perform()` override under the scanned roots, classify the
return paths:

  instant_latch : a return whose whole value is a hold constant with no result bit
                  (`AI_BEHAVIOR_INSTANT`, `NONE`, or an OR of only those).  This is the
                  exact fatal-#1 shape and is reported even when *other* paths in the same
                  proc do terminate.
  bare_return   : `return` with no value at all (implicitly null == NONE == no result bit).
  fallthrough   : the body never returns a value and never assigns `.`, so DM returns null.
  delay_hold    : the proc has returns, but not one of them ever carries a result bit and it
                  never delegates to `..()`.  A leaf that can only ever say "still running".

Every finding is a failure unless the node's typepath is on INTENTIONAL_HOLD below.

ALLOWLIST CONTRACT
------------------
An INTENTIONAL_HOLD entry is only accepted when the node is actually *gated* in a
`.bt.json` by an ancestor decorator whose `observer_abort` includes `BT_ABORT_SELF`
(so `BT_ABORT_SELF` or `BT_ABORT_BOTH`).  That is the one engine mechanism that can break a
hold from the outside: when the gate's condition drops, `on_observed_change()` fires
`cancel_current_plan()` and the tree replans.  `exploration_hold` had only
`BT_ABORT_LOWER_PRIORITY` on its gate - which is why it could never be released - so this
validation is precisely the property whose absence caused the incident.

`observer_abort` is resolved from both the JSON (`"vars": {"observer_abort": ...}`) and the
DM class default on the decorator typepath, following DM subtype inheritance.

A stale or ungated allowlist entry is itself a failure: the allowlist cannot rot into a
blanket suppression.

KNOWN FALSE POSITIVE (suppressed)
---------------------------------
`. = ..()`-then-log overrides, e.g. `/datum/bt_node/ai_behavior/move_to_target/
patrol_walk_through/perform` (voidcrew/modules/npc_ships/code/mob_patrol.dm).  The parent's
flags are the return value; the body only inspects them.  A proc whose first statement is
`. = ..()` is never flagged.

USAGE
-----
    python tools/ci/check_bt_returns.py                  # scan voidcrew/ (fork-owned code)
    python tools/ci/check_bt_returns.py --include-upstream   # also scan code/
    python tools/ci/check_bt_returns.py --selftest       # run the embedded fixtures
    python tools/ci/check_bt_returns.py --list-holds     # report holds without failing

Exit code 0 = clean, 1 = findings (or a selftest failure).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# --------------------------------------------------------------------------------------
# Allowlist
# --------------------------------------------------------------------------------------
#
# typepath -> reason.  Every entry is validated against the .bt.json gating described in the
# module docstring; an entry that stops being SELF-gated becomes a hard failure.
#
INTENTIONAL_HOLD: dict[str, str] = {
    # --- seeded by the incident report (spec 11.3) ---
    "/datum/bt_node/ai_behavior/npc_ship/movement_hold":
        "Idle movement mode owns the tick on purpose; a FAILED here would drop the ship "
        "through to a lower-priority movement mode. Gated by "
        "/datum/bt_node/decorator/npc_movement_mode (observer_abort = BT_ABORT_SELF), which "
        "cancels the plan the moment BB_NPC_DISPATCH_MODE changes.",
    "/datum/bt_node/ai_behavior/npc_ship/negotiation_hold":
        "Negotiation is a wait state with no action; failing would let the combat selector "
        "fall through to a lower-priority state mid-negotiation. Gated by "
        "/datum/bt_node/decorator/npc_combat_state (observer_abort = BT_ABORT_SELF).",

    # --- triaged 2026-08 during the pirate-AI test pass ---
    "/datum/bt_node/ai_behavior/move_to_target/hoarfrost":
        "Planted matriarch: holds the movement half of the combat parallel instead of "
        "failing it, because BT_PARALLEL_FAILURE_ANY on that parallel would drop her into "
        "the idle wander branch mid-ability. `inert` is cleared by the ability's own timer, "
        "not by the tree, so the hold is time-bounded rather than self-sealing. Gated by "
        "/datum/bt_node/decorator/bb_key_set with observer_abort BT_ABORT_BOTH in "
        "voidcrew/modules/mob/living/basic/hoarfrost/hoarfrost_matriarch.bt.json.",
}

# --------------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------------

BT_ABORT_VALUES = {
    "BT_ABORT_NONE": 0,
    "BT_ABORT_SELF": 1,
    "BT_ABORT_LOWER_PRIORITY": 2,
    "BT_ABORT_BOTH": 3,
}
BT_ABORT_SELF_BIT = 1

# Return values that carry no result bit. AI_BEHAVIOR_INSTANT is literally NONE.
HOLD_TOKENS = {"AI_BEHAVIOR_INSTANT", "NONE", "0"}
# Adds a cooldown but still no result bit.
DELAY_TOKENS = {"AI_BEHAVIOR_DELAY"}
RESULT_TOKENS = {"AI_BEHAVIOR_SUCCEEDED", "AI_BEHAVIOR_FAILED"}

PERFORM_HEADER_RE = re.compile(r"^(/datum/bt_node/[^\s(/]+(?:/[^\s(/]+)*)/perform\s*\(")
RETURN_RE = re.compile(r"^\s*return\b(?P<expr>.*)$")
DOT_ASSIGN_RE = re.compile(r"^\s*\.\s*=")
DECORATOR_HEADER_RE = re.compile(r"^(/datum/bt_node/decorator/[^\s(/]+(?:/[^\s(/]+)*)\s*$")
OBSERVER_ABORT_RE = re.compile(r"^\s+observer_abort\s*=\s*(?P<value>[A-Za-z_0-9| ]+?)\s*$")

SEVERITY_TEXT = {
    "instant_latch": "returns a bare hold constant (no SUCCEEDED/FAILED bit) - "
                     "tick() falls through to BT_RUNNING forever",
    "bare_return": "bare `return` (null == NONE == no result bit) - "
                   "tick() falls through to BT_RUNNING forever",
    "fallthrough": "no value ever returned and `.` never assigned - "
                   "tick() falls through to BT_RUNNING forever",
    "delay_hold": "no return path ever carries a result bit - "
                  "this leaf can only ever say 'still running'",
}


# --------------------------------------------------------------------------------------
# DM source parsing
# --------------------------------------------------------------------------------------

def strip_comments(text: str) -> str:
    """Remove DM line and block comments. String-aware enough for our purposes."""
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    string_ch = ""
    in_block = False
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            # keep newlines so line numbers survive
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue
        if in_string:
            out.append(ch)
            if ch == "\\":
                if i + 1 < n:
                    out.append(nxt)
                    i += 2
                    continue
            elif ch == string_ch:
                in_string = False
            i += 1
            continue
        if ch in ('"', "'"):
            in_string = True
            string_ch = ch
            out.append(ch)
            i += 1
            continue
        if ch == "/" and nxt == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def iter_perform_bodies(path: Path):
    """Yield (typepath, header_line_no, body_lines) for each perform() override in a file."""
    raw = path.read_text(encoding="utf-8", errors="ignore")
    lines = strip_comments(raw).splitlines()
    i = 0
    total = len(lines)
    while i < total:
        line = lines[i]
        match = PERFORM_HEADER_RE.match(line)
        if not match:
            i += 1
            continue
        typepath = match.group(1)
        if typepath.endswith("/proc"):
            # `/datum/bt_node/ai_behavior/proc/perform()` is the abstract declaration, not an
            # override. Its empty body is the contract, not a latch.
            i += 1
            continue
        header_line_no = i + 1
        # Consume a possibly-wrapped signature until the parens balance.
        depth = 0
        j = i
        while j < total:
            depth += lines[j].count("(") - lines[j].count(")")
            j += 1
            if depth <= 0:
                break
        # Body: indented lines until the next column-0 statement.
        body: list[tuple[int, str]] = []
        while j < total:
            candidate = lines[j]
            if candidate.strip() == "":
                body.append((j + 1, candidate))
                j += 1
                continue
            if not candidate[0].isspace():
                break
            body.append((j + 1, candidate))
            j += 1
        yield typepath, header_line_no, body
        i = j


def tokens_of(expr: str) -> set[str]:
    return {tok for tok in re.split(r"[|\s()]+", expr) if tok}


def classify_body(body: list[tuple[int, str]]) -> list[tuple[str, int, str]]:
    """Return a list of (kind, line_no, snippet) findings for one perform() body."""
    statements = [(no, text.strip()) for no, text in body if text.strip()]
    if not statements:
        # An empty override body is a compile error in DM, so this can't happen in practice.
        return []

    first = statements[0][1]
    findings: list[tuple[str, int, str]] = []
    returns: list[tuple[int, str]] = []
    assigns_dot = False
    delegates = False

    for line_no, text in statements:
        if DOT_ASSIGN_RE.match(text):
            assigns_dot = True
            if "..(" in text:
                delegates = True
        match = RETURN_RE.match(text)
        if not match:
            continue
        expr = match.group("expr").strip()
        returns.append((line_no, expr))
        if "..(" in expr:
            delegates = True

    has_result_bit = False
    for line_no, expr in returns:
        if not expr:
            # KNOWN FALSE POSITIVE: in a `. = ...` body a valueless `return` yields whatever
            # `.` holds, which is usually the parent's flags. Only flag it when nothing ever
            # assigned `.`, where it really does mean "return null == NONE".
            if not assigns_dot:
                findings.append(("bare_return", line_no, "return"))
            continue
        toks = tokens_of(expr)
        if toks & RESULT_TOKENS:
            has_result_bit = True
            continue
        # An explicit hold return is flagged unconditionally, including inside a `. = ..()`
        # body: it *discards* the parent's flags and hands tick() a bare 0.
        if toks and toks <= HOLD_TOKENS:
            findings.append(("instant_latch", line_no, "return " + expr))

    if not returns:
        # KNOWN FALSE POSITIVE: `. = ..()`-then-log overrides, e.g.
        # /datum/bt_node/ai_behavior/move_to_target/patrol_walk_through/perform. The parent's
        # flags are the return value; the body only inspects them.
        if not assigns_dot:
            findings.append(("fallthrough", statements[0][0], first))
        return findings

    if not has_result_bit and not delegates and not assigns_dot:
        # Every path is DELAY / INSTANT only. Report once, on the first return, and only if
        # we did not already report that same line as an instant_latch.
        already = {line_no for kind, line_no, _ in findings if kind == "instant_latch"}
        for line_no, expr in returns:
            toks = tokens_of(expr)
            if line_no in already:
                continue
            if toks and toks <= (HOLD_TOKENS | DELAY_TOKENS):
                findings.append(("delay_hold", line_no, "return " + expr))
                break

    return findings


# --------------------------------------------------------------------------------------
# .bt.json gating validation
# --------------------------------------------------------------------------------------

def build_decorator_abort_map(roots: list[Path]) -> dict[str, int]:
    """typepath -> declared observer_abort value, read from DM class bodies."""
    declared: dict[str, int] = {}
    for root in roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.dm")):
            lines = strip_comments(
                path.read_text(encoding="utf-8", errors="ignore")
            ).splitlines()
            current: str | None = None
            for line in lines:
                if line and not line[0].isspace():
                    match = DECORATOR_HEADER_RE.match(line.rstrip())
                    current = match.group(1) if match else None
                    continue
                if current is None:
                    continue
                match = OBSERVER_ABORT_RE.match(line)
                if not match:
                    continue
                value = 0
                for tok in tokens_of(match.group("value")):
                    value |= BT_ABORT_VALUES.get(tok, 0)
                declared[current] = value
    return declared


def resolve_abort(typepath: str, declared: dict[str, int]) -> int:
    """Effective observer_abort for a decorator typepath, following subtype inheritance."""
    best = 0
    best_len = -1
    for candidate, value in declared.items():
        if typepath == candidate or typepath.startswith(candidate + "/"):
            if len(candidate) > best_len:
                best_len = len(candidate)
                best = value
    return best


def node_abort(node: dict, declared: dict[str, int]) -> int:
    """observer_abort for one JSON decorator node: JSON vars win over the DM default."""
    decorator = node.get("decorator") or node.get("dm_type") or ""
    value = resolve_abort(decorator, declared) if decorator else 0
    raw = (node.get("vars") or {}).get("observer_abort")
    if raw is None:
        raw = node.get("observer_abort")
    if raw is not None:
        if isinstance(raw, (int, float)):
            value = int(raw)
        else:
            value = 0
            for tok in tokens_of(str(raw)):
                value |= BT_ABORT_VALUES.get(tok, 0)
    return value


def find_gated_behaviors(
    bt_files: list[Path], declared: dict[str, int]
) -> dict[str, list[tuple[str, bool]]]:
    """
    behavior typepath -> list of (tree file, is_self_gated) observations.

    A behavior is self-gated when some ancestor node in the same tree is a decorator whose
    effective observer_abort carries the BT_ABORT_SELF bit. Ancestry is only followed WITHIN
    one tree file: a subtree node is a leaf in its parent tree and has its own compiled file,
    and the engine's abort machinery is per-decorator-instance, so a SELF gate two trees up
    is not evidence that this hold can be released.
    """
    seen: dict[str, list[tuple[str, bool]]] = {}

    def walk(node, self_gated: bool, source: str):
        if isinstance(node, list):
            for child in node:
                walk(child, self_gated, source)
            return
        if not isinstance(node, dict):
            return
        gated = self_gated
        node_type = str(node.get("type") or "")
        is_decorator = node_type == "decorator" or "decorator" in node
        if is_decorator and (node_abort(node, declared) & BT_ABORT_SELF_BIT):
            gated = True
        behavior = node.get("behavior")
        if behavior:
            seen.setdefault(behavior, []).append((source, gated))
        for key in ("child", "children"):
            if key in node:
                walk(node[key], gated, source)

    for path in bt_files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as err:
            print(f"::warning::could not parse {path}: {err}")
            continue
        walk(data, False, path.as_posix())
    return seen


def validate_allowlist(bt_files: list[Path], declared: dict[str, int]) -> list[str]:
    """Return a list of problems with INTENTIONAL_HOLD entries."""
    gated = find_gated_behaviors(bt_files, declared)
    problems: list[str] = []
    for typepath in sorted(INTENTIONAL_HOLD):
        observations = gated.get(typepath)
        if not observations:
            problems.append(
                f"{typepath}: allowlisted but never referenced by any .bt.json - "
                "the entry is stale, remove it"
            )
            continue
        if not any(is_gated for _source, is_gated in observations):
            sites = "; ".join(
                f"{source} ({'SELF-gated' if is_gated else 'no SELF gate'})"
                for source, is_gated in observations
            )
            problems.append(
                f"{typepath}: allowlisted but no .bt.json gates it with an observer_abort "
                "carrying BT_ABORT_SELF, so nothing can break the hold from outside. "
                f"Sites: {sites}"
            )
    return problems


# --------------------------------------------------------------------------------------
# Selftest
# --------------------------------------------------------------------------------------

SELFTEST_CASES: list[tuple[str, bool, str]] = [
    (
        # The exact fatal-#1 shape.
        "/datum/bt_node/ai_behavior/selftest_bare_instant/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\treturn AI_BEHAVIOR_INSTANT\n",
        True,
        "a bare AI_BEHAVIOR_INSTANT return must be flagged",
    ),
    (
        # The documented false positive.
        "/datum/bt_node/ai_behavior/selftest_dot_parent/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\t. = ..()\n"
        "\tif(. & AI_BEHAVIOR_SUCCEEDED)\n"
        "\t\tPATROL_LOG(\"reached\")\n",
        False,
        "a `. = ..()` body must not be flagged",
    ),
    (
        "/datum/bt_node/ai_behavior/selftest_fixed_hold/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\treturn AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED\n",
        False,
        "INSTANT with a SUCCEEDED bit must not be flagged (this is the shipped fix)",
    ),
    (
        "/datum/bt_node/ai_behavior/selftest_bare_return/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\tif(!controller.pawn)\n"
        "\t\treturn AI_BEHAVIOR_FAILED\n"
        "\treturn\n",
        True,
        "a valueless `return` must be flagged",
    ),
    (
        "/datum/bt_node/ai_behavior/selftest_fallthrough/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\tcontroller.clear_blackboard_key(BB_PATROL_STEP)\n",
        True,
        "a body that never returns a value must be flagged",
    ),
    (
        "/datum/bt_node/ai_behavior/selftest_delay_only/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\treturn AI_BEHAVIOR_DELAY\n",
        True,
        "a DELAY-only hold must be flagged (allowlist is the escape hatch)",
    ),
    (
        # Hoarfrost shape: one delegating path, one bare-hold path.
        "/datum/bt_node/ai_behavior/selftest_mixed_hold/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\tvar/mob/living/basic/thing/pawn = controller.pawn\n"
        "\tif(istype(pawn) && pawn.inert)\n"
        "\t\treturn AI_BEHAVIOR_INSTANT\n"
        "\treturn ..()\n",
        True,
        "a bare-hold branch must be flagged even when another path delegates to ..()",
    ),
    (
        # Wrapped signature plus the false-positive body.
        "/datum/bt_node/ai_behavior/selftest_wrapped/perform(\n"
        "\tseconds_per_tick,\n"
        "\tdatum/ai_controller/controller,\n"
        ")\n"
        "\t. = ..()\n"
        "\treturn .\n",
        False,
        "a wrapped signature with a `. = ..()` body must not be flagged",
    ),
    (
        "/datum/bt_node/ai_behavior/selftest_normal/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\tif(!controller.pawn)\n"
        "\t\treturn AI_BEHAVIOR_FAILED\n"
        "\treturn AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED\n",
        False,
        "a normal terminating behavior must not be flagged",
    ),
    (
        # The `. = ..()` suppression must not become a blanket amnesty: an explicit bare hold
        # return still discards the parent's flags and hands tick() a 0.
        "/datum/bt_node/ai_behavior/selftest_dot_parent_but_latches/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\t. = ..()\n"
        "\tif(controller.blackboard[BB_THING])\n"
        "\t\treturn AI_BEHAVIOR_INSTANT\n",
        True,
        "an explicit bare hold return inside a `. = ..()` body must still be flagged",
    ),
    (
        # `. = ..()` plus a valueless `return` is the ordinary early-out idiom.
        "/datum/bt_node/ai_behavior/selftest_dot_parent_bare_return/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\t. = ..()\n"
        "\tif(!controller.pawn)\n"
        "\t\treturn\n"
        "\tPATROL_LOG(\"ok\")\n",
        False,
        "a valueless `return` in a `. = ..()` body must not be flagged",
    ),
    (
        # Comment containing the bad shape must not trip the scanner.
        "/datum/bt_node/ai_behavior/selftest_commented/perform("
        "seconds_per_tick, datum/ai_controller/controller)\n"
        "\t// a lone `return AI_BEHAVIOR_INSTANT` here would latch the tree\n"
        "\treturn AI_BEHAVIOR_SUCCEEDED\n",
        False,
        "the bad shape inside a comment must not be flagged",
    ),
]


def run_selftest(tmp_root: Path) -> int:
    failures = 0
    tmp_root.mkdir(parents=True, exist_ok=True)
    for index, (snippet, should_flag, description) in enumerate(SELFTEST_CASES):
        path = tmp_root / f"selftest_{index}.dm"
        path.write_text(snippet, encoding="utf-8")
        flagged = False
        for _typepath, _line, body in iter_perform_bodies(path):
            if classify_body(body):
                flagged = True
        path.unlink()
        if flagged != should_flag:
            failures += 1
            print(f"SELFTEST FAIL [{index}] {description} "
                  f"(expected flagged={should_flag}, got {flagged})")
        else:
            print(f"selftest ok  [{index}] {description}")
    if failures:
        print(f"\n{failures} selftest case(s) failed.")
        return 1
    print(f"\nAll {len(SELFTEST_CASES)} selftest cases passed.")
    return 0


# --------------------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--repo-root", default=None,
                        help="repo root (default: two levels above this script)")
    parser.add_argument("--include-upstream", action="store_true",
                        help="also scan code/ (upstream tg). Off by default: upstream churn "
                             "is not ours to gate and fixing it creates merge conflicts.")
    parser.add_argument("--selftest", action="store_true",
                        help="run the embedded fixtures and exit")
    parser.add_argument("--list-holds", action="store_true",
                        help="print findings but always exit 0")
    args = parser.parse_args()

    repo_root = Path(args.repo_root) if args.repo_root else Path(__file__).resolve().parents[2]

    if args.selftest:
        return run_selftest(repo_root / "tools" / "ci" / "_bt_selftest_tmp")

    scan_roots = [repo_root / "voidcrew"]
    if args.include_upstream:
        scan_roots.append(repo_root / "code")

    # Gate validation always reads every tree: a voidcrew leaf can be gated by an upstream
    # subtree json and vice versa.
    bt_files = sorted(
        list((repo_root / "voidcrew").rglob("*.bt.json"))
        + list((repo_root / "code").rglob("*.bt.json"))
    )
    declared = build_decorator_abort_map([repo_root / "voidcrew", repo_root / "code"])

    findings: list[tuple[str, str, int, str, str]] = []  # (kind, file, line, typepath, snippet)
    allowed_hits: list[tuple[str, str, int]] = []
    scanned = 0

    for root in scan_roots:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.dm")):
            for typepath, _header, body in iter_perform_bodies(path):
                scanned += 1
                for kind, line_no, snippet in classify_body(body):
                    rel = path.relative_to(repo_root).as_posix()
                    if typepath in INTENTIONAL_HOLD:
                        allowed_hits.append((typepath, rel, line_no))
                        continue
                    findings.append((kind, rel, line_no, typepath, snippet))

    allowlist_problems = validate_allowlist(bt_files, declared)

    # An allowlist entry that suppresses nothing is dead weight, and dead weight is how an
    # allowlist quietly becomes a blanket amnesty. Surface it, but don't fail on it.
    exercised = {typepath for typepath, _rel, _line in allowed_hits}
    unused = sorted(set(INTENTIONAL_HOLD) - exercised)

    print(f"check_bt_returns: scanned {scanned} perform() override(s) under "
          f"{', '.join(r.name for r in scan_roots if r.exists())}/")
    print(f"                  {len(bt_files)} .bt.json tree(s) available for gate validation")

    if allowed_hits:
        print(f"\n{len(allowed_hits)} allowlisted hold(s) suppressed:")
        for typepath, rel, line_no in sorted(allowed_hits):
            print(f"  - {rel}:{line_no}  {typepath}")

    if unused:
        print(f"\n{len(unused)} allowlist entry/entries suppressed nothing this run "
              "(the node no longer holds, or is outside the scanned roots):")
        for typepath in unused:
            print(f"::notice::allowlist entry is unused, consider removing: {typepath}")

    if allowlist_problems:
        print("\nINTENTIONAL_HOLD allowlist problems:")
        for problem in allowlist_problems:
            print(f"::error::allowlist: {problem}")

    if findings:
        print(f"\n{len(findings)} non-terminating perform() body/bodies:")
        for kind, rel, line_no, typepath, snippet in sorted(findings, key=lambda f: (f[1], f[2])):
            print(f"::error file={rel},line={line_no}::{typepath}: "
                  f"{SEVERITY_TEXT[kind]} [{kind}] -- `{snippet}`")
            print(f"  {rel}:{line_no}  {typepath}")
            print(f"    {kind}: {SEVERITY_TEXT[kind]}")
            print(f"    source: {snippet}")
        print("\nIf a hold here is deliberate, add it to INTENTIONAL_HOLD with a reason AND "
              "gate it in the .bt.json with a decorator whose observer_abort includes "
              "BT_ABORT_SELF, or nothing can ever release it.")

    if args.list_holds:
        return 0
    return 1 if (findings or allowlist_problems) else 0


if __name__ == "__main__":
    sys.exit(main())
