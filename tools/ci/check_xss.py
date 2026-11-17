"""Catch player text that reaches HTML output without being escaped.

With --base, only lines a branch adds are reported (CI uses this on pull requests).
Without it, every matching file is scanned, which is useful for an audit.

DM: free text from ui_act params, Topic href_list, raw input() and
tgui_input_text(encode = FALSE) is tracked through local variables in a proc.
It is reported when it reaches chat, browse(), announcements, admin messages,
an atom's name/desc, or a stored text variable, without passing through
html_encode(), sanitize(), strip_html(), reject_bad_text() or a similar helper.

TS/JS: raw HTML sinks (dangerouslySetInnerHTML, innerHTML, html= props, eval and
friends) are reported unless the line runs the value through DOMPurify or
sanitizeText().

Mark a reviewed line with `xss-safe: <reason>` in a comment on that line or the
line above it.
"""

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess
import sys


DM_SUFFIXES = {".dm"}
JS_SUFFIXES = {".ts", ".tsx", ".js", ".jsx"}
DEFAULT_ROOTS = ("voidcrew", "tgui/packages/voidcrew_tgui")
SKIP_PARTS = {"node_modules", ".yarn", "public"}

SUPPRESS = re.compile(r"xss-safe:\s*\S")

# Calls that turn text into something safe, or into something that is not text.
# A value that passes through any call not in PASSTHROUGH counts as clean, so this
# set only documents intent; PASSTHROUGH is what matters.
SANITIZERS = {
    "html_encode", "sanitize", "strip_html", "strip_html_full", "adminscrub",
    "STRIP_HTML_SIMPLE", "STRIP_HTML_FULL", "reject_bad_text", "reject_bad_name",
    "sanitize_name", "stripped_input", "stripped_multiline_input", "url_encode",
    "sanitize_filename", "SANITIZE_FILENAME", "text2num", "text2path", "locate",
}
# Calls that keep text dangerous: their result still holds the raw input.
PASSTHROUGH = {
    "trim", "trim_left", "trim_right", "copytext", "copytext_char", "lowertext",
    "uppertext", "capitalize", "replacetext", "replacetextEx", "replacetext_char",
    "html_decode", "LOWER_TEXT", "UPPER_TEXT", "jointext", "list", "splittext",
    "format_text", "full_capitalize", "examine_block", "boxed_message", "fieldset_block",
    "custom_boxed_message", "conditional_tooltip", "MAPTEXT", "MAPTEXT_TINY_UNICODE",
}

# Output that renders HTML for a player or admin.
SINK_CALLS = (
    "to_chat", "visible_message", "audible_message", "show_message", "message_admins",
    "priority_announce", "minor_announce", "print_command_report", "browse",
    "send_message", "relay_message", "talk_into", "say", "whisper", "me_verb",
    "send2chat", "to_chat_immediate", "admin_ticket_log", "fully_replace_character_name",
    "set_name", "radio_message", "announce", "send_radio_message",
    "ship_notify", "deadchat_broadcast", "brainwash",
)
SINK_CALL_RE = re.compile(r"(?<![\w.])(?:\w+\.)*(" + "|".join(SINK_CALLS) + r")\s*\(")
STREAM_RE = re.compile(r"<<\s*[\"(\w]")
HTML_BUILD_RE = re.compile(r"\b(dat|html|output|body|text|page|content)\s*\+=")
# Variables that hold text shown to players later (name, desc and stored notes).
TEXT_VAR = (
    r"name|real_name|desc|title|label|note|notes|message|msg|motto|reason|description|"
    r"caption|announcement|slogan|callsign|tagline|memo|comment|info|flavor_text|"
    r"maptext|custom_name|display_name|ship_name|crew_name|faction_name|nickname|alias"
)
TEXT_VAR_RE = re.compile(r"(?:^|[._])(?:" + TEXT_VAR + r")$")
ASSIGN_RE = re.compile(r"^\s*(var/(?:\w+/)*)?((?:[\w\]\[\"]+\.)*\w+)\s*(\+?=)\s*(?!=)(.+)$")
# Text that is checked or converted as a number is not text any more.
NUMERIC_RE = re.compile(r"\b(?:isnum|text2num|round|clamp|num2text)\s*\(")

