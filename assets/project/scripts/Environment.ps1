$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$BridgeRoot = Split-Path -Parent $PSScriptRoot
$BridgeMarkerPath = Join-Path $BridgeRoot '.bridge-project.json'
if (-not (Test-Path -LiteralPath $BridgeMarkerPath -PathType Leaf)) { throw 'Missing project marker; run New-Bridge.ps1 in an empty directory first.' }
$BridgeMarker = Get-Content -LiteralPath $BridgeMarkerPath -Raw -Encoding UTF8 | ConvertFrom-Json
$BridgeNode = (Get-Command node.exe -ErrorAction Stop).Source
$BridgeCli = Join-Path $BridgeRoot 'runtime\node_modules\openclaw\openclaw.mjs'
# Isolate this child shell from another project's OpenClaw overrides.
Get-ChildItem Env: | Where-Object { $_.Name -like 'OPENCLAW_*' } | ForEach-Object { Remove-Item -LiteralPath ('Env:'+$_.Name) }
$env:OPENCLAW_HOME = Join-Path $BridgeRoot 'host'
$env:OPENCLAW_STATE_DIR = Join-Path $BridgeRoot 'state'
$env:OPENCLAW_CONFIG_PATH = Join-Path $BridgeRoot 'state\openclaw.json'
$env:OPENCLAW_WORKSPACE_DIR = Join-Path $BridgeRoot 'workspace'
$env:OPENCLAW_NO_AUTO_UPDATE = '1'
$env:OPENCLAW_DISABLE_BONJOUR = '1'
$env:OPENCLAW_LOAD_SHELL_ENV = '0'
$env:npm_config_cache = Join-Path $BridgeRoot '.cache\npm'
$env:XDG_CACHE_HOME = Join-Path $BridgeRoot '.cache'
$env:TEMP = Join-Path $BridgeRoot '.tmp'
$env:TMP = $env:TEMP
$env:PATH = (Join-Path $BridgeRoot 'runtime') + ';' + $env:PATH
$BridgeNetwork = Get-Content -LiteralPath (Join-Path $BridgeRoot 'network.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($BridgeName in @('HTTPS_PROXY','HTTP_PROXY','ALL_PROXY')) { Remove-Item -LiteralPath ('Env:' + $BridgeName) -ErrorAction SilentlyContinue }
if ($BridgeNetwork.proxy) { $env:HTTPS_PROXY=$BridgeNetwork.proxy; $env:HTTP_PROXY=$BridgeNetwork.proxy }
$env:NO_PROXY = $BridgeNetwork.noProxy
$env:NODE_USE_ENV_PROXY = '1'
foreach ($BridgeName in @('OPENAI_API_KEY','CODEX_API_KEY','OPENAI_ADMIN_KEY','OPENAI_BASE_URL','OPENAI_API_BASE')) { Remove-Item -LiteralPath ('Env:' + $BridgeName) -ErrorAction SilentlyContinue }
$BridgeConfig = Get-Content -LiteralPath $env:OPENCLAW_CONFIG_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
$BridgePort = [int]$BridgeConfig.gateway.port
function Write-BridgeJson($Path, $Value) { [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding $false)) }
function Invoke-Bridge {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $BridgeCli)) { throw 'Runtime is not installed. Run Install-Runtime.ps1.' }
    & $BridgeNode $BridgeCli @Arguments
    if ($LASTEXITCODE -ne 0) { throw "OpenClaw command failed with exit code $LASTEXITCODE. Inspect its native output before retrying." }
}
function Test-BridgeReadiness {
    Add-Type -AssemblyName System.Net.Http
    $BridgeHandler = New-Object System.Net.Http.HttpClientHandler
    $BridgeHandler.UseProxy = $false
    $BridgeClient = New-Object System.Net.Http.HttpClient($BridgeHandler)
    $BridgeClient.Timeout = [TimeSpan]::FromSeconds(2)
    try {
        $BridgeResponse = $BridgeClient.GetAsync("http://127.0.0.1:$BridgePort/readyz").GetAwaiter().GetResult()
        if ([int]$BridgeResponse.StatusCode -ne 200) { return $false }
        return (($BridgeResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json).ready -eq $true)
    } catch { return $false } finally { $BridgeClient.Dispose(); $BridgeHandler.Dispose() }
}
