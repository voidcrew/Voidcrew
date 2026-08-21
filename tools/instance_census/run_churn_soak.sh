#!/usr/bin/env bash
# Planet-packing + content-zoo memory churn soak: compile, run headless, print the verdict.
#
# Usage (from anywhere, Git Bash):
#   tools/instance_census/run_churn_soak.sh                       # the short 4-cycle answer
#   SOAK_OVERNIGHT=1 SOAK_BUDGET_MIN=480 tools/instance_census/run_churn_soak.sh
#
# Environment overrides:
#   DM_EXE              path to dm.exe   (default: C:/Program Files (x86)/BYOND/bin/dm.exe)
#   DD_EXE              path to dd.exe   (default: C:/Program Files (x86)/BYOND/bin/dd.exe)
#   SOAK_PORT           world port       (default: 5597 - deliberately NOT 2599 and not the
#                                         unit-test range, so a suite run can share the box)
#   SOAK_NAME           scratch build basename (default: soakcheck). Give a concurrent run
#                       its own name and it gets its own .dmb/.rsc and its own PID match.
#   SOAK_CYCLES         build/teardown cycles (default: the compile-time default, 10).
#                       Ignored in overnight mode, which is bounded by the clock.
#   SOAK_OVERNIGHT      1 = run until SOAK_BUDGET_MIN is spent instead of a cycle count
#   SOAK_BUDGET_MIN     the harness's own wall budget in minutes (default: 35, or 480 when
#                       SOAK_OVERNIGHT=1). The script's timeout is this + SOAK_GRACE_MIN.
#   SOAK_GRACE_MIN      how long past the harness budget the script waits (default: 60)
#   SOAK_CENSUS_EVERY   NDJSON census snapshot every N cycles (default: 1, or 5 overnight)
#   SOAK_ZOO            0 to run map zones only (no ships/ruins/fields/arenas/weather)
#   SOAK_MEM_INTERVAL   seconds between memory samples (default: 20)
#   SOAK_KEEP_DD        1 = do NOT kill DreamDaemon when this script exits. Set it for a
#                       detached overnight run: if the babysitter is killed, the soak must
#                       not die with it. The harness qdel(world)s itself at its verdict
#                       either way, so the kill is only ever a safety net.
#   DM_DEFINES          extra dm.exe flags, e.g. "-DCBT" if a concurrent sprite pipeline is
#                       rewriting .dmi files and the compile reports bogus icon errors
#
# Exit codes: 0 = PASS, 1 = FAIL (verdict said FAIL, or the compile failed), 2 = the run
# never produced a verdict (timeout / crash).
#
# A CRASH IS A RESULT. If DreamDaemon dies mid-run - which on a 32-bit world usually means
# it walked into the 4 GB address-space wall - the script preserves the soak log and the
# memory CSV, writes a CRASHED summary naming the last sample and the last virtMB reading
# into the soak log, and exits 2. That is a successful overnight test with data, not a
# wasted night, and it is the single most likely way this run ends usefully.
#
# The soak log and the memory CSV are NEVER deleted. Everything else the run creates is.

set -u
cd "$(dirname "$0")/../.."

DM_EXE="${DM_EXE:-C:/Program Files (x86)/BYOND/bin/dm.exe}"
DD_EXE="${DD_EXE:-C:/Program Files (x86)/BYOND/bin/dd.exe}"
PORT="${SOAK_PORT:-5597}"
NAME="${SOAK_NAME:-soakcheck}"
BOOT_MIN="${SOAK_BOOT_MIN:-25}"
DM_DEFINES="${DM_DEFINES:-}"
OVERNIGHT="${SOAK_OVERNIGHT:-0}"
GRACE_MIN="${SOAK_GRACE_MIN:-60}"
MEM_INTERVAL="${SOAK_MEM_INTERVAL:-20}"
KEEP_DD="${SOAK_KEEP_DD:-0}"

if [ "$OVERNIGHT" = "1" ]; then
	BUDGET_MIN="${SOAK_BUDGET_MIN:-480}"
	CENSUS_EVERY="${SOAK_CENSUS_EVERY:-5}"
