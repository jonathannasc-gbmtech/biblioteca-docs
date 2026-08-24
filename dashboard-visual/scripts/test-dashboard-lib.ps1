# Auto-check das funcoes puras de dashboard-lib.ps1 (ponytail: assert
# executavel, sem framework). Cobre a logica de dado/comando do gerador
# do dashboard - a parte onde um bug de fato corrompe ou quebra algo, nao
# o HTML/CSS/JS de UI (isso exigiria DOM/browser, fora de escopo aqui).
$hubRoot = 'C:\teste-fake-hub'
. (Join-Path $PSScriptRoot 'dashboard-lib.ps1')

$failures = @()
function Assert($cond, [string]$label) {
    if (-not $cond) { $script:failures += $label }
}

# Esc
Assert ((Esc '<a href="x">&</a>') -eq '&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;') 'Esc: escapa & < > "'
Assert ((Esc $null) -eq '') 'Esc: null vira string vazia'
Assert ((Esc 'texto simples') -eq 'texto simples') 'Esc: texto sem caractere especial fica igual'

# Get-Signals
$docsComPr = @(
    [PSCustomObject]@{ Body = 'ver https://github.com/org/repo/pull/12 e mais texto' }
    [PSCustomObject]@{ Body = 'mesmo link de novo: https://github.com/org/repo/pull/12' }
    [PSCustomObject]@{ Body = 'outro PR https://github.com/org/repo2/pull/34, sem link nenhum aqui' }
)
$signals = Get-Signals $docsComPr
Assert (@($signals.PRs).Count -eq 2) 'Get-Signals: deduplica o mesmo link de PR'
Assert (@($signals.PRs) -contains 'https://github.com/org/repo/pull/12') 'Get-Signals: acha o link do 1o PR'
Assert (@($signals.PRs) -contains 'https://github.com/org/repo2/pull/34') 'Get-Signals: acha o link do 2o PR'

$signalsVazio = Get-Signals @([PSCustomObject]@{ Body = 'nada de PR aqui' })
Assert (@($signalsVazio.PRs).Count -eq 0) 'Get-Signals: corpo sem link de PR retorna lista vazia'

# Get-LaunchUri
Assert ((Get-LaunchUri 'echo oi') -eq ('biblioteca-cmd:' + [Uri]::EscapeDataString('echo oi'))) 'Get-LaunchUri: esquema sem -AutoRun'
Assert ((Get-LaunchUri 'echo oi' -AutoRun) -eq ('biblioteca-cmd-run:' + [Uri]::EscapeDataString('echo oi'))) 'Get-LaunchUri: esquema com -AutoRun'

# Get-CardCommands - regressao do fix do apostrofo em Task/Repo (item #2
# da auditoria de 2026-08-24: sem escape, um apostrofo fechava a string
# PowerShell cedo e quebrava o comando gerado).
$cardComApostrofo = [PSCustomObject]@{ Active = $true; Task = "104691"; Repo = "o'brien-app" }
$cmds = Get-CardCommands $cardComApostrofo
$resumeCmd = ($cmds | Where-Object { $_.Label -eq 'Retomar task' }).Cmd
Assert ($resumeCmd -match "no repo o''brien-app") 'Get-CardCommands: apostrofo em Repo vem escapado (dobrado) no comando'
Assert ($resumeCmd -notmatch "no repo o'brien-app'`"") 'Get-CardCommands: apostrofo cru NAO aparece sem escape (nao fecha a string cedo)'

$cardSemAtivo = [PSCustomObject]@{ Active = $false; Task = '999'; Repo = 'repo-normal' }
$cmdsSemAtivo = Get-CardCommands $cardSemAtivo
Assert (@($cmdsSemAtivo | Where-Object { $_.Label -eq 'Retomar task' }).Count -eq 0) 'Get-CardCommands: card inativo nao gera "Retomar task"'
Assert (@($cmdsSemAtivo | Where-Object { $_.Label -eq 'Reabrir p/ QA' }).Count -eq 1) 'Get-CardCommands: "Reabrir p/ QA" sempre presente'

# Get-RepoSortKey
$backend = Get-RepoSortKey 'gbm-app-settings-backend'
$frontend = Get-RepoSortKey 'gbm-mfe-settings'
Assert ($backend.Bucket -eq 0 -and $frontend.Bucket -eq 0) 'Get-RepoSortKey: backend/mfe de dominio conhecido ficam no Bucket 0'
Assert ($backend.DomainRank -eq $frontend.DomainRank) 'Get-RepoSortKey: backend/mfe do mesmo dominio (settings) ficam com o mesmo DomainRank (adjacentes na ordenacao)'
Assert ($backend.SubOrder -lt $frontend.SubOrder) 'Get-RepoSortKey: backend vem antes do mfe dentro do mesmo dominio'

$pessoal = Get-RepoSortKey 'gbm-ai-skills'
Assert ($pessoal.Bucket -eq 2) 'Get-RepoSortKey: repo pessoal cai no Bucket 2 (sempre por ultimo)'

$desconhecido = Get-RepoSortKey 'algum-repo-sem-padrao'
Assert ($desconhecido.Bucket -eq 1) 'Get-RepoSortKey: repo sem padrao conhecido cai no fallback Bucket 1'

if ($failures.Count -gt 0) {
    Write-Host "test-dashboard-lib: $($failures.Count) falha(s):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host 'test-dashboard-lib: ok (18 casos).'
