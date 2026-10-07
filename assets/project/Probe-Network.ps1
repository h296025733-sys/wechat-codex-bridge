. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
& $BridgeNode (Join-Path $BridgeRoot 'scripts\probe-network.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Public endpoint probe failed. Inspect the reported native error; do not repeat user authorization yet.' }
