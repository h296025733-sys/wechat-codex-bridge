[CmdletBinding()]
param([switch]$NoBrowser, [ValidateRange(0,600)][int]$TimeoutSeconds=0)
. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgePairArgs=@()
if ($NoBrowser) { $BridgePairArgs+='--no-browser' }
if ($TimeoutSeconds -gt 0) { $BridgePairArgs+=@('--timeout-seconds',$TimeoutSeconds.ToString()) }
& $BridgeNode (Join-Path $BridgeRoot 'scripts\pair-wechat.cjs') @BridgePairArgs
exit $LASTEXITCODE