PARAM_SOURCE = re.compile(r"(?<![\w\]])(params|href_list)\s*\[\s*\"[^\"]*\"\s*\]")
INPUT_SOURCE = re.compile(r"(?<![\w.])input\s*\(.*?\)\s*as\s+(?:null\s*\|\s*)?(?:text|message)\b")
TGUI_RAW_SOURCE = re.compile(r"\btgui_input_text\s*\((?=[^\n]*\bencode\s*=\s*(?:FALSE|0)\b)")

JS_RULES = (
    (re.compile(r"dangerouslySetInnerHTML"), "dangerouslySetInnerHTML renders raw HTML"),
    (re.compile(r"\.(?:inner|outer)HTML\s*\+?=(?!=)"), "innerHTML/outerHTML assignment renders raw HTML"),
    (re.compile(r"\binsertAdjacentHTML\s*\("), "insertAdjacentHTML renders raw HTML"),
    (re.compile(r"\bdocument\.write(?:ln)?\s*\("), "document.write renders raw HTML"),
    (re.compile(r"(?<![\w-])html\s*=\s*\{"), "an html= prop renders raw HTML"),
    (re.compile(r"\bjavascript:", re.IGNORECASE), "javascript: URLs run script"),
    (re.compile(r"(?<![\w.])eval\s*\(|\bnew\s+Function\s*\("), "eval/new Function runs strings as code"),
)
JS_CLEAN = re.compile(r"\b(?:DOMPurify\.sanitize|sanitizeText|purify\.sanitize)\s*\(")


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    message: str


MASK = "#"


def mask_dm_line(line: str) -> str:
    """Return the line with its // comment removed and plain string text blanked.

    Interpolated expressions inside strings ("[x]") are kept, since they are code.
    Indexes match the original line, so positions stay valid.
    """
    out = list(line)
    in_string = False
    keep = False
    depth = 0  # [ ] nesting inside a string is code again
    i = 0
    while i < len(line):
        char = line[i]
        if in_string and not depth:
            if char == "\\":
                out[i] = MASK
                if i + 1 < len(line):
                    out[i + 1] = MASK
                i += 2
                continue
            if char == "[":
                depth = 1
            elif char == '"':
                in_string = False
            elif not keep:
                out[i] = MASK
        elif in_string:
            if char == "[":
                depth += 1
            elif char == "]":
                depth -= 1
        else:
            if char == '"':
                in_string = True
                # Keep list keys such as params["name"] readable.
                keep = line[:i].rstrip().endswith("[")
            elif line.startswith("//", i):
                return "".join(out[:i])
        i += 1
    return "".join(out)


def enclosing_calls(text: str, index: int) -> list[str]:
    """Names of the calls whose parentheses enclose text[index], innermost first."""
    names = []
    depth = 0
    i = index - 1
    while i >= 0:
        char = text[i]
        if char == ")":
            depth += 1
        elif char == "(":
            if depth:
                depth -= 1
            else:
                match = re.search(r"([A-Za-z_][\w]*)\s*$", text[:i])
                names.append(match.group(1) if match else "")
        i -= 1
    return names


def is_passthrough(name: str) -> bool:
    return name in PASSTHROUGH or name.startswith("span_") or name in ("", "if", "return")


def stays_raw(text: str, index: int, stop_at_sink: bool) -> bool:
    """True when the value at text[index] comes out of its expression unescaped.

    Walks out through enclosing calls. Passthrough calls and bare parentheses keep
    it raw; a sink call ends the walk with it raw (when stop_at_sink); any other
    call is assumed to clean it or turn it into something that is not text.
    """
    for name in enclosing_calls(text, index):
        if is_passthrough(name):
            continue
        if stop_at_sink and name in SINK_CALLS:
            return True
        return False
    return True


def raw_sources(expr: str, tainted: dict[str, int]):
    """Yield (index, label) for raw player text in expr."""
    for match in PARAM_SOURCE.finditer(expr):
        yield match.start(), match.group(0)
    for match in INPUT_SOURCE.finditer(expr):
        yield match.start(), "input() text"
    for match in TGUI_RAW_SOURCE.finditer(expr):
        yield match.start(), "tgui_input_text(encode = FALSE)"
    for name in tainted:
        for match in re.finditer(r"(?<![\w.])" + re.escape(name) + r"(?![\w(])", expr):
            yield match.start(), name


