# Lista tasks pendentes (status draft/in_progress), uma linha por task+repo
param([switch]$Numbered)

. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
$files = Get-DocumentFiles $root

$typeOrder = @{ 'task-code' = 0; 'task-planning' = 1; 'testes' = 2; 'handover-tecnico' = 3 }

$pending = @()
foreach ($f in $files) {
    $p = Parse-Frontmatter ([IO.File]::ReadAllText($f.FullName))
    if (-not $p -or -not $p.Meta['number']) { continue }
    $status = Clean-Field $(if ($p.Meta['status']) { $p.Meta['status'] } else { 'draft' })
    if ($status -notin @('draft', 'in_progress')) { continue }
    $task = Clean-Field $(if ($p.Meta['task']) { $p.Meta['task'] } else { 'general' })
    $pending += [PSCustomObject]@{
        Task = $task
        Repo = Clean-Field $p.Meta['repo']
        Function = Clean-Field $p.Meta['function']
        Type = Clean-Field $p.Meta['type']
        Path = $f.FullName
    }
}

if ($pending.Count -eq 0) {
    Write-Output 'Nenhuma task pendente.'
    exit 0
}

# task "general" nao tem id real - nao agrupa entre si, senao iniciativas
# distintas do mesmo repo se misturariam numa linha so
$groups = $pending | Group-Object { if ($_.Task -eq 'general') { $_.Path } else { "$($_.Task)|$($_.Repo)" } }

$i = 0
foreach ($g in ($groups | Sort-Object Name)) {
    $i++
    $rep = $g.Group | Sort-Object { if ($typeOrder.ContainsKey($_.Type)) { $typeOrder[$_.Type] } else { 99 } } | Select-Object -First 1
    $prefix = if ($Numbered) { "$i. " } else { '' }
    Write-Output "${prefix}agente trabalhando na task $($rep.Task) no repo $($rep.Repo) $script:EmDash $($rep.Function)"
}

if ($Numbered) {
    Write-Output ''
    Write-Output 'Digite o numero da task e Enter pra retomar o trabalho nela.'
}
