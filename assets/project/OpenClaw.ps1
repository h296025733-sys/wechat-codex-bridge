# Invoke from a PowerShell terminal, e.g. .\OpenClaw.ps1 --version
. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
Push-Location -LiteralPath $BridgeRoot
try {
    & $BridgeNode $BridgeCli @args
    $BridgeExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $BridgeExitCode
