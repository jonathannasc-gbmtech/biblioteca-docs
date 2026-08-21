# Backfill de resumo/ a partir do historico de Pull Requests do usuario
# no GitHub - pra um usuario novo da Biblioteca (que ja resolveu tasks
# antes de existir a Biblioteca) comecar com um dashboard minimamente
# populado, sem precisar reescrever task-code/planning/testes de tudo.
#
# So' gera `resumo` (status/PR links) - e' o suficiente pro dashboard
# mostrar cards de verdade com pill de PR colorido. Sem dry-run (decisao
# do usuario): aplica direto, pula grupos (task+repo) que ja tem resumo.
# Sem ferramenta de limpeza pra entrada errada/duplicada ainda (fora de
# escopo, ver plano) - usuario esta ciente.
param(
    [string]$Org,
    [int]$Limit = 500
)

$libScript = Join-Path $PSScriptRoot 'lib-doc.ps1'
. $libScript

$root = Get-LibRoot
$config = Get-BibliotecaConfig

if (-not $Org) { $Org = $config.githubOrg }
if (-not $Org) {
    Write-Host "backfill-github-prs: nenhuma org informada. Passe -Org <nome> ou grave 'githubOrg' em biblioteca.config.json." -ForegroundColor Yellow
    exit 1
}

$ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if (-not $ghAvailable) {
    Write-Host "backfill-github-prs: 'gh' (GitHub CLI) nao encontrado no PATH." -ForegroundColor Yellow
    exit 1
}
$authCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "backfill-github-prs: 'gh' nao esta autenticado - rode 'gh auth login' primeiro." -ForegroundColor Yellow
    exit 1
}

Write-Host "backfill-github-prs: buscando PRs de @me em '$Org' (limite $Limit)..."
$fields = 'number,title,url,repository,closedAt'
$merged = @()
$open = @()
try {
    $merged = gh search prs --owner $Org --author '@me' --merged --json $fields --limit $Limit | ConvertFrom-Json
} catch { Write-Host "backfill-github-prs: erro buscando PRs mergeadas - $_" -ForegroundColor Yellow }
try {
    $open = gh search prs --owner $Org --author '@me' --state open --json $fields --limit $Limit | ConvertFrom-Json
} catch { Write-Host "backfill-github-prs: erro buscando PRs abertas - $_" -ForegroundColor Yellow }

$allPrs = @()
foreach ($pr in $merged) { $allPrs += [PSCustomObject]@{ Number = $pr.number; Title = $pr.title; Url = $pr.url; Repo = $pr.repository.name; State = 'merged' } }
foreach ($pr in $open) { $allPrs += [PSCustomObject]@{ Number = $pr.number; Title = $pr.title; Url = $pr.url; Repo = $pr.repository.name; State = 'open' } }

Write-Host "backfill-github-prs: $($allPrs.Count) PR(s) encontrada(s) no total (mergeadas + abertas)."

# So' PR com titulo no padrao "tipo(NNNNN): assunto" (ou "tipo(NNNNN-slug):
# assunto") - convencao de commitlint do GBM. Titulo fora do padrao e'
# ignorado, sem tentar adivinhar a task (ex.: PRs de migrations costumam
# ser "feat: seed ..." sem escopo nenhum - ficam de fora mesmo).
$titlePattern = '^\w+\((\d+)(?:-[\w-]+)?\):\s*(.+)$'
$groups = @{}
$ignored = 0
foreach ($pr in $allPrs) {
    if ($pr.Title -notmatch $titlePattern) { $ignored++; continue }
    $taskId = $Matches[1]
    $subject = $Matches[2].Trim()
    $key = "$taskId|$($pr.Repo)"
    if (-not $groups.ContainsKey($key)) {
        $groups[$key] = [PSCustomObject]@{ TaskId = $taskId; Repo = $pr.Repo; Prs = New-Object System.Collections.Generic.List[object] }
    }
    $groups[$key].Prs.Add([PSCustomObject]@{ Number = $pr.Number; Url = $pr.Url; State = $pr.State; Subject = $subject })
}
Write-Host "backfill-github-prs: $($groups.Count) grupo(s) task+repo com titulo reconhecido ($ignored PR(s) ignorada(s) - titulo fora do padrao tipo(NNNNN): assunto)."

# Mesma convencao de classificacao de repo usada em Get-PrKindInfo/
# Get-LayerStatusHtml (build-dashboard.ps1) - migrations/tooling cai em
# backend por padrao, mesmo lugar onde resumo de migration ja vive hoje.
function Get-RepoLayer([string]$repo) {
    if ($repo -match '-backend$') { return 'backend' }
    if ($repo -match '^(gbm-)?(mfe|mobile)-') { return 'frontend' }
    return 'backend'
}

