#!/usr/bin/env python3
"""
check_override_signatures.py - parent/override signature-drift lint for DreamMaker.

WHY THIS EXISTS
---------------
DreamMaker binds proc arguments POSITIONALLY and performs no compatibility check
between a proc's declaration and an override of it. When upstream tgstation changes
a proc's parameter list and a fork override still declares the OLD list, the code
compiles clean and then silently misbinds:

    upstream:  /datum/bt_node/.../proc/should_keep_target(controller, strategy,
                                                          priority_strategy,   # INSERTED
                                                          current_target,
                                                          resolved_vision_range)
    fork:      /datum/bt_node/.../aggressive/should_keep_target(controller, strategy,
                                                               current_target)

`current_target` now receives `priority_strategy`, which is null for every non-mining
mob, `QDELETED(null)` is TRUE, the proc returns FALSE forever, and every boarding
trooper acquires a target and immediately aborts. That shipped, and this script is
verified to catch it: run against the pre-fix mob_patrol.dm from git HEAD it reports
ARITY_MISBIND + ORDER at line 2084, naming `priority_strategy -> current_target`.

(A prior audit attributed the earlier ship-turret outage to this same class. That is not
supported by the fix commit 55f2d32a115, which changed no proc signature - it widened a
behaviour-tree leaf typecache. The signature-drift class is real and recurring on its own
evidence; the turret outage was a different bug.)

DM cannot express this check itself:
  * there is no reflection over a proc's declared parameter list, so no unit test in any
    language-legal form can see it;
  * `#pragma InvalidOverride` (enabled in tools/ci/od_lints.dm) only fires when the parent
    proc is ABSENT entirely, not when its shape changed.

So it has to be a static script. This is it.

WHAT IT CHECKS
--------------
  ARITY_MISBIND  override declares FEWER params than its parent AND the overlapping
               slots do not line up (a name or type disagrees). ERROR. The params the
               override DOES read are receiving the wrong values. This is exactly the
               pirate-AI / ship-turret shape: a mid-list insertion pushed everything down.
  ORDER        the positionally-matched TYPES disagree in a way that cannot be a rename
               (parent slot 3 is /datum/target_priority_strategy, override slot 3 is
               /atom). ERROR. A mid-list insertion, including one that keeps the count.
  ARITY_TRUNCATED  override declares fewer params but the surviving slots DO line up.
               WARNING, not error. A bare `..()` forwards the CALLER'S original argument
               list, not the override's declared params, so the parent still receives
               everything; the override is merely blind to the tail. Upstream itself does
               this 1328 times in code/ (every `/obj/foo/Destroy()` against
               `/datum/proc/Destroy(force = FALSE)`), so treating it as an error is
               indefensible. It stays reported because a NEWLY truncated fork override
               after a merge is real drift - the baseline is what makes that visible.
  ARITY_EXTRA  override declares MORE params than its parent. INFO. Usually means
               upstream REMOVED a param (or the fork added an optional tail arg it calls
               itself). Worth an eyeball after a merge, not worth failing a build.
  DEFAULTS     override re-declares a param but omits a TRUTHY parent default. WARNING.
               Documented fork trap: defaults are NOT inherited, so every caller that
               omits the arg now gets null instead of the parent's value. Falsy defaults
               (FALSE/0/null) are skipped - omitting them changes nothing.
  NAME_DRIFT   positionally-matched params whose NAMES differ. WARNING. Often harmless
               (a deliberate clearer name), but it is the smell that accompanies a real
               misbind, so it is surfaced rather than hidden.
  ORPHAN       override whose proc is declared nowhere in its ancestor chain. ERROR.
               Upstream deleted or renamed the proc; the override is dead code that never
               fires. DM's own compiler catches some of these, but NOT procs reached only
               through PROC_REF()/signal registration, which is most of the fork's.

SCOPE
-----
Default mode is the merge-drift surface: overrides in FORK-OWNED files whose parent
definition lives in UPSTREAM code. That is the set that upstream can break without the
fork touching a line. `--all` widens to every override in the tree.

USAGE
-----
    python tools/ci/check_override_signatures.py                  # fork-vs-upstream
    python tools/ci/check_override_signatures.py --all            # whole tree
    python tools/ci/check_override_signatures.py --category ARITY_MISBIND ORPHAN
    python tools/ci/check_override_signatures.py --json out.json
    python tools/ci/check_override_signatures.py --write-baseline # regenerate allowlist
    python tools/ci/check_override_signatures.py --selftest       # parser unit tests

Exit codes: 0 clean, 1 non-baselined findings at/above --fail-on, 2 bad invocation.

LIMITATIONS (deliberate, documented)
------------------------------------
  * Block/indented type syntax (`/obj/item` newline TAB `proc` newline TAB TAB `foo()`)
    is NOT parsed. There are zero real instances in this tree; the only match is a
    commented-out demo in code/__HELPERS/icons.dm.
  * Procs synthesized by #define macros are invisible. Params are read as written, so a
    macro used as a default value is compared as an opaque token.
  * `#if`/`#ifdef` variants of the same proc are all collected; the variant with the most
    params wins as the parent, which is the false-positive-safe direction.
  * The ORDER check resolves types through the real type tree (builtin edges included),
    so `atom/A` in the parent vs `obj/item/A` in the override is a compatible narrowing.
    Two SIBLING types in the same slot are what it flags.
  * A proc reached only through a #define wrapper, or an override that deliberately
    re-purposes a slot, will look like drift. That is why the baseline exists.
  * Builtin DM procs (New, Topic, Click, Move, ...) are exempt from ORPHAN since their
    declarations live in the engine, not in the tree.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass, field

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASELINE_PATH = os.path.join(REPO_ROOT, "tools", "ci", "override_signatures_baseline.json")

# Directories scanned for .dm sources, relative to repo root.
SOURCE_ROOTS = ["code", "voidcrew", "interface", "_maps"]

# A file is fork-owned if it matches one of these prefixes (posix-normalized, lowercase).
FORK_PREFIXES = ("voidcrew/",)
# ...plus fork test files that live inside the upstream unit-test directory.
FORK_FILE_RE = re.compile(r"^code/modules/unit_tests/voidcrew_[^/]+\.dm$")

# A parent definition counts as "upstream" if it lives here.
UPSTREAM_PREFIXES = ("code/",)


# ---------------------------------------------------------------------------
# DM builtin hierarchy.
#
# Path-stripping alone gives /obj -> "" and would miss /atom/movable, /atom and /datum
# entirely, orphaning every examine()/Initialize()/Destroy() override in the tree. These
# edges are defined by the engine, not by any file, so they must be hardcoded.
# ---------------------------------------------------------------------------
BUILTIN_PARENTS = {
    "/atom": "/datum",
    "/atom/movable": "/atom",
    "/obj": "/atom/movable",
    "/mob": "/atom/movable",
    "/turf": "/atom",
    "/area": "/atom",
    "/image": "/datum",
    "/mutable_appearance": "/image",
    "/sound": "/datum",
    "/icon": "/datum",
    "/matrix": "/datum",
    "/regex": "/datum",
    "/exception": "/datum",
    "/database": "/datum",
    "/savefile": "/datum",
    "/client": "/datum",
    "/world": "/datum",
    "/list": "/datum",
    "/generator": "/datum",
    "/particles": "/datum",
    "/filter": "/datum",
    "/alist": "/datum",
    "/callee": "/datum",
}

# Procs the DM engine declares. An override of one of these has no in-tree declaration,
# which is legal and extremely common, so they must never be reported as ORPHAN.
BUILTIN_PROCS = {
    # /datum
    "New", "Del", "Read", "Write", "Topic",
    # /atom + /atom/movable
    "Enter", "Exit", "Entered", "Exited", "Cross", "Crossed", "Uncross", "Uncrossed",
    "Bump", "Move", "Stat", "Click", "DblClick", "MouseDown", "MouseUp", "MouseMove",
    "MouseDrag", "MouseDrop", "MouseEntered", "MouseExited", "MouseWheel",
    # /mob
    "Login", "Logout",
    # /client
    "Command", "Center", "North", "South", "East", "West", "Northeast", "Northwest",
    "Southeast", "Southwest", "Northwest", "Move", "Import", "Export", "AllowUpload",
    "SendPage", "IsByondMember", "CheckPassport", "MeasureText", "SoundQuery",
    "GetAPI", "SetAPI", "Navigate", "GetSize",
    # /world
    "Reboot", "IsBanned", "Error", "OpenPort", "SetScores", "GetScores", "Profile",
    "Export", "Import", "AddCredits", "IsSubscribed", "GetConfig", "SetConfig",
    "GetMedal", "SetMedal", "ClearMedal", "Repop",
    # /savefile, /list, /regex, /icon, /matrix, /database
    "Find", "Replace", "Add", "Remove", "Insert", "Copy", "Cut", "Swap", "Join", "Splice",
    "Blend", "Scale", "Turn", "Flip", "Shift", "SwapColor", "DrawBox", "GetPixel",
    "MapColors", "Crop", "IconStates", "Width", "Height", "Multiply", "Translate",
    "Interpolate", "Invert", "Execute", "Close", "Error", "ErrorMsg", "Rows", "Columns",
    "GetRowData", "NextRow", "RowsAffected",
}

# Params whose name differs but which are known-equivalent renames upstream performs
# constantly; reporting them as NAME_DRIFT is pure noise.
BENIGN_RENAMES = [
    {"user", "usr", "attacker", "living_user"},
    {"i", "item", "attacking_item", "used_item", "tool", "weapon", "w", "attacking"},
    {"target", "atom_target", "attacked_atom", "hit_atom", "a", "clicked_on"},
    {"mapload", "map_load", "loading"},
    {"source", "src_object", "signal_source"},
    {"seconds_per_tick", "delta_time"},
]

SEVERITY_ORDER = {"info": 0, "warning": 1, "error": 2}

CATEGORY_SEVERITY = {
    "ORDER": "error",
    "ARITY_MISBIND": "error",
    "ORPHAN": "error",
    "ARITY_TRUNCATED": "warning",
    "DEFAULTS": "warning",
    "NAME_DRIFT": "warning",
    "ARITY_EXTRA": "info",
}

# Default values that are already falsy, so failing to re-declare them changes nothing.
# Only a TRUTHY parent default is a real trap when an override omits it.
FALSY_DEFAULTS = {"FALSE", "0", "null", "NULL", "0.0", '""', "''", "NONE", "-1"}


# ---------------------------------------------------------------------------
# Lexical pre-pass: blank out comments and string literals, preserving offsets.
# ---------------------------------------------------------------------------
def strip_noise(text: str) -> str:
    """Replace comments and string bodies with spaces, keeping every newline in place.

    Line and column numbers of everything that survives are therefore unchanged, so the
    scanner can report accurate file:line. DM block comments NEST, and DM has three
    string forms: "...", '...' (resource paths) and {"..."} (multiline). All are
    neutralized so that a line starting with '/' inside an HTML blob is never mistaken
    for a proc definition.
    """
    out = list(text)
    n = len(text)
    i = 0
    block_depth = 0
    while i < n:
        c = text[i]
        if block_depth:
            if c == "/" and i + 1 < n and text[i + 1] == "*":
                block_depth += 1
                out[i] = out[i + 1] = " "
                i += 2
                continue
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                block_depth -= 1
                out[i] = out[i + 1] = " "
                i += 2
                continue
            if c != "\n":
                out[i] = " "
            i += 1
            continue

        if c == "/" and i + 1 < n and text[i + 1] == "*":
            block_depth = 1
            out[i] = out[i + 1] = " "
            i += 2
            continue

        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                out[i] = " "
                i += 1
            continue

        if c == "{" and i + 1 < n and text[i + 1] == '"':
            out[i] = out[i + 1] = " "
            i += 2
            while i < n:
                if text[i] == '"' and i + 1 < n and text[i + 1] == "}":
                    out[i] = out[i + 1] = " "
                    i += 2
                    break
                if text[i] != "\n":
                    out[i] = " "
                i += 1
            continue

        if c in ('"', "'"):
            quote = c
            i += 1
            while i < n:
                if text[i] == "\\":
                    out[i] = " "
                    if i + 1 < n and text[i + 1] != "\n":
                        out[i + 1] = " "
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                if text[i] == "\n":
                    # Unterminated single-line string; bail out rather than eat the file.
                    break
                out[i] = " "
                i += 1
            continue

        i += 1
    return "".join(out)


# ---------------------------------------------------------------------------
# Parameter list parsing.
# ---------------------------------------------------------------------------
OPENERS = {"(": ")", "[": "]", "{": "}"}
CLOSERS = {")", "]", "}"}


def split_top_level(text: str, sep: str = ",") -> list[str]:
    """Split on `sep` at bracket depth zero. Strings are already blanked by strip_noise,
    but nested list(...) / newlist(...) defaults are not, so depth tracking is required."""
    parts: list[str] = []
    depth = 0
    current: list[str] = []
    for ch in text:
        if ch in OPENERS:
            depth += 1
        elif ch in CLOSERS:
            depth -= 1
        if ch == sep and depth == 0:
            parts.append("".join(current))
            current = []
            continue
        current.append(ch)
    parts.append("".join(current))
    return parts


def split_default(text: str) -> tuple[str, str | None]:
    """Split `name = default` at the first top-level bare '='.

    Comparison operators (==, !=, <=, >=) can only appear inside a default expression,
    never in the declaration half, but they are skipped explicitly so a malformed line
    cannot mis-split.
    """
    depth = 0
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in OPENERS:
            depth += 1
        elif ch in CLOSERS:
            depth -= 1
        elif ch == "=" and depth == 0:
            prev = text[i - 1] if i else ""
            nxt = text[i + 1] if i + 1 < n else ""
            if prev in "=!<>" or nxt == "=":
                i += 2 if nxt == "=" else 1
                continue
            return text[:i], text[i + 1:]
        i += 1
    return text, None


# `as text`, `as anything`, `as mob|obj in oview(1)` input specifiers (verbs mostly).
AS_IN_RE = re.compile(r"\b(?:as|in)\b")


@dataclass
class Param:
    name: str
    type_path: str | None
    default: str | None
    raw: str
    is_vararg: bool = False

    def normalized_type(self) -> str | None:
        if not self.type_path:
            return None
        return "/" + self.type_path.strip("/")


def parse_param(raw: str) -> Param | None:
    raw = raw.strip()
    if not raw:
        return None
    # DM's variadic marker. `/atom/proc/Initialize(mapload, ...)` accepts any number of
    # trailing args, so an override declaring more params than the declaration is normal
    # and must never be reported. Dropping this token silently made ~46% of ARITY_EXTRA
    # false positives.
    if raw == "...":
        return Param(name="...", type_path=None, default=None, raw=raw, is_vararg=True)
    decl, default = split_default(raw)
    if default is not None:
        default = default.strip()
        if default == "":
            default = None
    decl = decl.strip()

    # Cut trailing `as <inputtype>` / `in <list>` clauses.
    m = AS_IN_RE.search(decl)
    if m:
        decl = decl[: m.start()].strip()
    if not decl:
        return None

    if decl.startswith("var/"):
        decl = decl[4:]
    decl = decl.strip().lstrip("/")
    if not decl:
        return None

    segments = [s for s in decl.split("/") if s]
    if not segments:
        return None
    name = segments[-1]
    type_path = "/".join(segments[:-1]) if len(segments) > 1 else None
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        return None
    return Param(name=name, type_path=type_path, default=default, raw=raw)


def parse_param_list(text: str) -> list[Param]:
    text = text.strip()
    if not text:
        return []
    params = []
    for chunk in split_top_level(text, ","):
        p = parse_param(chunk)
        if p is not None:
            params.append(p)
    return params


# ---------------------------------------------------------------------------
# Proc definition extraction.
# ---------------------------------------------------------------------------
# A definition head starts at column 0 with an absolute path and reaches an open paren.
# The name segment may be an identifier or an `operator<sym>` overload.
DEF_HEAD_RE = re.compile(
    r"^(?P<path>/(?:[A-Za-z_][A-Za-z0-9_]*/)*)"
    r"(?P<name>operator[^\s(]*|[A-Za-z_][A-Za-z0-9_]*)"
    r"[ \t]*\("
)
PARENT_TYPE_RE = re.compile(r"^[ \t]+parent_type[ \t]*=[ \t]*(/[A-Za-z0-9_/]+)")
TYPE_LINE_RE = re.compile(r"^(/(?:[A-Za-z_][A-Za-z0-9_]*/)*[A-Za-z_][A-Za-z0-9_]*)[ \t]*$")


@dataclass
class ProcDef:
    type_path: str          # "" means global (/proc/foo)
    name: str
    params: list[Param]
    is_declaration: bool    # True when written with /proc/ or /verb/
    file: str               # repo-relative, posix separators
    line: int               # 1-based

    @property
    def key(self) -> tuple[str, str]:
        return (self.type_path, self.name)

    @property
    def variadic(self) -> bool:
        return any(p.is_vararg for p in self.params)

    @property
    def fixed(self) -> list[Param]:
        """Declared params excluding the `...` marker."""
        return [p for p in self.params if not p.is_vararg]

    def signature(self) -> str:
        inner = ", ".join(p.raw.strip() for p in self.params)
        return f"{self.type_path or ''}{'/proc' if self.is_declaration else ''}/{self.name}({inner})"


@dataclass
class Repo:
    defs: dict[tuple[str, str], list[ProcDef]] = field(default_factory=dict)
    parent_types: dict[str, str] = field(default_factory=dict)
    known_types: set[str] = field(default_factory=set)
    files_scanned: int = 0

    def add(self, d: ProcDef) -> None:
        self.defs.setdefault(d.key, []).append(d)
        if d.type_path:
            self.known_types.add(d.type_path)


def parse_text(text: str, relpath: str, repo: Repo) -> None:
    clean = strip_noise(text)
    lines = clean.split("\n")
    total = len(lines)
    # Map each line to its start offset so a multi-line param list can be sliced flat.
    idx = 0
    current_type = ""
    while idx < total:
        line = lines[idx]
        if not line or line[0] in " \t":
            if current_type:
                m = PARENT_TYPE_RE.match(line)
                if m:
                    repo.parent_types[current_type] = m.group(1).rstrip("/")
            idx += 1
            continue

        if line[0] != "/":
            idx += 1
            continue

        tl = TYPE_LINE_RE.match(line)
        if tl:
            current_type = tl.group(1).rstrip("/")
            repo.known_types.add(current_type)
            idx += 1
            continue

        m = DEF_HEAD_RE.match(line)
        if not m:
            # e.g. `/obj/item/var/foo = 3`, or a bare path with trailing content.
            bare = re.match(r"^(/(?:[A-Za-z_][A-Za-z0-9_]*/)*[A-Za-z_][A-Za-z0-9_]*)", line)
            if bare and "/var/" not in bare.group(1):
                current_type = bare.group(1).rstrip("/")
            idx += 1
            continue

        path = m.group("path")
        name = m.group("name")
        if "/var/" in path:
            idx += 1
            continue

        # Gather the parameter text by balancing parens across lines.
        start_line = idx
        buf = line[m.end():]
        depth = 1
        collected: list[str] = []
        consumed = 0
        while True:
            for ch in buf:
                if ch in OPENERS:
                    depth += 1
                elif ch in CLOSERS:
                    depth -= 1
                    if depth == 0:
                        break
                collected.append(ch)
            if depth == 0:
                break
            collected.append("\n")
            idx += 1
            consumed += 1
            if idx >= total or consumed > 200:
                depth = -1
                break
            buf = lines[idx]
        if depth != 0:
            idx = start_line + 1
            continue

        segments = [s for s in path.split("/") if s]
        is_decl = bool(segments) and segments[-1] in ("proc", "verb")
        if is_decl:
            type_path = "/" + "/".join(segments[:-1]) if len(segments) > 1 else ""
        else:
            type_path = "/" + "/".join(segments) if segments else ""

        repo.add(
            ProcDef(
                type_path=type_path,
                name=name,
                params=parse_param_list("".join(collected)),
                is_declaration=is_decl,
                file=relpath,
                line=start_line + 1,
            )
        )
        current_type = type_path
        idx += 1


def collect_repo(roots: list[str], base: str) -> Repo:
    repo = Repo()
    files: list[str] = []
    for root in roots:
        abs_root = os.path.join(base, root)
        if os.path.isfile(abs_root) and abs_root.endswith(".dm"):
            files.append(abs_root)
            continue
        if not os.path.isdir(abs_root):
            continue
        for dirpath, dirnames, filenames in os.walk(abs_root):
            dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules", "__pycache__")]
            for fn in filenames:
                if fn.endswith(".dm"):
                    files.append(os.path.join(dirpath, fn))
    for path in files:
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        rel = os.path.relpath(path, base).replace("\\", "/")
        parse_text(text, rel, repo)
        repo.files_scanned += 1
    return repo


# ---------------------------------------------------------------------------
# Hierarchy resolution.
# ---------------------------------------------------------------------------
def ancestors_of(type_path: str, repo: Repo):
    """Yield ancestor type paths nearest-first, honoring explicit parent_type and the
    engine's builtin edges. Stops at /datum (global procs are not inherited)."""
    seen = {type_path}
    current = type_path
    while current:
        explicit = repo.parent_types.get(current)
        if explicit:
            nxt = explicit
        elif current in BUILTIN_PARENTS:
            nxt = BUILTIN_PARENTS[current]
        else:
            head = current.rsplit("/", 1)[0]
            nxt = head if head else ""
        if not nxt or nxt in seen:
            return
        seen.add(nxt)
        yield nxt
        current = nxt


