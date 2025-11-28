param(
    [string]$Message,
    [string]$Session = "default",
    [string]$Model = "gemini-2.5-flash",
    [switch]$New,
    [switch]$List,
    [string]$Clear,
    [string]$Show
)

$SessionsDir = "$env:USERPROFILE\.gemini-sessions"

# Create sessions directory if it doesn't exist
if (-not (Test-Path $SessionsDir)) {
    New-Item -ItemType Directory -Path $SessionsDir | Out-Null
}

$SessionFile = Join-Path $SessionsDir "$Session.txt"

# Handle list action
if ($List) {
    Write-Host "Available sessions:"
    Write-Host ""
    $sessions = Get-ChildItem -Path $SessionsDir -Filter "*.txt" -ErrorAction SilentlyContinue
    if ($sessions) {
        foreach ($s in $sessions) {
            Write-Host "  - $($s.BaseName)"
        }
    } else {
        Write-Host "  No sessions found"
    }
    exit 0
}

# Handle clear action
if ($Clear) {
    $clearFile = Join-Path $SessionsDir "$Clear.txt"
    if (Test-Path $clearFile) {
        Remove-Item $clearFile
        Write-Host "Session '$Clear' cleared."
    } else {
        Write-Host "Session '$Clear' not found."
    }
    exit 0
}

# Handle show action
if ($Show) {
    $showFile = Join-Path $SessionsDir "$Show.txt"
    if (Test-Path $showFile) {
        Write-Host "=== Session: $Show ==="
        Write-Host ""
        Get-Content $showFile
    } else {
        Write-Host "Session '$Show' not found."
    }
    exit 0
}

# Handle new session
if ($New) {
    if (Test-Path $SessionFile) {
        Remove-Item $SessionFile
    }
    Write-Host "Session '$Session' cleared. Ready for new conversation."
    exit 0
}

# Chat action
if (-not $Message) {
    Write-Host "Error: No message provided"
    Write-Host "Usage: .\gemini-chat.ps1 -Message 'your message' [-Session name] [-New] [-List] [-Clear name] [-Show name]"
    exit 1
}

# Build prompt with history
if (Test-Path $SessionFile) {
    Write-Host "[Loading conversation history from session: $Session]"
    $history = Get-Content $SessionFile -Raw
    $fullPrompt = "Previous conversation history:`n`n$history`n---`n`nNew message: $Message"
} else {
    Write-Host "[Starting new conversation session: $Session]"
    $fullPrompt = $Message
}

# Send to Gemini
Write-Host ""
Write-Host "Sending to Gemini (model: $Model)..."
Write-Host ""

$response = $fullPrompt | gemini --model $Model

# Display response
Write-Host $response

# Save to history
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $SessionFile -Value "[$timestamp] User: $Message"
Add-Content -Path $SessionFile -Value ""
Add-Content -Path $SessionFile -Value "Assistant:"
Add-Content -Path $SessionFile -Value $response
Add-Content -Path $SessionFile -Value ""
Add-Content -Path $SessionFile -Value "---"
Add-Content -Path $SessionFile -Value ""

Write-Host ""
Write-Host "[Conversation saved to session: $Session]"
