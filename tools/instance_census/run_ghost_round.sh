#!/usr/bin/env bash
# Ghost round: a scripted, hour-long, ~70-crew round driven headless. Compile, run, report.
#
# This is the churn soak's sibling. The soak asks "does a build/teardown cycle leak?"; the
# ghost round asks "what does an hour of a full server actually COST" - MC tick usage, time
# dilation, subsystem costs, atmos, AI, combat, memory - with 12 player hulls, ~70 crew mobs
# with minds, real pirates, and planets AND ruins AND asteroid fields loaded concurrently.
#
# THE ONE THING IT CANNOT MEASURE: per-client cost. DM cannot fake a /client, so SendMaps -
# the per-viewer map streaming that is a large share of a real server's tick - is absent.
# Every other number here is real. See the report for the full caveat.
#
# Usage (Git Bash, from anywhere):
#   tools/instance_census/run_ghost_round.sh                     # the full hour
#   GHOST_SMOKE=1 tools/instance_census/run_ghost_round.sh        # 10-min reduced smoke
#   GHOST_WAIT_FOR_PORT=5597 tools/instance_census/run_ghost_round.sh   # wait out another run
#
# Environment overrides:
#   DM_EXE / DD_EXE     BYOND binaries
#   GHOST_PORT          world port (default 5593 - NOT 5597, which the churn soak uses)
#   GHOST_NAME          scratch build basename (default ghostround)
#   GHOST_BUDGET_MIN    in-world round length in minutes (default 70, smoke 12)
#   GHOST_SMOKE         1 = reduced scenario (4 ships / 20 crew / 2 planets / 1 ruin / 1 field)
#   GHOST_SHIPS         override ship count
#   GHOST_CREW          override crew count
#   GHOST_GRACE_MIN     how long past the budget the script waits (default 35)
#   GHOST_MEM_INTERVAL  seconds between memory samples (default 20)
#   GHOST_WAIT_FOR_PORT if set, poll until no dd.exe holds that port before launching
#   GHOST_WAIT_MAX_MIN  how long to poll for that (default 150)
#   GHOST_REGIME        stress | ordinary | real  (default: stress, i.e. runs 1-4's behaviour)
#   GHOST_CHURN_SCALE   multiplier on the LEGACY regimes' cadences - the founding, wipe, burst
#                       and mission-dwell clocks. Implied by GHOST_REGIME (stress 1,
#                       ordinary 3); set it explicitly to override. The real regime ignores it.
#   GHOST_KEEP_DD       1 = do not kill DreamDaemon on exit
#   DM_DEFINES          extra dm.exe flags (e.g. -DCBT)
#
# Regimes (measured against production rounds 7-9, 2026-08 - see
# scratchpad/real-round-churn-calibration.md):
#
#   stress    (default) founding 20m / wipe 8m / burst 20m, dwell 80-160s. ~1.2x a real
#             70-player round overall. The regime runs 1-4 were measured on.
#   ordinary  churn_scale 3: founding 60m / wipe 24m / burst 60m, dwell 240-480s. ~0.7x real.
#   real      the measured cadence of round-7 at a median of 70 players: a hull founded every
#             5.0m, a crew wiped every 14.4m from T+45m, and site loads on a continuous trickle
#             (median gap ~1.9m, ~32/h, ~5 planet builds/h) instead of 5-site worldgen bursts.
#
#   GHOST_REGIME=real GHOST_BUDGET_MIN=180 tools/instance_census/run_ghost_round.sh
#
# Exit codes: 0 = the hour completed and a profile was written, 1 = compile failure,
# 2 = no profile (crash / timeout). A CRASH IS A RESULT - the log and CSVs are preserved
# and a CRASHED summary naming the last phase and the last virtMB is appended.

set -u
cd "$(dirname "$0")/../.."

