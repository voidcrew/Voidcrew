#Requires -Version 7
<#
.SYNOPSIS
    Runs LibreTranslate (Russian <-> English only) in Docker on Windows,
    bound to loopback, for the SS13 auto-translation feature.

.DESCRIPTION
    The Windows counterpart to install-libretranslate.sh. There is no systemd
    here, so lifecycle is handled by Docker's own restart policy: the
    container comes back with Docker Desktop, which itself starts at login by
    default. Use -RegisterStartupTask if Docker Desktop is set not to
    autostart and you want the container up regardless.

    Unlike the Linux unit there is no periodic recycle configured. On a dev
    box the memory creep does not matter; if you leave this running for days,
    restart it yourself or add a scheduled task.

.PARAMETER MemoryLimit
    Hard memory cap for the container. Note this is on top of whatever WSL2
    itself reserves.

.PARAMETER Remove
    Tears everything down instead of installing.

.PARAMETER RegisterStartupTask
    Also registers a scheduled task that starts the container at logon.

.EXAMPLE
    .\Install-LibreTranslate.ps1

.EXAMPLE
    .\Install-LibreTranslate.ps1 -Remove
#>
[CmdletBinding()]
param(
    [string] $Image = 'libretranslate/libretranslate:latest',
    [string] $ContainerName = 'libretranslate',
    [string] $VolumeName = 'libretranslate-models',
    [string] $BindAddress = '127.0.0.1',
    [int]    $Port = 5000,
    [string] $Languages = 'en,ru',
    [string] $MemoryLimit = '2g',
    [string] $CpuLimit = '0.5',
    [int]    $StartupTimeoutSeconds = 900,
    [switch] $RegisterStartupTask,
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'
$TaskName = 'LibreTranslate-SS13'

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'docker was not found on PATH. Install Docker Desktop first.'
    }
    # `docker info` fails when the engine is installed but not running.
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'The Docker engine is not responding. Start Docker Desktop and try again.'
    }
}

# --- teardown ----------------------------------------------------------------

if ($Remove) {
    Test-Docker
    Write-Host '>> stopping and removing container'
    docker rm -f $ContainerName 2>&1 | Out-Null

    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Write-Host '>> removing scheduled task'
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    Write-Host ">> the model volume '$VolumeName' was left in place."
    Write-Host "   Remove it with: docker volume rm $VolumeName"
    return
}

# --- preflight ---------------------------------------------------------------

Test-Docker

Write-Host ">> pulling $Image"
docker pull $Image
if ($LASTEXITCODE -ne 0) { throw 'docker pull failed.' }

# Named volume for the Argos model files. The image ships with no models -
# they are downloaded on first boot - so without this every recreate pulls
# them down again.
docker volume inspect $VolumeName 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host ">> creating model volume $VolumeName"
    docker volume create $VolumeName | Out-Null
}

# The image runs as an unprivileged user, but Docker creates a fresh named
# volume owned by root. argostranslate then cannot create its packages/
# directory inside it and the container crash-loops on a PermissionError -
# which surfaces confusingly as "Error: '' is not a valid port number",
# because the entrypoint's argument parser dies on the same exception.
# Read the uid/gid out of the image rather than hardcoding them.
$ltUid = (docker run --rm --entrypoint id $Image -u libretranslate).Trim()
$ltGid = (docker run --rm --entrypoint id $Image -g libretranslate).Trim()
Write-Host ">> setting model volume ownership to ${ltUid}:${ltGid}"
docker run --rm -u root -v "${VolumeName}:/data" `
    --entrypoint chown $Image -R "${ltUid}:${ltGid}" /data
if ($LASTEXITCODE -ne 0) { throw 'Failed to set volume ownership.' }

Write-Host '>> removing any existing container'
docker rm -f $ContainerName 2>&1 | Out-Null

# --- run ---------------------------------------------------------------------

Write-Host '>> starting container'
$dockerArgs = @(
    'run', '-d',
    '--name', $ContainerName,
    '--restart', 'unless-stopped',
    '-p', "${BindAddress}:${Port}:5000",
    '--memory', $MemoryLimit,
    '--cpus', $CpuLimit,
    '-e', "LT_LOAD_ONLY=$Languages",
    '-e', 'LT_DISABLE_WEB_UI=true',
    '-e', 'LT_UPDATE_MODELS=false',
    '-e', 'LT_THREADS=1',
    '-v', "${VolumeName}:/home/libretranslate/.local/share/argos-translate",
    $Image
)
docker @dockerArgs | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'docker run failed.' }

# --- wait ---------------------------------------------------------------------

Write-Host -NoNewline '>> waiting for the endpoint (first run downloads models)'
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        Invoke-RestMethod -Uri "http://${BindAddress}:${Port}/languages" -TimeoutSec 5 | Out-Null
        $ready = $true
        break
    } catch {
        Write-Host -NoNewline '.'
        Start-Sleep -Seconds 5
    }
}

if (-not $ready) {
    Write-Host
    throw "Endpoint did not come up within $StartupTimeoutSeconds seconds. Check: docker logs $ContainerName"
}
Write-Host ' up.'

# --- smoke test ----------------------------------------------------------------

# Built from code points rather than literal Cyrillic so this file's encoding
# can never be the thing that breaks the test. This is "privet, gde sb?".
$russian = "`u{043F}`u{0440}`u{0438}`u{0432}`u{0435}`u{0442}, `u{0433}`u{0434}`u{0435} `u{0441}`u{0431}?"

Write-Host '>> smoke test'
$body = @{
    q      = $russian
    source = 'ru'
    target = 'en'
    format = 'text'
} | ConvertTo-Json -Compress

$response = Invoke-RestMethod `
    -Uri "http://${BindAddress}:${Port}/translate" `
    -Method Post `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

Write-Host "   $russian  ->  $($response.translatedText)"

# --- optional startup task ------------------------------------------------------

if ($RegisterStartupTask) {
    Write-Host '>> registering logon task'
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    $action  = New-ScheduledTaskAction -Execute 'docker' -Argument "start $ContainerName"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    # Docker Desktop takes a while to come up after logon.
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Description 'Starts the LibreTranslate container for SS13.' | Out-Null
}

# --- done -----------------------------------------------------------------------

@"

Done.

Add to config\game_options.txt:

    TRANSLATE_HTTP_URL http://${BindAddress}:${Port}
    TRANSLATE_HTTP_TIMEOUT_SECONDS 5

Then restart the server. SSautotranslate probes the endpoint at init; if it
does not answer, translation stays off for the round and nothing else breaks.

Useful commands:
    docker logs -f $ContainerName
    docker stats $ContainerName
    .\Install-LibreTranslate.ps1 -Remove
"@ | Write-Host
