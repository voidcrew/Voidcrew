@echo off
setlocal enabledelayedexpansion

:: Gemini CLI Conversation Persistence Wrapper
:: Usage: gemini-chat.bat [options] "your message"
:: Options:
::   -s, --session NAME    Use named session (default: default)
::   -n, --new            Start new conversation (clear history)
::   -l, --list           List all sessions
::   -c, --clear NAME     Clear specific session
::   --show NAME          Show session history

set "SESSION=default"
set "MESSAGE="
set "ACTION=chat"
set "SESSIONS_DIR=%USERPROFILE%\.gemini-sessions"

:: Create sessions directory if it doesn't exist
if not exist "%SESSIONS_DIR%" mkdir "%SESSIONS_DIR%"

:: Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="-s" (
    set "SESSION=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--session" (
    set "SESSION=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-n" (
    set "ACTION=new"
    shift
    goto :parse_args
)
if /i "%~1"=="--new" (
    set "ACTION=new"
    shift
    goto :parse_args
)
if /i "%~1"=="-l" (
    set "ACTION=list"
    shift
    goto :parse_args
)
if /i "%~1"=="--list" (
    set "ACTION=list"
    shift
    goto :parse_args
)
if /i "%~1"=="-c" (
    set "ACTION=clear"
    set "CLEAR_SESSION=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--clear" (
    set "ACTION=clear"
    set "CLEAR_SESSION=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--show" (
    set "ACTION=show"
    set "SHOW_SESSION=%~2"
    shift
    shift
    goto :parse_args
)
set "MESSAGE=%~1"
shift
goto :parse_args

:args_done

:: Handle actions
if "%ACTION%"=="list" goto :list_sessions
if "%ACTION%"=="clear" goto :clear_session
if "%ACTION%"=="show" goto :show_session
if "%ACTION%"=="new" goto :new_session

:: Chat action
if "%MESSAGE%"=="" (
    echo Error: No message provided
    echo Usage: gemini-chat.bat [options] "your message"
    exit /b 1
)

set "SESSION_FILE=%SESSIONS_DIR%\%SESSION%.txt"

:: Build prompt with history
set "FULL_PROMPT="
if exist "%SESSION_FILE%" (
    echo [Loading conversation history from session: %SESSION%]
    set "FULL_PROMPT=Previous conversation history:\n\n"
    for /f "usebackq delims=" %%a in ("%SESSION_FILE%") do (
        set "FULL_PROMPT=!FULL_PROMPT!%%a\n"
    )
    set "FULL_PROMPT=!FULL_PROMPT!\n---\n\nNew message: %MESSAGE%"
) else (
    echo [Starting new conversation session: %SESSION%]
    set "FULL_PROMPT=%MESSAGE%"
)

:: Send to Gemini
echo.
echo Sending to Gemini...
echo.
echo !FULL_PROMPT! | gemini > "%TEMP%\gemini-response.txt"

:: Display response
type "%TEMP%\gemini-response.txt"
set /p RESPONSE=<"%TEMP%\gemini-response.txt"

:: Save to history
echo User: %MESSAGE% >> "%SESSION_FILE%"
echo. >> "%SESSION_FILE%"
echo Assistant: >> "%SESSION_FILE%"
type "%TEMP%\gemini-response.txt" >> "%SESSION_FILE%"
echo. >> "%SESSION_FILE%"
echo --- >> "%SESSION_FILE%"
echo. >> "%SESSION_FILE%"

del "%TEMP%\gemini-response.txt"
exit /b 0

:new_session
set "SESSION_FILE=%SESSIONS_DIR%\%SESSION%.txt"
if exist "%SESSION_FILE%" del "%SESSION_FILE%"
echo Session "%SESSION%" cleared. Ready for new conversation.
exit /b 0

:list_sessions
echo Available sessions:
echo.
if exist "%SESSIONS_DIR%\*.txt" (
    for %%f in ("%SESSIONS_DIR%\*.txt") do (
        echo   - %%~nf
    )
) else (
    echo   No sessions found
)
exit /b 0

:clear_session
set "SESSION_FILE=%SESSIONS_DIR%\%CLEAR_SESSION%.txt"
if exist "%SESSION_FILE%" (
    del "%SESSION_FILE%"
    echo Session "%CLEAR_SESSION%" cleared.
) else (
    echo Session "%CLEAR_SESSION%" not found.
)
exit /b 0

:show_session
set "SESSION_FILE=%SESSIONS_DIR%\%SHOW_SESSION%.txt"
if exist "%SESSION_FILE%" (
    echo === Session: %SHOW_SESSION% ===
    echo.
    type "%SESSION_FILE%"
) else (
    echo Session "%SHOW_SESSION%" not found.
)
exit /b 0
