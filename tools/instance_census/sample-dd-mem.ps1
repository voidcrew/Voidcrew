# Samples DreamDaemon's virtual address-space usage to a CSV until the process
# exits. On 32-bit DreamDaemon the only number that matters is VirtualMemorySize64
# as a fraction of the 4096 MB user address-space ceiling - physical RAM is
# irrelevant. Run this on the host alongside a round; pair the CSV with the
# instance_census.ndjson the game writes (see census_diff.py).
#
#   powershell -File sample-dd-mem.ps1 [-OutFile dd-mem.csv] [-IntervalSeconds 30]
#
# Read-only: attaches to nothing, just polls the process table.
param(
    [string]$OutFile = "dd-mem.csv",
    [int]$IntervalSeconds = 30
)

$ErrorActionPreference = "Stop"

function Find-DD {
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

Write-Host "Sampling DreamDaemon memory every $IntervalSeconds s -> $OutFile (Ctrl+C to stop)"
$missing = 0
while ($true) {
    $dd = Find-DD
    if ($null -eq $dd) {
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
        $line = "{0:yyyy-MM-dd HH:mm:ss},{1},{2:N1},{3},{4:N2},{5:N1},{6:N1}" -f (Get-Date), $dd.Id, $uptime,
            $virtMB, ($virtMB / 4096 * 100),
            ($dd.WorkingSet64 / 1MB), ($dd.PrivateMemorySize64 / 1MB)
        Add-Content -Path $OutFile -Value $line -Encoding utf8
    } catch {
        # Process died between Find-DD and sampling; loop picks up the relaunch.
    }
    Start-Sleep -Seconds $IntervalSeconds
}
