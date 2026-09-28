# Sincroniza tabelas de todos os docs + regenera INDEX.md
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
Write-Host "sync-all: $root"
& (Join-Path $PSScriptRoot 'sync-header.ps1')
if ($LASTEXITCODE) {
    Write-Host 'sync-all: abortado - corrija os arquivos suspeitos acima antes de gerar o INDEX.' -ForegroundColor Red
    exit 1
}
# Parse compartilhado (ver Get-ParsedDocs em lib-doc.ps1) - calculado uma
# unica vez, DEPOIS do sync-header (que e' quem re-grava os arquivos), e
# passado pros 3 scripts abaixo. Antes cada um fazia sua propria varredura
# completa (4 parses da Biblioteca inteira por sync-all; agora 1).
$parsedDocs = Get-ParsedDocs $root
& (Join-Path $PSScriptRoot 'lint-clusters.ps1') -ParsedDocs $parsedDocs
if ($LASTEXITCODE) {
    Write-Host 'sync-all: abortado - corrija os clusters divergentes acima antes de gerar o INDEX.' -ForegroundColor Red
    exit 1
}
& (Join-Path $PSScriptRoot 'build-index.ps1') -ParsedDocs $parsedDocs
# Relativo a $PSScriptRoot, nao a $root - export publico e' flat (sem
# _ferramenta/), mesmo motivo do pre-commit-check.ps1.
$dashboardScript = Join-Path $PSScriptRoot '..\dashboard-visual\scripts\build-dashboard.ps1'
if (Test-Path $dashboardScript) { & $dashboardScript -ParsedDocs $parsedDocs }
Write-Host 'sync-all: concluido.'