DM_EXE="${DM_EXE:-C:/Program Files (x86)/BYOND/bin/dm.exe}"
DD_EXE="${DD_EXE:-C:/Program Files (x86)/BYOND/bin/dd.exe}"
PORT="${GHOST_PORT:-5593}"
NAME="${GHOST_NAME:-ghostround}"
BOOT_MIN="${GHOST_BOOT_MIN:-25}"
DM_DEFINES="${DM_DEFINES:-}"
GRACE_MIN="${GHOST_GRACE_MIN:-35}"
MEM_INTERVAL="${GHOST_MEM_INTERVAL:-20}"
KEEP_DD="${GHOST_KEEP_DD:-0}"
SMOKE="${GHOST_SMOKE:-0}"
WAIT_FOR_PORT="${GHOST_WAIT_FOR_PORT:-}"
WAIT_MAX_MIN="${GHOST_WAIT_MAX_MIN:-240}"
WAIT_POLL_MIN="${GHOST_WAIT_POLL_MIN:-10}"
SUSTAIN="${GHOST_SUSTAIN:-}"
CHURN_SCALE="${GHOST_CHURN_SCALE:-}"
REGIME="${GHOST_REGIME:-}"

# Fail fast on a typo. The world would otherwise warn into the round log and quietly run the
# default regime, and the result would be a run labelled `real` in somebody's report carrying
# stress cadences in its data.
case "$REGIME" in
	""|stress|ordinary|real) ;;
	*)
		echo ">> GHOST_REGIME='$REGIME' is not one of: stress, ordinary, real. Aborting."
		exit 1
		;;
esac

if [ "$SMOKE" = "1" ]; then
	BUDGET_MIN="${GHOST_BUDGET_MIN:-12}"
	SHIPS="${GHOST_SHIPS:-4}"
	CREW="${GHOST_CREW:-20}"
else
	BUDGET_MIN="${GHOST_BUDGET_MIN:-70}"
	SHIPS="${GHOST_SHIPS:-12}"
	CREW="${GHOST_CREW:-70}"
fi
TIMEOUT_MIN="${GHOST_TIMEOUT_MIN:-$((BUDGET_MIN + GRACE_MIN))}"

STAMP="$(date +%Y%m%d-%H%M%S)"
GHOST_LOG="data/ghost_round_${STAMP}.log"
MEM_CSV="data/ghost_round_${STAMP}_mem.csv"
LOG_DIR_NAME="ghost_round_${STAMP}"
DME="${NAME}.dme"
DMB="${NAME}.dmb"
LAUNCHER="${NAME}.launch.bat"
INCLUDE_LINE='#include "tools\instance_census\ghost_round.dm"'

DD_PID=""

# Same discipline as the churn soak: never kill anything not identified by THIS run's .dmb.
find_dd_pid() {
	powershell -NoProfile -NonInteractive -Command \
		"Get-CimInstance Win32_Process | Where-Object { \$PSItem.Name -eq 'dd.exe' -and \$PSItem.CommandLine -like '*${DMB}*' } | ForEach-Object { \$PSItem.ProcessId }" \
		2>/dev/null | tr -d "\r" | head -n 1
}

