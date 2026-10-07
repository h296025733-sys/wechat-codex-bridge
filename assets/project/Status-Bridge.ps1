. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgeProcessMatch=$false
$BridgePidFile=Join-Path $BridgeRoot 'state\gateway-process.json'
if (Test-Path -LiteralPath $BridgePidFile) {
    $BridgeSaved=Get-Content -LiteralPath $BridgePidFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $BridgeProcess=Get-Process -Id $BridgeSaved.pid -ErrorAction SilentlyContinue
    if ($BridgeProcess) { $BridgeProcessMatch=($BridgeSaved.projectId -eq $BridgeMarker.projectId -and $BridgeProcess.Path -eq $BridgeSaved.executable -and $BridgeProcess.StartTime.ToUniversalTime().Ticks.ToString() -eq $BridgeSaved.startTimeUtcTicks) }
}
$BridgeReady=($BridgeProcessMatch -and (Test-BridgeReadiness))
$BridgeSummary=[ordered]@{processIdentityMatches=$BridgeProcessMatch; localReady=$BridgeReady; port=$BridgePort; model=$BridgeConfig.agents.defaults.model.primary; toolsDeny=$BridgeConfig.tools.deny; channels=@()}
if ($BridgeReady) {
    $BridgeStatus=(Invoke-Bridge channels status --json | Out-String) | ConvertFrom-Json
    $BridgeSummary.channels=@($BridgeStatus.channelAccounts.'openclaw-weixin' | Select-Object configured,running,lifecycle,lastError,lastInboundAt,lastOutboundAt)
}
$BridgeSummary | ConvertTo-Json -Depth 6
