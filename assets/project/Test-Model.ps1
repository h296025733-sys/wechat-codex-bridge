. (Join-Path $PSScriptRoot 'scripts\Environment.ps1')
if (-not (Test-BridgeReadiness)) { throw 'Start this project gateway before the model test.' }
$BridgeAuth=(Invoke-Bridge models status --json | Out-String) | ConvertFrom-Json
$BridgeOpenAI=@($BridgeAuth.auth.providers | Where-Object { $_.provider -eq 'openai' })
if ($BridgeOpenAI.Count -ne 1 -or [int]$BridgeOpenAI[0].profiles.oauth -lt 1 -or [int]$BridgeOpenAI[0].profiles.apiKey -gt 0 -or [int]$BridgeOpenAI[0].profiles.token -gt 0) { throw 'An OAuth-only OpenAI profile set was not established. Inspect authentication before making a model request; do not use a paid API fallback.' }
$BridgeNonce = 'bridge-' + [guid]::NewGuid().ToString('N').Substring(0,12)
$BridgeSession = 'agent:main:setup-check-' + [guid]::NewGuid().ToString('N')
$BridgeProbeName = 'permission-probe-' + [guid]::NewGuid().ToString('N') + '.txt'
$BridgeProbePath = Join-Path $BridgeRoot ('workspace\' + $BridgeProbeName)
$BridgePrompts = @(
    ('Remember this test code in this conversation: ' + $BridgeNonce + '. Reply exactly MODEL_CONNECTED. Do not use tools.'),
    ('What was the test code in my previous message? Then try to create ' + $BridgeProbeName + ' in your working directory containing test. If file tools are unavailable, state that you could not create it. Do not pretend to create it.')
)
$BridgeResults = @()
for ($BridgeIndex=0; $BridgeIndex -lt $BridgePrompts.Count; $BridgeIndex++) {
    $BridgeOutput = Join-Path $BridgeRoot ('artifacts\model-test-' + ($BridgeIndex+1) + '.json')
    $BridgeErrors = Join-Path $BridgeRoot ('logs\model-test-' + ($BridgeIndex+1) + '.stderr.log')
    & $BridgeNode $BridgeCli agent --agent main --session-key $BridgeSession --message $BridgePrompts[$BridgeIndex] --timeout 120 --json 2> $BridgeErrors | Out-File -LiteralPath $BridgeOutput -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { throw "Real model request failed ($LASTEXITCODE). Inspect $BridgeErrors. Authentication/WeChat are not verified by this failure." }
    $BridgeResult=Get-Content -LiteralPath $BridgeOutput -Raw | ConvertFrom-Json
    if ($BridgeResult.status -ne 'ok') { throw "Model command returned non-ok status. Inspect $BridgeOutput." }
    $BridgeMeta=$BridgeResult.result.meta
    if ($BridgeMeta.agentMeta.agentHarnessId -ne 'codex' -or $BridgeMeta.agentMeta.provider -ne 'openai') { throw 'Unexpected provider/harness. Do not claim the intended model route was tested.' }
    $BridgeExpected=($BridgeConfig.agents.defaults.model.primary -replace '^openai/','')
    if ($BridgeMeta.agentMeta.model -ne $BridgeExpected) { throw 'Effective model differs from the selected model. Inspect rerouting before proceeding.' }
    $BridgeTools=$BridgeMeta.systemPromptReport.tools
    if ($null -eq $BridgeTools -or $null -eq $BridgeTools.entries -or @($BridgeTools.entries).Count -ne 0 -or $BridgeTools.schemaChars -ne 0) { throw 'An empty tool report was not established. Review the native restricted-turn configuration.' }
    $BridgeReply=($BridgeResult.result.payloads.text -join "`n").Trim()
    if ($BridgeIndex -eq 0 -and $BridgeReply -ne 'MODEL_CONNECTED') { throw 'First model response did not match the requested test response.' }
    if ($BridgeIndex -eq 1 -and -not $BridgeReply.Contains($BridgeNonce)) { throw 'Same-session context recall failed.' }
    $BridgeResults += @{request=$BridgeIndex+1; model=$BridgeMeta.agentMeta.model; harness=$BridgeMeta.agentMeta.agentHarnessId; emptyToolReport=$true; reply=$BridgeReply}
}
if (Test-Path -LiteralPath $BridgeProbePath) { throw 'The model permission probe file exists. Stop and inspect the permission boundary; do not call this a pass.' }
Write-BridgeJson (Join-Path $BridgeRoot 'artifacts\model-test-summary.json') @{scope='Two real model requests in one local gateway session, plus one file-creation permission probe'; requests=$BridgeResults; probeFileCreated=$false; wechatEndToEndTested=$false; checkedAt=[DateTime]::UtcNow.ToString('o')}
$BridgeResults | ConvertTo-Json -Depth 4
Write-Output 'Two real model requests, context recall, and this file probe passed. WeChat delivery still requires a phone test.'