def is_descendant(t: str | None, root: str | None, repo: Repo) -> bool:
    """True if `t` is `root` or inherits from it."""
    if t is None or root is None:
        return False
    if t == root:
        return True
    return root in ancestors_of(t, repo)


def find_root_declaration(d: ProcDef, repo: Repo) -> ProcDef | None:
    """The topmost `/proc/` declaration of this proc in the ancestry - the slot contract
    everyone narrows from."""
    best: ProcDef | None = None
    chain = [d.type_path] + list(ancestors_of(d.type_path, repo))
    for anc in chain:
        for cand in repo.defs.get((anc, d.name), []):
            if cand.is_declaration:
                best = cand
    return best


def pick_parent_def(defs: list[ProcDef]) -> ProcDef:
    """Among #if variants of the same proc at the same type, the widest signature wins.
    That is the false-positive-safe direction for ARITY (a narrower variant would
    manufacture errors)."""
    return max(defs, key=lambda d: (len(d.params), d.is_declaration))


def find_parent(d: ProcDef, repo: Repo) -> ProcDef | None:
    """Resolve the definition that this override's `..()` reaches.

    Checked BEFORE the ancestor walk: a definition of the same proc on the SAME type.
    This fork's `voidcrew/edits/` pattern re-opens an upstream type and redefines the proc
    without `/proc/` (`/turf/ChangeTurf()` against upstream `/turf/proc/ChangeTurf()`).
    Duplicate proc definitions CHAIN in DM - the later .dme include wraps the earlier and
    its `..()` reaches it - so the same-type definition is the real parent. Skipping this
    step reports every shadowing edit in voidcrew/edits/ as an ORPHAN, which is wrong.
    """
    same = [x for x in repo.defs.get((d.type_path, d.name), []) if x is not d]
    declarations = [x for x in same if x.is_declaration]
    if declarations:
        return pick_parent_def(declarations)
    if same:
        return pick_parent_def(same)
    for anc in ancestors_of(d.type_path, repo):
        cands = repo.defs.get((anc, d.name))
        if cands:
            return pick_parent_def(cands)
    return None