else
	BUDGET_MIN="${SOAK_BUDGET_MIN:-35}"
	CENSUS_EVERY="${SOAK_CENSUS_EVERY:-1}"
fi
# The script must always outlive the harness's own budget, or it reaps a run that was still
# working and throws away the verdict it was thirty seconds from writing.
TIMEOUT_MIN="${SOAK_TIMEOUT_MIN:-$((BUDGET_MIN + GRACE_MIN))}"

STAMP="$(date +%Y%m%d-%H%M%S)"
SOAK_LOG="data/churn_soak_${STAMP}.log"
MEM_CSV="data/churn_soak_${STAMP}_mem.csv"
LOG_DIR_NAME="churn_soak_${STAMP}"
DME="${NAME}.dme"
DMB="${NAME}.dmb"
LAUNCHER="${NAME}.launch.bat"
INCLUDE_LINE='#include "tools\instance_census\churn_soak.dm"'

DD_PID=""

# dd.exe is not findable by image name alone (several BYOND processes share it, a unit test
# suite may be running in the same tree, and the owner may be playing from a sibling
# worktree), so the PID is resolved by matching the command line against THIS run's own
# .dmb. Nothing in this script ever kills a process it did not identify that way.
find_dd_pid() {
	powershell -NoProfile -NonInteractive -Command \
		"Get-CimInstance Win32_Process | Where-Object { \$PSItem.Name -eq 'dd.exe' -and \$PSItem.CommandLine -like '*${DMB}*' } | ForEach-Object { \$PSItem.ProcessId }" \
		2>/dev/null | tr -d "\r" | head -n 1
}

# Same discipline for the sampler: it is identified by the sampler script's name AND by
# the CSV path, which carries this run's timestamp and so cannot match anybody else's
# sampler. `-ne $PID` is load-bearing - without it this query matches ITSELF, because its
# own command line necessarily contains both strings it is searching for, and the taskkill
# below would shoot the query instead of the sampler.
find_sampler_pid() {
	powershell -NoProfile -NonInteractive -Command \
		"Get-CimInstance Win32_Process | Where-Object { \$PSItem.Name -eq 'powershell.exe' -and \$PSItem.ProcessId -ne \$PID -and \$PSItem.CommandLine -like '*sample-dd-mem.ps1*' -and \$PSItem.CommandLine -like '*${MEM_CSV##*/}*' } | ForEach-Object { \$PSItem.ProcessId }" \
		2>/dev/null | tr -d "\r" | head -n 1
}

kill_dd() {
	if [ "$KEEP_DD" = "1" ]; then
		return
	fi
	local pid
	pid="$(find_dd_pid)"
	if [ -n "$pid" ]; then
		echo ">> Killing DreamDaemon PID $pid (${DMB})"
		taskkill //PID "$pid" //F >/dev/null 2>&1
	fi
}

# Ignores SOAK_KEEP_DD. Only used for the ghost-run case: a world that has rebooted under us
# is not the run we were asked to keep alive, and leaving it churning burns the box all night.
kill_dd_force() {
	local pid
	pid="$(find_dd_pid)"
	if [ -n "$pid" ]; then
		echo ">> Killing the REBOOTED DreamDaemon PID $pid (${DMB})"
		taskkill //PID "$pid" //F >/dev/null 2>&1
	fi
}

kill_sampler() {
	local pid
	pid="$(find_sampler_pid)"
	if [ -n "$pid" ]; then
		echo ">> Stopping memory sampler PID $pid"
		taskkill //PID "$pid" //F >/dev/null 2>&1
	fi
}

cleanup_build() {
	rm -f "${NAME}.dme" "${NAME}.dmb" "${NAME}.rsc" "${NAME}.int" "${NAME}.lk" \
		"${NAME}.dyn.rsc" "${NAME}.launch.bat" "${NAME}.m.dmb" 2>/dev/null
}

trap 'kill_sampler; kill_dd; sleep 3; cleanup_build' EXIT

