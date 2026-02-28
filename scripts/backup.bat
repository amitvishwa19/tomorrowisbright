@echo off
REM OpenClaw Backup Script for Windows (Batch)
REM Run every 5 minutes via Task Scheduler

setlocal

set WORKSPACE=%USERPROFILE%\.openclaw\workspace
set LOG_FILE=%WORKSPACE%\backup.log
set ISO_DATE=%date:~10,4%-%date:~4,2%-%date:~7,2%
set TIMESTAMP=%date:~10,4%-%date:~4,2%-%date:~7,2% %time:~0,2%:%time:~3,2% %time:~6,2%

echo [%TIMESTAMP%] Backup started >> "%LOG_FILE%"

REM Change to workspace
cd /d "%WORKSPACE%" || (
    echo [%TIMESTAMP%] ERROR: Cannot cd to %WORKSPACE% >> "%LOG_FILE%"
    exit /b 1
)

REM Ensure memory directory exists
if not exist memory\ mkdir memory

REM Create today's memory file if missing
if not exist memory\%ISO_DATE%.md (
    echo # Memory Log - %ISO_DATE%>> memory\%ISO_DATE%.md
    echo.>> memory\%ISO_DATE%.md
    echo ## Session Start>> memory\%ISO_DATE%.md
    echo **Time:** %TIMESTAMP% Asia/Kolkata>> memory\%ISO_DATE%.md
    echo **Agent:** Jarvis>> memory\%ISO_DATE%.md
    echo **User:** Amit>> memory\%ISO_DATE%.md
    echo.>> memory\%ISO_DATE%.md
    echo ### Conversation Transcript>> memory\%ISO_DATE%.md
    echo.>> memory\%ISO_DATE%.md
    echo [%TIMESTAMP%] System: Backup initialized >> memory\%ISO_DATE%.md
)

REM Update MEMORY.md timestamp (simple replace)
if exist MEMORY.md (
    powershell -Command "(Get-Content MEMORY.md -Raw) -replace '(?s)(Last updated:).*', 'Last updated: %ISO_DATE% (Asia/Kolkata)' | Set-Content MEMORY.md"
)

REM Stage files
git add -A memory\ MEMORY.md AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md scripts\ systemd\ config-templates\ 2>nul

REM Check if there are changes
git status --porcelain > nul 2>&1
if errorlevel 1 goto no_changes

REM Commit
git commit -m "Auto-backup %TIMESTAMP%" 2>> "%LOG_FILE%"
if errorlevel 1 (
    echo [%TIMESTAMP%] ERROR: Git commit failed >> "%LOG_FILE%"
    exit /b 1
)

REM Push with retry
set RETRY=0
:push_retry
git push origin main 2>> "%LOG_FILE%"
if errorlevel 1 (
    set /a RETRY+=1
    if %RETRY% lss 3 (
        timeout /t 5 >nul
        goto push_retry
    ) else (
        echo [%TIMESTAMP%] ERROR: Git push failed after %RETRY% attempts >> "%LOG_FILE%"
        exit /b 1
    )
)

:success
echo [%TIMESTAMP%] Backup completed successfully >> "%LOG_FILE%"
exit /b 0

:no_changes
echo [%TIMESTAMP%] No changes to commit >> "%LOG_FILE%"
exit /b 0
