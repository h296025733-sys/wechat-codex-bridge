[CmdletBinding()]
param([switch]$DeviceCode)
. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgeArgs = @('models','auth','login','--provider','openai')
if ($DeviceCode) { $BridgeArgs += '--device-code' }
Invoke-Bridge @BridgeArgs
Write-Output 'Login command completed. Verify the saved auth profile and a real model request; this is not a WeChat QR login.'
