#!/usr/bin/env bash
# Runs the full unit test suite locally on Windows and prints a failure summary.
# See docs/UNIT_TESTING_LOCAL.md for why things are done this way (read it first).
#
# Usage (from repo root, Git Bash):
#   tools/run_unit_tests_local.sh [port=1342] [boot_timeout_min=25] [suite_timeout_min=25]
#
# Exit codes: 0 = clean run (clean_run.lk written), 1 = suite finished with failures
# (or compile failed), 2 = timed out / suite never completed.

set -u
cd "$(dirname "$0")/.."

PORT="${1:-1342}"
BOOT_TIMEOUT_MIN="${2:-25}"
SUITE_TIMEOUT_MIN="${3:-75}"
DD='C:\Program Files (x86)\BYOND\bin\dd.exe'
CI_LOGS="data/logs/ci"
JSON="data/unit_tests.json"
LOCKFILE="$CI_LOGS/clean_run.lk"

kill_world() {
	echo ">> Killing the DreamDaemon holding port $PORT:"
	netstat -ano | grep "LISTENING" | grep ":$PORT " | awk '{print $5}' | sort -u | while read -r pid; do
		taskkill //PID "$pid" //F
	done
}

# --- Pre-flight: parent/override signature-drift lint (WARN-ONLY) -------------------
# Deliberately placed BEFORE the compile rather than at the end of this file: every exit
# path of the suite wait-loop below returns from inside that loop, so a stanza appended
# to the end of this script would be unreachable. Running it here also fails fast, before
# a 45-90 minute suite.
#
# What it catches: upstream changes a proc's parameter list, a fork override still
# declares the OLD list, DM binds positionally, and the override silently reads the wrong
# values. That shipped: pirate AI went inert this upgrade on exactly this. DM
# cannot express the check itself (no reflection over parameter lists; #pragma
# InvalidOverride only fires when the parent proc is absent entirely), so it is a static
# script.
#
# This NEVER fails the test run - it only prints. Standalone invocation:
#   python tools/ci/check_override_signatures.py            # fork-vs-upstream
#   python tools/ci/check_override_signatures.py --all      # whole tree
#   python tools/ci/check_override_signatures.py --selftest # parser unit tests
SIG_LINT="tools/ci/check_override_signatures.py"
PYTHON_BIN=""
for candidate in python python3 py; do
	if command -v "$candidate" >/dev/null 2>&1; then
		PYTHON_BIN="$candidate"
		break
	fi
done
if [ -z "$PYTHON_BIN" ]; then
	echo ">> [signature lint] SKIPPED: no python on PATH (this does not affect the suite)."
elif [ ! -f "$SIG_LINT" ]; then
	echo ">> [signature lint] SKIPPED: $SIG_LINT not found."
else
	echo ">> [signature lint] Checking fork overrides against upstream proc signatures..."
	if "$PYTHON_BIN" "$SIG_LINT"; then
		echo ">> [signature lint] clean (no non-baselined errors)."
	else
		echo ">> [signature lint] ^^ NON-BASELINED FINDINGS ABOVE - warn-only, the suite continues."
		echo ">> [signature lint] Each is a silent positional-rebind risk. Fix the override, or"
		echo ">> [signature lint] add it to tools/ci/override_signatures_baseline.json if intended."
	fi
fi

echo ">> Compiling: build.bat dm -DCIBUILDING -DRUNNING_LOCAL_TESTS"
compile_ok=0
for attempt in 1 2 3 4 5; do
	if cmd //c "tools\\build\\build.bat dm -DCIBUILDING -DRUNNING_LOCAL_TESTS"; then
		compile_ok=1
		break
	fi
	echo ">> Compile attempt $attempt failed. If the errors are 'icons/map_icons/... invalid"
	echo ">> expression', something is rewriting .dmis (trap #8), retrying in 75s..."
	sleep 75
done
if [ "$compile_ok" -ne 1 ]; then
	echo ">> Compile failed after 5 attempts. Make sure nothing else is rewriting .dmis, then retry."
	exit 1
fi

# Clean stale CI logs so fresh files are a reliable signal of this run's progress.
rm -rf "$CI_LOGS"
JSON_BEFORE=0
[ -f "$JSON" ] && JSON_BEFORE=$(stat -c %Y "$JSON")

echo ">> Launching DreamDaemon on port $PORT (detached, minimized)."
echo ">> Do NOT close the DreamDaemon window and do NOT connect a client to it."
cmd //c start "" //min //low "$DD" tgstation.dmb -port "$PORT" -close -trusted -invisible -params "log-directory=ci"

echo ">> Phase 1: waiting for the world to boot (up to ${BOOT_TIMEOUT_MIN}m; can be slow under load, trap #9)..."
BOOT_START=$(date +%s)
while [ ! -f "$CI_LOGS/game.log" ]; do
	if [ $(($(date +%s) - BOOT_START)) -gt $((BOOT_TIMEOUT_MIN * 60)) ]; then
		echo ">> TIMEOUT: world never reached logging (boot stall). Nothing was logged to $CI_LOGS."
		kill_world
		exit 2
	fi
	sleep 15
done

echo ">> World booted. Phase 2: waiting for the suite (up to ${SUITE_TIMEOUT_MIN}m; ~45m idle-machine - create_and_destroy alone runs ~27m)..."
SUITE_START=$(date +%s)
while true; do
	if [ -f "$LOCKFILE" ]; then
		echo ">> clean_run.lk written: PASS (zero failures, zero runtimes)."
		exit 0
	fi
	if [ -f "$JSON" ] && [ "$(stat -c %Y "$JSON")" -gt "$JSON_BEFORE" ]; then
		echo ">> Suite finished, but the run was NOT clean."
		python - <<'EOF'
import json
with open("data/unit_tests.json") as f:
	data = json.load(f)
passed = sum(1 for v in data.values() if v["status"] == 0)
failed = {k: v for k, v in data.items() if v["status"] == 1}
print(f">> {passed} passed, {len(failed)} failed")
for k, v in failed.items():
	n = (v["message"] or "").count("FAILURE")
	first = (v["message"] or "").split("\n")[0].strip()[:140]
	print(f"   FAIL {k.replace('/datum/unit_test/', '')}: {n} failure(s) | {first}")
EOF
		echo ">> (FinishTestRun also fails the run on ANY runtime; see docs/UNIT_TESTING_LOCAL.md)"
		exit 1
	fi
	if [ $(($(date +%s) - SUITE_START)) -gt $((SUITE_TIMEOUT_MIN * 60)) ]; then
		echo ">> TIMEOUT: suite never completed. A test may be stuck in a sleep loop."
		kill_world
		echo ">> For live output next time, see the world.log redirect trick in docs/UNIT_TESTING_LOCAL.md (trap #1)."
		exit 2
	fi
	sleep 20
done
