@echo off
REM Kills whatever is listening on the backend/frontend dev ports, then
REM restarts both in their own windows so hot-reload/logs stay visible.
setlocal

set BACKEND_PORT=8090
set FRONTEND_PORT=8080
set FRONTEND2_PORT=8081
REM FlutterSpell_Game builds URLs as "$baseUrl/path" (no trailing slash expected).
set API_BASE_URL_GAME=http://localhost:%BACKEND_PORT%
REM FlutterSpell builds URLs as "${baseUrl}path" (trailing slash required).
set API_BASE_URL_SPELL=http://localhost:%BACKEND_PORT%/

echo Stopping backend (port %BACKEND_PORT%)...
call :killport %BACKEND_PORT%

echo Stopping frontend (port %FRONTEND_PORT%)...
call :killport %FRONTEND_PORT%

echo Stopping frontend (port %FRONTEND2_PORT%)...
call :killport %FRONTEND2_PORT%

echo Starting backend (SpellBackend, port %BACKEND_PORT%)...
start "SpellBackend" cmd /k "cd /d "%~dp0SpellBackend" && set SERVER_PORT=%BACKEND_PORT% && python main.py"

echo Starting frontend (FlutterSpell_Game, port %FRONTEND_PORT%)...
start "FlutterSpell_Game" cmd /k "cd /d "%~dp0FlutterSpell_Game" && flutter run -d chrome --web-port=%FRONTEND_PORT% --dart-define=API_BASE_URL=%API_BASE_URL_GAME%"

echo Starting frontend (FlutterSpell, port %FRONTEND2_PORT%)...
start "FlutterSpell" cmd /k "cd /d "%~dp0FlutterSpell" && flutter run -d chrome --web-port=%FRONTEND2_PORT% --dart-define=API_BASE_URL=%API_BASE_URL_SPELL%"

echo Done.
goto :eof

:killport
set "port=%~1"
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /c:":%port% " ^| findstr /c:"LISTENING"') do (
    echo   killing PID %%p on port %port%
    taskkill /F /PID %%p >nul 2>&1
)
goto :eof