if [ ! -f "tgstation.dme" ]; then
	echo ">> Not in the repo root (no tgstation.dme). Aborting."
	exit 1
fi
if [ ! -f "tools/instance_census/churn_soak.dm" ]; then
	echo ">> tools/instance_census/churn_soak.dm is missing. Aborting."
	exit 1
fi

# --- 1. Build a scratch dme -----------------------------------------------------------
# A separate dme name, never tgstation.dme: concurrent compiles corrupt each other's .rsc,
# and the harness must not end up in a normal build by accident. The include goes LAST so
# its duplicate /world/New() and /world/RunUnattendedFunctions() chain outermost.
echo ">> Preparing $DME (tgstation.dme + churn_soak.dm)"
cleanup_build
cp tgstation.dme "$DME" || exit 1
printf '\n// churn soak harness - appended by tools/instance_census/run_churn_soak.sh\n%s\n' "$INCLUDE_LINE" >> "$DME"

echo ">> Compiling: dm.exe ${DM_DEFINES} $DME  (this takes a few minutes)"
COMPILE_OUT="$(mktemp)"
# shellcheck disable=SC2086
"$DM_EXE" $DM_DEFINES "$DME" > "$COMPILE_OUT" 2>&1
tail -n 20 "$COMPILE_OUT"
# dm.exe's last line is "<name>.dmb - N errors, M warnings"; anything but zero errors means
# no usable .dmb, and a stale .dmb from an earlier run would otherwise look like success
# (cleanup_build above deleted it, but be explicit).
if [ ! -f "$DMB" ] || ! grep -q -- "- 0 errors" "$COMPILE_OUT"; then
	echo ">> Compile FAILED. Full output above. (If the errors name icons/map_icons/*, the"
	echo ">> sprite pipeline is rewriting .dmi files - retry, or set DM_DEFINES=-DCBT.)"
	rm -f "$COMPILE_OUT"
	exit 1
fi
rm -f "$COMPILE_OUT"
echo ">> Compile OK."

# --- 2. Launch DreamDaemon detached ----------------------------------------------------
# Detached and via a generated .bat: an attached launch can stall at ~22 MB before
# world/New() with no error, and the -params string contains '&', which cmd would otherwise
# read as a command separator. The .bat quotes it properly.
if command -v cygpath >/dev/null 2>&1; then
	DD_WIN="$(cygpath -w "$DD_EXE")"
else
	DD_WIN="$(printf '%s' "$DD_EXE" | sed 's|/|\\|g')"
fi

PARAMS="churn-soak-log=${SOAK_LOG}&log-directory=${LOG_DIR_NAME}"
PARAMS="${PARAMS}&churn-soak-budget-min=${BUDGET_MIN}"
PARAMS="${PARAMS}&churn-soak-census-every=${CENSUS_EVERY}"
PARAMS="${PARAMS}&churn-soak-overnight=${OVERNIGHT}"
if [ -n "${SOAK_ZOO:-}" ]; then
	PARAMS="${PARAMS}&churn-soak-zoo=${SOAK_ZOO}"
fi
if [ -n "${SOAK_CYCLES:-}" ]; then
	PARAMS="${PARAMS}&churn-soak-cycles=${SOAK_CYCLES}"
fi

{
	printf '@echo off\r\n'
	printf 'start "" /min /low "%s" %s -port %s -close -trusted -invisible -params "%s"\r\n' \
		"$DD_WIN" "$DMB" "$PORT" "$PARAMS"
} > "$LAUNCHER"

mkdir -p data
rm -f "$SOAK_LOG" data/churn_soak_dd.log