def raw_in(code: str, start: int, expr: str, tainted, stop_at_sink: bool):
    """First raw source in expr (which starts at code[start]) that stays raw, or None."""
    if NUMERIC_RE.search(expr):
        return None
    # In `cond ? a : b` only the branches are the value.
    question = re.search(r"\s\?\s", expr)
    skip_before = question.end() if question else 0
    for index, label in raw_sources(expr, tainted):
        if index < skip_before:
            continue
        at = start + index
        before = code[:at].rstrip()
        # Used as a list index, the text is a lookup key, not output.
        if before.endswith("[") and re.search(r"[\w\])]\s*\[$", before):
            continue
        if stays_raw(code, at, stop_at_sink):
            return label
    return None


def is_sink_line(code: str) -> bool:
    return bool(SINK_CALL_RE.search(code) or STREAM_RE.search(code) or HTML_BUILD_RE.search(code))


def proc_arguments(code: str) -> set[str]:
    match = re.search(r"\((.*)\)", code)
    if not match:
        return set()
    names = set()
    for argument in match.group(1).split(","):
        argument = argument.split("=")[0].strip()
        found = re.search(r"(\w+)\s*$", argument)
        if found:
            names.add(found.group(1))
    return names


def membership_checked(code: str, tainted) -> set[str]:
    """Names (or params keys) tested with `in`, which means checked against a list."""
    checked = set()
    for match in re.finditer(r"((?:params|href_list)\s*\[\s*\"[^\"]*\"\s*\]|\b\w+)\s+in\s", code):
        checked.add(re.sub(r"\s+", "", match.group(1)))
    return checked


def scan_dm(path: str, text: str) -> list[Finding]:
    findings = []
    tainted: dict[str, int] = {}  # local name -> line it was tainted on
    local_names: set[str] = set()
    lines = text.splitlines()
    for number, raw_line in enumerate(lines, start=1):
        if raw_line and not raw_line[0].isspace():
            # A new proc or type definition starts.
            tainted.clear()
            local_names = proc_arguments(raw_line)
            continue
        code = mask_dm_line(raw_line)
        if not code.strip():
            continue
        suppressed = SUPPRESS.search(raw_line) or (number > 1 and SUPPRESS.search(lines[number - 2]))

        # Checking a value with a sanitizer, in place or in an if(), cleans it,
        # and so does testing it against a list.
        checked = membership_checked(code, tainted)
        for name in list(tainted):
            if name in checked:
                del tainted[name]
                continue
            for call in re.finditer(r"\b(\w+)\s*\(\s*" + re.escape(name) + r"\b", code):
                if call.group(1) in SANITIZERS:
                    del tainted[name]
                    break

        assign = ASSIGN_RE.match(code)
        if assign:
            declared, target, operator, rhs = assign.groups()
            start = assign.start(4)
            if declared:
                local_names.add(target)
            # A local typed as an object (var/obj/x, var/datum/x) does not hold text.
            if declared and declared not in ("var/", "var/list/") and not declared.startswith("var/list/"):
                tainted.pop(target, None)
                continue
            if "." not in target and target in local_names:
                label = raw_in(code, start, rhs, tainted, stop_at_sink=False)
                if label and re.sub(r"\s+", "", label) not in checked:
                    tainted.setdefault(target, tainted.get(label, number))
                elif operator == "=" and not re.search(r"(?<![\w.])" + re.escape(target) + r"(?![\w(])", rhs):
                    tainted.pop(target, None)
                if not is_sink_line(code):
                    continue
            elif TEXT_VAR_RE.search(target):
                label = raw_in(code, start, rhs, tainted, stop_at_sink=False)
                if label and not suppressed:
                    origin = f" (from line {tainted[label]})" if label in tainted else ""
                    findings.append(Finding(path, number, (
                        f"{label}{origin} is stored in {target} without escaping. "
                        "Encode it where it comes in (html_encode, sanitize, reject_bad_text, "
                        "or tgui_input_text with encode on)."
                    )))
                continue

        if not is_sink_line(code):
            continue
        label = raw_in(code, 0, code, tainted, stop_at_sink=True)
        if label and not suppressed:
            origin = f" (from line {tainted[label]})" if label in tainted else ""
            findings.append(Finding(path, number, (
                f"{label}{origin} reaches HTML output without escaping. "
                "Wrap it in html_encode() or sanitize(), or encode it where it comes in."
            )))
    return findings


