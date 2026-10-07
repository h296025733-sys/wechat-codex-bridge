. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
$BridgeAuthStatus=(Invoke-Bridge models status --json | Out-String) | ConvertFrom-Json
$BridgeProviders=@($BridgeAuthStatus.auth.providers | Where-Object { $_.provider -eq 'openai' })
$BridgeOAuth=0; $BridgeApiKeys=0; $BridgeTokens=0
foreach ($BridgeProvider in $BridgeProviders) {
    $BridgeOAuth += [int]$BridgeProvider.profiles.oauth
    $BridgeApiKeys += [int]$BridgeProvider.profiles.apiKey
    $BridgeTokens += [int]$BridgeProvider.profiles.token
}
@{openaiOAuthProfiles=$BridgeOAuth; apiKeyProfiles=$BridgeApiKeys; tokenProfiles=$BridgeTokens; missingProviders=$BridgeAuthStatus.auth.missingProvidersInUse; note='Existing native local Codex OAuth may bootstrap this project. Verify account ownership if unclear. This does not prove a real model request.'} | ConvertTo-Json -Depth 4
