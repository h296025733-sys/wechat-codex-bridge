. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgePidFile = Join-Path $BridgeRoot 'state\gateway-process.json'
if (Test-Path -LiteralPath $BridgePidFile) {
    $BridgeSaved = Get-Content -LiteralPath $BridgePidFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $BridgeExisting = Get-Process -Id $BridgeSaved.pid -ErrorAction SilentlyContinue
    if ($BridgeExisting) {
        if ($BridgeSaved.projectId -ne $BridgeMarker.projectId -or $BridgeExisting.Path -ne $BridgeSaved.executable -or $BridgeExisting.StartTime.ToUniversalTime().Ticks.ToString() -ne $BridgeSaved.startTimeUtcTicks) { throw 'Process record does not match this project; inspect it without terminating another process.' }
        if (-not (Test-BridgeReadiness)) { throw 'Project process exists but is not locally ready. Inspect project logs.' }
        Write-Output 'Project gateway is already running and locally ready.'
        exit 0
    }
}
$BridgeProbe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $BridgePort)
try { $BridgeProbe.Start() } catch { throw "Port $BridgePort is occupied. Do not stop an unrelated service." } finally { $BridgeProbe.Stop() }
Invoke-Bridge config validate
$BridgeProcess = Start-Process -FilePath $BridgeNode -ArgumentList @(('"'+$BridgeCli+'"'),'gateway','run') -WorkingDirectory $BridgeRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $BridgeRoot 'logs\gateway.stdout.log') -RedirectStandardError (Join-Path $BridgeRoot 'logs\gateway.stderr.log') -PassThru
Write-BridgeJson $BridgePidFile @{ pid=$BridgeProcess.Id; startTimeUtcTicks=$BridgeProcess.StartTime.ToUniversalTime().Ticks.ToString(); executable=$BridgeNode; cli=$BridgeCli; projectId=$BridgeMarker.projectId }
$BridgeReady = $false
for ($BridgeAttempt=0; $BridgeAttempt -lt 30; $BridgeAttempt++) {
    $BridgeProcess.Refresh()
    if ($BridgeProcess.HasExited) { throw 'Project gateway exited. Inspect logs/gateway.stderr.log and gateway.stdout.log.' }
    if (Test-BridgeReadiness) { $BridgeReady=$true; break }
    Start-Sleep -Milliseconds 1000
}
if (-not $BridgeReady) { throw 'Process started, but readiness was not confirmed. The PID record is retained for diagnosis.' }
Write-Output "Project gateway ready at loopback port $BridgePort. Authentication and message delivery need separate verification."
