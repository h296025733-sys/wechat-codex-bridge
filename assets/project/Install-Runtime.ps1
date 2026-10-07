. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
if (Test-Path -LiteralPath (Join-Path $BridgeRoot 'state\gateway-process.json')) { throw 'Stop this project gateway before installing or changing packages.' }
$BridgeVersion = $BridgeMarker.versions.openclaw
$BridgePackage = Join-Path $BridgeRoot 'runtime\node_modules\openclaw\package.json'
if (Test-Path -LiteralPath $BridgePackage) {
    $BridgeInstalled = Get-Content -LiteralPath $BridgePackage -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($BridgeInstalled.version -ne $BridgeVersion) { throw 'Installed runtime version differs from the project baseline. Review migration before changing it.' }
} else {
    $BridgeNpm = (Get-Command npm.cmd -ErrorAction Stop).Source
    $BridgeNpmVersion = & $BridgeNpm --version
    if ($LASTEXITCODE -ne 0) { throw 'npm version check failed.' }
    $BridgeInstallArgs = @('install','--global','--prefix',(Join-Path $BridgeRoot 'runtime'),("openclaw@"+$BridgeVersion),'--registry=https://registry.npmjs.org','--no-fund','--no-audit')
    # npm 11 requires --global when --allow-scripts is used without package.json.
    if ([version]$BridgeNpmVersion -ge [version]'11.0.0') { $BridgeInstallArgs += '--allow-scripts=openclaw' }
    & $BridgeNpm @BridgeInstallArgs
    if ($LASTEXITCODE -ne 0) { throw "Real npm installation failed ($LASTEXITCODE). It was not a successful install or self-test." }
}
Invoke-Bridge --version
$BridgePlugins = @(
    @{ id='codex'; spec=('@openclaw/codex@'+$BridgeMarker.versions.codexPlugin); version=$BridgeMarker.versions.codexPlugin },
    @{ id='openclaw-weixin'; spec=('@tencent-weixin/openclaw-weixin@'+$BridgeMarker.versions.weixinPlugin); version=$BridgeMarker.versions.weixinPlugin }
)
foreach ($BridgePlugin in $BridgePlugins) {
    $BridgeListing = (Invoke-Bridge plugins list --json | Out-String) | ConvertFrom-Json
    $BridgePresent = @($BridgeListing.plugins | Where-Object { $_.id -eq $BridgePlugin.id -and $_.version -eq $BridgePlugin.version -and $_.trustedOfficialInstall -eq $true -and (Test-Path -LiteralPath $_.source) })
    if ($BridgePresent.Count -eq 0) { Invoke-Bridge plugins install $BridgePlugin.spec --pin --accept-capabilities --force }
}
$BridgePatch = Join-Path $BridgeRoot 'chat-only.patch.json'
Invoke-Bridge config patch --file $BridgePatch --dry-run
Invoke-Bridge config patch --file $BridgePatch
Invoke-Bridge config validate
$BridgeListing = (Invoke-Bridge plugins list --json | Out-String) | ConvertFrom-Json
$BridgeSummary = @($BridgeListing.plugins | Where-Object { $_.id -in @('codex','openclaw-weixin') } | Select-Object id,version,status,enabled)
if (@($BridgeSummary | Where-Object { $_.status -eq 'loaded' -and $_.enabled }).Count -ne 2) { throw 'Both plugins must load successfully before installation is reported complete.' }
Write-BridgeJson (Join-Path $BridgeRoot 'artifacts\installed-components.json') $BridgeSummary
Write-Output 'Packages installed and chat-only config validated. Run Check-Auth.ps1 next; native local OAuth may already be available. WeChat messaging is still unverified.'