# ---------------------------------------------------------------------------
# Checks.
# ---------------------------------------------------------------------------
@dataclass
class Finding:
    category: str
    severity: str
    child: ProcDef
    parent: ProcDef | None
    message: str
    detail: str = ""

    def baseline_key(self) -> str:
        return f"{self.category}|{self.child.type_path}|{self.child.name}"


def names_equivalent(a: str, b: str) -> bool:
    if a == b:
        return True
    la, lb = a.lower(), b.lower()
    if la == lb:
        return True
    if la.lstrip("_") == lb.lstrip("_"):
        return True
    for group in BENIGN_RENAMES:
        if la in group and lb in group:
            return True
    return False


def types_compatible(pt: str | None, ct: str | None, repo: Repo) -> bool:
    """A slot's type is compatible if it is unconstrained on either side, identical, or
    one is an ANCESTOR of the other in the real type tree.

    Real ancestry, not string prefixes: `/obj/item` is a descendant of `/atom` but is not
    a string prefix of it, so a prefix test alone would flag every legitimate narrowing.
    Conversely a wildcard rule that treats `/atom` as "matches anything" would mask the
    flagship bug, where a `/datum/target_priority_strategy` slot is received as `/atom` -
    two SIBLINGS under /datum, which is precisely the mid-list-insertion signature.
    """
    if pt is None or ct is None:
        return True
    p = "/" + pt.strip("/")
    c = "/" + ct.strip("/")
    if p == c:
        return True
    # /datum is the universal base; a slot typed /datum constrains nothing useful.
    if p == "/datum" or c == "/datum":
        return True
    if p in ancestors_of(c, repo) or c in ancestors_of(p, repo):
        return True
    return False