echo ">> Launching DreamDaemon on port $PORT (detached, minimized)."
echo ">> Mode:      $([ "$OVERNIGHT" = "1" ] && echo "OVERNIGHT, ${BUDGET_MIN}m budget" || echo "fixed-cycle, ${BUDGET_MIN}m budget")"
echo ">> Do NOT close the DreamDaemon window and do NOT connect a client to it."
echo ">> Soak log:  $SOAK_LOG"
echo ">> Memory:    $MEM_CSV"
echo ">> World log: data/churn_soak_dd.log"
echo ">> Census:    data/logs/${LOG_DIR_NAME}/instance_census.ndjson"
# An absolute Windows path, not the bare name: cmd resolves a bare argument against PATH
# (and its own idea of the working directory), which under Git Bash is not this repo, so
# `cmd //c soakcheck.launch.bat` fails with "is not recognized as an internal or external
# command" and the world never starts.
if command -v cygpath >/dev/null 2>&1; then
	LAUNCHER_WIN="$(cygpath -w "$PWD/$LAUNCHER")"
else
	LAUNCHER_WIN="$(printf '%s' "$PWD/$LAUNCHER" | sed 's|/|\\|g')"
fi
cmd //c "$LAUNCHER_WIN"

# --- 3. Attach the memory sampler ------------------------------------------------------
# virtMB (VirtualMemorySize64) is the number that hits the 4 GB wall on a 32-bit
# DreamDaemon; working set and private bytes are both misleading here. The sampler is
# pinned to THIS world's PID, so a suite run or the owner's own game cannot be sampled by
# accident, and it exits by itself the moment that PID goes away.
echo ">> Waiting for the DreamDaemon PID..."
for _ in $(seq 1 30); do
	DD_PID="$(find_dd_pid)"
	[ -n "$DD_PID" ] && break
	sleep 2
done
if [ -n "$DD_PID" ]; then
	echo ">> DreamDaemon PID $DD_PID; starting the memory sampler (${MEM_INTERVAL}s)."
	powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass \
		-File tools/instance_census/sample-dd-mem.ps1 \
		-ProcessId "$DD_PID" -OutFile "$MEM_CSV" -IntervalSeconds "$MEM_INTERVAL" \
		>/dev/null 2>&1 &
else
	echo ">> WARNING: could not resolve the DreamDaemon PID - running without memory sampling."
fi

# --- 4. Wait for the world to say something --------------------------------------------
echo ">> Phase 1: waiting for the world to boot (up to ${BOOT_MIN}m)..."
BOOT_START=$(date +%s)
while [ ! -f "$SOAK_LOG" ]; do
	if [ $(($(date +%s) - BOOT_START)) -gt $((BOOT_MIN * 60)) ]; then
		echo ">> TIMEOUT: the world never reached SSchurn_soak's Initialize."
		echo ">> Check data/churn_soak_dd.log (the world.log redirect) for how far it got."
		[ -f data/churn_soak_dd.log ] && tail -n 40 data/churn_soak_dd.log
		exit 2
	fi
	if [ -z "$(find_dd_pid)" ] && [ $(($(date +%s) - BOOT_START)) -gt 60 ]; then
		echo ">> DreamDaemon is not running and no soak log was written - the world died on boot."
		[ -f data/churn_soak_dd.log ] && tail -n 40 data/churn_soak_dd.log
		exit 2
	fi
	sleep 10
done
echo ">> World booted, soak log is live."

# --- 5. Poll for the verdict -----------------------------------------------------------
echo ">> Phase 2: waiting for the verdict (up to ${TIMEOUT_MIN}m)..."
RUN_START=$(date +%s)
LAST_SHOWN=""

# The last virtMB reading in the CSV, or empty. Used by the crash summary.
last_virt_mb() {
	[ -f "$MEM_CSV" ] || return
	awk -F, 'NR > 1 && $4 != "" { v = $4 } END { if (v != "") print v }' "$MEM_CSV"
}