# Any dd.exe holding one of the given ports, whoever owns it. GHOST_WAIT_FOR_PORT takes a
# comma-separated list, because the box routinely has both a churn soak (5597) and a unit-test
# suite (1342) on it and a measured run must wait for ALL of them. Used only to WAIT, never to
# kill: whatever holds those ports belongs to somebody else.
find_dd_on_port() {
	local ports="$1"
	local port
	for port in ${ports//,/ }; do
		local pid
		pid="$(powershell -NoProfile -NonInteractive -Command \
			"Get-CimInstance Win32_Process | Where-Object { \$PSItem.Name -eq 'dd.exe' -and \$PSItem.CommandLine -like '*-port ${port}*' } | ForEach-Object { \$PSItem.ProcessId }" \
			2>/dev/null | tr -d "\r" | head -n 1)"
		if [ -n "$pid" ]; then
			printf '%s (port %s)' "$pid" "$port"
			return
		fi
	done
}

# Everything BYOND on the box, for the run record. The owner's own client/panel showing up
# here is not an error - it is a caveat, and it belongs in the report.
list_byond_procs() {
	powershell -NoProfile -NonInteractive -Command \
		"Get-CimInstance Win32_Process | Where-Object { \$PSItem.Name -in @('dd.exe','dreamdaemon.exe','dreamseeker.exe') } | ForEach-Object { \"\$(\$PSItem.ProcessId) \$(\$PSItem.Name) \$(\$PSItem.CommandLine)\" }" \
		2>/dev/null | tr -d "\r"
}

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
if [ ! -f "tools/instance_census/ghost_round.dm" ]; then
	echo ">> tools/instance_census/ghost_round.dm is missing. Aborting."
	exit 1
fi

# --- 0. Wait for the box to be ours ----------------------------------------------------
# The measured run must be ALONE. Polling, never killing: whatever holds that port belongs
# to somebody else and reaping it would destroy their result.
if [ -n "$WAIT_FOR_PORT" ]; then
	echo ">> Waiting for port(s) ${WAIT_FOR_PORT} to be free (up to ${WAIT_MAX_MIN}m, checking every ${WAIT_POLL_MIN}m)..."
	WAIT_START=$(date +%s)
	while true; do
		OTHER="$(find_dd_on_port "$WAIT_FOR_PORT")"
		if [ -z "$OTHER" ]; then
			echo ">> Port(s) ${WAIT_FOR_PORT} are free."
			break
		fi
		ELAPSED=$((($(date +%s) - WAIT_START) / 60))
		if [ "$ELAPSED" -gt "$WAIT_MAX_MIN" ]; then
			echo ">> Gave up waiting for ${WAIT_FOR_PORT} after ${ELAPSED}m (PID $OTHER still there). Aborting."
			exit 2
		fi
		echo "   still busy (PID $OTHER), ${ELAPSED}m elapsed..."
		sleep $((WAIT_POLL_MIN * 60))
	done
fi

# --- 1. Build a scratch dme -----------------------------------------------------------
echo ">> Preparing $DME (tgstation.dme + ghost_round.dm)"
cleanup_build
cp tgstation.dme "$DME" || exit 1
printf '\n// ghost round harness - appended by tools/instance_census/run_ghost_round.sh\n%s\n' "$INCLUDE_LINE" >> "$DME"

echo ">> Compiling: dm.exe ${DM_DEFINES} $DME  (this takes a few minutes)"
COMPILE_OUT="$(mktemp)"
# shellcheck disable=SC2086
"$DM_EXE" $DM_DEFINES "$DME" > "$COMPILE_OUT" 2>&1
tail -n 25 "$COMPILE_OUT"
if [ ! -f "$DMB" ] || ! grep -q -- "- 0 errors" "$COMPILE_OUT"; then
	echo ">> Compile FAILED. Full output above. (If the errors name icons/map_icons/*, the"
	echo ">> .dmi files are being rewritten concurrently - retry, or set DM_DEFINES=-DCBT.)"
	rm -f "$COMPILE_OUT"
	exit 1
fi
rm -f "$COMPILE_OUT"
echo ">> Compile OK."

# --- 2. Launch DreamDaemon detached ----------------------------------------------------
if command -v cygpath >/dev/null 2>&1; then
	DD_WIN="$(cygpath -w "$DD_EXE")"
else
	DD_WIN="$(printf '%s' "$DD_EXE" | sed 's|/|\\|g')"
fi

PARAMS="ghost-round-log=${GHOST_LOG}&log-directory=${LOG_DIR_NAME}"
PARAMS="${PARAMS}&ghost-round-budget-min=${BUDGET_MIN}"
PARAMS="${PARAMS}&ghost-round-ships=${SHIPS}"
PARAMS="${PARAMS}&ghost-round-crew=${CREW}"
PARAMS="${PARAMS}&ghost-round-smoke=${SMOKE}"
if [ -n "$SUSTAIN" ]; then
	PARAMS="${PARAMS}&ghost-round-sustain=${SUSTAIN}"
fi
if [ -n "$CHURN_SCALE" ]; then
	PARAMS="${PARAMS}&ghost-round-churn-scale=${CHURN_SCALE}"
fi
if [ -n "$REGIME" ]; then
	PARAMS="${PARAMS}&ghost-round-regime=${REGIME}"
fi

{
	printf '@echo off\r\n'
	printf 'start "" /min /low "%s" %s -port %s -close -trusted -invisible -params "%s"\r\n' \
		"$DD_WIN" "$DMB" "$PORT" "$PARAMS"
} > "$LAUNCHER"

mkdir -p data
rm -f "$GHOST_LOG" data/ghost_round_dd.log

echo ">> Launching DreamDaemon on port $PORT (detached, minimized)."
echo ">> Scenario:  $([ "$SMOKE" = "1" ] && echo "SMOKE" || echo "FULL") - ${SHIPS} ships, ${CREW} crew, ${BUDGET_MIN}m round, regime ${REGIME:-stress (default)}"
echo ">> Do NOT close the DreamDaemon window and do NOT connect a client to it."
echo ">> Round log: $GHOST_LOG"
echo ">> Memory:    $MEM_CSV"
echo ">> World log: data/ghost_round_dd.log"
echo ">> Perf CSV:  data/logs/${LOG_DIR_NAME}/perf-*.csv"

echo ">> BYOND processes on the box at launch (recorded as a run caveat):"
list_byond_procs | sed 's/^/     /'
{
	printf '[%s] === BOX STATE AT LAUNCH ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
	list_byond_procs | sed "s/^/[$(date '+%Y-%m-%d %H:%M:%S')] BOX /"
} >> "$GHOST_LOG"

if command -v cygpath >/dev/null 2>&1; then
	LAUNCHER_WIN="$(cygpath -w "$PWD/$LAUNCHER")"
else
	LAUNCHER_WIN="$(printf '%s' "$PWD/$LAUNCHER" | sed 's|/|\\|g')"
fi
cmd //c "$LAUNCHER_WIN"

# --- 3. Attach the memory sampler ------------------------------------------------------
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

# --- 4. Wait for the world to boot -----------------------------------------------------
echo ">> Phase 1: waiting for the world to boot (up to ${BOOT_MIN}m)..."
BOOT_START=$(date +%s)
while ! grep -q "GHOST ROUND: boot" "$GHOST_LOG" 2>/dev/null; do
	if [ $(($(date +%s) - BOOT_START)) -gt $((BOOT_MIN * 60)) ]; then
		echo ">> TIMEOUT: the world never reached SSghost_round's Initialize."
		[ -f data/ghost_round_dd.log ] && tail -n 40 data/ghost_round_dd.log
		exit 2
	fi
	if [ -z "$(find_dd_pid)" ] && [ $(($(date +%s) - BOOT_START)) -gt 60 ]; then
		echo ">> DreamDaemon is not running and no boot banner was written - the world died on boot."
		[ -f data/ghost_round_dd.log ] && tail -n 40 data/ghost_round_dd.log
		exit 2
	fi
	sleep 10
done
echo ">> World booted, round log is live."

# --- 5. Poll for the final profile -----------------------------------------------------
echo ">> Phase 2: waiting for the FINAL PROFILE (up to ${TIMEOUT_MIN}m)..."
RUN_START=$(date +%s)
LAST_SHOWN=""

last_virt_mb() {
	[ -f "$MEM_CSV" ] || return
	awk -F, 'NR > 1 && $4 != "" { v = $4 } END { if (v != "") print v }' "$MEM_CSV"
}

write_memory_report() {
	[ -f "$MEM_CSV" ] || return
	local report
	report="$(awk -F, '
		NR > 1 && $4 != "" {
			n++
			t[n] = $3 + 0
			v[n] = $4 + 0
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
			slope = (den == 0) ? 0 : ((cnt * sxy) - (sx * sy)) / den
			hours = (t[n] - t[1]) / 60
			printf "REPORT memory: virtMB first %.0f, last %.0f, PEAK %.0f of 4096 (%.1f%% of the wall); %.2f h of samples; growth %+.0f MB total, %+.1f MB/h over the run, %+.1f MB/h over the final half (%d samples)\n", \
				first, last, peak, peak / 4096 * 100, hours, last - first, \
				(hours > 0 ? (last - first) / hours : 0), slope * 60, cnt
		}
	' "$MEM_CSV")"
	[ -n "$report" ] || return
	echo "$report"
	printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$report" >> "$GHOST_LOG"
}

while true; do
	if grep -q "GHOST ROUND COMPLETE" "$GHOST_LOG" 2>/dev/null; then
		break
	fi

	BOOTS="$(grep -c "GHOST ROUND: boot" "$GHOST_LOG" 2>/dev/null || echo 0)"
	if [ "${BOOTS:-0}" -gt 1 ]; then
		REBOOT_AT="$(date '+%Y-%m-%d %H:%M:%S')"
		{
			printf '[%s] === GHOST ROUND: REBOOTED (driver-detected) ===\n' "$REBOOT_AT"
			printf '[%s] REBOOTED a second boot banner appeared - the world restarted mid-round. Ending here.\n' "$REBOOT_AT"
		} >> "$GHOST_LOG"
		echo ">> UNEXPECTED REBOOT detected. The run is over."
		write_memory_report
		kill_sampler
		kill_dd_force
		tail -n 40 "$GHOST_LOG"
		exit 2
	fi

	CURRENT="$(grep -- 'BEAT ' "$GHOST_LOG" 2>/dev/null | tail -n 1)"
	if [ -n "$CURRENT" ] && [ "$CURRENT" != "$LAST_SHOWN" ]; then
		echo "   $CURRENT"
		LAST_SHOWN="$CURRENT"
	fi

	if [ -z "$(find_dd_pid)" ]; then
		CRASH_AT="$(date '+%Y-%m-%d %H:%M:%S')"
		LAST_BEAT="$(grep -- 'BEAT ' "$GHOST_LOG" 2>/dev/null | tail -n 1)"
		LAST_BUCKET="$(grep -- 'BUCKET ' "$GHOST_LOG" 2>/dev/null | tail -n 1)"
		VIRT="$(last_virt_mb)"
		{
			printf '[%s] === GHOST ROUND: CRASHED ===\n' "$CRASH_AT"
			printf '[%s] CRASHED after %d minutes - DreamDaemon exited without writing a profile.\n' \
				"$CRASH_AT" "$((($(date +%s) - RUN_START) / 60))"
			printf '[%s] CRASHED last beat:   %s\n' "$CRASH_AT" "${LAST_BEAT:-none}"
			printf '[%s] CRASHED last bucket: %s\n' "$CRASH_AT" "${LAST_BUCKET:-none}"
			printf '[%s] CRASHED virtMB %s of 4096 at the last memory sample (%s)\n' \
				"$CRASH_AT" "${VIRT:-unknown}" "$MEM_CSV"
			printf '[%s] A crash WITH data is a result: an hour of 70 crew that does not fit in 4 GB is the finding.\n' "$CRASH_AT"
		} >> "$GHOST_LOG"
		echo ""
		echo ">> ======================================================================"
		echo ">> CRASHED at $CRASH_AT."
		echo ">>   last beat:   ${LAST_BEAT:-none}"
		echo ">>   last bucket: ${LAST_BUCKET:-none}"
		echo ">>   virtMB:      ${VIRT:-unknown} of 4096"
		echo ">> ======================================================================"
		write_memory_report
		echo ">> ---- round log tail ----"
		tail -n 50 "$GHOST_LOG"
		echo ">> ---- world log tail ----"
		[ -f data/ghost_round_dd.log ] && tail -n 40 data/ghost_round_dd.log
		exit 2
	fi

	if [ $(($(date +%s) - RUN_START)) -gt $((TIMEOUT_MIN * 60)) ]; then
		echo ">> TIMEOUT after ${TIMEOUT_MIN}m with no profile."
		write_memory_report
		tail -n 60 "$GHOST_LOG"
		exit 2
	fi
	sleep 20
done

# --- 6. Report -------------------------------------------------------------------------
sleep 5
write_memory_report
kill_sampler

echo ""
echo ">> ---- FINAL PROFILE ----"
sed -n '/=== GHOST ROUND: FINAL PROFILE ===/,$p' "$GHOST_LOG"
echo ">> -----------------------"
echo ""
echo ">> Full transcript kept at: $GHOST_LOG"
echo ">> Memory samples kept at:  $MEM_CSV"
echo ">> Perf CSV:                data/logs/${LOG_DIR_NAME}/perf-*.csv"
echo ">> Profiler dumps:          data/logs/${LOG_DIR_NAME}/profiler/"
echo ">> Census:                  data/logs/${LOG_DIR_NAME}/instance_census.ndjson"
exit 0
