# Gera dashboard-visual/dashboard.html a partir de TODOS os docs da
# Biblioteca (nao so pendentes) - secoes Ativas / Completas +
# comando copiavel de retomada/conclusao/QA por task. Reaproveita
# lib-doc.ps1, nao duplica parsing de frontmatter. Isso e' a camada visual
# da propria Biblioteca (nao um projeto separado) - mora em
# Biblioteca/dashboard-visual/.
#
# Favorito ("estrela") e puramente client-side (localStorage) - nao precisa
# de comando/skill, e' so uma preferencia de UI, sem logica de git.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hubRoot = Split-Path $PSScriptRoot -Parent
$libRoot = Split-Path $hubRoot -Parent
$libScript = Join-Path $libRoot 'scripts\lib-doc.ps1'
. $libScript

$root = Get-LibRoot
$files = Get-DocumentFiles $root
$typeOrder = @{ 'task-code' = 0; 'task-planning' = 1; 'testes' = 2; 'handover-tecnico' = 3 }
$activeStatuses = @('draft', 'in_progress')
$bibConfig = Get-BibliotecaConfig
$azureBase = $bibConfig.azureOrgUrl

function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

$githubIcon = '<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.02 1.93-.02 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>'
$linkIcon = '<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor"><path d="M4.72 3.5a2.25 2.25 0 000 4.5h1.5a.75.75 0 010 1.5h-1.5a3.75 3.75 0 010-7.5h1.5a.75.75 0 010 1.5h-1.5zm6.56 0h-1.5a.75.75 0 000 1.5h1.5a2.25 2.25 0 010 4.5h-1.5a.75.75 0 000 1.5h1.5a3.75 3.75 0 000-7.5zM5.5 8a.75.75 0 01.75-.75h3.5a.75.75 0 010 1.5h-3.5A.75.75 0 015.5 8z"/></svg>'
$starIcon = '<svg class="star-icon" viewBox="0 0 24 24" width="17" height="17"><path d="M12 2.5l2.9 6.26L22 9.77l-5 4.87L18.18 21.5 12 17.77 5.82 21.5 7 14.64l-5-4.87 7.1-1.01L12 2.5z"/></svg>'
$bookIcon = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z"/><path d="M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z"/></svg>'
$chevronIcon = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6l4 4 4-4"/></svg>'

# Favicon - livro verde vibrante, mesmo desenho do $bookIcon (silhueta) mas
# preenchido (stroke fino some em 16x16) - vai pra aba do navegador/favoritos.
$faviconSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path fill='%2322c55e' d='M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z'/><path fill='%2316a34a' d='M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z'/></svg>"
$faviconLink = "<link rel=`"icon`" type=`"image/svg+xml`" href=`"data:image/svg+xml,$faviconSvg`">"

# Marca do topo do dashboard - mesmo desenho/cores do favicon (preenchido, 2
# tons de verde), so' que sem URL-encoding - usado so' no header, nao troca o
# $bookIcon (contorno) usado em "Ver resumo"/paleta.
$brandIconGreen = '<svg viewBox="0 0 24 24"><path fill="#22c55e" d="M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z"/><path fill="#16a34a" d="M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z"/></svg>'
$paletteIcon = '<svg viewBox="0 0 16 16" width="12" height="12"><circle cx="8" cy="8" r="6" fill="currentColor"/></svg>'
$archiveIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2" y="6" width="12" height="8" rx="1"/><path d="M2 6l1-3h10l1 3"/></svg>'
$pendIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="6.3"/><path d="M5.5 8l1.8 1.8L10.8 6"/></svg>'
$searchIcon = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="7" cy="7" r="5"/><path d="M11 11l3.5 3.5"/></svg>'

function Get-Signals($docs) {
    $prLinks = New-Object System.Collections.Generic.List[string]
    $pend = New-Object System.Collections.Generic.List[string]
    foreach ($d in $docs) {
        foreach ($m in [regex]::Matches($d.Body, 'https?://github\.com/\S*?/pull/\d+')) {
            if (-not $prLinks.Contains($m.Value)) { $prLinks.Add($m.Value) }
        }
        foreach ($line in ($d.Body -split "`r?`n")) {
            $t = $line.Trim()
            if (-not $t -or $t -match '^#{1,6}\s') { continue }
            if ($t -match '(?i)aguardando|bloqueio|pendente|\[confirmar\]|\[bloqueio\]') {
                $clean = $t -replace '^[-*]\s*', ''
                if ($clean.Length -gt 160) { $clean = $clean.Substring(0, 160) + '...' }
                if (-not $pend.Contains($clean)) { $pend.Add($clean) }
            }
        }
    }
    return [PSCustomObject]@{
        PRs        = @($prLinks | Select-Object -First 5)
        Pendencies = @($pend | Select-Object -First 5)
    }
}

# Comandos copiaveis de um card - usado tanto pelos botoes inline do card
# quanto pela caixa de acoes da pagina de resumo, pra nao duplicar as
# strings de comando em dois lugares.
# Prefixo do protocolo customizado registrado por register-protocol.ps1 -
# um link biblioteca-cmd:<comando url-encoded> abre um cmd novo com o
# comando ja digitado (launch-command.vbs), sem apertar Enter. Some sem
# erro em navegador/maquina sem o protocolo registrado - so o clipboard
# (fallback de sempre) continua funcionando.
function Get-LaunchUri([string]$cmdText) {
    return 'biblioteca-cmd:' + [Uri]::EscapeDataString($cmdText)
}

