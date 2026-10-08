@echo off
REM ===========================================================================
REM  FIT Sight - start the two AI servers AND bridge them to the phone.
REM
REM  WHY THIS EXISTS
REM  ---------------
REM  Windows Firewall blocks inbound LAN connections by default, so a physical
REM  phone on the same Wi-Fi times out on http://192.168.100.181:3001 even
REM  though the PC reaches it fine. Opening a firewall port needs an elevated
REM  shell, which a normal dev terminal does not have.
REM
REM  `adb reverse` is the way around it: it forwards a port ON THE PHONE to a
REM  port ON THE PC over the USB cable, so the traffic never crosses the
REM  network and the firewall is never consulted. NO ADMIN RIGHTS NEEDED.
REM
REM  USAGE
REM  -----
REM    1. Plug the phone in with USB debugging ON.
REM    2. Double-click this file (no "Run as administrator" needed).
REM    3. flutter run  -> the AI Progress Forecast card fills in by itself.
REM
REM  The app tries http://localhost:3001 first, which is exactly what this
REM  script makes reachable. 3001 is the Express proxy; 8001 is the FastAPI
REM  AI service it fronts.
REM
REM  EMULATOR? Skip this file: 10.0.2.2 is already in the app's fallback list.
REM  NEED THE PHONE OFF THE CABLE? Run open-firewall-lan.bat as administrator
REM  instead (or as well) - it opens the real network ports.
REM ===========================================================================
setlocal
cd /d "%~dp0\..\..\ai-service"

echo [1/3] Checking for a connected phone...
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
    echo   [!] No phone detected over USB.
    echo       - plug the phone in
    echo       - enable Settings ^> Developer options ^> USB debugging
    echo       - accept the "Allow USB debugging?" prompt on the phone
    echo.
    echo       Starting the servers anyway - the PC can still use them.
) else (
    echo   Phone found. Tunneling its localhost to this PC over USB...
    "%ADB%" reverse tcp:3001 tcp:3001
    "%ADB%" reverse tcp:8001 tcp:8001
    "%ADB%" reverse --list
)

echo.
echo [2/3] Starting the AI service on port 8001 ^(new window^)...
start "FIT AI Service 8001" cmd /k "title FIT AI Service :8001 && python -m uvicorn main:app --host 0.0.0.0 --port 8001"

echo [3/3] Checking the admin API proxy on port 3001...
netstat -ano | findstr /R /C:":3001 .*LISTENING" >nul
if errorlevel 1 (
    echo   Port 3001 is free - starting the admin API server ^(new window^)...
    start "FIT Admin API 3001" cmd /k "title FIT Admin API :3001 && cd /d %~dp0.. && node server\index.js"
) else (
    echo   Port 3001 is already serving - reusing it.
)

echo.
echo Done. Leave this window's children running, then:  flutter run
echo The forecast card should now load instead of "Could not reach the
echo prediction service".
endlocal
