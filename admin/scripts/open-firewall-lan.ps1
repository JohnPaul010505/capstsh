# Opens Windows Firewall inbound for the two local dev servers so a PHYSICAL
# PHONE on the same Wi-Fi can reach them. They bind 0.0.0.0 but Windows blocks
# unsolicited inbound LAN traffic by default - which is why the member app's
# AI forecast card shows "Could not reach the prediction service" on the phone
# while the PC itself reaches http://192.168.100.181:3001 fine.
#
#   3001 : admin Express proxy  (POST /api/ai/predictions)
#   8001 : ai-service FastAPI   (uvicorn main:app --port 8001)
#
# Run in an ELEVATED PowerShell (right-click -> Run as administrator), or
# launch via:  Start-Process powershell -Verb RunAs -ArgumentList '-File', '<this path>'
# To undo: delete the two "FIT ..." rules in
#          Windows Defender Firewall -> Advanced Settings -> Inbound Rules.

$rules = @(
    @{ Name = 'FIT Admin 3001'; Port = 3001 },
    @{ Name = 'FIT AI 8001';    Port = 8001 }
)

foreach ($r in $rules) {
    netsh advfirewall firewall delete rule name=$($r.Name) | Out-Null
    netsh advfirewall firewall add rule name=$($r.Name) dir=in action=allow protocol=TCP localport=$($r.Port) | Out-Null
    Write-Host "Added: $($r.Name) (TCP $($r.Port))"
}

# Verify
Get-NetFirewallRule -Direction Inbound -Enabled True -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'FIT *' } |
    ForEach-Object {
        $port = ($_ | Get-NetFirewallPortFilter).LocalPort
        Write-Host "Verified: $($_.DisplayName) -> TCP $port"
    }