def analyze(repo: Repo, is_in_scope) -> list[Finding]:
    findings: list[Finding] = []
    for (type_path, name), defs in repo.defs.items():
        if not type_path:
            continue  # global procs cannot be overridden
        for d in defs:
            if d.is_declaration:
                continue
            parent = find_parent(d, repo)
            if not is_in_scope(d, parent):
                continue

            if parent is None:
                if name in BUILTIN_PROCS or name.startswith("operator"):
                    continue
                findings.append(
                    Finding(
                        category="ORPHAN",
                        severity=CATEGORY_SEVERITY["ORPHAN"],
                        child=d,
                        parent=None,
                        message=(
                            f"override of {name}() has no declaration anywhere in the "
                            f"ancestry of {type_path} - it never fires"
                        ),
                    )
                )
                continue

            pn, cn = len(parent.fixed), len(d.fixed)

            # Positional comparisons over the overlapping prefix. These decide whether an
            # arity difference is a harmless truncation or a genuine misbind.
            drifted_names: list[str] = []
            lost_defaults: list[str] = []
            bad_types: list[str] = []
            root_decl = find_root_declaration(d, repo)
            for i in range(min(pn, cn)):
                pp, cp = parent.fixed[i], d.fixed[i]
                if not names_equivalent(pp.name, cp.name):
                    drifted_names.append(f"#{i + 1} {pp.name} -> {cp.name}")
                if not types_compatible(pp.normalized_type(), cp.normalized_type(), repo):
                    # Sibling narrowing is not drift. When the ROOT declaration types this
                    # slot generically (`/atom/proc/mouse_drop_receive(atom/dropped, ...)`)
                    # and BOTH the intermediate parent and this override narrow it to their
                    # own expected subtype (/mob/living vs /obj/structure/closet/crate),
                    # they are siblings under the same contract, not a rebind. DM does not
                    # type-check proc args at runtime, so each override just declares what
                    # it expects and guards with istype().
                    root_slot = (
                        root_decl.fixed[i].normalized_type()
                        if root_decl and i < len(root_decl.fixed)
                        else None
                    )
                    sibling_narrowing = (
                        root_slot is not None
                        and is_descendant(pp.normalized_type(), root_slot, repo)
                        and is_descendant(cp.normalized_type(), root_slot, repo)
                    )
                    if not sibling_narrowing:
                        bad_types.append(
                            f"#{i + 1} {pp.normalized_type() or 'untyped'} -> "
                            f"{cp.normalized_type() or 'untyped'} ({pp.name}/{cp.name})"
                        )
                # Only meaningful when the slot genuinely corresponds. If the slot itself
                # drifted, the "missing default" belongs to a different parameter and the
                # message would name the wrong one - that is an ORDER problem, not a
                # defaults problem.
                slot_corresponds = names_equivalent(pp.name, cp.name) and types_compatible(
                    pp.normalized_type(), cp.normalized_type(), repo
                )
                if (
                    slot_corresponds
                    and pp.default is not None
                    and cp.default is None
                    and pp.default.strip() not in FALSY_DEFAULTS
                ):
                    lost_defaults.append(f"#{i + 1} {cp.name} (parent default `{pp.default}`)")

            # TYPE evidence is authoritative for "the slots do not line up". A name-only
            # difference on slots whose types agree (`affected_mob` vs `M`) is a rename,
            # not a rebind, and treating it as an error buries the real signal.
            misbound = bool(bad_types)

            if cn < pn:
                dropped = ", ".join(p.name for p in parent.fixed[cn:])
                if misbound:
                    # Surviving slots do not line up: the params the override DOES read are
                    # receiving the wrong values. This is the pirate-AI / turret shape.
                    findings.append(
                        Finding(
                            category="ARITY_MISBIND",
                            severity=CATEGORY_SEVERITY["ARITY_MISBIND"],
                            child=d,
                            parent=parent,
                            message=(
                                f"declares {cn} params, parent declares {pn}, AND the "
                                f"overlapping slots do not line up "
                                f"({'; '.join(bad_types or drifted_names)}) - the override "
                                f"reads the wrong values; missing [{dropped}]"
                            ),
                        )
                    )
                else:
                    # Bare `..()` forwards the caller's original args regardless of what the
                    # override declares, so the parent still receives everything. The
                    # override is merely BLIND to the tail. Upstream itself does this 1300+
                    # times (Destroy()), so it cannot be an error - but a NEWLY truncated
                    # fork override after a merge is exactly the drift signal we want.
                    findings.append(
                        Finding(
                            category="ARITY_TRUNCATED",
                            severity=CATEGORY_SEVERITY["ARITY_TRUNCATED"],
                            child=d,
                            parent=parent,
                            message=(
                                f"declares {cn} params, parent declares {pn} - override "
                                f"cannot see [{dropped}] (slots that remain do line up"
                                + (f"; renamed {', '.join(drifted_names)}" if drifted_names else "")
                                + ")"
                            ),
                        )
                    )
            elif cn > pn:
                # Measure "extra" against the ROOT /proc/ declaration, not the nearest
                # ancestor. The nearest ancestor is very often itself tail-truncated
                # (`/obj/machinery/process()` against `/datum/proc/process(seconds_per_tick)`),
                # so a fork that correctly restores the ROOT signature was being reported as
                # having "extra" params. And a variadic root accepts any tail at all.
                reference = root_decl or parent
                rn = len(reference.fixed)
                if not reference.variadic and cn > rn:
                    extra = ", ".join(p.name for p in d.fixed[rn:])
                    findings.append(
                        Finding(
                            category="ARITY_EXTRA",
                            severity=CATEGORY_SEVERITY["ARITY_EXTRA"],
                            child=d,
                            parent=reference,
                            message=(
                                f"declares {cn} params, root declaration "
                                f"({reference.file}:{reference.line}) declares {rn} - "
                                f"extra [{extra}]"
                            ),
                        )
                    )

            if bad_types:
                findings.append(
                    Finding(
                        category="ORDER",
                        severity=CATEGORY_SEVERITY["ORDER"],
                        child=d,
                        parent=parent,
                        message="positional type mismatch - " + "; ".join(bad_types),
                    )
                )
            if lost_defaults:
                findings.append(
                    Finding(
                        category="DEFAULTS",
                        severity=CATEGORY_SEVERITY["DEFAULTS"],
                        child=d,
                        parent=parent,
                        message=(
                            "omits a TRUTHY parent default, so callers that skip the arg "
                            "get null instead: " + "; ".join(lost_defaults)
                        ),
                    )
                )
            if drifted_names and not bad_types and cn >= pn:
                findings.append(
                    Finding(
                        category="NAME_DRIFT",
                        severity=CATEGORY_SEVERITY["NAME_DRIFT"],
                        child=d,
                        parent=parent,
                        message="param name drift - " + "; ".join(drifted_names),
                    )
                )
    findings.sort(
        key=lambda f: (-SEVERITY_ORDER[f.severity], f.category, f.child.file, f.child.line)
    )
    return findings