# first / peak / last virtMB and the slope over the final half of the run, as MB/hour.
# Reported, never a hard gate: BYOND's arena quantization makes a VM figure wobble by tens
# of megabytes between identical states, so a positive slope is a lead to follow with the
# instance census, not a verdict on its own. The instance counters are the hard gates.
write_memory_report() {
	[ -f "$MEM_CSV" ] || return
	local report
	report="$(awk -F, '
		NR > 1 && $4 != "" {
			n++
			t[n] = $3 + 0      # uptime minutes
			v[n] = $4 + 0      # virtual MB
			if (n == 1 || v[n] > peak) peak = v[n]
		}
		END {
			if (n < 2) { print "REPORT memory: only " n " sample(s) - nothing to trend"; exit }
			first = v[1]; last = v[n]
			half = int(n / 2); if (half < 1) half = 1
			cnt = 0; sx = 0; sy = 0; sxy = 0; sxx = 0
			for (i = half; i <= n; i++) {
				cnt++; sx += t[i]; sy += v[i]; sxy += t[i] * v[i]; sxx += t[i] * t[i]
			}
			den = (cnt * sxx) - (sx * sx)
			slope = (den == 0) ? 0 : ((cnt * sxy) - (sx * sy)) / den   # MB per minute
			hours = (t[n] - t[1]) / 60
			printf "REPORT memory (ADVISORY, not a gate): virtMB first %.0f, last %.0f, peak %.0f of 4096 (%.1f%% of the wall); %.1f h of samples; growth %+.0f MB total, %+.1f MB/h over the run, %+.1f MB/h over the final half (%d samples)\n", \
				first, last, peak, peak / 4096 * 100, hours, last - first, \
				(hours > 0 ? (last - first) / hours : 0), slope * 60, cnt
		}
	' "$MEM_CSV")"
	[ -n "$report" ] || return
	echo "$report"
	# Into the soak log too, so the transcript is self-contained tomorrow morning.
	printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$report" >> "$SOAK_LOG"
}

