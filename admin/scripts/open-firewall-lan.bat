@echo off
REM ---------------------------------------------------------------------------
REM  Opens Windows Firewall so a PHYSICAL PHONE on the same Wi-Fi can reach
REM  the two local dev servers (they bind 0.0.0.0 but Windows blocks inbound
REM  LAN by default, which is why the phone timed out on 192.168.100.181:3001
REM  while the PC reached it fine).
REM
REM  RIGHT-CLICK this file -> "Run as administrator".
REM    - 3001 : admin Express proxy  (GET/POST /api/ai/predictions)
REM    - 8001 : ai-service FastAPI   (uvicorn main:app --port 8001)
REM
REM  After running: keep phone + PC on the SAME Wi-Fi, then flutter run.
REM  To undo, delete the two "FIT ..." rules in
REM  Windows Defender Firewall -> Advanced Settings -> Inbound Rules.
REM ---------------------------------------------------------------------------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Not running as administrator. Right-click -^> Run as administrator.
    pause
    exit /b 1
)

echo Adding inbound firewall rules...
netsh advfirewall firewall delete rule name="FIT AI 8001" >nul 2>&1
netsh advfirewall firewall delete rule name="FIT Admin 3001" >nul 2>&1
netsh advfirewall firewall add rule name="FIT AI 8001"    dir=in action=allow protocol=TCP localport=8001
netsh advfirewall firewall add rule name="FIT Admin 3001" dir=in action=allow protocol=TCP localport=3001
echo.
echo Done. Phone on the same Wi-Fi can now reach both services.
pause