# ---------------------------------------------------------------------------
# Scope predicates.
# ---------------------------------------------------------------------------
def is_fork_file(relpath: str) -> bool:
    p = relpath.replace("\\", "/")
    if p.startswith(FORK_PREFIXES):
        return True
    return bool(FORK_FILE_RE.match(p))


def is_upstream_file(relpath: str) -> bool:
    p = relpath.replace("\\", "/")
    return p.startswith(UPSTREAM_PREFIXES) and not is_fork_file(p)


def make_scope(mode: str):
    if mode == "all":
        return lambda child, parent: True

    def fork_scope(child: ProcDef, parent: ProcDef | None) -> bool:
        if not is_fork_file(child.file):
            return False
        if parent is None:
            return True  # ORPHAN in fork code is always in scope
        return is_upstream_file(parent.file)

    return fork_scope


# ---------------------------------------------------------------------------
# Baseline.
# ---------------------------------------------------------------------------
def load_baseline(path: str) -> set[str]:
    if not os.path.exists(path):
        return set()
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    return {e["key"] for e in data.get("entries", [])}


def write_baseline(path: str, findings: list[Finding], note: str) -> None:
    entries = []
    seen = set()
    for f in sorted(findings, key=lambda x: x.baseline_key()):
        key = f.baseline_key()
        if key in seen:
            continue
        seen.add(key)
        entries.append(
            {
                "key": key,
                "category": f.category,
                "type": f.child.type_path,
                "proc": f.child.name,
                "file": f.child.file,
                "reason": note,
            }
        )
    payload = {
        "_comment": (
            "Allowlist for tools/ci/check_override_signatures.py. Each entry silences one "
            "(category, typepath, proc) triple. NEVER baseline a real signature-drift bug - "
            "fix the override instead. Regenerate with --write-baseline only after triage."
        ),
        "generated_by": "tools/ci/check_override_signatures.py --write-baseline",
        "entries": entries,
    }
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(payload, fh, indent=2)
        fh.write("\n")


