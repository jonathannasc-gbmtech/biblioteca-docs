# Guard de pre-commit: bloqueia commit de .md corrompido (crescimento anormal de tamanho)
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot

$staged = git diff --cached --name-only --diff-filter=ACM
$failed = $false

# lib-doc.ps1 mudou nesta commit? Roda o self-check do Parse-Frontmatter
# antes de deixar passar - e' a funcao compartilhada que corrompeu 42 docs
# da ultima vez que quebrou sem teste nenhum (commit 9a4edaf).
if ($staged -contains '_ferramenta/scripts/lib-doc.ps1') {
    & (Join-Path $PSScriptRoot 'test-lib-doc.ps1')
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
