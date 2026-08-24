# Guard de pre-commit: bloqueia commit de .md corrompido (crescimento anormal de tamanho)
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot

$staged = git diff --cached --name-only --diff-filter=ACM
$failed = $false

# lib-doc.ps1 mudou nesta commit? Roda o self-check do Parse-Frontmatter
# antes de deixar passar - e' a funcao compartilhada que corrompeu 42 docs
# da ultima vez que quebrou sem teste nenhum (commit 9a4edaf).
# Match por SUFIXO do path, nunca path completo - o path do repo diverge
# entre a copia pessoal (_ferramenta/scripts/...) e o export publico
# biblioteca-docs (flat, scripts/...); comparar path inteiro deixava o
# check morto (nunca disparava) num dos dois lados. Mesma logica no
# caminho de invocacao abaixo: relativo a $PSScriptRoot, nao a $root, pra
# funcionar igual nas duas estruturas de pasta.
if ($staged | Where-Object { $_ -match 'scripts[\\/]lib-doc\.ps1$' }) {
    & (Join-Path $PSScriptRoot 'test-lib-doc.ps1')
    if ($LASTEXITCODE) { $failed = $true }
}

# dashboard-lib.ps1 mudou nesta commit? Roda o self-check das funcoes
# puras extraidas do build-dashboard.ps1 (Esc/Get-Signals/Get-LaunchUri/
# Get-CardCommands/Get-RepoSortKey) - inclui a regressao do fix de
# apostrofo em Task/Repo (auditoria 2026-08-24).
if ($staged | Where-Object { $_ -match 'dashboard-visual[\\/]scripts[\\/]dashboard-lib\.ps1$' }) {
    & (Join-Path $PSScriptRoot '..\dashboard-visual\scripts\test-dashboard-lib.ps1')
    if ($LASTEXITCODE) { $failed = $true }
}

$staged = $staged | Where-Object { $_ -match '\.md$' }

foreach ($f in $staged) {
    $full = Join-Path $root $f
    if (-not (Test-Path $full)) { continue }
    $bytes = (Get-Item $full).Length
    if ($bytes -gt 2MB) {
        Write-Host "pre-commit: $f tem $([math]::Round($bytes/1KB)) KB, acima do limite de 2048 KB." -ForegroundColor Red
        Write-Host "  Rode scripts/sync-all.ps1 e revise o arquivo antes de commitar." -ForegroundColor Red
        $failed = $true
    }
}

if ($failed) { exit 1 }
exit 0