# ---------------------------------------------------------------------------
# Reporting.
# ---------------------------------------------------------------------------
COLORS = {"error": "\033[31m", "warning": "\033[33m", "info": "\033[34m"}
RESET = "\033[0m"
ON_GITHUB = os.getenv("GITHUB_ACTIONS") == "true"


def color(sev: str, text: str) -> str:
    if ON_GITHUB or not sys.stdout.isatty():
        return text
    return f"{COLORS.get(sev, '')}{text}{RESET}"


def report(findings: list[Finding], baselined: int, verbose: bool) -> None:
    for f in findings:
        head = f"{f.category} [{f.severity}] {f.child.file}:{f.child.line}"
        if ON_GITHUB and f.severity == "error":
            print(
                f"::error file={f.child.file},line={f.child.line},"
                f"title=Override signature drift ({f.category})::{f.child.type_path}/"
                f"{f.child.name}() {f.message}"
            )
        print(color(f.severity, head))
        print(f"    override  {f.child.signature()}")
        if f.parent:
            print(f"    parent    {f.parent.signature()}")
            print(f"              declared at {f.parent.file}:{f.parent.line}")
        print(f"    -> {f.message}")
        print()


def summarize(findings: list[Finding], baselined: int, elapsed: float, repo: Repo) -> None:
    by_cat: dict[str, int] = {}
    for f in findings:
        by_cat[f.category] = by_cat.get(f.category, 0) + 1
    print("-" * 72)
    print(
        f"scanned {repo.files_scanned} .dm files, "
        f"{sum(len(v) for v in repo.defs.values())} proc definitions, "
        f"{len(repo.parent_types)} explicit parent_type overrides "
        f"in {elapsed:.1f}s"
    )
    if by_cat:
        parts = ", ".join(f"{k}={v}" for k, v in sorted(by_cat.items()))
        print(f"findings: {len(findings)} ({parts})")
    else:
        print("findings: 0")
    print(f"baselined (suppressed): {baselined}")


# ---------------------------------------------------------------------------
# Self-test.
# ---------------------------------------------------------------------------
SELFTEST_UPSTREAM = r'''
// Upstream-shaped fixtures. Everything here lives under a synthetic code/ root.

/atom/proc/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	return TRUE

/datum/bt_node/ai_behavior/acquire_target/proc/should_keep_target(
	datum/ai_controller/controller,
	datum/targeting_strategy/strategy,
	datum/target_priority_strategy/priority_strategy,
	atom/current_target,
	resolved_vision_range,
)
	return TRUE

/obj/machinery/proc/default_deconstruction(obj/item/tool, mob/user, disassembled = TRUE)
	return TRUE

/obj/machinery/proc/only_upstream_has_this(a, b)
	return

/datum/proc/plain(a, b)
	return

/* a block comment with a fake def:
/atom/proc/i_am_not_real(x)
*/

/obj/item/proc/multiline_defaults(
	obj/item/thing,
	list/opts = list("a", "b"),  // trailing comment inside the list
	quiet = FALSE,
)
	return

/obj/effect/proc/verbish(mob/user)
	return

/datum/deleted_parent/proc/gone_upstream(a)
	return

/obj/machinery/proc/falsy_default_user(a, force = FALSE)
	return

/obj/effect/proc/variadic_init(mapload, ...)
	return

/datum/proc/rooted(a, b, c)
	return

/datum/midlayer/rooted(a)
	return
'''

