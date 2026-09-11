# Remove a subpasta frontend/backend dentro de cada tipo - `repo:` no
# frontmatter ja diferencia a camada em todo lugar que consome (ver
# Get-RepoLayer em build-dashboard.ps1, so' olha o nome do repo, nunca a
# pasta). Onde backend e frontend tinham o MESMO nome de arquivo (colisao
# real, confirmada em task-code/task-planning/testes/resumo antes de rodar
# isto), sufixa com -backend/-frontend pra nao perder nenhum dos dois.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot

$types = @('task-code', 'task-planning', 'testes', 'handover-tecnico', 'resumo')
$layers = @('frontend', 'backend')
$moves = @()

foreach ($type in $types) {
    $byName = @{}
    foreach ($layer in $layers) {
        $dir = Join-Path $root "$type\$layer"
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem $dir -Filter '*.md' | ForEach-Object {
            if (-not $byName.ContainsKey($_.Name)) { $byName[$_.Name] = @() }
            $byName[$_.Name] += $layer
        }
    }
    foreach ($layer in $layers) {
        $srcDir = Join-Path $root "$type\$layer"
        if (-not (Test-Path $srcDir)) { continue }
        Get-ChildItem $srcDir -Filter '*.md' | ForEach-Object {
            $name = $_.Name
            $collision = $byName[$name].Count -gt 1
            $destName = if ($collision) { $name -replace '\.md$', "-$layer.md" } else { $name }
            $destDir = Join-Path $root $type
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            $dest = Join-Path $destDir $destName
            $oldRel = "$type/$layer/$name" -replace '\\', '/'
            $newRel = "$type/$destName" -replace '\\', '/'
            Move-Item $_.FullName $dest -Force
            $moves += @{ Old = $oldRel; New = $newRel }
            Write-Host "MOVE $oldRel -> $newRel"
        }
        if ((Get-ChildItem $srcDir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
            Remove-Item $srcDir -Force -ErrorAction SilentlyContinue
        }
    }
}

# Reescreve related:/links relativos em todo .md com as novas paths.
Get-ChildItem $root -Recurse -Filter '*.md' | Where-Object {
    $_.FullName -notmatch '_templates' -and $_.Name -notin @('INDEX.md', 'README.md', 'CATALOGO.md')
} | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    $orig = $text
    foreach ($m in $moves) {
        $text = $text.Replace($m.Old, $m.New)
    }
    if ($text -ne $orig) {
        [IO.File]::WriteAllText($_.FullName, $text)
        Write-Host "LINK $($_.Name)"
    }
}

Write-Host "unify-type-folders: $($moves.Count) movimentacao(oes). Rode sync-all.ps1"
