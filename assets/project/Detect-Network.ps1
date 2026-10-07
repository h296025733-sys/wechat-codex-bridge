[CmdletBinding()]
param([ValidateSet('Auto','Direct','Explicit')][string]$Mode='Auto', [string]$Proxy)
$ErrorActionPreference = 'Stop'
# Capture the caller's existing settings before Environment.ps1 isolates them.
$BridgeCandidate = $null
$BridgeSource = 'direct'
if ($Mode -eq 'Explicit') {
    if (-not $Proxy) { throw '-Proxy is required with -Mode Explicit.' }
    $BridgeCandidate=$Proxy; $BridgeSource='user-specified'
} elseif ($Mode -eq 'Auto') {
    foreach ($BridgeVar in @('HTTPS_PROXY','HTTP_PROXY')) {
        $BridgeValue=[Environment]::GetEnvironmentVariable($BridgeVar)
        if ($BridgeValue) { $BridgeCandidate=$BridgeValue; $BridgeSource='existing-environment'; break }
    }
    if (-not $BridgeCandidate) {
        $BridgeUri = [uri]'https://auth.openai.com'
        $BridgeRoute = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($BridgeUri)
        if ($BridgeRoute.AbsoluteUri -ne $BridgeUri.AbsoluteUri) { $BridgeCandidate=$BridgeRoute.AbsoluteUri; $BridgeSource='existing-windows-proxy' }
    }
}
if ($BridgeCandidate) {
    $BridgeParsed = [uri]$BridgeCandidate
    if ($BridgeParsed.Scheme -notin @('http','https')) { throw 'Only HTTP(S) proxy URLs are supported by this helper.' }
    if ($BridgeParsed.UserInfo) { throw 'Do not put proxy passwords into this project. Configure an existing OS-managed/local proxy instead.' }
}
. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgeNetwork.proxy=$BridgeCandidate
$BridgeNetwork.source=$BridgeSource
Write-BridgeJson (Join-Path $BridgeRoot 'network.json') $BridgeNetwork
Write-Output "Project network route saved ($BridgeSource). No system settings were changed."
Write-Output 'Run Probe-Network.ps1 before asking the user to authorize. Changing a route does not establish account or region eligibility.'