SELFTEST_FORK = r'''
// Fork-shaped fixtures. Everything here lives under a synthetic voidcrew/ root.

// 1. ARITY: the real pre-fix attacked_by shape. MUST be flagged.
/obj/machinery/forkthing/attacked_by(obj/item/attacking_item, mob/living/user)
	return ..()

// 2. ARITY + ORDER: the pirate-AI shape, pre-fix. MUST be flagged.
/datum/bt_node/ai_behavior/acquire_target/aggressive/should_keep_target(
	datum/ai_controller/controller,
	datum/targeting_strategy/strategy,
	atom/current_target,
)
	return TRUE

// 3. DEFAULTS: re-declares disassembled without the parent's = TRUE.
/obj/machinery/forkthing/default_deconstruction(obj/item/tool, mob/user, disassembled)
	return ..()

// 4. NAME_DRIFT only: same count, renamed slot 2, compatible types.
/datum/forkdatum/plain(a, totally_different_name)
	return ..()

// 5. Clean: exact match, must produce nothing.
/obj/item/forkitem/multiline_defaults(
	obj/item/thing,
	list/opts = list("a", "b"),
	quiet = FALSE,
)
	return ..()

// 6. ORPHAN: parent proc no longer exists anywhere.
/datum/deleted_parent/fork_child/proc_that_vanished(a)
	return

// 7. Builtin override, never an ORPHAN.
/obj/machinery/forkthing/Topic(href, href_list)
	return ..()

// 8. ARITY_EXTRA: fork appended an optional tail arg.
/obj/machinery/forkextra/only_upstream_has_this(a, b, c)
	return ..()

// 9. A var declaration with parens must NOT be read as a proc.
/obj/machinery/forkthing/var/list/some_list = list("x", "y")

// 10. parent_type redirection: this type's parent is /obj/machinery, not /obj/weird.
/obj/weird/redirected
	parent_type = /obj/machinery
	name = "redirected"

/obj/weird/redirected/default_deconstruction(obj/item/tool, mob/user)
	return ..()

// 11b. Omitting a FALSY parent default changes nothing, so it must stay silent.
/obj/machinery/forkthing/falsy_default_user(a, force)
	return ..()

// 12. A variadic parent accepts any tail - must NOT be ARITY_EXTRA.
/obj/effect/forkeffect/variadic_init(mapload, extra_one, extra_two)
	return ..()

// 13. Restoring the ROOT signature over a truncated intermediate is NOT "extra".
/datum/midlayer/forkchild/rooted(a, b, c)
	return ..()

// 11. A string containing something that looks like a def must be ignored.
/obj/machinery/forkthing/proc/emit_html()
	var/blob = {"
/atom/proc/fake_from_a_string(x)
"}
	return blob
'''


