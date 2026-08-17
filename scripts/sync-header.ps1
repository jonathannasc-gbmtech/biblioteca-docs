# Regenera tabela de metadados a partir do YAML (fonte unica de verdade)
param([string]$Path)

. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot

if ($Path) {
    $files = @(Get-Item (Resolve-Path $Path))
}
else {
    $files = Get-DocumentFiles $root
}

$changed = 0
foreach ($f in $files) {
    if (Sync-DocumentFile $f.FullName) {
        $changed++
        Write-Host "  $($f.FullName.Replace($root + '\', ''))"
    }
}
Write-Host "sync-header: $changed arquivo(s) atualizado(s)."

if ($script:GuardSkips.Count -gt 0) {
    Write-Host "sync-header: $($script:GuardSkips.Count) arquivo(s) IGNORADO(S) por suspeita de corrupcao:" -ForegroundColor Yellow
    foreach ($s in $script:GuardSkips) { Write-Host "  $s" -ForegroundColor Yellow }
    exit 1
}
