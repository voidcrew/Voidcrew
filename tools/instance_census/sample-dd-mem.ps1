# Samples DreamDaemon's virtual address-space usage to a CSV until the process
# exits. On 32-bit DreamDaemon the only number that matters is VirtualMemorySize64
# as a fraction of the 4096 MB user address-space ceiling - physical RAM is
# irrelevant. Run this on the host alongside a round; pair the CSV with the
# instance_census.ndjson the game writes (see census_diff.py).
#
#   powershell -File sample-dd-mem.ps1 [-OutFile dd-mem.csv] [-IntervalSeconds 30]
#   powershell -File sample-dd-mem.ps1 -ProcessId 1234 -OutFile soak-mem.csv -IntervalSeconds 20
#
# With -ProcessId the sampler watches EXACTLY that process and exits as soon as it is gone.
# That is what the churn soak driver uses: "newest dd.exe wins" is wrong on a box where a
# unit-test suite, a playtest and a soak can all be running at once, and an overnight run
# whose sampler wandered onto somebody else's world is worse than no sampler at all.
# Exiting on the watched process's death is also how the driver learns a soak crashed
# without having to poll for it twice.
#
# Read-only: attaches to nothing, just polls the process table.
param(
    [string]$OutFile = "dd-mem.csv",
    [int]$IntervalSeconds = 30,
    [int]$ProcessId = 0
)

$ErrorActionPreference = "Stop"

function Find-DD {
    if ($ProcessId -gt 0) {
        # Exact PID only. No fallback to "some other dd.exe" - if the watched world is
        # gone, the watch is over.
        return (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
    }
    # dd.exe is TGS's launcher name; dreamdaemon.exe is the stock name.
    $procs = @(Get-Process -Name dd, dreamdaemon -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return $null }
    # Newest process wins if TGS relaunched mid-watch.
    return ($procs | Sort-Object StartTime -Descending)[0]
}

if (-not (Test-Path $OutFile)) {
    "timestamp,pid,uptime_min,virtual_mb,virtual_pct_of_4gb,workingset_mb,private_mb" |
        Out-File -FilePath $OutFile -Encoding utf8
}

if ($ProcessId -gt 0) {
    Write-Host "Sampling PID $ProcessId every $IntervalSeconds s -> $OutFile (exits when it does)"
} else {
    Write-Host "Sampling DreamDaemon memory every $IntervalSeconds s -> $OutFile (Ctrl+C to stop)"
}
$missing = 0
while ($true) {
    $dd = Find-DD
    if ($null -eq $dd) {
        if ($ProcessId -gt 0) {
            Add-Content -Path $OutFile -Value ("{0:yyyy-MM-dd HH:mm:ss},{1},,,,," -f (Get-Date), $ProcessId) -Encoding utf8
            Write-Host "PID $ProcessId is gone; sampler exiting."
            break
        }
        $missing++
        if ($missing -ge 10) { Write-Host "No DreamDaemon for $($missing * $IntervalSeconds)s; still watching..."; $missing = 0 }
        Start-Sleep -Seconds $IntervalSeconds
        continue
    }
    $missing = 0
    try {
        $dd.Refresh()
        $uptime = ((Get-Date) - $dd.StartTime).TotalMinutes
        $virtMB = [math]::Round($dd.VirtualMemorySize64 / 1MB, 1)
        # F, not N: the N format inserts the culture's thousands separator, so a working set
        # over 1 GB writes "1,023.9" and splits itself across two CSV fields. Every column
        # after it then reads shifted, which is exactly the kind of quiet corruption an
        # overnight CSV must not have.
        $line = "{0:yyyy-MM-dd HH:mm:ss},{1},{2:F1},{3:F1},{4:F2},{5:F1},{6:F1}" -f (Get-Date), $dd.Id, $uptime,
            $virtMB, ($virtMB / 4096 * 100),
            ($dd.WorkingSet64 / 1MB), ($dd.PrivateMemorySize64 / 1MB)
        Add-Content -Path $OutFile -Value $line -Encoding utf8
    } catch {
        # Process died between Find-DD and sampling; loop picks up the relaunch.
    }
    Start-Sleep -Seconds $IntervalSeconds
}