def run_selftest() -> int:
    import tempfile

    failures: list[str] = []

    def check(cond: bool, label: str) -> None:
        if cond:
            print(f"  ok    {label}")
        else:
            print(f"  FAIL  {label}")
            failures.append(label)

    with tempfile.TemporaryDirectory() as tmp:
        os.makedirs(os.path.join(tmp, "code", "fixtures"))
        os.makedirs(os.path.join(tmp, "voidcrew", "fixtures"))
        with open(os.path.join(tmp, "code", "fixtures", "upstream.dm"), "w", encoding="utf-8") as fh:
            fh.write(SELFTEST_UPSTREAM)
        with open(os.path.join(tmp, "voidcrew", "fixtures", "fork.dm"), "w", encoding="utf-8") as fh:
            fh.write(SELFTEST_FORK)

        repo = collect_repo(["code", "voidcrew"], tmp)
        findings = analyze(repo, make_scope("fork"))

        idx: dict[tuple[str, str], list[Finding]] = {}
        for f in findings:
            idx.setdefault((f.category, f.child.name), []).append(f)

        print("parser self-test")

        # --- lexer ---
        stripped = strip_noise('a = "he said // not a comment" // real\nb = 2\n')
        check("real" not in stripped and "b = 2" in stripped, "line comments stripped, code kept")
        check(
            len(strip_noise("x\n/* a\nb */\ny\n").split("\n")) == 5,
            "block comment preserves line count",
        )
        check(
            "i_am_not_real" not in [d.name for v in repo.defs.values() for d in v],
            "def inside a block comment is not parsed",
        )
        check(
            "fake_from_a_string" not in [d.name for v in repo.defs.values() for d in v],
            'def inside a {"..."} string is not parsed',
        )
        check(
            not any(d.name == "some_list" for v in repo.defs.values() for d in v),
            "var/list declaration with list() is not read as a proc",
        )

        # --- param parsing ---
        ps = parse_param_list('obj/item/thing, list/opts = list("a", "b"), quiet = FALSE')
        check(len(ps) == 3, "commas inside list() defaults do not split params")
        check(ps[0].name == "thing" and ps[0].normalized_type() == "/obj/item", "typed param parsed")
        check(ps[1].default == 'list("a", "b")'.replace('"a"', "   ").replace('"b"', "   ")
              or ps[1].default is not None, "default value captured")
        check(parse_param("var/mob/living/M").name == "M", "var/ prefix stripped")
        check(parse_param("msg as text").name == "msg", "`as text` clause stripped")
        check(parse_param("target as mob in oview(1)").name == "target", "`in` clause stripped")

        # --- multiline heads ---
        skt = repo.defs.get(("/datum/bt_node/ai_behavior/acquire_target", "should_keep_target"))
        check(skt is not None and len(skt[0].params) == 5, "multiline parent param list = 5 params")

        # --- hierarchy ---
        anc = list(ancestors_of("/obj/machinery/forkthing", repo))
        check(
            "/obj/machinery" in anc and "/atom/movable" in anc and "/atom" in anc and "/datum" in anc,
            "builtin edges /obj -> /atom/movable -> /atom -> /datum are walked",
        )
        anc2 = list(ancestors_of("/obj/weird/redirected", repo))
        check("/obj/machinery" in anc2, "explicit parent_type redirects the ancestor walk")

        # --- the checks ---
        check(
            ("ARITY_TRUNCATED", "attacked_by") in idx,
            "ARITY: pre-fix attacked_by (2 vs 4) is FLAGGED",
        )
        ab = idx.get(("ARITY_TRUNCATED", "attacked_by"), [])
        check(
            bool(ab) and "modifiers" in ab[0].message and "attack_modifiers" in ab[0].message,
            "ARITY message names the dropped params",
        )
        check(
            ("ARITY_MISBIND", "should_keep_target") in idx,
            "ARITY_MISBIND: pre-fix should_keep_target (3 vs 5) FLAGGED (the pirate-AI bug)",
        )
        skt_f = idx.get(("ARITY_MISBIND", "should_keep_target"), [])
        check(
            bool(skt_f) and skt_f[0].severity == "error",
            "the pirate-AI shape is severity=error",
        )
        check(
            not any(f.category == "ARITY_MISBIND" for f in idx.get(("ARITY_TRUNCATED", "attacked_by"), [])),
            "aligned tail-truncation is NOT escalated to a misbind",
        )
        check(
            ("ORDER", "should_keep_target") in idx,
            "ORDER: mid-list insertion produces a positional type mismatch",
        )
        check(
            ("DEFAULTS", "default_deconstruction") in idx,
            "DEFAULTS: omitted parent default is flagged",
        )
        check(("NAME_DRIFT", "plain") in idx, "NAME_DRIFT: renamed positional param is flagged")
        check(
            not any(f.category == "DEFAULTS" and f.child.name == "falsy_default_user"
                    for f in findings),
            "DEFAULTS: omitting a FALSY parent default is not reported",
        )
        check(
            ("ORPHAN", "proc_that_vanished") in idx,
            "ORPHAN: override with no ancestor declaration is flagged",
        )
        check(
            ("ARITY_EXTRA", "only_upstream_has_this") in idx,
            "ARITY_EXTRA: fork-appended tail arg is reported as info",
        )
        check(
            parse_param("...") is not None and parse_param("...").is_vararg,
            "DM's `...` vararg marker is parsed, not dropped",
        )
        check(
            not any(f.child.name == "variadic_init" for f in findings),
            "variadic parent (mapload, ...) accepts any tail - no ARITY_EXTRA",
        )
        check(
            not any(f.category == "ARITY_EXTRA" and f.child.name == "rooted" for f in findings),
            "restoring the ROOT signature over a truncated ancestor is not ARITY_EXTRA",
        )
        check(
            not any(f.child.name == "Topic" for f in findings),
            "builtin proc override (Topic) is NOT an ORPHAN",
        )
        check(
            not any(f.child.name == "multiline_defaults" for f in findings),
            "exactly-matching multiline override produces NO finding",
        )
        check(
            not any(f.child.name == "emit_html" for f in findings),
            "fork-declared new proc produces no finding",
        )

        # --- scope control ---
        all_findings = analyze(repo, make_scope("all"))
        check(len(all_findings) >= len(findings), "--all is a superset of fork scope")

        # --- baseline ---
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as bf:
            bpath = bf.name
        try:
            write_baseline(bpath, findings, "selftest")
            keys = load_baseline(bpath)
            remaining = [f for f in findings if f.baseline_key() not in keys]
            check(not remaining, "a generated baseline suppresses every finding it was built from")
        finally:
            os.unlink(bpath)

    print()
    if failures:
        print(f"SELFTEST FAILED: {len(failures)} assertion(s)")
        return 1
    print("SELFTEST PASSED")
    return 0


# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------
def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Parent/override signature-drift lint for DreamMaker code.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--all", action="store_true",
                    help="check every override in the tree, not just fork-over-upstream")
    ap.add_argument("--category", nargs="+", metavar="CAT",
                    choices=sorted(CATEGORY_SEVERITY), help="restrict output to these categories")
    ap.add_argument("--fail-on", choices=["error", "warning", "info", "never"], default="error",
                    help="minimum severity of a non-baselined finding that fails the run")
    ap.add_argument("--baseline", default=BASELINE_PATH, help="path to the allowlist JSON")
    ap.add_argument("--no-baseline", action="store_true", help="ignore the allowlist entirely")
    ap.add_argument("--write-baseline", action="store_true",
                    help="regenerate the allowlist from the current findings (triage first!)")
    ap.add_argument("--json", metavar="PATH", help="also write findings as JSON")
    ap.add_argument("--repo", default=REPO_ROOT, help="repository root to scan")
    ap.add_argument("--quiet", action="store_true", help="summary only")
    ap.add_argument("--selftest", action="store_true", help="run the embedded parser tests")
    args = ap.parse_args(argv)

    if args.selftest:
        return run_selftest()

    start = time.time()
    repo = collect_repo(SOURCE_ROOTS, args.repo)
    findings = analyze(repo, make_scope("all" if args.all else "fork"))
    if args.category:
        findings = [f for f in findings if f.category in args.category]
    elapsed = time.time() - start

    if args.write_baseline:
        write_baseline(args.baseline, findings, "pre-existing at baseline generation; triage pending")
        print(f"wrote {args.baseline} with {len(findings)} entries")
        return 0

    baseline = set() if args.no_baseline else load_baseline(args.baseline)
    kept = [f for f in findings if f.baseline_key() not in baseline]
    suppressed = len(findings) - len(kept)

    if not args.quiet:
        report(kept, suppressed, verbose=False)
    summarize(kept, suppressed, elapsed, repo)

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(
                [
                    {
                        "category": f.category,
                        "severity": f.severity,
                        "type": f.child.type_path,
                        "proc": f.child.name,
                        "file": f.child.file,
                        "line": f.child.line,
                        "override_signature": f.child.signature(),
                        "parent_signature": f.parent.signature() if f.parent else None,
                        "parent_file": f.parent.file if f.parent else None,
                        "parent_line": f.parent.line if f.parent else None,
                        "message": f.message,
                    }
                    for f in kept
                ],
                fh,
                indent=2,
            )

    if args.fail_on == "never":
        return 0
    threshold = SEVERITY_ORDER[args.fail_on]
    fatal = [f for f in kept if SEVERITY_ORDER[f.severity] >= threshold]
    if fatal:
        print(f"\nFAILED: {len(fatal)} non-baselined finding(s) at severity >= {args.fail_on}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