while true; do
	if grep -q "CHURN SOAK VERDICT:" "$SOAK_LOG" 2>/dev/null; then
		break
	fi

	# An unexpected reboot is a RUN END, never a restart. The harness's /world/Reboot()
	# override turns one into a verdict + shutdown, so the branch above normally catches it
	# first - but if that override is ever bypassed (a hard reboot, a crash-and-relaunch, a
	# second world booting on the same params), the log grows a second boot banner and a
	# ghost soak starts churning on top of the run we care about. Overnight of 2026-08-19
	# lost seven hours to exactly that. Treat it as the end of THIS run: stop the sampler,
	# preserve everything, and say plainly that the numbers past the second banner belong to
	# a different world.
	BOOTS="$(grep -c "=== CHURN SOAK: boot ===" "$SOAK_LOG" 2>/dev/null || echo 0)"
	if [ "${BOOTS:-0}" -gt 1 ]; then
		REBOOT_AT="$(date '+%Y-%m-%d %H:%M:%S')"
		LAST_SAMPLE="$(grep -- 'SAMPLE cycle=' "$SOAK_LOG" 2>/dev/null | tail -n 1)"
		{
			printf '[%s] === CHURN SOAK: REBOOTED (driver-detected) ===\n' "$REBOOT_AT"
			printf '[%s] REBOOTED a second "CHURN SOAK: boot" banner appeared in this transcript - the world restarted mid-run and a ghost soak is running. Ending the run here.\n' "$REBOOT_AT"
			printf '[%s] REBOOTED last counters before the driver noticed: %s\n' "$REBOOT_AT" "${LAST_SAMPLE:-none}"
			printf '[%s] REBOOTED snapshots of the pre-reboot transcript are at %s.prevN (written by churn_soak_preserve_previous_logs).\n' "$REBOOT_AT" "$SOAK_LOG"
		} >> "$SOAK_LOG"
		echo ""
		echo ">> ======================================================================"
		echo ">> UNEXPECTED REBOOT detected ($BOOTS boot banners in $SOAK_LOG)."
		echo ">>   last counters: ${LAST_SAMPLE:-none}"
		echo ">> The run is over; anything after the second banner is a different world."
		echo ">> ======================================================================"
		write_memory_report
		kill_sampler
		kill_dd_force
		tail -n 40 "$SOAK_LOG"
		exit 2
	fi

	# Progress echo: surface each new cycle boundary so a long run is not silent.
	CURRENT="$(grep -- '--- cycle' "$SOAK_LOG" 2>/dev/null | tail -n 1)"
	if [ -n "$CURRENT" ] && [ "$CURRENT" != "$LAST_SHOWN" ]; then
		echo "   $CURRENT"
		LAST_SHOWN="$CURRENT"
	fi

	if [ -z "$(find_dd_pid)" ]; then
		# THE INTERESTING OUTCOME. Preserve everything and say plainly what the world was
		# doing and how much address space it was holding when it went.
		CRASH_AT="$(date '+%Y-%m-%d %H:%M:%S')"
		LAST_SAMPLE="$(grep -- 'SAMPLE cycle=' "$SOAK_LOG" 2>/dev/null | tail -n 1)"
		LAST_CYCLE="$(grep -- '--- cycle' "$SOAK_LOG" 2>/dev/null | tail -n 1)"
		VIRT="$(last_virt_mb)"
		{
			printf '[%s] === CHURN SOAK: CRASHED ===\n' "$CRASH_AT"
			printf '[%s] CRASHED at %s - DreamDaemon exited without writing a verdict, after %d minutes.\n' \
				"$CRASH_AT" "$CRASH_AT" "$((($(date +%s) - RUN_START) / 60))"
			printf '[%s] CRASHED last cycle boundary: %s\n' "$CRASH_AT" "${LAST_CYCLE:-none}"
			printf '[%s] CRASHED last counters: %s\n' "$CRASH_AT" "${LAST_SAMPLE:-none}"
			printf '[%s] CRASHED virtMB %s of 4096 at the last memory sample (%s)\n' \
				"$CRASH_AT" "${VIRT:-unknown}" "$MEM_CSV"
			printf '[%s] A crash WITH data is a result: the counters and the CSV above are the finding.\n' "$CRASH_AT"
		} >> "$SOAK_LOG"

		echo ""
		echo ">> ======================================================================"
		echo ">> CRASHED at $CRASH_AT - DreamDaemon exited without writing a verdict."
		echo ">>   last cycle:    ${LAST_CYCLE:-none}"
		echo ">>   last counters: ${LAST_SAMPLE:-none}"
		echo ">>   virtMB:        ${VIRT:-unknown} of 4096"
		echo ">> ======================================================================"
		write_memory_report
		echo ">> ---- soak log tail ----"
		tail -n 40 "$SOAK_LOG"
		echo ">> ---- world log tail ----"
		[ -f data/churn_soak_dd.log ] && tail -n 40 data/churn_soak_dd.log
		echo ""
		echo ">> Preserved: $SOAK_LOG"
		echo ">> Preserved: $MEM_CSV"
		exit 2
	fi

	if [ $(($(date +%s) - RUN_START)) -gt $((TIMEOUT_MIN * 60)) ]; then
		echo ">> TIMEOUT after ${TIMEOUT_MIN}m with no verdict."
		write_memory_report
		echo ">> ---- soak log tail ----"
		tail -n 60 "$SOAK_LOG"
		exit 2
	fi
	sleep 20
done

# --- 6. Report -------------------------------------------------------------------------
# The harness qdel(world)s a few seconds after its verdict; let the sampler catch the tail
# of the run before it is stopped.
sleep 5
write_memory_report
kill_sampler

echo ""
echo ">> ---- soak log tail ----"
tail -n 60 "$SOAK_LOG"
echo ">> -----------------------"
echo ""
grep -E "^\[.*\] (PASS|FAIL|WARN|WATCH|REPORT|CHURN SOAK VERDICT)" "$SOAK_LOG"
echo ""
echo ">> Full transcript kept at: $SOAK_LOG"
echo ">> Memory samples kept at:  $MEM_CSV"
echo ">> Per-cycle instance census: data/logs/${LOG_DIR_NAME}/instance_census.ndjson"
echo ">>   python tools/instance_census/census_diff.py data/logs/${LOG_DIR_NAME}/instance_census.ndjson --trend"

if grep -q "CHURN SOAK VERDICT: PASS" "$SOAK_LOG"; then
	echo ">> RESULT: PASS"
	exit 0
fi
echo ">> RESULT: FAIL"
exit 1