function Get-CardCommands([PSCustomObject]$card) {
    # Envolvido em "powershell -NoProfile -Command" pra funcionar colado tanto
    # no cmd.exe (onde ; nao separa comandos, quebrava o cd) quanto no
    # PowerShell - independe do shell padrao do usuario.
    $base = "cd '$hubRoot'"
    $cmds = New-Object System.Collections.Generic.List[PSCustomObject]
    if ($card.Active) {
        $cmd = "powershell -NoProfile -Command `"$base; claude 'retomar task $($card.Task) no repo $($card.Repo)'`""
        $cmds.Add([PSCustomObject]@{ Label = 'Copiar comando'; Class = 'copy-btn'; Cmd = $cmd; Uri = Get-LaunchUri $cmd })
    }
    $qaCmd = "powershell -NoProfile -Command `"$base; claude 'ajustar qa task $($card.Task) no repo $($card.Repo)'`""
    $cmds.Add([PSCustomObject]@{ Label = 'Reabrir p/ QA'; Class = 'copy-btn qa-btn'; Cmd = $qaCmd; Uri = Get-LaunchUri $qaCmd })
    return $cmds
}

# Pills de links externos (Azure DevOps + PR do GitHub, com cor por estado
# real - aberto/mergeado/rejeitado). Compartilhada entre o card da grade e a
# pagina de resumo, pra nao duplicar a logica de cor em dois lugares.
function Get-ExtLinksHtml([PSCustomObject]$card) {
    $extLinks = New-Object System.Collections.Generic.List[string]
    if ($azureBase -and $card.Task -match '^\d+$') {
        $azureUrl = "$azureBase/$($card.Task)"
        $extLinks.Add("<a class=`"ext-link ext-azure`" href=`"$azureUrl`" target=`"_blank`" title=`"Abrir work item no Azure DevOps`">$linkIcon Azure</a>")
    }
    $cardDocsForState = @($card.Docs) + $card.ResumoDoc | Where-Object { $_ }
    foreach ($pr in $card.Signals.PRs) {
        $num = if ($pr -match '(\d+)$') { $Matches[1] } else { '' }
        # cor por estado real (igual GitHub: aberto=verde, mergeado=roxo,
        # fechado sem merge=vermelho) - olha o frontmatter dos docs do card,
        # cai pra neutro (cinza, comportamento antigo) se nenhum tiver o estado
        # desse link ainda (sweep/backfill em build-dashboard.ps1 preenche isso).
        # Contains, nao -eq: tasks tipo "migration espelho" (3 ambientes, 3 PRs)
        # guardam varias URLs no mesmo campo pr_merged/pr_pending/pr_rejected
        # (uma lista simples, sem virar YAML multi-linha) - -eq so bateria com
        # a primeira URL do campo.
        $stateClass = ''
        $stateTitle = 'Abrir PR no GitHub'
        if (@($cardDocsForState | Where-Object { $_.PrMerged -and $_.PrMerged.Contains($pr) }).Count -gt 0) {
            $stateClass = ' ext-github-merged'; $stateTitle = 'PR mergeado'
        } elseif (@($cardDocsForState | Where-Object { $_.PrRejected -and $_.PrRejected.Contains($pr) }).Count -gt 0) {
            $stateClass = ' ext-github-rejected'; $stateTitle = 'PR fechado sem merge'
        } elseif (@($cardDocsForState | Where-Object { $_.PrPending -and $_.PrPending.Contains($pr) }).Count -gt 0) {
            $stateClass = ' ext-github-open'; $stateTitle = 'PR aberto, aguardando merge'
        }
        $extLinks.Add("<a class=`"ext-link ext-github$stateClass`" href=`"$(Esc $pr)`" target=`"_blank`" title=`"$stateTitle`">$githubIcon PR #$num</a>")
    }
    if ($extLinks.Count -eq 0) { return '' }
    return "<div class=`"ext-links`">$($extLinks -join "`n")</div>"
}

# Pills de "outras tasks/repos do mesmo assunto" (task numerica igual ou
# cluster identico) - so' pra pagina de resumo (Build-SummaryHtml), por
# pedido explicito (nao entra no card da grade). Le $cardsByTask/
# $cardsByCluster (script scope, montados depois que $cards esta pronto).
function Get-RelatedTasksHtml([PSCustomObject]$card) {
    $siblings = if ($card.Task -match '^\d+$') {
        @($cardsByTask[$card.Task])
    } elseif ($card.Cluster) {
        @($cardsByCluster[$card.Cluster])
    } else {
        @()
    }
    $siblings = @($siblings | Where-Object { $_ -and $_.RepPath -ne $card.RepPath } | Sort-Object Repo)
    if ($siblings.Count -eq 0) { return '' }

    $items = $siblings | ForEach-Object {
        if ($_.ResumoDoc) {
            $href = [IO.Path]::GetFileNameWithoutExtension($_.ResumoDoc.Path) + '.html'
            $title = 'Ver resumo'
            $typeLabel = 'Resumo'
        } else {
            $href = 'file:///' + ($_.RepPath -replace '\\', '/')
            $title = 'Sem resumo ainda - abrir doc bruto'
            $docType = $_.Docs[0].Type
            $typeLabel = if ($script:TypeLabels.ContainsKey($docType)) { $script:TypeLabels[$docType] } else { $docType }
        }
        $taskTag = if ($_.Task -match '^\d+$') { "#$($_.Task) $([char]0xB7) " } else { '' }
        $label = "$taskTag$($_.Repo) $([char]0xB7) $typeLabel"
        "<a class=`"chip chip-task-code`" href=`"$(Esc $href)`" title=`"$(Esc $title)`">$(Esc $label)</a>"
    }
    return "<h3 class=`"related-title`">Tasks relacionadas</h3><div class=`"chips`">$($items -join "`n")</div>"
}

$all = @()
foreach ($f in $files) {
    $raw = [IO.File]::ReadAllText($f.FullName)
    $p = Parse-Frontmatter $raw
    if (-not $p -or -not $p.Meta['number']) { continue }
    $status = Clean-Field $(if ($p.Meta['status']) { $p.Meta['status'] } else { 'draft' })
    $task = Clean-Field $(if ($p.Meta['task']) { $p.Meta['task'] } else { 'general' })
    $all += [PSCustomObject]@{
        Task     = $task
        Repo     = Clean-Field $p.Meta['repo']
        Function = Clean-Field $p.Meta['function']
        Type     = Clean-Field $p.Meta['type']
        Status   = $status
        Updated  = Clean-Field $p.Meta['updated']
        Path     = $f.FullName
        Body     = $p.Body
        Related  = $p.Meta['related']
        Branch    = Clean-Field $p.Meta['branch']
        Cluster   = Clean-Field $p.Meta['cluster']
        PrPending  = Clean-Field $p.Meta['pr_pending']
        PrMerged   = Clean-Field $p.Meta['pr_merged']
        PrRejected = Clean-Field $p.Meta['pr_rejected']
    }
}

# Lista de repos conhecidos - repos ja com doc na Biblioteca + pastas reais em
# reposBasePath (repo novo que ainda nao tem task nenhuma). Usada nos
# datalists de nova-task.html e do seletor "Abrir Claude" do header do
# dashboard - montada 1x aqui pra nao duplicar a logica nos dois lugares.
$knownRepos = New-Object System.Collections.Generic.List[string]
foreach ($r in @($all | ForEach-Object { $_.Repo } | Where-Object { $_ })) {
    if (-not $knownRepos.Contains($r)) { $knownRepos.Add($r) }
}
if ($bibConfig.reposBasePath -and (Test-Path $bibConfig.reposBasePath)) {
    foreach ($dir in (Get-ChildItem -Path $bibConfig.reposBasePath -Directory -ErrorAction SilentlyContinue)) {
        if (-not $knownRepos.Contains($dir.Name)) { $knownRepos.Add($dir.Name) }
    }
}

# Ordenacao logica (nao alfabetica pura): backend + frontend/mfe/mobile do
# mesmo dominio ficam juntos (settings-backend do lado de mfe-settings),
# dominios sem par (migrations, geral) ficam depois dos pares, e repos de
# skills pessoais (nao-projeto) sempre por ultimo. Descarta entradas
# malformadas (valor com virgula/espaco vindo de frontmatter com 2 repos
# no mesmo campo por engano - nao e' pasta de verdade).
$domainAliases = @{ 'schedule' = 'scheduling' }
$domainRank = @{ 'backoffice' = 0; 'collector' = 1; 'railroad' = 2; 'road' = 3; 'scheduling' = 4; 'settings' = 5; 'stock' = 6 }
$personalRepos = @('gbm-ai-skills', 'jow-ai-skills', 'ponytail')

function Get-RepoSortKey([string]$repo) {
    if ($personalRepos -contains $repo.ToLowerInvariant()) {
        return [PSCustomObject]@{ Bucket = 2; DomainRank = 99; Domain = ''; SubOrder = 0; Name = $repo }
    }
    $domain = $null
    $subOrder = 3
    if ($repo -match '^gbm-app-(.+)-backend$') { $domain = $Matches[1]; $subOrder = 0 }
    elseif ($repo -match '^gbm-mfe-(.+)$') {
        $raw = $Matches[1]
        $domain = if ($domainAliases.ContainsKey($raw)) { $domainAliases[$raw] } else { $raw }
        $subOrder = 1
    } elseif ($repo -match '^gbm-mobile-(.+)$') { $domain = $Matches[1]; $subOrder = 2 }

    if ($domain) {
        $rank = if ($domainRank.ContainsKey($domain)) { $domainRank[$domain] } else { 50 }
        return [PSCustomObject]@{ Bucket = 0; DomainRank = $rank; Domain = $domain; SubOrder = $subOrder; Name = $repo }
    }
    return [PSCustomObject]@{ Bucket = 1; DomainRank = 0; Domain = ''; SubOrder = 0; Name = $repo }
}

$knownRepos = @($knownRepos | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' } |
    ForEach-Object { Get-RepoSortKey $_ } |
    Sort-Object Bucket, DomainRank, Domain, SubOrder, Name |
    ForEach-Object { $_.Name })
$knownReposOptionsHtml = ($knownRepos | ForEach-Object { "<option value=`"$(Esc $_)`">" }) -join "`n"

# Regex de link de PR no corpo - mesma usada pelo Get-Signals (linha ~38),
# reaproveitada aqui pro backfill de estado (cor do pill).
$prLinkPattern = 'https?://github\.com/\S*?/pull/\d+'

# Sweep de PR mergeado: guarda barata - so chama `gh` (rede) se existir pelo
# menos 1 doc com `pr_pending`. Maioria das rodadas custa zero. Doc mergeado
# flipa status:completed, some o pr_pending, e o proprio arquivo e' regravado
# via Sync-DocumentFile (lib-doc.ps1) pra badge/footer sairem corretos ja
# nesta mesma rodada, sem esperar o proximo sync-all.
$pending = @($all | Where-Object { $_.PrPending })
if ($pending.Count -gt 0) {
    $ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    if (-not $ghAvailable) {
        Write-Host "dashboard: 'gh' nao encontrado no PATH - pulando sweep de PR pendente ($($pending.Count) doc(s))." -ForegroundColor Yellow
    }
    foreach ($doc in $pending) {
        if (-not $ghAvailable) { continue }
        if ($doc.PrPending -notmatch 'github\.com/([^/]+)/([^/]+)/pull/(\d+)') {
            Write-Host "dashboard: pr_pending com formato inesperado em $($doc.Path): $($doc.PrPending)" -ForegroundColor Yellow
            continue
        }
        $ghRepo = "$($Matches[1])/$($Matches[2])"
        $prNumber = $Matches[3]
        try {
            $json = gh pr view $prNumber --repo $ghRepo --json state 2>$null | ConvertFrom-Json
        } catch { $json = $null }
        if (-not $json -or $json.state -eq 'OPEN') { continue }

        $raw = [IO.File]::ReadAllText($doc.Path)
        $parsed = Parse-Frontmatter $raw
        if (-not $parsed) { continue }
        $meta = $parsed.Meta
        $meta.Remove('pr_pending')
        $body = Get-ContentBody $parsed.Body

        if ($json.state -eq 'MERGED') {
            $meta['status'] = 'completed'
            $meta['pr_merged'] = $doc.PrPending
            $note = 'Mergeado em `develop`/`production` (deteccao automatica) - sem pendencia de codigo, so ajustes se vier retorno de QA.'
            $doc.Status = 'completed'
            $doc.PrMerged = $doc.PrPending
            $verb = 'mergeado'
        } else {
            # CLOSED sem merge = rejeitado. Nao flipa status (fechado != task resolvida
            # nem abandonada, so' quem decide isso e' o usuario) - so' marca pra cor.
            $meta['pr_rejected'] = $doc.PrPending
            $note = 'PR fechado sem merge (deteccao automatica) - revisar o que fazer com a task.'
            $doc.PrRejected = $doc.PrPending
            $verb = 'fechado sem merge'
        }
        if ($body -notmatch '(?:Mergeado em|PR fechado sem merge)') {
            if ($body -match '(?m)^# .*$') {
                $m = [regex]::Match($body, '(?m)^# .*$')
                $insertAt = $m.Index + $m.Length
                $body = $body.Substring(0, $insertAt) + "`n`n**Status:** $note" + $body.Substring($insertAt)
            }
        }

        [IO.File]::WriteAllText($doc.Path, (Serialize-Frontmatter $meta) + $body)
        Sync-DocumentFile $doc.Path | Out-Null

        $doc.PrPending = ''
        Write-Host "dashboard: PR #$prNumber ($ghRepo) $verb - $($doc.Path.Substring($root.Length + 1)) atualizado automaticamente."
    }
}

# Backfill (1x por doc): link de PR encontrado no corpo (jeito antigo, so' texto
# solto, sem pr_pending/pr_merged/pr_rejected) tem estado desconhecido pro pill
# colorido. Confere 1 vez via `gh` e grava o resultado no frontmatter - depois
# disso nunca mais custa rede pra esse doc (mesma guarda barata do sweep acima).
$unknown = @($all | Where-Object { -not $_.PrPending -and -not $_.PrMerged -and -not $_.PrRejected -and $_.Body -match $prLinkPattern })
if ($unknown.Count -gt 0) {
    $ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    foreach ($doc in $unknown) {
        if (-not $ghAvailable) { break }
        $link = [regex]::Match($doc.Body, $prLinkPattern).Value
        if ($link -notmatch 'github\.com/([^/]+)/([^/]+)/pull/(\d+)') { continue }
        $ghRepo = "$($Matches[1])/$($Matches[2])"
        $prNumber = $Matches[3]
        try {
            $json = gh pr view $prNumber --repo $ghRepo --json state 2>$null | ConvertFrom-Json
        } catch { $json = $null }
        if (-not $json) { continue }

        $raw = [IO.File]::ReadAllText($doc.Path)
        $parsed = Parse-Frontmatter $raw
        if (-not $parsed) { continue }
        $meta = $parsed.Meta
        if ($json.state -eq 'MERGED') { $meta['pr_merged'] = $link; $doc.PrMerged = $link }
        elseif ($json.state -eq 'CLOSED') { $meta['pr_rejected'] = $link; $doc.PrRejected = $link }
        else { $meta['pr_pending'] = $link; $doc.PrPending = $link }
        [IO.File]::WriteAllText($doc.Path, (Serialize-Frontmatter $meta) + (Get-ContentBody $parsed.Body))
        Sync-DocumentFile $doc.Path | Out-Null
    }
    if ($ghAvailable) {
        Write-Host "dashboard: backfill de estado de PR - $($unknown.Count) doc(s) verificado(s) 1a vez."
    }
}

# task "general" nao tem id real - agrupa por `cluster` quando presente (mesmo
# texto em todo doc do assunto = mesmo grupo, independente de repo/related).
# Sem cluster, cai no fallback antigo: doc `resumo` agrupa pelo 1o doc em
# `related:` (o doc-fonte), senao vira card solto (mesma regra do status.ps1).
$groups = $all | Group-Object {
    if ($_.Task -eq 'general') {
        if ($_.Cluster) {
            # cluster+repo, nao so cluster: mesmo assunto em repos diferentes
            # (ex.: CRUD frontend vs backend) continua card separado por repo,
            # igual toda task numerica ja funciona hoje ("$Task|$Repo").
            "cluster|$($_.Cluster)|$($_.Repo)"
        } elseif ($_.Type -eq 'resumo' -and @($_.Related | Where-Object { $_ }).Count -gt 0) {
            $rel = ([string]@($_.Related | Where-Object { $_ })[0]).Trim() -replace '/', '\'
            Join-Path $root $rel
        } else {
            $_.Path
        }
    } else {
        "$($_.Task)|$($_.Repo)"
    }
}

$cards = @()
foreach ($g in $groups) {
    $docs = $g.Group | Sort-Object { if ($typeOrder.ContainsKey($_.Type)) { $typeOrder[$_.Type] } else { 99 } }
    # resumo e' dado pro dashboard consumir, nao entra nos chips nem pode
    # ser o doc "representante" (task-code tem prioridade pra isso). Ignora
    # superseded/archived na escolha - defensivo contra a colisao de
    # 2026-08-14 (resumo substituido esquecido na pasta normal em vez de
    # fisicamente movido pra _archive/ ainda nao devia "vencer" a escolha).
    $resumoDoc = $docs | Where-Object { $_.Type -eq 'resumo' -and $_.Status -notin @('superseded', 'archived') } | Select-Object -First 1
    $docs = @($docs | Where-Object { $_.Type -ne 'resumo' })
    if ($docs.Count -eq 0 -and $resumoDoc) { $docs = @($resumoDoc) }
    $rep = $docs | Select-Object -First 1
    $isActive = @($docs | Where-Object { $_.Status -in $activeStatuses }).Count -gt 0
    $latest = ($docs | Where-Object { $_.Updated } | Sort-Object Updated -Descending | Select-Object -First 1).Updated
    # PR e Azure precisam aparecer em Ativas E Completas - so as pendencias
    # (texto de "aguardando/bloqueio") ficam restritas a tasks ativas na hora de exibir.
    $signals = Get-Signals $docs
    # cluster opcional (so faz diferenca pra task "general" - o card mostra
    # "Geral" por padrao, sem jeito de distinguir varios de cor no dashboard;
    # qualquer doc do grupo com `cluster:` no frontmatter vira o titulo do card
    # - e agora tambem a propria chave de agrupamento, ver Group-Object acima)
    $cardCluster = ($docs + $resumoDoc | Where-Object { $_ -and $_.Cluster } | Select-Object -First 1).Cluster
    $cards += [PSCustomObject]@{
        Task      = $rep.Task
        Repo      = $rep.Repo
        Function  = $rep.Function
        Cluster   = $cardCluster
        Active    = $isActive
        Updated   = $latest
        Docs      = $docs
        Signals   = $signals
        RepPath   = $rep.Path
        ResumoDoc = $resumoDoc
        Branch    = if ($resumoDoc) { $resumoDoc.Branch } else { '' }
    }
}

# Conversor leve pro corpo das secoes do resumo - nao e' um motor de
# markdown generico, so o suficiente pro que um agente escreve ali:
# paragrafos, bullets, **bold**, [texto](url http/https).
function Convert-SectionHtml([string]$text) {
    $text = if ($text) { $text.Trim() } else { '' }
    # tira comentarios HTML (ex: dica de preenchimento deixada no template)
    # antes de qualquer coisa - senao vazam como texto escapado na pagina
    $text = [regex]::Replace($text, '(?s)<!--.*?-->', '').Trim()
    if (-not $text) { return '<p class="empty">(vazio)</p>' }
    $lines = $text -split "`r?`n"
    $htmlLines = New-Object System.Collections.Generic.List[string]
    $inList = $false
    foreach ($line in $lines) {
        $t = $line.Trim()
        if (-not $t) { continue }
        $isBullet = $t -match '^[-*]\s+(.*)'
        $content = if ($isBullet) { $Matches[1] } else { $t }
        $content = Esc $content
        $content = $content -replace '\[([^\]]+)\]\((https?://[^)]+)\)', '<a href="$2" target="_blank">$1</a>'
        $content = $content -replace '\*\*([^*]+)\*\*', '<strong>$1</strong>'
        $content = $content -replace '`([^`]+)`', '<code>$1</code>'
        if ($isBullet) {
            if (-not $inList) { $htmlLines.Add('<ul>'); $inList = $true }
            $htmlLines.Add("<li>$content</li>")
        } else {
            if ($inList) { $htmlLines.Add('</ul>'); $inList = $false }
            $htmlLines.Add("<p>$content</p>")
        }
    }
    if ($inList) { $htmlLines.Add('</ul>') }
    return ($htmlLines -join "`n")
}

$resumoSectionOrder = @('Status atual', 'O que foi implementado', 'REQs seguidas', 'O que falta')

function Get-ResumoSections([string]$body) {
    $clean = Strip-GeneratedParts $body
    $sections = @{}
    foreach ($n in $resumoSectionOrder) { $sections[$n] = '' }
    $sectionMatches = [regex]::Matches($clean, '(?m)^##\s+(.+?)\s*$')
    for ($i = 0; $i -lt $sectionMatches.Count; $i++) {
        $title = $sectionMatches[$i].Groups[1].Value.Trim()
        $start = $sectionMatches[$i].Index + $sectionMatches[$i].Length
        $end = if ($i + 1 -lt $sectionMatches.Count) { $sectionMatches[$i + 1].Index } else { $clean.Length }
        $content = $clean.Substring($start, $end - $start)
        if ($sections.ContainsKey($title)) { $sections[$title] = $content }
    }
    return $sections
}

function Build-SummaryHtml([PSCustomObject]$card) {
    $resumoDoc = $card.ResumoDoc
    $sections = Get-ResumoSections $resumoDoc.Body
    $mainSections = @('Status atual', 'O que foi implementado')
    $sideSections = @('REQs seguidas')
    $mainHtml = ($mainSections | ForEach-Object {
        $name = $_
        $contentHtml = Convert-SectionHtml $sections[$name]
        "<section class=`"resumo-section`"><h2>$(Esc $name)</h2>$contentHtml</section>"
    }) -join "`n"
    $sideHtml = ($sideSections | ForEach-Object {
        $name = $_
        $contentHtml = Convert-SectionHtml $sections[$name]
        "<section class=`"resumo-section`"><h2>$(Esc $name)</h2>$contentHtml</section>"
    }) -join "`n"

    $taskLabel = if ($card.Cluster) { $card.Cluster } elseif ($card.Task -eq 'general') { 'Geral' } else { "Task $($card.Task)" }
    $extLinksHtml = Get-ExtLinksHtml $card

    # Testes - so os CONCLUIDOS, so o link (sem detalhe de resultado aqui,
    # o doc de testes em si ja tem isso - aqui e' so "foi feito, olha o link")
    $testesItems = @($card.Docs) | Where-Object { $_.Type -eq 'testes' -and $_.Status -eq 'completed' } | ForEach-Object {
        $fileUri = 'file:///' + ($_.Path -replace '\\', '/')
        $label = if ($_.Function) { $_.Function } else { Split-Path $_.Path -Leaf }
        "<li>&#9989; <a href=`"$fileUri`" target=`"_blank`">$(Esc $label)</a></li>"
    }
    $testesHtml = if (@($testesItems).Count -gt 0) {
        "<section class=`"resumo-section`"><h2>Testes</h2><ul class=`"testes-list`">$($testesItems -join "`n")</ul></section>"
    } else { '' }

    $relatedItems = @($resumoDoc.Related) | Where-Object { $_ } | ForEach-Object {
        $relPath = $_.Trim()
        $fileUri = 'file:///' + (($root.TrimEnd('/', '\') + '/' + $relPath) -replace '\\', '/')
        $label = Split-Path $relPath -Leaf
        "<a class=`"chip chip-task-code`" href=`"$fileUri`" target=`"_blank`">$(Esc $label)</a>"
    }
    $relatedHtml = if (@($relatedItems).Count -gt 0) {
        "<h3 class=`"related-title`">Documentos relacionados</h3><div class=`"chips`">$($relatedItems -join "`n")</div>"
    } else { '' }

    $relatedTasksHtml = Get-RelatedTasksHtml $card
    $sideHtml = "$sideHtml`n$testesHtml`n$relatedTasksHtml`n$relatedHtml"

    $actionsHtml = (Get-CardCommands $card | ForEach-Object { "<a class=`"$($_.Class)`" href=`"$(Esc $_.Uri)`" data-cmd=`"$(Esc $_.Cmd)`">$(Esc $_.Label)</a>" }) -join "`n"

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Resumo - $(Esc $taskLabel)</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
    --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
    --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
  }
  * { box-sizing: border-box; }
  *:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
  body {
    background: var(--bg); color: var(--text); max-width: 1080px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0; padding: 16px 24px 40px;
  }
  .topbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; }
  .back:hover { color: var(--gold-bright); }
  .head-row { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; margin-bottom: 12px; }
  h1 { font-size: 1.25rem; margin: 0; color: #fff; }
  .repo { font-family: ui-monospace, "SF Mono", monospace; color: var(--gold-bright); font-size: 0.85rem; }
  .branch { font-family: ui-monospace, "SF Mono", monospace; color: var(--text-dim); font-size: 0.8rem; }
  .branch::before { content: "\1F500  "; }
  .ext-link {
    display: inline-flex; align-items: center; gap: 6px; font-size: 0.78rem; font-weight: 500;
    padding: 4px 10px; border-radius: 999px; text-decoration: none;
    background: #2c3038; border: 1px solid #454a54; color: var(--gold-bright);
  }
  .ext-link:hover { background: #363b45; color: #fff; }
  .ext-azure { background: #1f2a33; color: #7fa8c2; border-color: #3d5566; }
  .ext-github { border-color: #4d5560; }
  .ext-github-open { background: #242e1f; color: #a3b886; border-color: #4a5c3d; }
  .ext-github-merged { background: #281f33; color: #a996c4; border-color: #4f3d5c; }
  .ext-github-rejected { background: #33221f; color: #c98a7a; border-color: #5c3d34; }
  .actions-box { display: flex; flex-wrap: wrap; gap: 8px; }
  .copy-btn {
    background: var(--gold-bg); color: var(--text); border: 1px solid var(--gold-border); border-radius: 6px;
    padding: 6px 10px; font-size: 0.78rem; cursor: pointer; text-align: left;
    display: inline-block; text-decoration: none;
  }
  .copy-btn:hover { filter: brightness(1.2); }
  .qa-btn { border-color: #6b3f34; }
  .summary-grid { display: grid; grid-template-columns: 1.4fr 1fr; gap: 12px; align-items: start; }
  @media (max-width: 720px) { .summary-grid { grid-template-columns: 1fr; } }
  .resumo-section {
    background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 10px;
    padding: 10px 14px; margin-bottom: 8px;
  }
  .resumo-section h2 {
    font-size: 0.76rem; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--gold-bright); margin: 0 0 6px;
  }
  .resumo-section p { margin: 3px 0; font-size: 0.87rem; line-height: 1.42; color: #c2c4c9; }
  .resumo-section ul { margin: 3px 0; padding-left: 18px; }
  .resumo-section li { font-size: 0.87rem; line-height: 1.42; color: #c2c4c9; }
  .resumo-section strong { color: #fff; }
  .resumo-section code {
    font-family: ui-monospace, "SF Mono", monospace; font-size: 0.85em;
    background: #1a1c1f; border: 1px solid #34373c; border-radius: 4px; padding: 1px 5px;
    color: var(--gold-bright);
  }
  .resumo-section .empty { color: var(--text-faint); font-style: italic; }
  .testes-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 5px; }
  .testes-list li { font-size: 0.87rem; color: #c2c4c9; }
  .testes-list a { color: var(--gold-bright); }
  .testes-list a:hover { color: #fff; }
  .related-title {
    font-size: 0.76rem; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--text-faint); margin: 8px 0 6px;
  }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip {
    font-size: 0.72rem; padding: 3px 9px; border-radius: 999px; text-decoration: none;
    border: 1px solid var(--gold-border); background: #332a12; color: var(--gold-bright);
  }
  .chip:hover { filter: brightness(1.2); }
</style>
</head>
<body>
<div class="topbar">
  <a class="back" href="../dashboard.html">&larr; Voltar ao dashboard</a>
</div>
<div class="head-row">
  <h1>Resumo $($script:EmDash) $(Esc $taskLabel)</h1>
  <span class="repo">$(Esc $card.Repo)</span>
  $(if ($card.Branch) { "<span class=`"branch`">$(Esc $card.Branch)</span>" } else { '' })
</div>
<div class="resumo-section actions-box">$extLinksHtml$actionsHtml</div>
<div class="summary-grid">
  <div class="col-main">$mainHtml</div>
  <div class="col-side">$sideHtml</div>
</div>
<script>
document.querySelectorAll('.copy-btn[data-cmd]').forEach(function (btn) {
  btn.addEventListener('click', function () {
    var text = btn.getAttribute('data-cmd');
    function fallback() {
      var ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).catch(fallback);
    } else {
      fallback();
    }
    var original = btn.textContent;
    btn.textContent = 'Copiado!';
    setTimeout(function () { btn.textContent = original; }, 1500);
  });
});
</script>
</body>
</html>
"@
}

function Build-Card([PSCustomObject]$card) {
    $chipsHtml = ($card.Docs | ForEach-Object {
        $typeLabel = if ($script:TypeLabels.ContainsKey($_.Type)) { $script:TypeLabels[$_.Type] } else { $_.Type }
        $statusLabel = if ($script:StatusLabels.ContainsKey($_.Status)) { $script:StatusLabels[$_.Status] } else { $_.Status }
        $emoji = if ($script:StatusEmoji.ContainsKey($_.Status)) { $script:StatusEmoji[$_.Status] } else { '' }
        $fileUri = 'file:///' + ($_.Path -replace '\\', '/')
        $chipClass = "chip chip-$($_.Type)"
        "<a class=`"$chipClass`" href=`"$fileUri`" target=`"_blank`" title=`"$(Esc $statusLabel)`">$(Esc $typeLabel) $emoji</a>"
    }) -join "`n"

    $updatedHtml = if ($card.Updated) { "<span class=`"updated`">Atualizado $(Esc $card.Updated)</span>" } else { '' }

    $posHtml = ''
    if ($card.Active -and @($card.Signals.Pendencies).Count -gt 0) {
        $pendItems = ($card.Signals.Pendencies | ForEach-Object { "<li>$(Esc $_)</li>" }) -join "`n"
        $posHtml = "<div class=`"position`"><div class=`"sig-group`"><span class=`"sig-label`">Pendencias</span><ul class=`"sig-list`">$pendItems</ul></div></div>"
    }

    # Links externos (Azure DevOps + PR do GitHub) - aparecem em Ativas E
    # Completas, sempre visiveis mesmo com o card fechado - e' o dado mais
    # importante de bater o olho.
    $extLinksHtml = Get-ExtLinksHtml $card

    $starHtml = if ($card.Active) { "<button class=`"star-btn`" title=`"Marcar como favorita`" aria-label=`"Marcar como favorita`" aria-pressed=`"false`">$starIcon</button>" } else { '' }

    $resumoBtnHtml = ''
    if ($card.ResumoDoc) {
        $summaryFile = [IO.Path]::GetFileNameWithoutExtension($card.ResumoDoc.Path) + '.html'
        $resumoBtnHtml = "<a class=`"icon-btn resumo-btn`" href=`"summaries/$summaryFile`" title=`"Ver resumo`" aria-label=`"Ver resumo`">$bookIcon</a>"
    }

    $btns = (Get-CardCommands $card | ForEach-Object { "<a class=`"$($_.Class)`" href=`"$(Esc $_.Uri)`" data-cmd=`"$(Esc $_.Cmd)`">$(Esc $_.Label)</a>" }) -join ''
    $btnsHtml = "<div class=`"btns`">$btns</div>"

    $taskLabel = if ($card.Cluster) { $card.Cluster } elseif ($card.Task -eq 'general') { 'Geral' } else { "Task $($card.Task)" }
    $searchBlob = Esc(("$taskLabel $($card.Repo) $($card.Function)").ToLowerInvariant())
    $repoLower = Esc(($card.Repo).ToLowerInvariant())
    $cardId = Esc($card.RepPath)

    return @"
<div class="card" data-search="$searchBlob" data-repo="$repoLower" data-id="$cardId">
  <div class="card-head">
    <div class="card-head-left">
      <span class="task-id" title="$(Esc $taskLabel)">$(Esc $taskLabel)</span>
    </div>
    <div class="card-head-right">
      <span class="repo" title="$(Esc $card.Repo)">$(Esc $card.Repo)</span>
      $resumoBtnHtml
      $starHtml
    </div>
  </div>
  $extLinksHtml
  <p class="func">$(Esc $card.Function)</p>
  <div class="chips">
$chipsHtml
  </div>
  $posHtml
  <div class="card-foot">
    $updatedHtml
    $btnsHtml
  </div>
  <button class="expand-btn" type="button" title="Expandir" aria-label="Expandir">$chevronIcon</button>
</div>
"@
}

# Pagina de referencia rapida da paleta - so pra ver as cores/icones sem
# precisar procurar um card real que use cada um. Gerada junto com o
# dashboard, nao faz parte da navegacao de tasks.
function Build-PaletteHtml() {
    $chipTypes = @('task-code', 'task-planning', 'testes', 'handover-tecnico', 'rules')
    $chipRows = ($chipTypes | ForEach-Object {
        $type = $_
        $label = $script:TypeLabels[$type]
        $emoji = $script:StatusEmoji['in_progress']
        "<div class=`"swatch-row`"><a class=`"chip chip-$type`">$(Esc $label) $emoji</a><code>.chip-$type</code></div>"
    }) -join "`n"

    $statusRows = (@('draft', 'in_progress', 'completed') | ForEach-Object {
        $status = $_
        "<div class=`"swatch-row`"><span>$($script:StatusEmoji[$status]) $(Esc $script:StatusLabels[$status])</span><code>StatusEmoji.$status</code></div>"
    }) -join "`n"

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Paleta de cores</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
    --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
    --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
    --current: #d97b3f; --current-glow: rgba(217, 123, 63, 0.28);
  }
  * { box-sizing: border-box; }
  *:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
  body {
    background: var(--bg); color: var(--text); max-width: 720px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0; padding: 24px 32px 64px;
  }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; }
  .back:hover { color: var(--gold-bright); }
  h1 { font-size: 1.3rem; margin: 14px 0 4px; color: #fff; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 0 0 24px; }
  section { margin-bottom: 28px; }
  h2 {
    font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--gold-bright); border-bottom: 1px solid var(--card-border); padding-bottom: 6px; margin: 0 0 12px;
  }
  .swatch-row {
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
    padding: 8px 0; border-bottom: 1px solid #2a2c30;
  }
  .swatch-row code { font-size: 0.76rem; color: var(--text-faint); }
  .chip {
    font-size: 0.72rem; padding: 3px 9px; border-radius: 999px; text-decoration: none;
    border: 1px solid transparent; white-space: nowrap;
  }
  .chip-task-code { background: #332a12; color: #d9b568; border-color: #6b5628; }
  .chip-task-planning { background: #1a2e30; color: #7cbfc4; border-color: #355a5e; }
  .chip-testes { background: #1f2e22; color: #86b894; border-color: #3d5c44; }
  .chip-handover-tecnico { background: #2e1f28; color: #c184a0; border-color: #5c3a4f; }
  .chip-rules { background: #292420; color: #a89484; border-color: #4d413a; }
  .ext-link {
    display: inline-flex; align-items: center; gap: 6px; font-size: 0.78rem; font-weight: 500;
    padding: 4px 10px; border-radius: 999px; text-decoration: none;
    background: #2c3038; border: 1px solid #454a54; color: var(--gold-bright);
  }
  .ext-azure { background: #1f2a33; color: #7fa8c2; border-color: #3d5566; }
  .ext-github { border-color: #4d5560; }
  .ext-github-open { background: #242e1f; color: #a3b886; border-color: #4a5c3d; }
  .ext-github-merged { background: #281f33; color: #a996c4; border-color: #4f3d5c; }
  .ext-github-rejected { background: #33221f; color: #c98a7a; border-color: #5c3d34; }
  .chip-pend-draft { background: #2a2c30; color: #b0b4bc; border-color: #4a4e58; }
  .chip-pend-progress { background: #1f2733; color: #86a3d9; border-color: #3d4f6b; }
  .copy-btn {
    background: var(--gold-bg); color: var(--text); border: 1px solid var(--gold-border); border-radius: 6px;
    padding: 5px 10px; font-size: 0.76rem; cursor: pointer;
  }
  .qa-btn { border-color: #6b3f34; }
  .icon-sample { display: flex; align-items: center; gap: 10px; color: var(--text-dim); }
  .icon-sample.current { color: var(--current); }
  .icon-sample svg { width: 20px; height: 20px; }
  .badge-current {
    background: var(--current); color: #2b1d0a; font-weight: 700;
    font-size: 0.66rem; letter-spacing: 0.06em; text-transform: uppercase;
    padding: 3px 8px; border-radius: 999px;
  }
  .mini-card {
    background: var(--card-bg); border: 1px solid var(--current); border-radius: 10px;
    padding: 10px 14px; box-shadow: 0 0 0 1px var(--current), 0 0 16px -2px var(--current-glow);
    font-size: 0.8rem; color: var(--text-dim); width: fit-content;
  }
</style>
</head>
<body>
<a class="back" href="dashboard.html">&larr; Voltar ao dashboard</a>
<h1>Paleta de cores $($script:EmDash) Biblioteca</h1>
<p class="sub">Referencia rapida de todo icone/cor usado no dashboard e no resumo - so pra revisar sem precisar procurar um card real.</p>

<section>
  <h2>Chips por tipo de documento</h2>
  $chipRows
</section>

<section>
  <h2>Emoji de status (usado dentro dos chips)</h2>
  $statusRows
</section>

<section>
  <h2>Links externos</h2>
  <div class="swatch-row"><a class="ext-link ext-azure">$linkIcon Azure</a><code>.ext-link.ext-azure</code></div>
  <div class="swatch-row"><a class="ext-link ext-github">$githubIcon PR #000</a><code>.ext-link.ext-github</code></div>
  <div class="swatch-row"><a class="ext-link ext-github-open">$githubIcon PR #000</a><code>.ext-github-open (aberto)</code></div>
  <div class="swatch-row"><a class="ext-link ext-github-merged">$githubIcon PR #000</a><code>.ext-github-merged</code></div>
  <div class="swatch-row"><a class="ext-link ext-github-rejected">$githubIcon PR #000</a><code>.ext-github-rejected</code></div>
</section>

<section>
  <h2>Chips de status (pagina Pendencias)</h2>
  <div class="swatch-row"><span class="chip chip-pend-draft">Rascunho</span><code>.chip-pend-draft</code></div>
  <div class="swatch-row"><span class="chip chip-pend-progress">Em andamento</span><code>.chip-pend-progress</code></div>
</section>

<section>
  <h2>Botoes de acao</h2>
  <div class="swatch-row"><button class="copy-btn">Copiar comando</button><code>.copy-btn</code></div>
  <div class="swatch-row"><button class="copy-btn qa-btn">Reabrir p/ QA</button><code>.copy-btn.qa-btn</code></div>
</section>

<section>
  <h2>Icones</h2>
  <div class="swatch-row"><span class="icon-sample">$starIcon Estrela (normal)</span><code>.star-icon</code></div>
  <div class="swatch-row"><span class="icon-sample current">$starIcon Estrela (favorita/atual)</span><code>.card-current .star-icon</code></div>
  <div class="swatch-row"><span class="icon-sample">$bookIcon Ver resumo</span><code>.resumo-btn</code></div>
  <div class="swatch-row"><span class="icon-sample">$chevronIcon Expandir/recolher card</span><code>.expand-btn</code></div>
</section>

<section>
  <h2>Destaque de favorito ("atual")</h2>
  <div class="swatch-row"><span class="badge-current">TRABALHANDO ATUALMENTE</span><code>.badge-current</code></div>
  <div class="mini-card">Borda/glow de card favoritado (.card-current)</div>
</section>
</body>
</html>
"@
}

# Pagina soh pra dar acesso ao _archive/ (planos antigos/superados) sem
# precisar procurar pasta manualmente - "desencargo de consciencia", nao
# navegacao do dia a dia. _archive/ e' flat (sem subpasta) e fica fora do
# indice/sync-all.ps1 (Get-DocumentFiles exclui), entao os itens aqui nao
# viram card nenhum - so um link file:// direto pro .md bruto.
function Build-ArchiveHtml() {
    $archiveDir = Join-Path $root '_archive'
    $items = @(Get-ChildItem -Path $archiveDir -Filter '*.md' -File | Sort-Object Name | ForEach-Object {
        $raw = [IO.File]::ReadAllText($_.FullName)
        $desc = ''
        $parsed = Parse-Frontmatter $raw
        if ($parsed -and $parsed.Meta['function']) {
            $desc = Clean-Field $parsed.Meta['function']
            $repo = Clean-Field $parsed.Meta['repo']
            if ($repo) { $desc = "$desc ($repo)" }
        } else {
            $titleMatch = [regex]::Match($raw, '(?m)^#\s+(.+)$')
            $desc = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { '(sem descricao)' }
        }
        $fileUri = 'file:///' + ($_.FullName -replace '\\', '/')
        [PSCustomObject]@{ Name = $_.Name; Desc = $desc; Uri = $fileUri }
    })

    $rows = ($items | ForEach-Object {
        $searchBlob = Esc(("$($_.Name) $($_.Desc)").ToLowerInvariant())
        "<div class=`"swatch-row`" data-search=`"$searchBlob`"><div><strong>$(Esc $_.Name)</strong><div class=`"sub`" style=`"margin:2px 0 0;`">$(Esc $_.Desc)</div></div><a class=`"chip chip-task-code`" href=`"$($_.Uri)`" target=`"_blank`">Abrir</a></div>"
    }) -join "`n"
    if (-not $rows) { $rows = '<p class="empty">Nada em _archive/ ainda.</p>' }

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Arquivo</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
    --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
    --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
  }
  * { box-sizing: border-box; }
  *:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
  body {
    background: var(--bg); color: var(--text); max-width: 760px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0; padding: 24px 32px 64px;
  }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; }
  .back:hover { color: var(--gold-bright); }
  h1 { font-size: 1.3rem; margin: 14px 0 4px; color: #fff; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 0 0 24px; }
  .search-wrap { margin-bottom: 20px; }
  #archive-search {
    width: 100%; max-width: 360px; background: #262931; border: 1px solid var(--card-border);
    color: var(--text); border-radius: 8px; padding: 7px 12px; font-size: 0.82rem;
  }
  #archive-search:focus-visible { border-color: var(--gold); }
  #archive-search::placeholder { color: var(--text-faint); }
  .swatch-row {
    display: flex; align-items: center; justify-content: space-between; gap: 16px;
    padding: 10px 0; border-bottom: 1px solid #2a2c30; font-size: 0.85rem;
  }
  .chip {
    font-size: 0.72rem; padding: 4px 10px; border-radius: 999px; text-decoration: none;
    border: 1px solid transparent; white-space: nowrap; flex: 0 0 auto;
  }
  .chip-task-code { background: #332a12; color: #d9b568; border-color: #6b5628; }
  .empty { color: var(--text-faint); font-size: 0.85rem; }
</style>
</head>
<body>
<a class="back" href="dashboard.html">&larr; Voltar ao dashboard</a>
<h1>Arquivo $($script:EmDash) Biblioteca</h1>
<p class="sub">Docs superados/antigos, fora do dashboard principal. So pra acesso caso precise consultar historico - $($items.Count) arquivo(s).</p>
<div class="search-wrap">
  <input id="archive-search" type="text" placeholder="Buscar por nome ou descricao..." autocomplete="off">
</div>
<div id="archive-list">
$rows
</div>
<script>
var archiveSearch = document.getElementById('archive-search');
if (archiveSearch) {
  archiveSearch.addEventListener('input', function () {
    var q = archiveSearch.value.trim().toLowerCase();
    var list = document.getElementById('archive-list');
    var rows = list.querySelectorAll('.swatch-row');
    var anyVisible = false;
    rows.forEach(function (row) {
      var match = !q || row.getAttribute('data-search').indexOf(q) !== -1;
      row.style.display = match ? '' : 'none';
      if (match) { anyVisible = true; }
    });
    var emptyMsg = list.querySelector('.empty-search');
    if (!anyVisible) {
      if (!emptyMsg) {
        emptyMsg = document.createElement('p');
        emptyMsg.className = 'empty empty-search';
        emptyMsg.textContent = 'Nenhum arquivo encontrado.';
        list.appendChild(emptyMsg);
      }
    } else if (emptyMsg) {
      emptyMsg.remove();
    }
  });
}
</script>
</body>
</html>
"@
}

# Formulario de criacao de task - dump completo (nao pergunta parcial por
# chat): usuario preenche link(s) do Azure, repo e a demanda em texto livre,
# a pagina monta um comando que abre o Claude DIRETO na pasta do repo
# escolhido, com um prompt auto-suficiente (sem skill dedicada - o texto
# ja inclui as instrucoes de busca/confirmacao/historico, e o gate global
# do CLAUDE.md do usuario dispara sozinho, igual qualquer demanda digitada
# nesse repo). Estatica (sem backend) - so compoe o texto, quem processa
# e' o agente depois que a sessao abre. Reaproveita o mesmo mecanismo de
# lancamento do biblioteca-cmd: (Get-LaunchUri) + copia pro clipboard como
# fallback, igual todo outro botao de acao.
function Build-NovaTaskHtml() {
    # $reposBasePathJs vem do escopo do script (calculado antes desta funcao
    # ser chamada, perto do fim do arquivo) - mesmo padrao de closure que as
    # outras Build-*Html usam pra $hubRoot/$faviconLink etc.
    $hubRootJs = $hubRoot.Replace('\', '\\')

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Nova Task</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
    --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
    --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
    --azure-bg: #1f2a33; --azure-text: #7fa8c2; --azure-border: #3d5566;
    --claude-bg: #2e1f16; --claude-border: #a85a35; --claude-bright: #d97757;
  }
  * { box-sizing: border-box; }
  *:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
  html, body { height: 100%; }
  body {
    background: var(--bg); color: var(--text); max-width: 1400px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0 auto; padding: 20px 32px 24px; display: flex; flex-direction: column;
  }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; flex-shrink: 0; }
  .back:hover { color: var(--gold-bright); }
  h1 { font-size: 1.3rem; margin: 10px 0 4px; color: #fff; flex-shrink: 0; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 0 0 16px; flex-shrink: 0; }
  /* grid-template-rows: minmax(0,1fr) - forca a linha unica a ocupar toda
     a altura restante do container (que ja e' definida, vem do flex:1 do
     body) em vez de depender do "auto" calculado a partir do conteudo -
     "auto" mediu a coluna esquerda mais alta que a direita mesmo crescida,
     deixando vao vazio antes do botao. */
  .nt-grid {
    display: grid; grid-template-columns: 1.1fr 1fr; grid-template-rows: minmax(0, 1fr);
    gap: 20px; align-items: stretch; flex: 1 1 auto; min-height: 0;
  }
  /* height:100% (nao so' o stretch implicito do grid) - sem isso o
     flex-grow dos filhos (a secao do prompt/demanda) nao enxerga uma
     altura definida pra crescer contra, e vira um vao vazio embaixo em
     vez de esticar a caixa. */
  .nt-col-main, .nt-col-side { display: flex; flex-direction: column; min-height: 0; height: 100%; }
  .nt-desc-section { flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; }
  .nt-desc-section textarea { flex: 1 1 auto; min-height: 200px; }
  .nt-prompt-section { flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; }
  .nt-prompt-section textarea { flex: 1 1 auto; min-height: 200px; }
  .nt-col-side .actions { flex-shrink: 0; margin-top: auto; padding-top: 14px; }
  @media (max-width: 980px) {
    html, body { height: auto; }
    body { display: block; }
    .nt-grid { grid-template-columns: 1fr; }
    .nt-col-main, .nt-col-side { height: auto; }
  }
  .nt-section {
    background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 10px;
    padding: 14px 16px; margin: 0 0 14px;
  }
  .nt-section h2 {
    font-size: 0.76rem; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--gold-bright); margin: 0 0 10px; display: flex; align-items: center; gap: 6px;
  }
  .nt-azure { border-color: var(--azure-border); }
  .nt-azure h2 { color: var(--azure-text); }
  label { display: block; font-size: 0.8rem; color: var(--text-dim); margin: 12px 0 6px; }
  label:first-of-type { margin-top: 0; }
  label.req::after { content: " *"; color: var(--gold-bright); }
  label.nt-optional { font-size: 0.72rem; color: var(--text-faint); }
  input[type="text"], textarea {
    width: 100%; background: #262931; border: 1px solid var(--card-border);
    color: var(--text); border-radius: 8px; padding: 8px 12px; font-size: 0.88rem;
    font-family: inherit;
  }
  textarea { resize: vertical; }
  input[type="text"]:focus-visible, textarea:focus-visible { border-color: var(--gold); }
  #nt-desc { min-height: 140px; }
  .hint { color: var(--text-faint); font-size: 0.76rem; margin: 6px 0 0; }
  .hint code { font-family: ui-monospace, "SF Mono", monospace; color: var(--gold-bright); }
  .hint a { color: var(--gold-bright); }
  .warn { color: #c98a7a; font-size: 0.8rem; min-height: 1.1em; margin: 10px 0; }
  #nt-prompt { min-height: 150px; font-size: 0.85rem; line-height: 1.4; }
  details { margin-top: 10px; }
  details summary { color: var(--text-dim); font-size: 0.76rem; cursor: pointer; }
  details summary:hover { color: var(--gold-bright); }
  #nt-output {
    margin-top: 8px; min-height: 80px; font-family: ui-monospace, "SF Mono", monospace;
    font-size: 0.74rem; color: var(--text-dim);
  }
  .actions { display: flex; gap: 10px; margin-top: 18px; flex-wrap: wrap; }
  .claude-btn {
    background: var(--claude-bg); color: var(--claude-bright); border: 1px solid var(--claude-border);
    border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer;
    display: inline-block; text-decoration: none;
  }
  .claude-btn:hover { filter: brightness(1.2); }
</style>
</head>
<body>
<a class="back" href="dashboard.html">&larr; Voltar ao dashboard</a>
<h1>Nova Task</h1>
<p class="sub">Preenche os campos - o prompt se monta sozinho na caixa ao lado, pode ajustar antes de abrir. "Abrir Claude" ja copia e tenta abrir direto na pasta do repositorio.</p>

<div class="nt-grid">
  <div class="nt-col-main">
    <section class="nt-section nt-azure">
      <h2>$linkIcon Origem (Azure DevOps)</h2>
      <label class="req" for="nt-azure">Link do work item</label>
      <input type="text" id="nt-azure" placeholder="https://dev.azure.com/.../_workitems/edit/12345" autocomplete="off">
      <label class="nt-optional" for="nt-parent">Link do item pai (opcional)</label>
      <input type="text" id="nt-parent" placeholder="https://dev.azure.com/.../_workitems/edit/12000" autocomplete="off">
      <p class="hint">Pode deixar em branco - o Claude acha o parent sozinho via MCP do Azure DevOps, se estiver conectado.</p>
    </section>

    <section class="nt-section">
      <h2>Repositorio</h2>
      <label class="req" for="nt-repo">Repositorio</label>
      <input type="text" id="nt-repo" list="nt-repos" placeholder="meu-app-frontend" autocomplete="off">
      <datalist id="nt-repos">
$knownReposOptionsHtml
      </datalist>
      <p class="hint" id="nt-path-hint"></p>
    </section>

    <section class="nt-section nt-desc-section">
      <h2>Demanda</h2>
      <label class="req" for="nt-desc">O que precisa ser feito</label>
      <textarea id="nt-desc" placeholder="Contexto, aceite, qualquer coisa relevante - sem limite de linhas."></textarea>
    </section>
  </div>

  <div class="nt-col-side">
    <section class="nt-section nt-prompt-section">
      <h2>Prompt (isso vai ser enviado pro Claude)</h2>
      <textarea id="nt-prompt" placeholder="Preencha os campos ao lado - o prompt aparece aqui sozinho."></textarea>
      <p class="hint" id="nt-recalc-wrap" style="display:none">Editado manualmente - <a href="#" id="nt-recalc">recalcular a partir dos campos</a></p>
      <details>
        <summary>Comando bruto (powershell)</summary>
        <textarea id="nt-output" readonly placeholder="Aparece depois de clicar em Abrir Claude."></textarea>
      </details>
    </section>

    <p class="warn" id="nt-warn"></p>
    <div class="actions">
      <a class="claude-btn" id="nt-launch" href="#">Abrir Claude</a>
    </div>
  </div>
</div>

<script>
var azureEl = document.getElementById('nt-azure');
var parentEl = document.getElementById('nt-parent');
var repoEl = document.getElementById('nt-repo');
var descEl = document.getElementById('nt-desc');
var promptEl = document.getElementById('nt-prompt');
var pathHint = document.getElementById('nt-path-hint');
var recalcWrap = document.getElementById('nt-recalc-wrap');
var warn = document.getElementById('nt-warn');
var rawOutput = document.getElementById('nt-output');
var launch = document.getElementById('nt-launch');
var manualEdit = false;
var syncing = false;

// Sem skill dedicada - o prompt e' auto-suficiente: abre direto no repo e
// usa o fluxo global de skills (gbm-triagem/criar-task-code/plano-acao)
// que ja dispara sozinho por causa do CLAUDE.md do usuario. As instrucoes
// de busca/confirmacao/historico vao dentro do proprio texto, nao numa
// skill separada. Confirmacao do Azure e' objetiva (link + sim/nao), nao
// um paragrafo aberto - e so acontece 1x, depois o REQ salvo vira a fonte.
function buildPromptText() {
  var azure = azureEl.value.trim();
  var parent = parentEl.value.trim();
  var repo = repoEl.value.trim();
  var desc = descEl.value.trim();
  if (!azure && !repo && !desc) { return ''; }
  var parts = [];
  parts.push('Nova demanda - Azure: ' + (azure || '(nao informado)') + (parent ? ' (parent: ' + parent + ')' : '') + '.');
  parts.push('Repo: ' + (repo || '(nao informado)') + '. Se esta pasta nao for exatamente esse repositorio, mova-se (cd) pra pasta correta antes de seguir.');
  parts.push('Descricao: ' + (desc || '(nao informado)'));
  parts.push('Antes de gravar qualquer doc: busque REQ/parent via MCP azure-devops se estiver conectado (ferramenta wit_work_item, `$expand=relations pra achar o parent - nunca wit_work_item_write/wit_work_item_comment_write/wit_work_item_link_write/wit_backlog). Mostre o link do work item (e do parent, se achar) e peca uma confirmacao objetiva (sim/nao) se e esse mesmo - nao descreva tudo em texto solto, so o link + a pergunta.');
  parts.push('So depois da confirmacao, grave o REQ (e o parent, se houver) em reqs/ na Biblioteca e siga o fluxo normal (gbm-triagem, criar-task-code, plano-acao). A partir dai, use o arquivo salvo como fonte - nao reconsulte o Azure ao vivo de novo pra essa mesma task.');
  parts.push('Ao terminar de gravar os docs (task-code/reqs/resumo), anexe uma entrada em ' + '$hubRootJs' + '\\historico-nova-task.md (cabecalho \'## {data/hora} - task {id|slug} ({repo})\' + bullets Azure/Parent/REQs confirmados/Docs gerados) antes de considerar concluido.');
  return parts.join('\n\n');
}

function updatePathHint() {
  var repo = repoEl.value.trim();
  pathHint.textContent = repo ? ('Vai abrir em: ' + '$reposBasePathJs\\' + repo) : '';
}

function regeneratePrompt() {
  syncing = true;
  promptEl.value = buildPromptText();
  syncing = false;
  manualEdit = false;
  recalcWrap.style.display = 'none';
}

[azureEl, parentEl, repoEl, descEl].forEach(function (el) {
  el.addEventListener('input', function () {
    if (!manualEdit) { regeneratePrompt(); }
    updatePathHint();
  });
});

promptEl.addEventListener('input', function () {
  if (syncing) { return; }
  manualEdit = true;
  recalcWrap.style.display = 'block';
});

document.getElementById('nt-recalc').addEventListener('click', function (e) {
  e.preventDefault();
  regeneratePrompt();
});

launch.addEventListener('click', function (e) {
  var azure = azureEl.value.trim();
  var repo = repoEl.value.trim();
  var desc = descEl.value.trim();
  if (!azure || !repo || !desc) {
    e.preventDefault();
    warn.textContent = 'Preencha ao menos o link do Azure, o repositorio e a descricao.';
    return;
  }
  warn.textContent = '';
  var promptOneLine = promptEl.value.trim().replace(/\r\n|\r|\n/g, '\\n').replace(/"/g, "'");
  var escapedPhrase = promptOneLine.replace(/'/g, "''");
  var cmd = 'powershell -NoProfile -Command "cd \'$reposBasePathJs\\' + repo + '\'; claude \'' + escapedPhrase + '\'"';

  rawOutput.value = cmd;
  launch.setAttribute('href', 'biblioteca-cmd:' + encodeURIComponent(cmd));

  function fallback() {
    var ta = document.createElement('textarea');
    ta.value = cmd;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (err) {}
    document.body.removeChild(ta);
  }
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(cmd).catch(fallback);
  } else {
    fallback();
  }
});
</script>
</body>
</html>
"@
}

# Pagina de acao pontual: lista tasks cujo `resumo` ficou pra tras (status
# draft/in_progress) enquanto o resto da task ja nao esta mais ativo -
# exatamente o tipo de deriva encontrada manualmente em 2026-08-14
# (resumo/111 dizia draft com o task-code ja completed/mergeado). Selecionar
# via checkbox + "Copiar comando" gera um prompt de agente pra conferir o
# merge real e corrigir a documentacao em lote, sem precisar caçar card por
# card. Nao compara contra outros tipos de doc - so' o status do resumo, de
# proposito (pedido do usuario: manter simples).
function Build-PendenciasHtml() {
    $pendentes = @($cards | Where-Object { $_.ResumoDoc -and $_.ResumoDoc.Status -in @('draft', 'in_progress') -and -not $_.Active })
    # barra invertida dobrada pro literal JS abaixo - sem isso, sequencias tipo
    # \U/\D dentro do path do Windows somem no parser JS (nao sao escape valido).
    $hubRootJs = $hubRoot.Replace('\', '\\')

    $rows = ($pendentes | ForEach-Object {
        $c = $_
        $taskLabel = if ($c.Task -match '^\d+$') { "#$($c.Task)" } elseif ($c.Cluster) { $c.Cluster } else { $c.Task }
        $desc = if ($c.Function) { $c.Function } else { '(sem descricao)' }
        # mesma cor que o resto da Biblioteca ja associa a cada status (StatusEmoji:
        # draft=circulo branco, in_progress=circulo azul, lib-doc.ps1) - so nao existia
        # ainda como chip colorido, so como emoji dentro do badge:auto.
        $isProgress = $c.ResumoDoc.Status -eq 'in_progress'
        $statusLabel = if ($isProgress) { 'Em andamento' } else { 'Rascunho' }
        $statusClass = if ($isProgress) { 'chip-pend-progress' } else { 'chip-pend-draft' }
        $updated = if ($c.Updated) { $c.Updated } else { $script:EmDash }
        $searchBlob = Esc(("$taskLabel $($c.Repo) $desc").ToLowerInvariant())
        "<div class=`"swatch-row`" data-search=`"$searchBlob`"><label class=`"pend-label`"><input type=`"checkbox`" class=`"pend-check`" data-task=`"$(Esc $c.Task)`" data-repo=`"$(Esc $c.Repo)`"><div><strong>$(Esc $taskLabel)</strong> <span class=`"sub`">$(Esc $c.Repo)</span><div class=`"sub`" style=`"margin:2px 0 0;`">$(Esc $desc)</div></div></label><span class=`"chip $statusClass`">$statusLabel</span><span class=`"updated`">$(Esc $updated)</span></div>"
    }) -join "`n"
    if (-not $rows) { $rows = '<p class="empty">Nenhuma pendencia - tudo em dia.</p>' }

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Pendencias</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
    --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
    --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
  }
  * { box-sizing: border-box; }
  *:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
  body {
    background: var(--bg); color: var(--text); max-width: 760px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0; padding: 24px 32px 88px;
  }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; }
  .back:hover { color: var(--gold-bright); }
  h1 { font-size: 1.3rem; margin: 14px 0 4px; color: #fff; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 0 0 24px; }
  .search-wrap { margin-bottom: 20px; }
  #pend-search {
    width: 100%; max-width: 360px; background: #262931; border: 1px solid var(--card-border);
    color: var(--text); border-radius: 8px; padding: 7px 12px; font-size: 0.82rem;
  }
  #pend-search:focus-visible { border-color: var(--gold); }
  #pend-search::placeholder { color: var(--text-faint); }
  .swatch-row {
    display: flex; align-items: center; justify-content: space-between; gap: 16px;
    padding: 10px 0; border-bottom: 1px solid #2a2c30; font-size: 0.85rem;
  }
  .pend-label { display: flex; align-items: flex-start; gap: 10px; cursor: pointer; flex: 1 1 auto; min-width: 0; }
  .pend-label input[type="checkbox"] { margin-top: 3px; flex-shrink: 0; width: 15px; height: 15px; accent-color: var(--gold); cursor: pointer; }
  .updated { color: var(--text-faint); font-size: 0.75rem; white-space: nowrap; flex-shrink: 0; }
  .chip { font-size: 0.72rem; padding: 4px 10px; border-radius: 999px; white-space: nowrap; flex: 0 0 auto; border: 1px solid transparent; }
  .chip-pend-draft { background: #2a2c30; color: #b0b4bc; border-color: #4a4e58; }
  .chip-pend-progress { background: #1f2733; color: #86a3d9; border-color: #3d4f6b; }
  .empty { color: var(--text-faint); font-size: 0.85rem; }
  .action-bar {
    position: sticky; bottom: 0; margin-top: 20px; padding: 14px 0; background: var(--bg);
    border-top: 1px solid var(--card-border);
  }
  .copy-btn {
    background: var(--gold-bg); color: var(--text); border: 1px solid var(--gold-border); border-radius: 6px;
    padding: 8px 16px; font-size: 0.82rem; cursor: pointer;
  }
  .copy-btn:hover:not(:disabled) { filter: brightness(1.15); }
  .copy-btn:disabled { opacity: 0.45; cursor: not-allowed; }
</style>
</head>
<body>
<a class="back" href="dashboard.html">&larr; Voltar ao dashboard</a>
<h1>Pendencias $($script:EmDash) Biblioteca</h1>
<p class="sub">Resumos que ficaram pra tras (status nao reflete o que ja foi feito) - $($pendentes.Count) task(s). Marque e copie o comando pra um agente conferir o merge real e corrigir.</p>
<div class="search-wrap">
  <input id="pend-search" type="text" placeholder="Buscar por task, repo ou descricao..." autocomplete="off">
</div>
<div id="pend-list">
$rows
</div>
<div class="action-bar">
  <button id="pend-copy-btn" class="copy-btn" disabled>Copiar comando</button>
</div>
<script>
var pendSearch = document.getElementById('pend-search');
if (pendSearch) {
  pendSearch.addEventListener('input', function () {
    var q = pendSearch.value.trim().toLowerCase();
    var list = document.getElementById('pend-list');
    var rows = list.querySelectorAll('.swatch-row');
    var anyVisible = false;
    rows.forEach(function (row) {
      var match = !q || row.getAttribute('data-search').indexOf(q) !== -1;
      row.style.display = match ? '' : 'none';
      if (match) { anyVisible = true; }
    });
    var emptyMsg = list.querySelector('.empty-search');
    if (!anyVisible) {
      if (!emptyMsg) {
        emptyMsg = document.createElement('p');
        emptyMsg.className = 'empty empty-search';
        emptyMsg.textContent = 'Nenhuma pendencia encontrada.';
        list.appendChild(emptyMsg);
      }
    } else if (emptyMsg) {
      emptyMsg.remove();
    }
  });
}

var pendBtn = document.getElementById('pend-copy-btn');
function updatePendBtn() {
  var checked = document.querySelectorAll('.pend-check:checked');
  pendBtn.disabled = checked.length === 0;
  pendBtn.textContent = checked.length ? 'Copiar comando (' + checked.length + ' selecionada' + (checked.length > 1 ? 's' : '') + ')' : 'Copiar comando';
}
document.querySelectorAll('.pend-check').forEach(function (c) { c.addEventListener('change', updatePendBtn); });
pendBtn.addEventListener('click', function () {
  var items = Array.from(document.querySelectorAll('.pend-check:checked')).map(function (c) {
    return c.getAttribute('data-task') + ' (' + c.getAttribute('data-repo') + ')';
  });
  if (!items.length) { return; }
  var text = 'powershell -NoProfile -Command "cd \'$hubRootJs\'; claude \'verificar o estado real de merge/PR e atualizar a documentacao (resumo e status) das tasks pendentes na Biblioteca: ' + items.join(', ') + '\'"';
  function fallback() {
    var ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);
  }
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).catch(fallback);
  } else {
    fallback();
  }
  var original = pendBtn.textContent;
  pendBtn.textContent = 'Copiado!';
  setTimeout(updatePendBtn, 1500);
});
</script>
</body>
</html>
"@
}

$activeCards = @($cards | Where-Object { $_.Active } | Sort-Object Updated -Descending)
$doneCards = @($cards | Where-Object { -not $_.Active } | Sort-Object Updated -Descending)
$pendenciasCount = @($cards | Where-Object { $_.ResumoDoc -and $_.ResumoDoc.Status -in @('draft', 'in_progress') -and -not $_.Active }).Count

$activeHtml = ($activeCards | ForEach-Object { Build-Card $_ }) -join "`n"
$doneHtml = ($doneCards | ForEach-Object { Build-Card $_ }) -join "`n"
if (-not $activeHtml) { $activeHtml = '<p class="empty">Nenhuma task ativa.</p>' }
if (-not $doneHtml) { $doneHtml = '<p class="empty">Nenhuma task completa.</p>' }

$today = Get-Date -Format 'dd/MM/yyyy HH:mm'

$head = @'
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Dashboard</title>
<style>
  :root {
    color-scheme: dark;
    --bg: #1c1e21;
    --card-bg: #24262a;
    --card-border: #34373c;
    --input-bg: #262931;
    --text: #e2e4e7;
    --text-dim: #93969e;
    --text-faint: #6d7078;
    --gold: #b8935a;
    --gold-bright: #d9b26a;
    --gold-bg: #2e2717;
    --gold-border: #6b5628;
    --current: #d97b3f;
    --current-glow: rgba(217, 123, 63, 0.28);
    --claude-bg: #2e1f16;
    --claude-border: #a85a35;
    --claude-bright: #d97757;
  }
  * { box-sizing: border-box; }
  *:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0;
    padding: 24px 32px 64px;
  }
  .top-header { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; border-bottom: 2px solid var(--gold-border); padding-bottom: 16px; margin-bottom: 22px; }
  .brand-icon { flex-shrink: 0; }
  .brand-icon svg { width: 32px; height: 32px; }
  .palette-link {
    margin-left: auto; color: var(--text-dim); text-decoration: none; font-size: 0.78rem;
    border: 1px solid var(--card-border); border-radius: 999px; padding: 5px 12px;
    display: inline-flex; align-items: center; gap: 5px;
  }
  .palette-link:hover { color: var(--gold-bright); border-color: var(--gold-border); }
  .palette-link + .palette-link { margin-left: 0; }
  h1 { font-size: 1.6rem; margin: 0; color: #fff; letter-spacing: 0.02em; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 2px 0 0; }
  .stat { display: inline-flex; align-items: center; gap: 5px; margin-left: 10px; }
  .dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; display: inline-block; }
  .dot-neutral { background: var(--text-faint); }
  .search-wrap { position: relative; margin: 0; max-width: 480px; flex: 1 1 260px; }
  .search-icon { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--text-faint); pointer-events: none; display: flex; }
  #search {
    width: 100%; max-width: 480px; background: var(--input-bg); border: 1px solid var(--card-border);
    color: var(--text); border-radius: 8px; padding: 10px 14px 10px 34px; font-size: 0.9rem;
  }
  #search:focus-visible { border-color: var(--gold); }
  #search::placeholder { color: var(--text-faint); }
  h2 {
    font-size: 1rem; color: var(--gold-bright); text-transform: uppercase; letter-spacing: 0.08em;
    border-bottom: 1px solid var(--card-border); padding-bottom: 8px; margin-top: 32px;
  }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 14px; margin-top: 16px; }
  .card {
    background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 10px;
    padding: 14px 16px 34px; display: flex; flex-direction: column; gap: 8px; position: relative;
  }
  .card-current {
    border-color: var(--current); box-shadow: 0 0 0 1px var(--current), 0 0 16px -2px var(--current-glow);
  }
  .badge-current {
    align-self: flex-start; background: var(--current); color: #2b1d0a; font-weight: 700;
    font-size: 0.66rem; letter-spacing: 0.06em; text-transform: uppercase;
    padding: 3px 8px; border-radius: 999px;
  }
  .card-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 10px; }
  .card-head-left { display: flex; align-items: center; gap: 8px; min-width: 0; flex: 1 1 auto; }
  .card-head-right { display: flex; align-items: center; gap: 6px; flex: 0 0 auto; }
  .task-id {
    font-weight: 600; color: #fff; display: inline-block; max-width: 100%;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .repo {
    font-family: ui-monospace, "SF Mono", monospace; font-size: 0.8rem; color: var(--gold-bright);
    display: inline-block; max-width: 110px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .func {
    font-size: 0.88rem; color: #c2c4c9; margin: 0; line-height: 1.35;
    display: -webkit-box; -webkit-line-clamp: 1; line-clamp: 1; -webkit-box-orient: vertical; overflow: hidden;
  }
  .card.expanded .func { display: block; -webkit-line-clamp: unset; overflow: visible; }
  .ext-links { display: flex; flex-wrap: wrap; gap: 6px; }
  .ext-link {
    display: inline-flex; align-items: center; gap: 6px; font-size: 0.78rem; font-weight: 500;
    padding: 4px 10px; border-radius: 999px; text-decoration: none;
    background: #2c3038; border: 1px solid #454a54; color: var(--gold-bright);
  }
  .ext-link:hover { background: #363b45; color: #fff; }
  .ext-azure { background: #1f2a33; color: #7fa8c2; border-color: #3d5566; }
  .ext-github { border-color: #4d5560; }
  .ext-github-open { background: #242e1f; color: #a3b886; border-color: #4a5c3d; }
  .ext-github-merged { background: #281f33; color: #a996c4; border-color: #4f3d5c; }
  .ext-github-rejected { background: #33221f; color: #c98a7a; border-color: #5c3d34; }
  .icon-btn, .star-btn, .expand-btn {
    background: transparent; border: none; cursor: pointer; padding: 2px;
    display: flex; align-items: center; line-height: 0; color: var(--text-dim);
    text-decoration: none;
  }
  .icon-btn:hover, .resumo-btn:hover { color: var(--gold-bright); }
  .resumo-btn { color: var(--text); }
  .star-icon { fill: none; stroke: var(--text-dim); stroke-width: 1.6; transition: fill .15s, stroke .15s; }
  .star-btn:hover .star-icon { stroke: var(--current); }
  .card-current .star-icon { fill: var(--current); stroke: var(--current); }
  .expand-btn {
    position: absolute; right: 12px; bottom: 10px;
    border: 1px solid var(--card-border); border-radius: 6px; width: 22px; height: 22px;
    justify-content: center; transition: transform .15s, color .15s, border-color .15s;
  }
  .expand-btn:hover { color: var(--gold-bright); border-color: var(--gold-border); }
  .card.expanded .expand-btn { transform: rotate(180deg); }
  .chips, .position, .btns { display: none; }
  .card.expanded .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .card.expanded .position { display: flex; }
  .card.expanded .btns { display: flex; gap: 6px; flex-wrap: wrap; }
  .chip {
    font-size: 0.72rem; padding: 3px 9px; border-radius: 999px; text-decoration: none;
    border: 1px solid transparent; white-space: nowrap;
  }
  .chip:hover { filter: brightness(1.2); }
  .chip-task-code { background: #332a12; color: #d9b568; border-color: #6b5628; }
  .chip-task-planning { background: #1a2e30; color: #7cbfc4; border-color: #355a5e; }
  .chip-testes { background: #1f2e22; color: #86b894; border-color: #3d5c44; }
  .chip-handover-tecnico { background: #2e1f28; color: #c184a0; border-color: #5c3a4f; }
  .chip-rules { background: #292420; color: #a89484; border-color: #4d413a; }
  .position { background: #202225; border: 1px solid #303338; border-radius: 8px; padding: 8px 10px; flex-direction: column; gap: 6px; }
  .sig-label { font-size: 0.64rem; text-transform: uppercase; color: var(--text-faint); letter-spacing: 0.06em; }
  .sig-list { list-style: none; margin: 3px 0 0; padding: 0; display: flex; flex-direction: column; gap: 2px; }
  .sig-list li { font-size: 0.76rem; color: #c2c4c9; }
  .card-foot { display: flex; justify-content: space-between; align-items: center; margin-top: auto; padding-top: 6px; padding-right: 26px; gap: 8px; flex-wrap: wrap; }
  .updated { font-size: 0.72rem; color: var(--text-faint); }
  .copy-btn {
    background: var(--gold-bg); color: var(--text); border: 1px solid var(--gold-border); border-radius: 6px;
    padding: 5px 10px; font-size: 0.76rem; cursor: pointer;
    display: inline-block; text-decoration: none;
  }
  .copy-btn:hover { filter: brightness(1.15); }
  .qa-btn { border-color: #6b3f34; }
  /* Botoes do header (Abrir Claude / + Nova Task) tem escala propria, igual
     a altura das caixas de busca/repo ao lado - nao reaproveita o padding
     menor do .copy-btn generico (usado nos botoes de card/resumo). */
  .top-header .primary-link, .claude-btn {
    padding: 9px 16px; font-size: 0.85rem; border-radius: 8px;
  }
  .primary-link { border-color: var(--gold); font-weight: 600; }
  .claude-btn {
    background: var(--claude-bg); color: var(--claude-bright); border: 1px solid var(--claude-border);
    font-weight: 600; cursor: pointer; display: inline-block; text-decoration: none;
  }
  .claude-btn:hover { filter: brightness(1.2); }
  .quick-open { display: flex; align-items: center; gap: 6px; margin: 0; flex: 0 0 auto; }
  .quick-open input {
    background: var(--input-bg); border: 1px solid var(--card-border); color: var(--text);
    border-radius: 8px; padding: 10px 14px; font-size: 0.9rem; width: 170px;
  }
  .quick-open input:focus-visible { border-color: var(--gold); }
  .empty { color: var(--text-faint); font-size: 0.85rem; }
</style>
</head>
<body>
'@
$head = $head.Replace('$faviconLink', $faviconLink)

$foot = @'
<script>
document.querySelectorAll('.copy-btn[data-cmd]').forEach(function (btn) {
  btn.addEventListener('click', function () {
    var text = btn.getAttribute('data-cmd');
    function fallback() {
      var ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch (e) {}
      document.body.removeChild(ta);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).catch(fallback);
    } else {
      fallback();
    }
    var original = btn.textContent;
    btn.textContent = 'Copiado!';
    setTimeout(function () { btn.textContent = original; }, 1500);
  });
});

// Acesso rapido "Abrir Claude no repo" - o comando depende do repo escolhido
// no navegador, entao e' montado aqui no clique (nao em build-time como os
// outros botoes) - mesmo mecanismo biblioteca-cmd:/clipboard, so' calculado
// tarde. __REPOS_BASE_PATH__ e' substituido por texto literal depois (mesma
// tecnica do $faviconLink no $head - $foot e' single-quoted, sem interpolar).
var quickBtn = document.getElementById('quick-open-btn');
if (quickBtn) {
  var quickBtnOriginal = quickBtn.textContent;
  quickBtn.addEventListener('click', function (e) {
    var repo = document.getElementById('quick-repo').value.trim();
    // Sem repo escolhido -> abre solto na pasta que contem todos os repos
    // (reposBasePath), em vez de nao fazer nada.
    var targetPath = repo ? ('__REPOS_BASE_PATH__\\' + repo) : '__REPOS_BASE_PATH__';
    var cmd = 'powershell -NoProfile -Command "cd \'' + targetPath + '\'; claude"';
    // -run: aperta Enter sozinho - so abre uma janela solta do Claude, sem
    // disparar nenhuma skill nem gravar nada, diferente dos outros botoes.
    quickBtn.setAttribute('href', 'biblioteca-cmd-run:' + encodeURIComponent(cmd));
    function fallback() {
      var ta = document.createElement('textarea');
      ta.value = cmd;
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch (err) {}
      document.body.removeChild(ta);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(cmd).catch(fallback);
    } else {
      fallback();
    }
    quickBtn.textContent = 'Copiado!';
    setTimeout(function () { quickBtn.textContent = quickBtnOriginal; }, 1500);
  });
}

document.querySelectorAll('.expand-btn').forEach(function (btn) {
  btn.addEventListener('click', function () {
    var card = btn.closest('.card');
    card.classList.toggle('expanded');
    var expanded = card.classList.contains('expanded');
    btn.title = expanded ? 'Recolher' : 'Expandir';
    btn.setAttribute('aria-label', btn.title);
  });
});

// Favorito ("estrela") e puramente local (localStorage) - clique tem efeito
// imediato na pagina. Casa por data-id (unico por card - o path do doc
// representativo), NUNCA por task+repo: duas tasks "Geral" podem ter o
// mesmo repo e o mesmo task="general", so o path e garantido unico.
function getCurrentId() { return localStorage.getItem('taskHubCurrent') || null; }
function applyCurrent() {
  var currentId = getCurrentId();
  var activeGrid = document.getElementById('grid-active');
  var found = false;
  (activeGrid ? activeGrid.querySelectorAll('.card[data-id]') : []).forEach(function (card) {
    var isCurrent = !!currentId && card.getAttribute('data-id') === currentId;
    if (isCurrent) { found = true; }
    card.classList.toggle('card-current', isCurrent);
    var badge = card.querySelector('.badge-current');
    if (isCurrent && !badge) {
      badge = document.createElement('span');
      badge.className = 'badge-current';
      badge.textContent = 'TRABALHANDO ATUALMENTE';
      card.insertBefore(badge, card.firstChild);
    } else if (!isCurrent && badge) {
      badge.remove();
    }
    var starBtn = card.querySelector('.star-btn');
    if (starBtn) {
      starBtn.setAttribute('aria-pressed', isCurrent ? 'true' : 'false');
      starBtn.title = isCurrent ? 'Remover destaque' : 'Marcar como favorita';
    }
  });
  // task marcada nao esta mais em Ativas (foi concluida, por ex.) - limpa
  if (currentId && !found) { localStorage.removeItem('taskHubCurrent'); }
}
document.querySelectorAll('.star-btn').forEach(function (btn) {
  btn.addEventListener('click', function () {
    var card = btn.closest('.card');
    var id = card.getAttribute('data-id');
    var wasCurrent = getCurrentId() === id;
    if (wasCurrent) {
      localStorage.removeItem('taskHubCurrent');
    } else {
      localStorage.setItem('taskHubCurrent', id);
    }
    applyCurrent();
    if (!wasCurrent) {
      var grid = card.closest('.grid');
      if (grid && grid.firstChild !== card) { grid.insertBefore(card, grid.firstChild); }
    }
  });
});
applyCurrent();

var search = document.getElementById('search');
var quickRepoFilter = document.getElementById('quick-repo');

// Filtro combinado: texto livre (search) E repo escolhido no "Abrir Claude"
// (quick-repo) - o repo funciona como um 2o ponto de filtro, nao substitui
// a busca. Os dois reaplicam o mesmo applyFilters ao mudar.
function applyFilters() {
  var q = search ? search.value.trim().toLowerCase() : '';
  var repoQ = quickRepoFilter ? quickRepoFilter.value.trim().toLowerCase() : '';
  document.querySelectorAll('.grid').forEach(function (grid) {
    var cards = grid.querySelectorAll('.card');
    if (cards.length === 0) { return; }
    var anyVisible = false;
    cards.forEach(function (card) {
      var searchMatch = !q || card.getAttribute('data-search').indexOf(q) !== -1;
      var repoMatch = !repoQ || (card.getAttribute('data-repo') || '').indexOf(repoQ) !== -1;
      var match = searchMatch && repoMatch;
      card.style.display = match ? '' : 'none';
      if (match) { anyVisible = true; }
    });
    var emptyMsg = grid.querySelector('.empty-search');
    if (!anyVisible) {
      if (!emptyMsg) {
        emptyMsg = document.createElement('p');
        emptyMsg.className = 'empty empty-search';
        emptyMsg.textContent = 'Nenhuma task encontrada.';
        grid.appendChild(emptyMsg);
      }
    } else if (emptyMsg) {
      emptyMsg.remove();
    }
  });
}
if (search) { search.addEventListener('input', applyFilters); }
if (quickRepoFilter) { quickRepoFilter.addEventListener('input', applyFilters); }

// Auto-reload: dashboard.html e' estatico, sync-all.ps1 regenera o arquivo
// mas a aba aberta nao sabe sozinha - sem servidor rodando, um file:// nao
// consegue reler a si mesmo sem recarregar (fetch bloqueado por seguranca
// em arquivo local, document.lastModified so' reflete o carregamento atual).
// Recarrega a pagina inteira periodicamente e preserva busca/cards abertos/
// scroll via sessionStorage pra nao perder o que estava sendo visto.
var LIVE_RELOAD_MS = 20000;
var RELOAD_STATE_KEY = 'dashboardReloadState';

function saveReloadState() {
  var expandedIds = Array.prototype.map.call(
    document.querySelectorAll('.card.expanded[data-id]'),
    function (c) { return c.getAttribute('data-id'); }
  );
  var state = {
    search: search ? search.value : '',
    quickRepo: quickRepoFilter ? quickRepoFilter.value : '',
    expanded: expandedIds,
    scrollY: window.scrollY
  };
  sessionStorage.setItem(RELOAD_STATE_KEY, JSON.stringify(state));
}

function restoreReloadState() {
  var raw = sessionStorage.getItem(RELOAD_STATE_KEY);
  if (!raw) { return; }
  sessionStorage.removeItem(RELOAD_STATE_KEY);
  var state;
  try { state = JSON.parse(raw); } catch (e) { return; }
  if (quickRepoFilter && state.quickRepo) { quickRepoFilter.value = state.quickRepo; }
  if (search && state.search) {
    search.value = state.search;
    search.dispatchEvent(new Event('input'));
  } else if (quickRepoFilter && state.quickRepo) {
    quickRepoFilter.dispatchEvent(new Event('input'));
  }
  var expanded = state.expanded || [];
  if (expanded.length) {
    document.querySelectorAll('.card[data-id]').forEach(function (card) {
      if (expanded.indexOf(card.getAttribute('data-id')) === -1) { return; }
      card.classList.add('expanded');
      var btn = card.querySelector('.expand-btn');
      if (btn) { btn.title = 'Recolher'; btn.setAttribute('aria-label', 'Recolher'); }
    });
  }
  if (typeof state.scrollY === 'number') { window.scrollTo(0, state.scrollY); }
}

restoreReloadState();
setInterval(function () { saveReloadState(); location.reload(); }, LIVE_RELOAD_MS);
</script>
</body>
</html>
'@

# Acesso rapido "Abrir Claude" - so aparece se reposBasePath estiver
# configurado (sem ele nao ha path valido pra montar o comando). Repo
# escolhido no navegador -> comando montado em JS no clique (ver $foot),
# mesmo mecanismo biblioteca-cmd:/clipboard dos outros botoes.
$quickOpenHtml = ''
$reposBasePathJs = if ($bibConfig.reposBasePath) { $bibConfig.reposBasePath.Replace('\', '\\') } else { '' }
$foot = $foot.Replace('__REPOS_BASE_PATH__', $reposBasePathJs)
if ($bibConfig.reposBasePath) {
    $quickOpenHtml = @"
<div class="quick-open">
  <input type="text" id="quick-repo" list="quick-repos" placeholder="Repositorio..." autocomplete="off">
  <datalist id="quick-repos">
$knownReposOptionsHtml
  </datalist>
  <a class="claude-btn" id="quick-open-btn" href="#">Abrir Claude</a>
</div>
"@
}

$body = @"
<header class="top-header">
  <span class="brand-icon">$brandIconGreen</span>
  <div>
    <h1>Biblioteca</h1>
    <p class="sub">Dashboard de tasks &middot; Gerado em $today
      <span class="stat"><span class="dot"></span>$($activeCards.Count) ativas</span>
      <span class="stat"><span class="dot dot-neutral"></span>$($doneCards.Count) completas</span>
    </p>
  </div>
  <div class="search-wrap">
    <span class="search-icon">$searchIcon</span>
    <input id="search" type="text" placeholder="Buscar por task, repo ou descricao..." autocomplete="off">
  </div>
  $quickOpenHtml
  <a class="copy-btn primary-link" href="nova-task.html" target="_blank">+ Nova Task</a>
  <a class="palette-link" href="historico-nova-task.md" target="_blank">$archiveIcon Historico</a>
  <a class="palette-link" href="paleta.html" target="_blank">$paletteIcon Paleta de cores</a>
  <a class="palette-link" href="archive.html" target="_blank">$archiveIcon Arquivo</a>
  <a class="palette-link" href="pendencias.html" target="_blank">$pendIcon Pendencias$(if ($pendenciasCount) { " ($pendenciasCount)" })</a>
</header>

<h2>Ativas</h2>
<div class="grid" id="grid-active">
$activeHtml
</div>

<h2>Completas</h2>
<div class="grid" id="grid-done">
$doneHtml
</div>
"@

$html = $head + $body + $foot
$outPath = Join-Path $hubRoot 'dashboard.html'
[System.IO.File]::WriteAllText($outPath, $html)

# Redirect no caminho antigo (raiz/dashboard-visual/) - a reorganizacao de
# 17/08/2026 moveu o dashboard pra dentro de _ferramenta/, mas favorito/
# aba ja aberta no navegador continua apontando pro path velho. Sem isso,
# quem nao atualizou o favorito acha que o dashboard "parou de mostrar"
# coisa nova, quando na verdade esta olhando um arquivo/cache antigo.
$legacyRedirect = @"
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=../_ferramenta/dashboard-visual/dashboard.html">
<title>Biblioteca - redirecionando...</title>
</head><body>
<p>O dashboard mudou de lugar - redirecionando pra
<a href="../_ferramenta/dashboard-visual/dashboard.html">_ferramenta/dashboard-visual/dashboard.html</a>.
Atualize seu favorito.</p>
<script>location.replace('../_ferramenta/dashboard-visual/dashboard.html');</script>
</body></html>
"@
$legacyDir = Join-Path $root 'dashboard-visual'
New-Item -ItemType Directory -Force -Path $legacyDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $legacyDir 'dashboard.html'), $legacyRedirect)

[System.IO.File]::WriteAllText((Join-Path $hubRoot 'paleta.html'), (Build-PaletteHtml))
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'archive.html'), (Build-ArchiveHtml))
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'pendencias.html'), (Build-PendenciasHtml))
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'nova-task.html'), (Build-NovaTaskHtml))

# Historico de criacao de tasks (o proprio agente anexa as entradas,
# seguindo a instrucao embutida no prompt de nova-task.html - sem skill
# dedicada) - so' garante que o arquivo existe pra o link "Historico" do
# header nao dar 404 antes da 1a task criada pelo formulario; nunca
# sobrescreve conteudo.
$historicoPath = Join-Path $hubRoot 'historico-nova-task.md'
if (-not (Test-Path $historicoPath)) {
    [System.IO.File]::WriteAllText($historicoPath, "# Historico de criacao de tasks`n`nEntradas anexadas pelo agente (instrucao embutida no prompt de nova-task.html) a cada task criada - append-only, nao editar a mao.`n")
}

# Related tasks (cross-repo): mesma task numerica, ou mesmo cluster exato
# (so' task "general"), aparecendo em outro card/repo. So' usado na pagina
# de resumo (Get-RelatedTasksHtml). As duas listas sao mutuamente exclusivas
# por construcao (Task numerica cai so' aqui, "general"+Cluster cai so' ali)
# - nunca precisa deduplicar um card que bateria nos dois.
$cardsByTask = @{}
$cardsByCluster = @{}
foreach ($c in $cards) {
    if ($c.Task -match '^\d+$') {
        if (-not $cardsByTask.ContainsKey($c.Task)) { $cardsByTask[$c.Task] = @() }
        $cardsByTask[$c.Task] += $c
    } elseif ($c.Cluster) {
        if (-not $cardsByCluster.ContainsKey($c.Cluster)) { $cardsByCluster[$c.Cluster] = @() }
        $cardsByCluster[$c.Cluster] += $c
    }
}

# Paginas de resumo standalone - uma por task+repo que tem doc `resumo`
$summariesDir = Join-Path $hubRoot 'summaries'
New-Item -ItemType Directory -Force -Path $summariesDir | Out-Null
$summaryCount = 0
foreach ($card in $cards) {
    if (-not $card.ResumoDoc) { continue }
    $baseName = [IO.Path]::GetFileNameWithoutExtension($card.ResumoDoc.Path)
    $summaryHtml = Build-SummaryHtml $card
    [System.IO.File]::WriteAllText((Join-Path $summariesDir "$baseName.html"), $summaryHtml)
    $summaryCount++
}

Write-Output "dashboard: $($cards.Count) tasks ($($activeCards.Count) ativas, $($doneCards.Count) completas), $summaryCount resumos -> $outPath"