function Get-Slug([string]$text) {
    $slug = $text.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if ($slug.Length -gt 50) { $slug = $slug.Substring(0, 50).Trim('-') }
    if (-not $slug) { $slug = 'tarefa' }
    return $slug
}

# Ja existe resumo pra essa task+repo? Mesmo grep documentado em
# controle-documentacao - nao sobrescreve resumo real nem backfill anterior.
function Test-ResumoExists([string]$taskId, [string]$repo) {
    $resumoDir = Join-Path $root 'resumo'
    if (-not (Test-Path $resumoDir)) { return $false }
    $files = Get-ChildItem -Path $resumoDir -Recurse -Filter '*.md' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $raw = [IO.File]::ReadAllText($f.FullName)
        $p = Parse-Frontmatter $raw
        if ($p -and (Clean-Field $p.Meta['task']) -eq $taskId -and (Clean-Field $p.Meta['repo']) -eq $repo) { return $true }
    }
    return $false
}

$allDocs = Get-DocumentFiles $root
$nextNumber = Get-NextNumber $allDocs
$created = 0
$skipped = 0
$today = Get-Date -Format 'yyyy-MM-dd'

foreach ($key in $groups.Keys) {
    $g = $groups[$key]
    if (Test-ResumoExists $g.TaskId $g.Repo) { $skipped++; continue }

    $layer = Get-RepoLayer $g.Repo
    $prsSorted = @($g.Prs | Sort-Object Number -Descending)
    $latestSubject = $prsSorted[0].Subject
    $slug = Get-Slug $latestSubject
    $allMerged = @($g.Prs | Where-Object { $_.State -ne 'merged' }).Count -eq 0
    $status = if ($allMerged) { 'completed' } else { 'in_progress' }

    $mergedUrls = @($g.Prs | Where-Object { $_.State -eq 'merged' } | ForEach-Object { $_.Url })
    $openUrls = @($g.Prs | Where-Object { $_.State -eq 'open' } | ForEach-Object { $_.Url })

    $prLines = ($prsSorted | ForEach-Object {
        $stateLabel = if ($_.State -eq 'merged') { 'mergeado' } else { 'aberto' }
        "- [$($g.Repo)#$($_.Number)]($($_.Url)) $($script:EmDash) $stateLabel $($script:EmDash) $($_.Subject)"
    }) -join "`n"

    $meta = [ordered]@{
        number   = "$nextNumber"
        type     = 'resumo'
        status   = $status
        repo     = $g.Repo
        task     = $g.TaskId
        function = $latestSubject
        stub     = [char]0x2014
    }
    if ($mergedUrls.Count -gt 0) { $meta['pr_merged'] = ($mergedUrls -join ' ') }
    if ($openUrls.Count -gt 0) { $meta['pr_pending'] = ($openUrls -join ' ') }
    $meta['updated'] = $today
    $meta['author'] = if ($config.author) { $config.author } else { [char]0x2014 }

    $body = @"
# Resumo $($script:EmDash) $latestSubject ($($g.TaskId))

## Status atual

Gerado automaticamente a partir do historico de Pull Requests no GitHub
(backfill inicial, sem task-code/planning detalhado) - $($g.Prs.Count) PR(s):

$prLines

## O que foi implementado

- Nao documentado - backfill automatico, sem acesso ao contexto da
  mudanca alem do titulo da PR. Complementar manualmente se for revisar
  essa task.

## REQs seguidas

- Nao rastreado (backfill automatico)

## O que falta

- Nada registrado - ver PR(s) acima pro diff real
"@

    $fileName = "$nextNumber-resumo-$($g.TaskId)-$slug.md"
    $destDir = Join-Path $root "resumo\$layer"
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $destPath = Join-Path $destDir $fileName

    [IO.File]::WriteAllText($destPath, (Serialize-Frontmatter $meta) + $body)
    Sync-DocumentFile $destPath | Out-Null

    Write-Host "  criado: resumo/$layer/$fileName (task $($g.TaskId), $($g.Repo), $status)"
    $nextNumber++
    $created++
}

Write-Host "backfill-github-prs: $created resumo(s) criado(s), $skipped pulado(s) (ja existia)."

if ($created -gt 0) {
    Write-Host "backfill-github-prs: rodando sync-all.ps1..."
    & (Join-Path $PSScriptRoot 'sync-all.ps1')
}
