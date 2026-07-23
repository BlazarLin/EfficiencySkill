@echo off
REM Created: 2026-07-23
REM Function: Publish the nearest Git repository to the Project network share.
REM Purpose: Replace the target contents with Git non-ignored files and create an update marker.

setlocal EnableExtensions DisableDelayedExpansion
set "DESTINATION=\\192.168.205.91\f\Project\EfficiencySkill"
set "REPOSITORY="
set "WHATIF="
set /a COPIED_COUNT=0
set /a MISSING_COUNT=0
set /a FAILED_COUNT=0

if /I "%~1"=="--whatif" set "WHATIF=1"

call :FindGitRoot "%CD%"
if not defined REPOSITORY call :FindGitRoot "%~dp0"
if not defined REPOSITORY (
    echo ERROR: No Git repository was found from the current or script directory.
    goto :Finish
)

git -C "%REPOSITORY%" rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git is unavailable or the repository cannot be accessed.
    goto :Finish
)

echo Source repository: %REPOSITORY%
echo Destination: %DESTINATION%
if defined WHATIF echo Mode: WHATIF ^(no files will be deleted or copied^)
echo.

if not exist "%DESTINATION%" (
    if defined WHATIF (
        echo [WHATIF] Create directory: %DESTINATION%
    ) else (
        mkdir "%DESTINATION%" >nul 2>&1
        if errorlevel 1 (
            echo ERROR: Cannot create or access destination directory.
            goto :Finish
        )
    )
)

if defined WHATIF (
    echo [WHATIF] Clear all existing contents: %DESTINATION%
) else (
    call :ClearDestination
    if errorlevel 1 (
        echo ERROR: Cannot clear destination contents. Publish cancelled.
        goto :Finish
    )
)

for /f "usebackq delims=" %%F in (`git -C "%REPOSITORY%" ls-files --cached --others --exclude-standard`) do (
    call :CopyOne "%%F"
)

echo.
if defined WHATIF (
    echo [WHATIF] Create LastUpdateYYYYMMDD-HHmmss.txt marker.
    echo WHATIF completed. No files were deleted or copied.
) else (
    echo Publish completed: %COPIED_COUNT% files processed successfully.
)
if not "%MISSING_COUNT%"=="0" echo WARNING: %MISSING_COUNT% listed files were missing and skipped.
if not "%FAILED_COUNT%"=="0" echo WARNING: %FAILED_COUNT% files could not be copied.
if not defined WHATIF if "%MISSING_COUNT%"=="0" if "%FAILED_COUNT%"=="0" (
    call :WriteUpdateMarker
    if errorlevel 1 (
        echo WARNING: Files were published, but the update marker could not be created.
    ) else (
        echo Update marker created.
    )
)
goto :Finish

:CopyOne
set "RELATIVE_PATH=%~1"
set "SOURCE_FILE=%REPOSITORY%\%RELATIVE_PATH%"
set "DESTINATION_FILE=%DESTINATION%\%RELATIVE_PATH%"

if not exist "%SOURCE_FILE%" (
    set /a MISSING_COUNT+=1
    echo WARNING: Missing file skipped: %RELATIVE_PATH%
    exit /b
)

for %%D in ("%DESTINATION_FILE%") do set "DESTINATION_DIRECTORY=%%~dpD"
for %%S in ("%SOURCE_FILE%") do set "SOURCE_DIRECTORY=%%~dpS"
for %%S in ("%SOURCE_FILE%") do set "SOURCE_NAME=%%~nxS"
set "DESTINATION_DIRECTORY=%DESTINATION_DIRECTORY:~0,-1%"
set "SOURCE_DIRECTORY=%SOURCE_DIRECTORY:~0,-1%"
if not exist "%DESTINATION_DIRECTORY%" (
    if defined WHATIF (
        echo [WHATIF] Create directory: %DESTINATION_DIRECTORY%
    ) else (
        mkdir "%DESTINATION_DIRECTORY%" >nul 2>&1
        if errorlevel 1 (
            set /a FAILED_COUNT+=1
            echo WARNING: Cannot create directory: %DESTINATION_DIRECTORY%
            exit /b
        )
    )
)

if defined WHATIF (
    echo [WHATIF] Copy: %RELATIVE_PATH%
) else (
    call :RobocopyOne "%SOURCE_DIRECTORY%" "%DESTINATION_DIRECTORY%" "%SOURCE_NAME%"
    if errorlevel 8 (
        set /a FAILED_COUNT+=1
        echo WARNING: Copy failed: %RELATIVE_PATH% ^(robocopy reported an error^)
    ) else (
        set /a COPIED_COUNT+=1
    )
)
exit /b

:RobocopyOne
robocopy "%~1" "%~2" "%~3" /R:2 /W:1 /COPY:DAT /DCOPY:DAT /NFL /NDL /NJH /NJS >nul
exit /b %ERRORLEVEL%

:ClearDestination
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:DESTINATION; try { Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction Stop; exit 0 } catch { Write-Error $_; exit 1 }"
exit /b %ERRORLEVEL%

:WriteUpdateMarker
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:DESTINATION; $d=Get-Date -Format yyyyMMdd-HHmmss; $n='LastUpdate'+$d+'.txt'; $target=$p+'\'+$n; $c='PublishedDate='+$d; try { Set-Content -LiteralPath $target -Value $c -Encoding utf8 -ErrorAction Stop; exit 0 } catch { Write-Error $_; exit 1 }"
exit /b %ERRORLEVEL%

:FindGitRoot
set "CANDIDATE_DIRECTORY=%~f1"
:FindGitRootLoop
if exist "%CANDIDATE_DIRECTORY%\.git" (
    set "REPOSITORY=%CANDIDATE_DIRECTORY%"
    exit /b
)
for %%P in ("%CANDIDATE_DIRECTORY%\..") do set "PARENT_DIRECTORY=%%~fP"
if /I "%PARENT_DIRECTORY%"=="%CANDIDATE_DIRECTORY%" exit /b
set "CANDIDATE_DIRECTORY=%PARENT_DIRECTORY%"
goto :FindGitRootLoop

:Finish
echo.
pause
endlocal
