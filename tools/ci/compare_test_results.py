#!/usr/bin/env python3
"""Compare a unit test run against the expected-failure manifest.

This fork carries a set of tests that are known to fail (mostly map tests that
assume upstream station layouts). CI must not be red forever because of those,
but it also must not hide anything new. This script is the gate:

  * ANY failing test that is not in the manifest  -> exit 1 (new breakage)
  * ANY manifest entry that PASSED               -> exit 1 (stale manifest)
  * manifest entries that were skipped / absent  -> warn only (see --strict-missing)

Usage:
    python tools/ci/compare_test_results.py \
        --results data/unit_tests.json \
        --expected tools/ci/expected_failures.txt

data/unit_tests.json is a dict keyed by unit test type path, e.g.
    {"/datum/unit_test/area_contents": {"status": 1, "message": "..."}}
where status is 0 = passed, 1 = failed, 2 = skipped.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

STATUS_PASSED = 0
STATUS_FAILED = 1
STATUS_SKIPPED = 2

TEST_PREFIX = "/datum/unit_test/"


def normalize(name):
    """Normalize a test identifier so the manifest can be written either way.

    Accepts "/datum/unit_test/area_contents" or bare "area_contents" and
    returns the bare form used for comparison.
    """
    name = name.strip()
    if name.startswith(TEST_PREFIX):
        name = name[len(TEST_PREFIX):]
    return name.strip("/")


def load_expected(path):
    """Read the manifest: one test name per line, hash starts a comment."""
    expected = set()
    original = {}
    if not os.path.exists(path):
        print("::warning::expected-failure manifest not found at %s; "
              "every failure will be treated as new" % path)
        return expected, original
    with open(path, "r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            key = normalize(line)
            if not key:
                continue
            expected.add(key)
            original[key] = line
    return expected, original


def load_results(path):
    if not os.path.exists(path):
        print("::error::test results not found at %s. The server most likely "
              "crashed or timed out before finishing the suite." % path)
        sys.exit(2)
    with open(path, "r", encoding="utf-8") as handle:
        try:
            data = json.load(handle)
        except json.JSONDecodeError as exc:
            print("::error::%s is not valid JSON: %s" % (path, exc))
            sys.exit(2)
    if not isinstance(data, dict):
        print("::error::%s did not contain a JSON object" % path)
        sys.exit(2)
    normalized = {}
    for key, value in data.items():
        if not isinstance(value, dict):
            print("::warning::skipping malformed entry for %s" % key)
            continue
        normalized[normalize(key)] = value
    return normalized


def first_lines(message, limit=12):
    if not message:
        return "(no message recorded)"
    lines = [line.rstrip() for line in str(message).splitlines() if line.strip()]
    if len(lines) > limit:
        lines = lines[:limit] + ["... (%d more lines)" % (len(lines) - limit)]
    return "\n".join(lines)


def write_github_summary(new_failures, stale, expected_absent, results,
                         passed, failed, skipped):
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with open(summary_path, "a", encoding="utf-8") as out:
        out.write("# Unit test gate\n\n")
        out.write("- total: **%d**\n" % len(results))
        out.write("- passed: **%d**\n" % len(passed))
        out.write("- failed: **%d**\n" % len(failed))
        out.write("- skipped: **%d**\n\n" % len(skipped))
        if new_failures:
            out.write("## New failures (%d)\n\n" % len(new_failures))
            for name in new_failures:
                out.write("### %s\n\n```\n" % name)
                out.write(first_lines(results[name].get("message")))
                out.write("\n```\n\n")
        if stale:
            out.write("## Stale manifest entries (%d)\n\n" % len(stale))
            out.write("These passed but are listed as expected failures. "
                      "Remove them from `tools/ci/expected_failures.txt`.\n\n")
            for name in stale:
                out.write("- `%s`\n" % name)
            out.write("\n")
        if expected_absent:
            out.write("## Manifest entries not present in results (%d)\n\n"
                      % len(expected_absent))
            for name in expected_absent:
                out.write("- `%s`\n" % name)
            out.write("\n")
        if not new_failures and not stale:
            out.write("No new failures. Manifest is current.\n")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Diff unit test results against the expected-failure manifest")
    parser.add_argument("--results", default="data/unit_tests.json")
    parser.add_argument("--expected", default="tools/ci/expected_failures.txt")
    parser.add_argument("--strict-missing", action="store_true",
                        help="fail if a manifest entry is absent from the results")
    parser.add_argument("--github-summary", action="store_true",
                        help="also append a markdown report to $GITHUB_STEP_SUMMARY")
    args = parser.parse_args(argv)

    expected, expected_original = load_expected(args.expected)
    results = load_results(args.results)

    passed = set(k for k, v in results.items() if v.get("status") == STATUS_PASSED)
    failed = set(k for k, v in results.items() if v.get("status") == STATUS_FAILED)
    skipped = set(k for k, v in results.items() if v.get("status") == STATUS_SKIPPED)

    new_failures = sorted(failed - expected)
    stale_now_passing = sorted(expected & passed)
    expected_hit = sorted(expected & failed)
    expected_skipped = sorted(expected & skipped)
    expected_absent = sorted(expected - set(results))

    print("=" * 72)
    print("UNIT TEST GATE")
    print("=" * 72)
    print("results manifest : %s" % args.results)
    print("expected manifest: %s" % args.expected)
    print("total tests      : %d" % len(results))
    print("  passed         : %d" % len(passed))
    print("  failed         : %d" % len(failed))
    print("  skipped        : %d" % len(skipped))
    print("expected failures: %d" % len(expected))
    print("")

    if new_failures:
        print("!" * 72)
        print("NEW FAILURES (%d) - not in the manifest, these must be fixed:"
              % len(new_failures))
        print("!" * 72)
        for name in new_failures:
            print("")
            print("--- FAIL %s" % name)
            print(first_lines(results[name].get("message")))
        print("")

    if stale_now_passing:
        print("!" * 72)
        print("STALE MANIFEST ENTRIES (%d) - listed as expected failures but "
              "they PASSED." % len(stale_now_passing))
        print("Remove them from the manifest so real regressions stay visible:")
        print("!" * 72)
        for name in stale_now_passing:
            print("  %s" % expected_original.get(name, name))
        print("")

    if expected_hit:
        print("Known failures still failing (%d):" % len(expected_hit))
        for name in expected_hit:
            print("  %s" % name)
        print("")

    if expected_skipped:
        print("::warning::Manifest entries SKIPPED this run (%d) - usually "
              "map-driven (ignored_unit_tests), not a problem:"
              % len(expected_skipped))
        for name in expected_skipped:
            print("  %s" % name)
        print("")

    if expected_absent:
        level = "error" if args.strict_missing else "warning"
        print("::%s::Manifest entries absent from the results (%d) - renamed "
              "or deleted tests?" % (level, len(expected_absent)))
        for name in expected_absent:
            print("  %s" % expected_original.get(name, name))
        print("")

    if args.github_summary:
        write_github_summary(new_failures, stale_now_passing, expected_absent,
                             results, passed, failed, skipped)

    failing_gate = bool(new_failures) or bool(stale_now_passing)
    if args.strict_missing and expected_absent:
        failing_gate = True

    if failing_gate:
        print("RESULT: FAIL")
        if new_failures:
            print("  %d new failure(s)" % len(new_failures))
        if stale_now_passing:
            print("  %d stale manifest entry/entries" % len(stale_now_passing))
        if args.strict_missing and expected_absent:
            print("  %d manifest entry/entries missing" % len(expected_absent))
        print("")
        print("If a new failure is a genuine, accepted fork difference, add its "
              "name to tools/ci/expected_failures.txt with a comment saying why.")
        return 1

    print("RESULT: PASS (no new failures, manifest is current)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
