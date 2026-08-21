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

echo ">> Compiling: build.bat dm -DCIBUILDING"
compile_ok=0
for attempt in 1 2 3 4 5; do
	if cmd //c "tools\\build\\build.bat dm -DCIBUILDING"; then
		compile_ok=1
		break
	fi
	echo ">> Compile attempt $attempt failed. If the errors are 'icons/map_icons/... invalid"
	echo ">> expression', the sprite pipeline is rewriting .dmis (trap #8), retrying in 75s..."
	sleep 75
done
if [ "$compile_ok" -ne 1 ]; then
	echo ">> Compile failed after 5 attempts. Wait for the sprite pipeline to finish and retry."
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