def scan_js(path: str, text: str) -> list[Finding]:
    findings = []
    lines = text.splitlines()
    for number, line in enumerate(lines, start=1):
        if SUPPRESS.search(line) or (number > 1 and SUPPRESS.search(lines[number - 2])):
            continue
        if JS_CLEAN.search(line):
            continue
        for pattern, message in JS_RULES:
            if pattern.search(line):
                findings.append(Finding(path, number, (
                    f"{message}. Render text as children, or pass it through DOMPurify.sanitize()."
                )))
                break
    return findings


def scan_file(path: Path, display: str) -> list[Finding]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        return [Finding(display, 1, f"cannot read file: {error}")]
    if path.suffix in DM_SUFFIXES:
        return scan_dm(display, text)
    if path.suffix in JS_SUFFIXES:
        return scan_js(display, text)
    return []


def wanted(path: str) -> bool:
    parts = set(Path(path).parts)
    if parts & SKIP_PARTS:
        return False
    suffix = Path(path).suffix
    if suffix in JS_SUFFIXES:
        name = Path(path).name
        return path.startswith("tgui/") and ".test." not in name and ".stories." not in name
    return suffix in DM_SUFFIXES


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True, encoding="utf-8"
    ).stdout


def added_lines(base: str) -> dict[str, set[int]]:
    """Lines added in the working tree since the merge base with `base`."""
    merge_base = git("merge-base", base, "HEAD").strip()
    diff = git("diff", "--unified=0", "--no-color", "--diff-filter=AMR", "-M", merge_base)
    added: dict[str, set[int]] = {}
    current = None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            target = line[4:]
            current = target[2:] if target.startswith("b/") else None
            if current is not None:
                added.setdefault(current, set())
        elif line.startswith("@@") and current is not None:
            match = re.search(r"\+(\d+)(?:,(\d+))?", line)
            start, count = int(match.group(1)), int(match.group(2) or 1)
            added[current].update(range(start, start + count))
    return {path: lines for path, lines in added.items() if lines and wanted(path)}


def all_files(roots) -> list[str]:
    files = []
    for root in roots:
        root_path = Path(root)
        candidates = [root_path] if root_path.is_file() else root_path.rglob("*")
        for path in candidates:
            display = path.as_posix()
            if path.is_file() and wanted(display):
                files.append(display)
    return sorted(files)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", help=f"Files or folders to scan in full (default: {', '.join(DEFAULT_ROOTS)})")
    parser.add_argument("--base", help="Only report lines added since the merge base with this ref")
    parser.add_argument("--github", action="store_true", help="Emit GitHub error annotations")
    args = parser.parse_args(argv)

    if args.base:
        try:
            changed = added_lines(args.base)
        except subprocess.CalledProcessError as error:
            print(f"Cannot diff against {args.base}: {error.stderr.strip()}")
            return 2
        findings = [
            finding
            for path, lines in sorted(changed.items())
            for finding in scan_file(Path(path), path)
            if finding.line in lines
        ]
        scope = f"{len(changed)} changed files"
    else:
        files = all_files(args.paths or DEFAULT_ROOTS)
        findings = [finding for path in files for finding in scan_file(Path(path), path)]
        scope = f"{len(files)} files"

    for finding in findings:
        if args.github:
            print(f"::error file={finding.path},line={finding.line}::{finding.message}")
        else:
            print(f"{finding.path}:{finding.line}: {finding.message}")
    if findings:
        print(
            f"\n{len(findings)} possible XSS issue(s) in {scope}. If a line is safe, say why "
            "with an `xss-safe: <reason>` comment on it or the line above."
        )
        return 1
    print(f"Checked {scope}: no unescaped player text reaches HTML output.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
