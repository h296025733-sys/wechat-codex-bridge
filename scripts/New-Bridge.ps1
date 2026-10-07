[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$TargetDir,
    [Parameter(Mandatory=$true)][ValidatePattern('^openai/[a-zA-Z0-9._-]+$')][string]$Model,
    [ValidateRange(1024,65535)][int]$Port = 18791
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This initializer is for Windows. Read references/portability.md.' }
$BridgeTarget = [System.IO.Path]::GetFullPath($TargetDir)
if ($BridgeTarget.TrimEnd('\') -eq [System.IO.Path]::GetPathRoot($BridgeTarget).TrimEnd('\')) { throw 'Choose a project subdirectory, not a drive root.' }
if (Test-Path -LiteralPath $BridgeTarget) {
    if (-not (Test-Path -LiteralPath $BridgeTarget -PathType Container)) { throw 'Target exists and is not a directory.' }
    if (@(Get-ChildItem -LiteralPath $BridgeTarget -Force).Count -gt 0) { throw 'Target is not empty. Resume its existing setup instead of overwriting it.' }
}
$BridgeNodePath = (Get-Command node.exe -ErrorAction Stop).Source
$BridgeVersion = & $BridgeNodePath -p 'process.versions.node'
if ($LASTEXITCODE -ne 0 -or [version]$BridgeVersion -lt [version]'24.0.0') { throw 'Install a compatible Node.js 24+ runtime first; this script does not replace system Node.' }
Get-Command npm.cmd -ErrorAction Stop | Out-Null
$BridgeProbe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
try { $BridgeProbe.Start() } catch { throw "Port $Port is already in use. Choose another free port; do not stop its owner." } finally { $BridgeProbe.Stop() }
$BridgeTemplate = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\project'
New-Item -ItemType Directory -Path $BridgeTarget -Force | Out-Null
Get-ChildItem -LiteralPath $BridgeTemplate -Force | Copy-Item -Destination $BridgeTarget -Recurse
foreach ($BridgePart in @('state','host','logs','artifacts','.tmp','.cache','runtime')) { New-Item -ItemType Directory -Path (Join-Path $BridgeTarget $BridgePart) -Force | Out-Null }
$BridgeEncoding = New-Object System.Text.UTF8Encoding $false
$BridgeConfig = Get-Content -LiteralPath (Join-Path $BridgeTarget 'config.template.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$BridgeBytes = New-Object byte[] 32
$BridgeRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $BridgeRandom.GetBytes($BridgeBytes) } finally { $BridgeRandom.Dispose() }
$BridgeConfig.gateway.auth.token = [System.BitConverter]::ToString($BridgeBytes).Replace('-','').ToLowerInvariant()
$BridgeConfig.gateway.port = $Port
$BridgeConfig.agents.defaults.workspace = Join-Path $BridgeTarget 'workspace'
$BridgeConfig.agents.defaults.model.primary = $Model
$BridgeConfig.agents.defaults.models = @{ $Model = @{ agentRuntime = @{ id = 'codex' } } }
$BridgeConfig.logging.file = Join-Path $BridgeTarget 'logs\openclaw.log'
[System.IO.File]::WriteAllText((Join-Path $BridgeTarget 'state\openclaw.json'), ($BridgeConfig | ConvertTo-Json -Depth 35), $BridgeEncoding)
$BridgeMarker = [ordered]@{ formatVersion=1; projectId=[guid]::NewGuid().ToString(); createdAt=[DateTime]::UtcNow.ToString('o'); model=$Model; port=$Port; versions=@{ openclaw='2026.9.2'; codexPlugin='2026.9.2'; weixinPlugin='2.4.8' } }
[System.IO.File]::WriteAllText((Join-Path $BridgeTarget '.bridge-project.json'), ($BridgeMarker | ConvertTo-Json -Depth 5), $BridgeEncoding)
$BridgeNetwork = @{ proxy=$null; source='direct-until-detected'; noProxy='localhost,127.0.0.1,::1,ilinkai.weixin.qq.com,liteapp.weixin.qq.com,novac2c.cdn.weixin.qq.com' }
[System.IO.File]::WriteAllText((Join-Path $BridgeTarget 'network.json'), ($BridgeNetwork | ConvertTo-Json), $BridgeEncoding)
Write-Output "Created isolated project: $BridgeTarget"
Write-Output 'No packages installed, no accounts authenticated, and no messages sent by this initializer.'
