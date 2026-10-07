. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgePidFile = Join-Path $BridgeRoot 'state\gateway-process.json'
if (-not (Test-Path -LiteralPath $BridgePidFile)) { Write-Output 'No project gateway PID record.'; exit 0 }
$BridgeSaved = Get-Content -LiteralPath $BridgePidFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($BridgeSaved.projectId -ne $BridgeMarker.projectId -or $BridgeSaved.cli -ne $BridgeCli -or $BridgeSaved.executable -ne $BridgeNode) { throw 'Saved process identity does not match this project.' }
$BridgeExisting = Get-Process -Id $BridgeSaved.pid -ErrorAction SilentlyContinue
if ($BridgeExisting) {
    if ($BridgeExisting.Path -ne $BridgeSaved.executable -or $BridgeExisting.StartTime.ToUniversalTime().Ticks.ToString() -ne $BridgeSaved.startTimeUtcTicks) { throw 'PID was reused or identity changed. Refusing to terminate it.' }
    & "$env:SystemRoot\System32\taskkill.exe" /PID $BridgeSaved.pid /T /F
    if ($LASTEXITCODE -ne 0) { throw 'Project process termination failed.' }
}
Remove-Item -LiteralPath $BridgePidFile
Write-Output 'Project gateway stopped. Credentials and conversations are preserved.'
