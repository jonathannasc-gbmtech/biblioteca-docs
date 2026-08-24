# Lint de consistencia do campo `cluster` (docs com task: general).
# (a) dois docs do mesmo grupo com `cluster` preenchido e diferente entre si
# (b) doc `task: general` novo sem `cluster` nenhum
# (c) mais de um `resumo` ativo (nao superseded/archived) no mesmo cluster+repo
#     - build-dashboard.ps1 so guarda 1 ResumoDoc por card (Select-Object -First 1),
#     entao um segundo resumo no mesmo grupo fica invisivel no dashboard sem aviso
#     nenhum (foi assim que 8 resumos sumiram silenciosamente, ver regularizacao
#     de 2026-08-14). Se precisar de mais de um resumo pro mesmo cluster+repo,
#     mesclar num so ou marcar os extras `status: superseded`/`archived`.
param([array]$ParsedDocs)
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
# -ParsedDocs vem de sync-all.ps1 (parse compartilhado, ver Get-ParsedDocs
# em lib-doc.ps1); sem ele (rodando este script solo), parseia por conta
# propria - mesmo resultado, so' sem o reaproveitamento entre scripts.
$parsedDocs = if ($ParsedDocs) { $ParsedDocs } else { Get-ParsedDocs $root }

$allDocs = @()
foreach ($d in $parsedDocs) {
    $f = $d.File
    $p = $d.Parsed
    if (-not $p -or -not $p.Meta['number']) { continue }
    $task = Clean-Field $(if ($p.Meta['task']) { $p.Meta['task'] } else { 'general' })
    $rel = $f.FullName.Substring($root.Length + 1) -replace '\\', '/'
    $allDocs += [PSCustomObject]@{
        Path    = $rel
        Task    = $task
        Cluster = Clean-Field $p.Meta['cluster']
        Related = @($p.Meta['related'] | Where-Object { $_ })
        Type    = Clean-Field $p.Meta['type']
        Repo    = Clean-Field $p.Meta['repo']
        Status  = Clean-Field $p.Meta['status']
    }
}
# Checks (a)/(b)/(c) abaixo sao especificas de task: general - checks (d)
# em diante usam $allDocs (todo doc, numerico ou general).
$docs = @($allDocs | Where-Object { $_.Task -eq 'general' })

$errors = @()
$warnings = @()

# (a) mesmo grupo, cluster diferente -- grupo = doc + tudo que ele referencia
# em `related`, e tudo que referencia ele de volta (mesma logica do dashboard)
$byPath = @{}
foreach ($d in $docs) { $byPath[$d.Path] = $d }
$visited = New-Object System.Collections.Generic.HashSet[string]
foreach ($d in $docs) {
    if ($visited.Contains($d.Path)) { continue }
    $groupPaths = New-Object System.Collections.Generic.HashSet[string]
    $queue = New-Object System.Collections.Generic.Queue[string]
    $queue.Enqueue($d.Path)
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        if (-not $groupPaths.Add($cur)) { continue }
        $curDoc = $byPath[$cur]
        if (-not $curDoc) { continue }
        foreach ($r in $curDoc.Related) { if ($byPath.ContainsKey($r)) { $queue.Enqueue($r) } }
        foreach ($other in $docs) {
            if (@($other.Related) -contains $cur) { $queue.Enqueue($other.Path) }
        }
    }
    foreach ($p in $groupPaths) { $visited.Add($p) | Out-Null }
    $clusters = @($groupPaths | ForEach-Object { $byPath[$_].Cluster } | Where-Object { $_ } | Select-Object -Unique)
    if ($clusters.Count -gt 1) {
        $errors += "cluster divergente no grupo [$($groupPaths -join ', ')]: $($clusters -join ' / ')"
    }
}

# (b) general sem cluster -- so aviso, nao bloqueia (doc novo cai em "Geral" ate alguem rotular)
foreach ($d in $docs) {
    if (-not $d.Cluster) { $warnings += "$($d.Path) - task: general sem ``cluster`` (card aparece so como 'Geral')" }
}

# (c) mais de um resumo ativo por cluster+repo -- ver comentario no topo do arquivo
$resumosAtivos = $docs | Where-Object { $_.Type -eq 'resumo' -and $_.Cluster -and $_.Status -notin @('superseded', 'archived') }
$porClusterRepo = $resumosAtivos | Group-Object { "$($_.Cluster)|$($_.Repo)" }
foreach ($g in $porClusterRepo) {
    if ($g.Count -gt 1) {
        $paths = ($g.Group | ForEach-Object { $_.Path }) -join ', '
        $errors += "mais de um resumo ativo no mesmo cluster+repo [$($g.Name)]: $paths -- mesclar num so ou marcar os extras status: superseded/archived"
    }
}

# (d) related: apontando pra arquivo que nao existe mais (renome/delete sem
# atualizar o link de volta - achado real: resumo/backend/907 e 914 ainda
# referenciavam o nome antigo do handover-tecnico depois da migracao
# pseudo_task). So aviso, nao bloqueia - referencia morta nao impede o build.
$allByPath = @{}
foreach ($d in $allDocs) { $allByPath[$d.Path] = $true }
foreach ($d in $allDocs) {
    foreach ($r in $d.Related) {
        if (-not $allByPath.ContainsKey($r)) {
            $warnings += "$($d.Path) - related quebrado, arquivo nao existe: $r"
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "lint-clusters: $($warnings.Count) aviso(s):" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "  $w" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host "lint-clusters: $($errors.Count) erro(s) - corrija antes de continuar:" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }
    exit 1
}
Write-Host 'lint-clusters: ok.'
