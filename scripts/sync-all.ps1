# Sincroniza tabelas de todos os docs + regenera INDEX.md
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
Write-Host "sync-all: $root"
& (Join-Path $PSScriptRoot 'sync-header.ps1')
if ($LASTEXITCODE) {
    Write-Host 'sync-all: abortado - corrija os arquivos suspeitos acima antes de gerar o INDEX.' -ForegroundColor Red
    exit 1
}
& (Join-Path $PSScriptRoot 'lint-clusters.ps1')
if ($LASTEXITCODE) {
    Write-Host 'sync-all: abortado - corrija os clusters divergentes acima antes de gerar o INDEX.' -ForegroundColor Red
    exit 1
}
& (Join-Path $PSScriptRoot 'build-index.ps1')
$dashboardScript = Join-Path $root 'dashboard-visual\scripts\build-dashboard.ps1'
if (Test-Path $dashboardScript) { & $dashboardScript }
Write-Host 'sync-all: concluido.'
