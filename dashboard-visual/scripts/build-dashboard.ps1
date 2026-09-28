# Gera dashboard-visual/dashboard.html a partir de TODOS os docs da
# Biblioteca (nao so pendentes) - secoes Ativas / Completas +
# comando copiavel de retomada/conclusao/QA por task. Reaproveita
# lib-doc.ps1, nao duplica parsing de frontmatter. Isso e' a camada visual
# da propria Biblioteca (nao um projeto separado) - mora em
# Biblioteca/dashboard-visual/.
#
# Favorito ("estrela") e puramente client-side (localStorage) - nao precisa
# de comando/skill, e' so uma preferencia de UI, sem logica de git.
param([array]$ParsedDocs)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hubRoot = Split-Path $PSScriptRoot -Parent
$libRoot = Split-Path $hubRoot -Parent
$libScript = Join-Path $libRoot 'scripts\lib-doc.ps1'
. $libScript
. (Join-Path $PSScriptRoot 'dashboard-lib.ps1')

$root = Get-LibRoot
# -ParsedDocs vem de sync-all.ps1 (parse compartilhado); sem ele (rodando
# este script solo, como faz task-hub-complete/qa), parseia por conta
# propria - ver lint-clusters.ps1.
$parsedDocs = if ($ParsedDocs) { $ParsedDocs } else { Get-ParsedDocs $root }
$typeOrder = @{ 'task-code' = 0; 'task-planning' = 1; 'testes' = 2; 'handover-tecnico' = 3 }
$activeStatuses = @('draft', 'in_progress')
$bibConfig = Get-BibliotecaConfig
$azureBase = $bibConfig.azureOrgUrl

$githubIcon = '<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.02 1.93-.02 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>'
$linkIcon = '<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor"><path d="M4.72 3.5a2.25 2.25 0 000 4.5h1.5a.75.75 0 010 1.5h-1.5a3.75 3.75 0 010-7.5h1.5a.75.75 0 010 1.5h-1.5zm6.56 0h-1.5a.75.75 0 000 1.5h1.5a2.25 2.25 0 010 4.5h-1.5a.75.75 0 000 1.5h1.5a3.75 3.75 0 000-7.5zM5.5 8a.75.75 0 01.75-.75h3.5a.75.75 0 010 1.5h-3.5A.75.75 0 015.5 8z"/></svg>'
$starIcon = '<svg class="star-icon" viewBox="0 0 24 24" width="17" height="17"><path d="M12 2.5l2.9 6.26L22 9.77l-5 4.87L18.18 21.5 12 17.77 5.82 21.5 7 14.64l-5-4.87 7.1-1.01L12 2.5z"/></svg>'
$bookIcon = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z"/><path d="M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z"/></svg>'
$chevronIcon = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6l4 4 4-4"/></svg>'

# Padrao unico de lancamento (biblioteca-cmd-run:) - injetado no <script> de
# TODA pagina com botao que abre um cmd novo (dashboard.html, resumo/*.html,
# nova-task.html), fonte unica em vez de 3 copias que podiam divergir (foi
# assim que o header "Abrir Claude" ficou com preventDefault+location.href
# enquanto os outros usavam <a href> real - bug de janela dupla, 2026-09-01).
# href sempre atualizado ANTES do clique nativo seguir - nunca
# preventDefault + location.href de novo pra reabrir um protocolo
# customizado (dispara o handler do SO 2x em alguns navegadores). Clipboard
# e' so fallback assincrono pra maquina sem o protocolo registrado, nao
# bloqueia a navegacao.
$launchButtonJs = @'
function biblLaunch(el, cmd) {
  el.setAttribute('href', 'biblioteca-cmd-run:' + encodeURIComponent(cmd));
  function fallback() {
    var ta = document.createElement('textarea');
    ta.value = cmd;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);
  }
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(cmd).catch(fallback);
  } else {
    fallback();
  }
  var original = el.textContent;
  el.textContent = 'Abrindo...';
  setTimeout(function () { el.textContent = original; }, 1500);
}
'@

# Tokens de cor + reset base - identicos nas 6 paginas geradas (dashboard,
# resumo, paleta, archive, nova-task, pendencias). Cada pagina pode somar
# um `:root { --token-extra: ...; }` proprio logo depois deste bloco pra
# variaveis que so ela usa (ex.: nova-task.html tem --azure-*/--claude-*,
# paleta.html tem --current/--current-glow) - nao precisa duplicar as
# 10 variaveis base, so' extender.
$sharedCss = @'
:root {
  color-scheme: dark;
  --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
  --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
  --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
}
* { box-sizing: border-box; }
*:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
'@

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
$mockIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M1 8s2.5-4.5 7-4.5S15 8 15 8s-2.5 4.5-7 4.5S1 8 1 8z"/><circle cx="8" cy="8" r="1.8" fill="currentColor" stroke="none"/></svg>'

# Icones do "tipo de repo" do PR (backend/frontend/migration) - trocam o
# $githubIcon generico no pill de PR, inferido do nome do repo na propria
# URL (convencao GBM: sufixo -backend, prefixo mfe-/mobile-, ou
# gbm-app-migrations). "PR #N" no texto ja diz que e' PR - o icone generico
# do github era redundante; agora carrega informacao nova.
$backendIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2" y="2" width="12" height="4.5" rx="1"/><rect x="2" y="9.5" width="12" height="4.5" rx="1"/><circle cx="4.3" cy="4.25" r="0.55" fill="currentColor" stroke="none"/><circle cx="4.3" cy="11.75" r="0.55" fill="currentColor" stroke="none"/></svg>'
$frontendIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="1.5" y="2.5" width="13" height="9" rx="1"/><path d="M6 14.5h4M8 11.5v3"/></svg>'
$migrationIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5.5h9.5m0 0L10 3M12.5 5.5L10 8"/><path d="M13 10.5H3.5m0 0L6 8M3.5 10.5L6 13"/></svg>'

# Cards irmaos da mesma task (task numerica igual, ou mesmo cluster exato
# pra task "general") - inclui o proprio $card. Le $cardsByTask/
# $cardsByCluster (script scope, montados logo apos $cards ficar pronto,
# antes de qualquer chamada a esta funcao). Usada por qualquer lugar que
# precisa agregar dado cross-repo da mesma task (PRs, estado de PR, testes,
# tasks relacionadas).
function Get-TaskSiblings([PSCustomObject]$card) {
    $siblings = if ($card.Task -match '^\d+$') {
        @($cardsByTask[$card.Task])
    } elseif ($card.Cluster) {
        @($cardsByCluster[$card.Cluster])
    } else {
        @()
    }
    if ($siblings.Count -eq 0) { return @($card) }
    return $siblings
}

# Classifica um nome de repo pela convencao GBM (sufixo -backend, prefixo
# mfe-/mobile-, ou "migrations") - fonte unica usada tanto pelo icone do PR
# (Get-PrKindInfo) quanto pelo rotulo curto de camada no titulo do card
# (Build-Card/Build-SummaryHtml, taskLabel). $null se o nome nao bater com
# nenhuma convencao conhecida (repo pessoal, nome atipico etc.).
function Get-RepoLayer([string]$repo) {
    if (-not $repo) { return $null }
    if ($repo -match '-backend$') { return 'backend' }
    if ($repo -match 'migrations') { return 'migrations' }
    if ($repo -match '^(gbm-)?(mfe|mobile)-') { return 'frontend' }
    return $null
}
$script:RepoLayerLabels = @{ backend = 'Backend'; frontend = 'Frontend'; migrations = 'Migrations' }

# Nome do arquivo summaries/*.html de um card - sufixado pela camada
# (Get-RepoLayer) quando reconhecida, pra nao colidir quando o backend e
# o frontend (ou migrations) da mesma task usam o mesmo slug de arquivo
# (`resumo/backend/X.md` e `resumo/frontend/X.md` geravam os DOIS
# `summaries/X.html`, um sobrescrevendo o outro no disco - bug real,
# confirmado em 3 tasks: 103269, 104689, 104691). Sem camada reconhecida
# (repo fora da convencao), mantem o nome antigo sem sufixo - nao regride
# quem nunca colidiu. Fonte unica usada pelo loop que escreve os arquivos
# e por todo lugar que linka pra eles (Get-RelatedTasksHtml, Build-Card,
# Build-QaRoundCard, Build-UnifiedQaRoundCard).
function Get-SummaryFileName([PSCustomObject]$card) {
    if (-not $card.ResumoDoc) { return $null }
    # Ate' 2026-09-10 o nome do .md em `resumo/` nao diferenciava camada
    # (vivia em subpasta `frontend`/`backend`) - por isso o -$layer era
    # somado aqui pra nao colidir 2 resumos com o mesmo nome-base gerando
    # o mesmo .html. Depois da unificacao de pastas, o proprio nome do
    # arquivo ja e' unico (colisao real ganhou sufixo -backend/-frontend
    # na origem) - somar de novo aqui duplicava o sufixo
    # ("...-backend-backend.html", achado ao commitar em 2026-09-11).
    $baseName = [IO.Path]::GetFileNameWithoutExtension($card.ResumoDoc.Path)
    return "$baseName.html"
}

# Classifica o PR pelo nome do repo na propria URL - sem depender de campo
# novo no frontmatter. Fallback pro icone generico do github se o nome nao
# bater com nenhuma convencao conhecida (repo pessoal, nome atipico etc.).
function Get-PrKindInfo([string]$prUrl) {
    if ($prUrl -notmatch 'github\.com/[^/]+/([^/]+)/pull/') {
        return [PSCustomObject]@{ Icon = $githubIcon; Title = 'PR'; Layer = $null }
    }
    $repo = $Matches[1]
    switch (Get-RepoLayer $repo) {
        'backend' { return [PSCustomObject]@{ Icon = $backendIcon; Title = 'PR de backend'; Layer = 'backend' } }
        'migrations' { return [PSCustomObject]@{ Icon = $migrationIcon; Title = 'PR de migration'; Layer = 'migrations' } }
        'frontend' { return [PSCustomObject]@{ Icon = $frontendIcon; Title = 'PR de frontend'; Layer = 'frontend' } }
        default { return [PSCustomObject]@{ Icon = $githubIcon; Title = 'PR'; Layer = $null } }
    }
}

# 4 badges de status por camada (migrations/backend/frontend/testes) da
# task inteira (todos os repos, via $cardsByTask/$cardsByCluster - mesmo
# agrupamento cross-repo do Get-RelatedTasksHtml) - substitui a antiga
# lista de texto livre "Pendencias" (extraida por regex do corpo do doc,
# pouco legivel e nao confiavel). Verde = feito, vermelho = pendente,
# amarelo = camada nao existe nesta task (nenhum PR/doc encontrado).
function Get-LayerStatusHtml([PSCustomObject]$card) {
    $siblings = Get-TaskSiblings $card

    # Uniao dos PRs de todos os irmaos, montada aqui (card.Signals.PRs NAO
    # vem mais agregado - ver nota logo apos $cardsByTask/$cardsByCluster
    # serem montados) - o painel de status por camada precisa ver a task
    # inteira mesmo quando chamado a partir do card de um unico repo.
    $allPrs = @($siblings | ForEach-Object { $_.Signals.PRs } | Select-Object -Unique)
    $allDocs = New-Object System.Collections.Generic.List[object]
    foreach ($s in $siblings) {
        foreach ($d in $s.Docs) { $allDocs.Add($d) }
        if ($s.ResumoDoc) { $allDocs.Add($s.ResumoDoc) }
    }

    function Get-PrState([string]$pr) {
        # mesma checagem de estado do Get-ExtLinksHtml (Contains, nao -eq,
        # pra bater com campo com varias URLs - migration espelho etc.)
        if (@($allDocs | Where-Object { $_.PrMerged -and $_.PrMerged.Contains($pr) }).Count -gt 0) { return 'done' }
        if (@($allDocs | Where-Object { $_.PrRejected -and $_.PrRejected.Contains($pr) }).Count -gt 0) { return 'done' }
        return 'pending'
    }

    function Get-LayerState([string]$layer) {
        $prsInLayer = @($allPrs | Where-Object { (Get-PrKindInfo $_).Layer -eq $layer })
        if ($prsInLayer.Count -eq 0) { return 'na' }
        if (@($prsInLayer | Where-Object { (Get-PrState $_) -eq 'pending' }).Count -gt 0) { return 'pending' }
        return 'done'
    }

    # Isola o texto de UMA secao "## Titulo" ate a proxima "## " (ou fim do
    # doc) - split com lookahead, sem regex multilinha fragil. So' a
    # primeira linha do trecho e' comparada contra o titulo procurado.
    function Get-SectionText([string]$body, [string]$headingSubstring) {
        $parts = $body -split '(?m)(?=^## )'
        foreach ($p in $parts) {
            $firstLine = ($p -split "`n")[0]
            if ($firstLine -match [regex]::Escape($headingSubstring)) { return $p }
        }
        return $null
    }

    # Heuristica sobre texto ja convencionado (mesma familia de risco da
    # antiga extracao de pendencias, escopo bem mais restrito): secao
    # "## Testes unitarios" (padrao backend) ou "## Verificacao estatica"
    # (papel equivalente no frontend, tsc/biome/build) = camada unitaria;
    # "## Testes manuais" = camada manual. Sem secao em nenhum doc irmao
    # `testes/` = amarelo (nao necessario). Com secao, procura marcador
    # negativo ja usado na convencao atual (cross/hourglass emoji, "pendente",
    # "nao executado") dentro DAQUELE trecho especifico, nao o doc inteiro - senao um doc
    # com unitario verde + manual pendente contaminaria os dois).
    function Get-TestTypeState([string]$headingSubstring, [string[]]$negativeMarkers) {
        $sections = @($testesDocs | ForEach-Object { Get-SectionText $_.Body $headingSubstring } | Where-Object { $_ })
        if ($sections.Count -eq 0) { return 'na' }
        foreach ($sec in $sections) {
            foreach ($marker in $negativeMarkers) {
                if ($sec -match $marker) { return 'pending' }
            }
        }
        return 'done'
    }

    # Caracteres especiais via codepoint, nao literal - este arquivo nao tem
    # BOM, PowerShell 5.1 le como ANSI e corrompe qualquer char nao-ASCII
    # digitado direto no source (mesmo motivo do $script:EmDash em
    # lib-doc.ps1 e do $emDash em export-public.ps1).
    $crossmark = [char]0x274C
    $hourglass = [char]0x23F3
    $aTilde = [char]0x00E3
    $aAcute = [char]0x00E1

    $testesDocs = @($allDocs | Where-Object { $_.Type -eq 'testes' })
    $unitState = Get-TestTypeState 'Testes unitarios' @($crossmark, '(?i)falhou', '(?i)regress\w* encontrada')
    if ($unitState -eq 'na') {
        $unitState = Get-TestTypeState 'Verifica' @($crossmark, '(?i)falhou')
    }
    $manualState = Get-TestTypeState 'Testes manuais' @($hourglass, '(?i)pendente', "(?i)n${aTilde}o executado")

    $layers = @(
        @{ Label = 'Migrations'; State = (Get-LayerState 'migrations') }
        @{ Label = 'Backend'; State = (Get-LayerState 'backend') }
        @{ Label = 'Frontend'; State = (Get-LayerState 'frontend') }
        @{ Label = "Testes unit${aAcute}rios"; State = $unitState }
        @{ Label = 'Testes manuais'; State = $manualState }
    )
    # Se nenhuma camada tem sinal nenhum (sem PR em migrations/backend/
    # frontend, sem doc `testes/` com secao unitaria/manual), o bloco
    # inteiro seria so' 5 linhas amarelas "nao necessario" - ruido puro em
    # card que nunca teve essas camadas pra comecar (handover/investigacao,
    # tasks `general` na maioria das vezes). Nao mostra nada nesse caso.
    if (@($layers | Where-Object { $_.State -ne 'na' }).Count -eq 0) { return '' }
    $rows = ($layers | ForEach-Object {
        $stateLabel = switch ($_.State) { 'done' { 'feito' }; 'pending' { 'pendente' }; default { 'nao necessario' } }
        "<div class=`"layer-row layer-$($_.State)`"><span class=`"layer-dot`"></span><span class=`"layer-label`">$($_.Label)</span><span class=`"layer-state`">$stateLabel</span></div>"
    }) -join "`n"
    return "<div class=`"position layer-status`">$rows</div>"
}

# Pills de links externos (Azure DevOps + PR do GitHub, com cor por estado
# real - aberto/mergeado/rejeitado). Compartilhada entre o card da grade e a
# pagina de resumo, pra nao duplicar a logica de cor em dois lugares.
# -AllSiblings: mostra a uniao de PRs de todos os irmaos da mesma task
# (todos os repos) - so' a pagina de resumo usa isso, o "principal" que
# mostra tudo. Sem o switch (default, usado pelo card da grade), mostra
# so' os PRs do proprio repo desse card.
function Get-ExtLinksHtml([PSCustomObject]$card, [switch]$AllSiblings) {
    $extLinks = New-Object System.Collections.Generic.List[string]
    if ($azureBase -and $card.Task -match '^\d+$') {
        $azureUrl = "$azureBase/$($card.Task)"
        $extLinks.Add("<a class=`"ext-link ext-azure`" href=`"$azureUrl`" target=`"_blank`" title=`"Abrir work item no Azure DevOps`">$linkIcon Azure</a>")
    }
    # Estado (mergeado/aberto/rejeitado) precisa olhar os docs de TODOS os
    # irmaos da mesma task, nao so' os do proprio repo - senao um PR
    # "emprestado" de outro repo (ja incluido em Signals.PRs pela agregacao
    # cross-repo acima) aparece na cor certa num card e cinza no outro,
    # dependendo de qual repo tem o campo pr_merged daquele PR especifico.
    $cardDocsForState = New-Object System.Collections.Generic.List[object]
    foreach ($s in (Get-TaskSiblings $card)) {
        foreach ($d in $s.Docs) { $cardDocsForState.Add($d) }
        if ($s.ResumoDoc) { $cardDocsForState.Add($s.ResumoDoc) }
    }
    $prList = if ($AllSiblings) {
        $merged = New-Object System.Collections.Generic.List[string]
        foreach ($s in (Get-TaskSiblings $card)) {
            foreach ($pr in $s.Signals.PRs) { if (-not $merged.Contains($pr)) { $merged.Add($pr) } }
        }
        @($merged)
    } else { @($card.Signals.PRs) }
    foreach ($pr in $prList) {
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
        $kind = Get-PrKindInfo $pr
        $extLinks.Add("<a class=`"ext-link ext-github$stateClass`" href=`"$(Esc $pr)`" target=`"_blank`" title=`"$($kind.Title) - $stateTitle`">$($kind.Icon) PR #$num</a>")
    }
    if ($extLinks.Count -eq 0) { return '' }
    return "<div class=`"ext-links`">$($extLinks -join "`n")</div>"
}

# Pills de "outras tasks/repos do mesmo assunto" (task numerica igual ou
# cluster identico) - so' pra pagina de resumo (Build-SummaryHtml), por
# pedido explicito (nao entra no card da grade). Le $cardsByTask/
# $cardsByCluster (script scope, montados depois que $cards esta pronto).
function Get-RelatedTasksHtml([PSCustomObject]$card) {
    $siblings = @(Get-TaskSiblings $card | Where-Object { $_ -and $_.RepPath -ne $card.RepPath } | Sort-Object Repo)
    if ($siblings.Count -eq 0) { return '' }

    $items = $siblings | ForEach-Object {
        if ($_.ResumoDoc) {
            $href = Get-SummaryFileName $_
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
foreach ($d in $parsedDocs) {
    $f = $d.File
    $p = $d.Parsed
    if (-not $p -or -not $p.Meta['number']) { continue }
    $status = Clean-Field $(if ($p.Meta['status']) { $p.Meta['status'] } else { 'draft' })
    $task = Clean-Field $(if ($p.Meta['task']) { $p.Meta['task'] } else { 'general' })
    $all += [PSCustomObject]@{
        Task     = $task
        Repo     = Clean-Field $p.Meta['repo']
        Function = Clean-Field $p.Meta['function']
        TituloBusca = Clean-Field $p.Meta['titulo_busca']
        Type     = Clean-Field $p.Meta['type']
        Status   = $status
        Updated  = Clean-Field $p.Meta['updated']
        UpdatedTime = $f.LastWriteTime.ToString('HH:mm')
        Path     = $f.FullName
        Body     = $p.Body
        Related  = $p.Meta['related']
        Branch    = Clean-Field $p.Meta['branch']
        Cluster   = Clean-Field $p.Meta['cluster']
        PseudoTask = Clean-Field $p.Meta['pseudo_task']
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

$knownRepos = @($knownRepos | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' } |
    ForEach-Object { Get-RepoSortKey $_ } |
    Sort-Object Bucket, DomainRank, Domain, SubOrder, Name |
    ForEach-Object { $_.Name })
# "Biblioteca" nao mora em reposBasePath (e' a raiz do proprio repo da
# Biblioteca, pasta irma de reposBasePath) - por isso nunca aparecia nesta
# lista (que so' varre reposBasePath + repo: dos docs). Forcado primeiro na
# lista (nao passa por Get-RepoSortKey) pra abrir o Claude direto nela pelo
# seletor "Abrir Claude" - ver caso especial de path em __LIB_ROOT_PATH__.
$knownRepos = @('Biblioteca') + @($knownRepos | Where-Object { $_ -ne 'Biblioteca' })
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
        # pr_pending pode ter VARIAS URLs (task "migration espelho" - 1 PR
        # por ambiente, separadas por espaco no mesmo campo). Checar TODAS,
        # nao so' a primeira - senao a 1a mergear ja fecha a task inteira e
        # apaga o rastro das URLs restantes ainda abertas (bug real,
        # encontrado 2026-08-25).
        $urls = @([regex]::Matches($doc.PrPending, $prLinkPattern) | ForEach-Object { $_.Value })
        if ($urls.Count -eq 0) {
            Write-Host "dashboard: pr_pending com formato inesperado em $($doc.Path): $($doc.PrPending)" -ForegroundColor Yellow
            continue
        }
        $stillPending = New-Object System.Collections.Generic.List[string]
        $newlyMerged = New-Object System.Collections.Generic.List[string]
        $newlyRejected = New-Object System.Collections.Generic.List[string]
        $anyResolved = $false
        foreach ($url in $urls) {
            if ($url -notmatch 'github\.com/([^/]+)/([^/]+)/pull/(\d+)') { $stillPending.Add($url); continue }
            $ghRepo = "$($Matches[1])/$($Matches[2])"
            $prNumber = $Matches[3]
            try {
                $json = gh pr view $prNumber --repo $ghRepo --json state 2>$null | ConvertFrom-Json
            } catch { $json = $null }
            if (-not $json -or $json.state -eq 'OPEN') { $stillPending.Add($url); continue }
            $anyResolved = $true
            if ($json.state -eq 'MERGED') { $newlyMerged.Add($url) } else { $newlyRejected.Add($url) }
        }
        if (-not $anyResolved) { continue }

        $raw = [IO.File]::ReadAllText($doc.Path)
        $parsed = Parse-Frontmatter $raw
        if (-not $parsed) { continue }
        $meta = $parsed.Meta
        $body = Get-ContentBody $parsed.Body

        # Acumula com o que ja existia no campo (nao sobrescreve - uma
        # rodada anterior do sweep pode ja ter marcado outras URLs).
        if ($newlyMerged.Count -gt 0) {
            $prior = if ($doc.PrMerged) { $doc.PrMerged.Trim() + ' ' } else { '' }
            $meta['pr_merged'] = ($prior + ($newlyMerged -join ' ')).Trim()
            $doc.PrMerged = $meta['pr_merged']
        }
        if ($newlyRejected.Count -gt 0) {
            $prior = if ($doc.PrRejected) { $doc.PrRejected.Trim() + ' ' } else { '' }
            $meta['pr_rejected'] = ($prior + ($newlyRejected -join ' ')).Trim()
            $doc.PrRejected = $meta['pr_rejected']
        }

        $note = $null
        if ($stillPending.Count -eq 0) {
            $meta.Remove('pr_pending')
            $doc.PrPending = ''
            if ($newlyRejected.Count -eq 0) {
                # Todas as URLs mergearam, nenhuma rejeitada - so' ENTAO
                # fecha a task. Se sobrou alguma rejeitada junto das
                # mergeadas, e' estado misto - nao flipa status sozinho,
                # mesmo principio do PR unico fechado sem merge (quem
                # decide o que fazer e' o usuario).
                $meta['status'] = 'completed'
                $doc.Status = 'completed'
                $note = 'Mergeado em `develop`/`production` (deteccao automatica) - sem pendencia de codigo, so ajustes se vier retorno de QA.'
            }
        } else {
            $meta['pr_pending'] = ($stillPending -join ' ')
            $doc.PrPending = $meta['pr_pending']
        }

        if ($note -and $body -notmatch '(?:Mergeado em|PR fechado sem merge)') {
            if ($body -match '(?m)^# .*$') {
                $m = [regex]::Match($body, '(?m)^# .*$')
                $insertAt = $m.Index + $m.Length
                $body = $body.Substring(0, $insertAt) + "`n`n**Status:** $note" + $body.Substring($insertAt)
            }
        }

        [IO.File]::WriteAllText($doc.Path, (Serialize-Frontmatter $meta) + $body)
        Sync-DocumentFile $doc.Path | Out-Null

        $resolvedCount = $newlyMerged.Count + $newlyRejected.Count
        Write-Host "dashboard: $resolvedCount/$($urls.Count) PR(s) resolvido(s) ($($newlyMerged.Count) mergeado(s), $($newlyRejected.Count) rejeitado(s)) - $($doc.Path.Substring($root.Length + 1)) atualizado automaticamente."
    }
}

# Backfill INCREMENTAL (nao 1x por doc): link de PR encontrado no corpo
# (jeito antigo, so' texto solto) mas AINDA nao coberto por nenhum dos 3
# campos (pr_pending/pr_merged/pr_rejected) tem estado desconhecido pro
# pill colorido. Roda em QUALQUER sync-all.ps1, de qualquer task/sessao -
# nao so' verifica os PRs pendentes conhecidos (sweep acima), mas tambem
# descobre PR que foi mencionado em prosa e nunca ganhou campo nenhum
# (fix de review em PR separado, por exemplo). Guarda por LINK, nao por
# doc: um doc que ja tem `pr_merged` com 1 URL ainda entra aqui se o
# corpo mencionar uma 2a URL que esse campo nao cobre - a guarda antiga
# ("doc ja tem qualquer campo preenchido = nunca mais confere") deixava
# PR novo em doc antigo pendurado cinza pra sempre (bug real, encontrado
# manualmente 2026-08-25 em 4 PRs - #300/#394/#395/#176 - o motivo desta
# reescrita: "verificar de uma vez, sem precisar voltar depois").
$unknown = @($all | Where-Object {
    if ($_.Body -notmatch $prLinkPattern) { return $false }
    $knownUrls = "$($_.PrPending) $($_.PrMerged) $($_.PrRejected)"
    @([regex]::Matches($_.Body, $prLinkPattern) | ForEach-Object { $_.Value } | Where-Object { -not $knownUrls.Contains($_) }).Count -gt 0
})
if ($unknown.Count -gt 0) {
    $ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    foreach ($doc in $unknown) {
        if (-not $ghAvailable) { break }
        # So' os links que AINDA nao estao em nenhum dos 3 campos - nao
        # re-consulta `gh` pra link ja conhecido (mesma guarda barata de
        # rede de antes, so' que por link, nao por doc inteiro).
        $knownUrls = "$($doc.PrPending) $($doc.PrMerged) $($doc.PrRejected)"
        $links = @([regex]::Matches($doc.Body, $prLinkPattern) | ForEach-Object { $_.Value } | Select-Object -Unique | Where-Object { -not $knownUrls.Contains($_) })
        if ($links.Count -eq 0) { continue }
        $merged = New-Object System.Collections.Generic.List[string]
        $rejected = New-Object System.Collections.Generic.List[string]
        $stillPending = New-Object System.Collections.Generic.List[string]
        foreach ($link in $links) {
            if ($link -notmatch 'github\.com/([^/]+)/([^/]+)/pull/(\d+)') { continue }
            $ghRepo = "$($Matches[1])/$($Matches[2])"
            $prNumber = $Matches[3]
            try {
                $json = gh pr view $prNumber --repo $ghRepo --json state 2>$null | ConvertFrom-Json
            } catch { $json = $null }
            if (-not $json) { continue }
            if ($json.state -eq 'MERGED') { $merged.Add($link) }
            elseif ($json.state -eq 'CLOSED') { $rejected.Add($link) }
            else { $stillPending.Add($link) }
        }
        if ($merged.Count -eq 0 -and $rejected.Count -eq 0 -and $stillPending.Count -eq 0) { continue }

        $raw = [IO.File]::ReadAllText($doc.Path)
        $parsed = Parse-Frontmatter $raw
        if (-not $parsed) { continue }
        $meta = $parsed.Meta
        # Acumula com o que ja existia - nunca sobrescreve (doc que ja
        # tinha pr_merged com outra URL continua com as duas).
        if ($merged.Count -gt 0) {
            $prior = if ($doc.PrMerged) { $doc.PrMerged.Trim() + ' ' } else { '' }
            $meta['pr_merged'] = ($prior + ($merged -join ' ')).Trim(); $doc.PrMerged = $meta['pr_merged']
        }
        if ($rejected.Count -gt 0) {
            $prior = if ($doc.PrRejected) { $doc.PrRejected.Trim() + ' ' } else { '' }
            $meta['pr_rejected'] = ($prior + ($rejected -join ' ')).Trim(); $doc.PrRejected = $meta['pr_rejected']
        }
        if ($stillPending.Count -gt 0) {
            $prior = if ($doc.PrPending) { $doc.PrPending.Trim() + ' ' } else { '' }
            $meta['pr_pending'] = ($prior + ($stillPending -join ' ')).Trim(); $doc.PrPending = $meta['pr_pending']
        }
        [IO.File]::WriteAllText($doc.Path, (Serialize-Frontmatter $meta) + (Get-ContentBody $parsed.Body))
        Sync-DocumentFile $doc.Path | Out-Null
    }
    if ($ghAvailable) {
        Write-Host "dashboard: backfill de estado de PR - $($unknown.Count) doc(s) com link novo verificado(s)."
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
    $latestDoc = ($docs | Where-Object { $_.Updated } | Sort-Object Updated -Descending | Select-Object -First 1)
    $latest = $latestDoc.Updated
    $latestTime = $latestDoc.UpdatedTime
    # PR, Azure e o status por camada (Get-LayerStatusHtml) aparecem em
    # Ativas E Completas por igual - nenhum e' restrito a tasks ativas.
    $signals = Get-Signals $docs $rep.Task
    # cluster opcional (so faz diferenca pra task "general" - o card mostra
    # "Geral" por padrao, sem jeito de distinguir varios de cor no dashboard;
    # qualquer doc do grupo com `cluster:` no frontmatter vira o titulo do card
    # - e agora tambem a propria chave de agrupamento, ver Group-Object acima)
    $cardCluster = ($docs + $resumoDoc | Where-Object { $_ -and $_.Cluster } | Select-Object -First 1).Cluster
    # pseudo_task e' opcional mesmo em cluster "general" - so os que quiserem
    # um numero curto pra achar por busca (ver 01-regras-biblioteca.md).
    $cardPseudoTask = ($docs + $resumoDoc | Where-Object { $_ -and $_.PseudoTask } | Select-Object -First 1).PseudoTask
    # titulo_busca e' opcional (campo novo, docs antigos nao tem) - pega o
    # primeiro preenchido no grupo, mesma logica de cluster/pseudo_task acima.
    # Sem valor, o card cai pro fallback de Function (ver Build-Card).
    $cardTituloBusca = ($docs + $resumoDoc | Where-Object { $_ -and $_.TituloBusca } | Select-Object -First 1).TituloBusca
    $cards += [PSCustomObject]@{
        Task      = $rep.Task
        Repo      = $rep.Repo
        Function  = $rep.Function
        TituloBusca = $cardTituloBusca
        Cluster   = $cardCluster
        PseudoTask = $cardPseudoTask
        Active    = $isActive
        Updated   = $latest
        UpdatedTime = $latestTime
        Docs      = $docs
        Signals   = $signals
        RepPath   = $rep.Path
        ResumoDoc = $resumoDoc
        Branch    = if ($resumoDoc) { $resumoDoc.Branch } else { '' }
    }
}

# Related tasks (cross-repo): mesma task numerica, ou mesmo cluster exato
# (so' task "general"), aparecendo em outro card/repo. Usado na pagina de
# resumo (Get-RelatedTasksHtml) e no status por camada do card
# (Get-LayerStatusHtml, precisa vir antes de Build-Card ser chamado mais
# abaixo). As duas listas sao mutuamente exclusivas por construcao (Task
# numerica cai so' aqui, "general"+Cluster cai so' ali) - nunca precisa
# deduplicar um card que bateria nos dois.
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

# NOTA: card.Signals.PRs NAO e mais sobrescrito com a uniao dos irmaos
# aqui - cada card volta a expor so' os PRs do proprio repo (Get-ExtLinksHtml
# na grade). A uniao cross-repo agora e' calculada sob demanda: dentro de
# Get-LayerStatusHtml (sempre, painel de status por camada - compacto,
# faz sentido em qualquer card da task) e dentro de Get-ExtLinksHtml so'
# quando chamada com -AllSiblings (pagina de resumo, o "principal" que
# mostra todos os PRs da task inteira). Decisao 2026-08-25: card da grade
# poluia (lista de ~13 PRs identica nos 3 cards de uma task multi-repo,
# mesmo cada card sendo de 1 repo so') - resumo ja tinha Get-RelatedTasksHtml
# linkando pros outros repos da mesma task, virou o lugar natural pra
# mostrar a lista completa.

# Conversor leve pro corpo das secoes do resumo - nao e' um motor de
# markdown generico, so o suficiente pro que um agente escreve ali:
# paragrafos, bullets, **bold**, [texto](url http/https).
function Format-InlineMd([string]$s) {
    $c = Esc $s
    $c = $c -replace '\[([^\]]+)\]\((https?://[^)]+)\)', '<a href="$2" target="_blank">$1</a>'
    $c = $c -replace '\*\*([^*]+)\*\*', '<strong>$1</strong>'
    $c = $c -replace '`([^`]+)`', '<code>$1</code>'
    return $c
}

# Nao e' um motor de markdown generico, so o suficiente pro que um agente
# escreve ali: paragrafos, bullets, **bold**, [texto](url http/https).
# Junta linhas fisicas consecutivas (prosa hard-wrapped ~80 chars, convencao
# de todo doc da Biblioteca) numa unica <p> - bug real corrigido 2026-08-25:
# a versao anterior tratava CADA quebra de linha do markdown-fonte como um
# paragrafo novo (1 <p> por linha fisica, nao por paragrafo logico),
# fragmentando toda secao de resumo da Biblioteca inteira em dezenas de
# <p> de 1 linha cada. So' quebra paragrafo em linha em branco de verdade
# ou ao entrar/sair de uma lista.
function Convert-SectionHtml([string]$text) {
    $text = if ($text) { $text.Trim() } else { '' }
    # tira comentarios HTML (ex: dica de preenchimento deixada no template)
    # antes de qualquer coisa - senao vazam como texto escapado na pagina
    $text = [regex]::Replace($text, '(?s)<!--.*?-->', '').Trim()
    if (-not $text) { return '<p class="empty">(vazio)</p>' }
    $lines = $text -split "`r?`n"
    $htmlLines = New-Object System.Collections.Generic.List[string]
    $paraBuffer = New-Object System.Collections.Generic.List[string]
    $listItemBuffer = New-Object System.Collections.Generic.List[string]
    $inList = $false

    function Flush-Para {
        if ($paraBuffer.Count -gt 0) {
            $htmlLines.Add("<p>$(Format-InlineMd ($paraBuffer -join ' '))</p>")
            $paraBuffer.Clear()
        }
    }
    function Flush-ListItem {
        if ($listItemBuffer.Count -gt 0) {
            $htmlLines.Add("<li>$(Format-InlineMd ($listItemBuffer -join ' '))</li>")
            $listItemBuffer.Clear()
        }
    }

    foreach ($line in $lines) {
        $t = $line.Trim()
        if (-not $t) { Flush-ListItem; Flush-Para; continue }
        $isBullet = $t -match '^[-*]\s+(.*)'
        if ($isBullet) {
            Flush-Para
            Flush-ListItem
            if (-not $inList) { $htmlLines.Add('<ul>'); $inList = $true }
            $listItemBuffer.Add($Matches[1])
        } elseif ($inList -and $listItemBuffer.Count -gt 0) {
            # Continuacao do item de lista atual (linha indentada sem
            # marcador, mesma convencao de todo doc da Biblioteca - "- foo"
            # seguido de linhas com 2 espacos de indentacao, sem linha em
            # branco entre elas).
            $listItemBuffer.Add($t)
        } else {
            if ($inList) { Flush-ListItem; $htmlLines.Add('</ul>'); $inList = $false }
            $paraBuffer.Add($t)
        }
    }
    Flush-ListItem
    Flush-Para
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

# Dados de "Rodadas de QA" - le as secoes "## Ajustes QA - rodada N" que
# ja existem nos docs `testes/` do proprio card (mesmo repo, task-hub-qa
# ja grava uma por rodada) e devolve um objeto por rodada (numero, data,
# teaser, PRs mencionados so' NAQUELA secao, doc de origem). Nao cria doc
# novo nem campo novo - so' le o que ja existe. Consumido por
# Build-QaRoundCard pra virar card de verdade na grade principal (nao
# fica escondido so' na pagina de resumo).
# Acha o campo `- **Label:** texto` (bullet opcional) dentro de uma secao
# de rodada de QA - junta linhas de continuacao (mesma convencao de
# indentacao/wrap de todo doc da Biblioteca), para no proximo campo em
# negrito ou linha em branco. $null se o label nao existir na secao
# (rodada ainda no formato antigo, sem os 3 campos padronizados).
function Get-QaFieldValue([string]$sectionBody, [string]$label) {
    $lines = $sectionBody -split "`r?`n"
    $labelPattern = "^-?\s*\*\*$([regex]::Escape($label)):\*\*\s*(.*)$"
    # Fronteira = qualquer bullet novo (com ou sem label em negrito) ou
    # label solto sem bullet - continuacao de verdade nesta convencao
    # nunca comeca com "-" (e' sempre texto indentado simples). Sem
    # cobrir "^-\s" aqui, um bullet extra sem negrito logo depois do
    # campo (ex.: "- Detalhe completo: ver...") era engolido como se
    # fosse continuacao do campo anterior (bug real, 2026-08-25).
    $boundaryPattern = '^-\s|^\*\*'
    $collecting = $false
    $buffer = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($collecting) {
            if (-not $t -or $t -match $boundaryPattern) { break }
            $buffer.Add($t)
            continue
        }
        if ($t -match $labelPattern) {
            $collecting = $true
            $first = $Matches[1].Trim()
            if ($first) { $buffer.Add($first) }
        }
    }
    if ($buffer.Count -eq 0) { return $null }
    $joined = ($buffer -join ' ') -replace '\*\*([^*]+)\*\*', '$1' -replace '`([^`]+)`', '$1' -replace '\[([^\]]+)\]\(https?://[^)]+\)', '$1'
    return $joined.Trim()
}

# HTML de exibicao de UMA rodada de QA - cada campo (Reportado/Causa
# raiz/Corrigido) em linha propria com label em negrito, junto via <br>
# dentro do MESMO <p> (nao 3 <p> separados) - um bloco visual so, sem
# espacamento extra de paragrafo entre os campos. Cai pro teaser bruto
# (1o paragrafo, ja sem markdown) quando a rodada nao tem os campos
# padronizados ainda.
function Get-QaFieldsHtml([PSCustomObject]$round) {
    if ($round.Reportado) {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("<strong>Reportado:</strong> $(Esc $round.Reportado)")
        if ($round.CausaRaiz) { $lines.Add("<strong>Causa raiz:</strong> $(Esc $round.CausaRaiz)") }
        if ($round.Corrigido) { $lines.Add("<strong>Corrigido:</strong> $(Esc $round.Corrigido)") }
        return $lines -join '<br>'
    }
    return Esc $round.Teaser
}

# Mesmo conteudo de Get-QaFieldsHtml, mas texto puro (sem HTML) - pro
# indice de busca (data-search), nunca pra exibicao.
function Get-QaSearchText([PSCustomObject]$round) {
    if ($round.Reportado) {
        $parts = New-Object System.Collections.Generic.List[string]
        $parts.Add("Reportado: $($round.Reportado)")
        if ($round.CausaRaiz) { $parts.Add("Causa raiz: $($round.CausaRaiz)") }
        if ($round.Corrigido) { $parts.Add("Corrigido: $($round.Corrigido)") }
        return $parts -join ' '
    }
    return $round.Teaser
}

function Get-QaRounds([PSCustomObject]$card) {
    $testesDocs = @($card.Docs | Where-Object { $_.Type -eq 'testes' })
    if ($testesDocs.Count -eq 0) { return @() }

    $rounds = New-Object System.Collections.Generic.List[object]
    foreach ($doc in $testesDocs) {
        $parts = $doc.Body -split '(?m)(?=^## )'
        $roundIndex = 0
        foreach ($p in $parts) {
            $firstLine = ($p -split "`n")[0]
            if ($firstLine -notmatch 'Ajustes QA') { continue }
            $roundIndex++
            # Numero da rodada vem do proprio heading quando existe
            # ("rodada N") - so' cai pro contador posicional se a secao
            # nao foi numerada (task-hub-qa permite a 1a rodada sem
            # numero, ver SKILL.md).
            $roundNum = if ($firstLine -match 'rodada\s+(\d+)') { $Matches[1] } else { "$roundIndex" }
            $dateLabel = if ($firstLine -match '(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $doc.Updated }

            # Campos padronizados: Reportado/Causa raiz/Corrigido (formato
            # obrigatorio no task-hub-qa, ver SKILL.md) - mantidos
            # SEPARADOS aqui (nao junta numa string so') pra quem
            # renderiza o card (Get-QaFieldsHtml) poder formatar cada um
            # em linha propria com label em negrito - um paragrafo so'
            # com tudo junto (jeito anterior) ficava dificil de ler.
            # $teaser (1o paragrafo bruto) e' so' o fallback pra rodada
            # que ainda nao foi migrada pro formato novo (Reportado
            # ausente). Texto sempre COMPLETO, sem cortar aqui - o corte
            # visual (clamp + botao de expandir) e' so' CSS/JS no card.
            $reportado = Get-QaFieldValue $p 'Reportado'
            $causaRaiz = if ($reportado) { Get-QaFieldValue $p 'Causa raiz' } else { $null }
            $corrigido = if ($reportado) { Get-QaFieldValue $p 'Corrigido' } else { $null }
            $teaser = if (-not $reportado) {
                $bodyText = ($p -split "`n", 2)[1]
                $firstPara = if ($bodyText) { (($bodyText.Trim() -split "`r?`n`r?`n")[0] -replace '\s+', ' ').Trim() } else { '' }
                $firstPara -replace '\*\*([^*]+)\*\*', '$1' -replace '`([^`]+)`', '$1' -replace '\[([^\]]+)\]\(https?://[^)]+\)', '$1'
            } else { $null }

            # PRs so' dessa rodada (regex escopada ao texto da secao $p,
            # nao ao doc inteiro) - e' isso que faz o card da rodada
            # mostrar so' o que e' relevante pra ela, nao a lista inteira
            # do repo (mesmo motivo da mudanca de Get-ExtLinksHtml desta
            # sessao).
            $prs = New-Object System.Collections.Generic.List[string]
            foreach ($m in [regex]::Matches($p, 'https?://github\.com/\S*?/pull/\d+')) {
                if (-not $prs.Contains($m.Value)) { $prs.Add($m.Value) }
            }

            $rounds.Add([PSCustomObject]@{
                RoundNum  = $roundNum
                DateLabel = $dateLabel
                Reportado = $reportado
                CausaRaiz = $causaRaiz
                Corrigido = $corrigido
                Teaser    = $teaser
                PRs       = @($prs)
                TestesDoc = $doc
            })
        }
    }
    # .ToArray(), nao @($rounds) - nesta maquina, @() aplicado direto
    # (fora de pipeline) sobre List[object] lanca "Os tipos de argumento
    # nao correspondem" (ArgumentException), diferente de List[string]
    # (funciona) ou de uma lista passada por pipeline antes do @() (ver
    # padrao @($allDocs | Where-Object {...}) usado no resto do arquivo -
    # esse funciona pq o pipe ja converteu pra stream antes do @()).
    return $rounds.ToArray()
}

# Card de verdade na grade principal (Ativas/Completas, mesma secao do
# card "pai" do repo) representando UMA rodada de QA - nao entra no
# array $cards (evita mexer em contagem/sweep/favorito, que sao pensados
# pra card de repo, nao de rodada), so' e' renderizado logo depois do
# card do repo no HTML final (ver loop de $activeHtml/$doneHtml). Mesmo
# funcionamento do card normal (Build-Card): nasce fechado, mesmo botao
# de expandir/recolher (bug 2026-09-01: nascia com `expanded` fixo no
# HTML, revertia sozinho pro estado expandido a cada rebuild/reload
# mesmo se o usuario tivesse fechado - card normal e card de QA numa
# mesma linha da grade ficavam com alturas inconsistentes por causa
# disso). Botao de acao e' so' "Reabrir p/ QA" (mesmo
# comando do card do repo, task+repo - nao existe granularidade menor
# pra "retomar exatamente aquela rodada", a branch da rodada geralmente
# ja foi mergeada/deletada). Icone de resumo aponta pro MESMO resumo do
# card pai (nao existe resumo por rodada) - pedido explicito do usuario.
# Pill de PR (icone por camada + cor por estado real) pra UM link - usada
# por Build-QaRoundCard e Build-UnifiedQaRoundCard, mesma logica que
# Get-ExtLinksHtml ja tinha inline (nao mexida ali pra nao arriscar
# codigo ja validado - so' extraida aqui pros 2 pontos novos que
# precisavam da mesma coisa duas vezes).
function Get-PrPillHtml([string]$pr, $docs) {
    $num = if ($pr -match '(\d+)$') { $Matches[1] } else { '' }
    $stateClass = ''; $stateTitle = 'Abrir PR no GitHub'
    if (@($docs | Where-Object { $_.PrMerged -and $_.PrMerged.Contains($pr) }).Count -gt 0) {
        $stateClass = ' ext-github-merged'; $stateTitle = 'PR mergeado'
    } elseif (@($docs | Where-Object { $_.PrRejected -and $_.PrRejected.Contains($pr) }).Count -gt 0) {
        $stateClass = ' ext-github-rejected'; $stateTitle = 'PR fechado sem merge'
    } elseif (@($docs | Where-Object { $_.PrPending -and $_.PrPending.Contains($pr) }).Count -gt 0) {
        $stateClass = ' ext-github-open'; $stateTitle = 'PR aberto, aguardando merge'
    }
    $kind = Get-PrKindInfo $pr
    return "<a class=`"ext-link ext-github$stateClass`" href=`"$(Esc $pr)`" target=`"_blank`" title=`"$($kind.Title) - $stateTitle`">$($kind.Icon) PR #$num</a>"
}

# Uma caixa por modulo (mesmo estilo visual da caixa "Pendencias" do
# card ativo, `.position` - fundo escuro, borda, cantos arredondados),
# cada uma com os campos Reportado/Causa raiz/Corrigido daquele modulo
# (Get-QaFieldsHtml). So' mostra o rotulo do modulo (LayerLabel) quando
# tem mais de 1 - card solo (1 modulo) fica so' com a caixa, sem titulo
# (nao tem o que desambiguar).
function Get-QaFieldBoxesHtml($entries) {
    $entries = @($entries)
    $showLabel = $entries.Count -gt 1
    $boxes = $entries | ForEach-Object {
        $labelHtml = if ($showLabel) { "<div class=`"qa-field-box-label`">$(Esc $_.LayerLabel)</div>" } else { '' }
        "<div class=`"qa-field-box`">$labelHtml<p class=`"qa-field-text`">$(Get-QaFieldsHtml $_.Round)</p></div>"
    }
    return "<div class=`"qa-field-boxes`">$($boxes -join "`n")</div>"
}

function Build-QaRoundCard([PSCustomObject]$card, [PSCustomObject]$round) {
    $repoLayer = Get-RepoLayer $card.Repo
    $repoLayerLabel = if ($repoLayer) { $script:RepoLayerLabels[$repoLayer] } else { $null }
    $label = if ($repoLayerLabel) { "Task $($card.Task) $($script:EmDash) $repoLayerLabel $($script:EmDash) QA#$($round.RoundNum)" } else { "Task $($card.Task) $($script:EmDash) QA#$($round.RoundNum)" }

    $resumoBtnHtml = ''
    if ($card.ResumoDoc) {
        $summaryFile = Get-SummaryFileName $card
        $resumoBtnHtml = "<a class=`"icon-btn resumo-btn`" href=`"summaries/$summaryFile`" title=`"Ver resumo`" aria-label=`"Ver resumo`">$bookIcon</a>"
    }

    # Estado real (mergeado/aberto/rejeitado) do PR costuma estar gravado
    # so' no frontmatter do `resumo` (pr_merged), nao em task-planning/
    # testes - sem incluir o ResumoDoc aqui, o pill fica cinza mesmo com
    # o PR ja mergeado (bug real, 2026-08-25; mesmo padrao ja usado em
    # Get-ExtLinksHtml pro card normal, que sempre incluiu ResumoDoc).
    $stateDocs = @($card.Docs) + @(if ($card.ResumoDoc) { $card.ResumoDoc })
    $extLinks = @($round.PRs | ForEach-Object { Get-PrPillHtml $_ $stateDocs })
    $extLinksHtml = if ($extLinks.Count -gt 0) { "<div class=`"ext-links`">$($extLinks -join "`n")</div>" } else { '' }

    $qaCmds = @(Get-CardCommands $card | Where-Object { $_.Label -eq 'Reabrir p/ QA' })
    $btns = ($qaCmds | ForEach-Object { "<a class=`"$($_.Class)`" href=`"$(Esc $_.Uri)`" data-cmd=`"$(Esc $_.Cmd)`">$(Esc $_.Label)</a>" }) -join ''
    $btnsHtml = "<div class=`"btns`">$btns</div>"

    $updatedHtml = if ($round.DateLabel) { "<span class=`"updated`">Atualizado $(Esc $round.DateLabel)</span>" } else { '' }
    $repoLower = Esc(($card.Repo).ToLowerInvariant())
    $searchBlob = Esc(("$label $($card.Repo) $($card.TituloBusca) $(Get-QaSearchText $round)").ToLowerInvariant())
    $cardId = Esc("$($round.TestesDoc.Path)#qa$($round.RoundNum)")
    $fieldBoxesHtml = Get-QaFieldBoxesHtml @([PSCustomObject]@{ LayerLabel = $repoLayerLabel; Round = $round })
    # Mesmo tratamento do card normal: titulo_busca (quando existe) vira o
    # titulo do card, o rotulo antigo (Task NNN - Layer - QA#N) desce pra
    # subtitulo. Sem titulo_busca, comportamento igual a antes.
    $cardTitle = if ($card.TituloBusca) { $card.TituloBusca } else { $label }
    $funcHtml = if ($card.Function) { "<p class=`"func`">$(Esc $card.Function)</p>" } else { '' }
    $headHtml = Get-CardHeadHtml $cardTitle $resumoBtnHtml
    $subtitlesHtml = Get-CardSubtitlesHtml $label ([bool]$card.TituloBusca) $card.Repo
    $footHtml = Get-CardFootHtml $updatedHtml $btnsHtml $chevronIcon

    return @"
<div class="card qa-round-card" data-search="$searchBlob" data-repo="$repoLower" data-id="$cardId">
$headHtml
$subtitlesHtml
  $extLinksHtml
  $funcHtml
  $fieldBoxesHtml
$footHtml
</div>
"@
}

# Versao unificada de Build-QaRoundCard - quando a MESMA rodada (rodada N
# + mesma data no heading) existe em 2 ou 3 camadas da mesma task
# (backend/frontend/migrations, qualquer combinacao), vira UM card so'
# em vez de varios (pedido explicito do usuario, 2026-08-25: "unificar
# quando o qa foi feito junto" - estendido depois pra incluir migrations
# tambem, "os 3 tipos nao precisam estar separados se foi feitos
# juntos"). $entries e' um array de objetos { Card; Round; LayerLabel },
# 2 ou 3 itens, ja ordenados (ver Get-RoundEntrySortKey no ponto de
# chamada) - PRs e link de resumo somam todas as camadas; o botao de
# acao mostra um comando por camada (a reativacao ainda e' por repo, nao
# existe granularidade "todas juntas" no fluxo de git, ver task-hub-qa).
function Build-UnifiedQaRoundCard($entries) {
    $firstCard = $entries[0].Card
    $layerLine = ($entries | ForEach-Object { $_.LayerLabel }) -join ' + '
    $label = "Task $($firstCard.Task) $($script:EmDash) $layerLine $($script:EmDash) QA#$($entries[0].Round.RoundNum)"

    $resumoBtnHtml = ''
    if ($firstCard.ResumoDoc) {
        $summaryFile = Get-SummaryFileName $firstCard
        $resumoBtnHtml = "<a class=`"icon-btn resumo-btn`" href=`"summaries/$summaryFile`" title=`"Ver resumo`" aria-label=`"Ver resumo`">$bookIcon</a>"
    }

    # ResumoDoc incluido pelo mesmo motivo de Build-QaRoundCard - estado
    # real do PR costuma estar so' la, nao em task-planning/testes.
    $allDocs = @($entries | ForEach-Object { @($_.Card.Docs) + @(if ($_.Card.ResumoDoc) { $_.Card.ResumoDoc }) })
    $mergedPrs = New-Object System.Collections.Generic.List[string]
    foreach ($e in $entries) { foreach ($pr in $e.Round.PRs) { if (-not $mergedPrs.Contains($pr)) { $mergedPrs.Add($pr) } } }
    $extLinks = @($mergedPrs | ForEach-Object { Get-PrPillHtml $_ $allDocs })
    $extLinksHtml = if ($extLinks.Count -gt 0) { "<div class=`"ext-links`">$($extLinks -join "`n")</div>" } else { '' }

    # Cada camada vira sua propria caixa (Get-QaFieldBoxesHtml, mesmo
    # estilo da caixa "Pendencias") - $teaserPlain (texto puro, sem HTML)
    # so' pro indice de busca.
    $teaserPlain = (@($entries | ForEach-Object { Get-QaSearchText $_.Round }) | Where-Object { $_ }) -join ' | '
    $fieldBoxesHtml = Get-QaFieldBoxesHtml $entries

    $btns = ''
    foreach ($e in $entries) {
        foreach ($c in (Get-CardCommands $e.Card | Where-Object { $_.Label -eq 'Reabrir p/ QA' })) {
            $btns += "<a class=`"$($c.Class)`" href=`"$(Esc $c.Uri)`" data-cmd=`"$(Esc $c.Cmd)`">Reabrir p/ QA ($($e.LayerLabel.ToLowerInvariant()))</a>"
        }
    }
    $btnsHtml = "<div class=`"btns`">$btns</div>"

    $updatedHtml = if ($entries[0].Round.DateLabel) { "<span class=`"updated`">Atualizado $(Esc $entries[0].Round.DateLabel)</span>" } else { '' }
    $repoLine = ($entries | ForEach-Object { $_.Card.Repo }) -join ' + '
    $repoLower = Esc(($repoLine).ToLowerInvariant())
    $searchBlob = Esc(("$label $repoLine $($firstCard.TituloBusca) $teaserPlain").ToLowerInvariant())
    $cardId = Esc((($entries | ForEach-Object { "$($_.Round.TestesDoc.Path)#qa$($_.Round.RoundNum)" }) -join '+'))
    # Mesmo tratamento do card normal/Build-QaRoundCard: titulo_busca (do
    # card representante) vira o titulo, o rotulo antigo desce pra subtitulo.
    $cardTitle = if ($firstCard.TituloBusca) { $firstCard.TituloBusca } else { $label }
    $funcHtml = if ($firstCard.Function) { "<p class=`"func`">$(Esc $firstCard.Function)</p>" } else { '' }
    $headHtml = Get-CardHeadHtml $cardTitle $resumoBtnHtml
    $subtitlesHtml = Get-CardSubtitlesHtml $label ([bool]$firstCard.TituloBusca) $repoLine
    $footHtml = Get-CardFootHtml $updatedHtml $btnsHtml $chevronIcon

    return @"
<div class="card qa-round-card" data-search="$searchBlob" data-repo="$repoLower" data-id="$cardId">
$headHtml
$subtitlesHtml
  $extLinksHtml
  $funcHtml
  $fieldBoxesHtml
$footHtml
</div>
"@
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
    # pseudo_task aparece entre parenteses no titulo pra dar um numero curto
    # e buscavel a task "general" (senao so acha por nome do cluster, ver
    # 01-regras-biblioteca.md) - mesma ideia de "Task N", mas sem ser uma
    # task numerica de verdade.
    # Rotulo curto de camada (Backend/Frontend/Migrations, ver Get-RepoLayer)
    # no lugar do texto de Function - o titulo precisa dar pra entender o
    # card sem ler mais nada (mesmo card.Function e' longo demais pra
    # caber sem cortar/quebrar em varias linhas). $card.Function continua
    # sendo mostrado por extenso logo abaixo (<p class="func">).
    $repoLayer = Get-RepoLayer $card.Repo
    $repoLayerLabel = if ($repoLayer) { $script:RepoLayerLabels[$repoLayer] } else { $null }
    $taskLabel = if ($card.Cluster) { if ($card.PseudoTask) { "$($card.Cluster) (#$($card.PseudoTask))" } else { $card.Cluster } } elseif ($card.Task -eq 'general') { if ($card.PseudoTask) { "Geral (#$($card.PseudoTask))" } else { 'Geral' } } elseif ($repoLayerLabel) { "Task $($card.Task) $($script:EmDash) $repoLayerLabel" } else { "Task $($card.Task)" }
    $extLinksHtml = Get-ExtLinksHtml $card -AllSiblings

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
$sharedCss
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
$launchButtonJs
document.querySelectorAll('.copy-btn[data-cmd]').forEach(function (btn) {
  btn.addEventListener('click', function () { biblLaunch(btn, btn.getAttribute('data-cmd')); });
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

    # Hora fica num <span> proprio (.updated-time) - CSS decide quando mostra:
    # sempre visivel em Ativas (#grid-active), so' com o card expandido em
    # Completas (.card.expanded), pra nao poluir a grade compacta por padrao.
    $timeHtml = if ($card.UpdatedTime) { " <span class=`"updated-time`">$(Esc $card.UpdatedTime)</span>" } else { '' }
    $updatedHtml = if ($card.Updated) { "<span class=`"updated`">Atualizado $(Esc $card.Updated)$timeHtml</span>" } else { '' }

    $posHtml = Get-LayerStatusHtml $card

    # Links externos (Azure DevOps + PR do GitHub) - aparecem em Ativas E
    # Completas, sempre visiveis mesmo com o card fechado - e' o dado mais
    # importante de bater o olho.
    $extLinksHtml = Get-ExtLinksHtml $card

    $starHtml = if ($card.Active) { "<button class=`"star-btn`" title=`"Marcar como favorita`" aria-label=`"Marcar como favorita`" aria-pressed=`"false`">$starIcon</button>" } else { '' }

    $resumoBtnHtml = ''
    if ($card.ResumoDoc) {
        $summaryFile = Get-SummaryFileName $card
        $resumoBtnHtml = "<a class=`"icon-btn resumo-btn`" href=`"summaries/$summaryFile`" title=`"Ver resumo`" aria-label=`"Ver resumo`">$bookIcon</a>"
    }

    $btns = (Get-CardCommands $card | ForEach-Object { "<a class=`"$($_.Class)`" href=`"$(Esc $_.Uri)`" data-cmd=`"$(Esc $_.Cmd)`">$(Esc $_.Label)</a>" }) -join ''
    $btnsHtml = "<div class=`"btns`">$btns</div>"

    # pseudo_task aparece entre parenteses no titulo pra dar um numero curto
    # e buscavel a task "general" (senao so acha por nome do cluster, ver
    # 01-regras-biblioteca.md) - mesma ideia de "Task N", mas sem ser uma
    # task numerica de verdade.
    # Rotulo curto de camada (Backend/Frontend/Migrations, ver Get-RepoLayer)
    # no lugar do texto de Function - o titulo precisa dar pra entender o
    # card sem ler mais nada (mesmo card.Function e' longo demais pra
    # caber sem cortar/quebrar em varias linhas). $card.Function continua
    # sendo mostrado por extenso logo abaixo (<p class="func">).
    $repoLayer = Get-RepoLayer $card.Repo
    $repoLayerLabel = if ($repoLayer) { $script:RepoLayerLabels[$repoLayer] } else { $null }
    $taskLabel = if ($card.Cluster) { if ($card.PseudoTask) { "$($card.Cluster) (#$($card.PseudoTask))" } else { $card.Cluster } } elseif ($card.Task -eq 'general') { if ($card.PseudoTask) { "Geral (#$($card.PseudoTask))" } else { 'Geral' } } elseif ($repoLayerLabel) { "Task $($card.Task) $($script:EmDash) $repoLayerLabel" } else { "Task $($card.Task)" }
    $searchBlob = Esc(("$taskLabel $($card.Repo) $($card.Function) $($card.TituloBusca)").ToLowerInvariant())
    $repoLower = Esc(($card.Repo).ToLowerInvariant())
    $cardId = Esc($card.RepPath)
    # titulo_busca e' opcional (campo novo) - vira o titulo do card quando
    # preenchido (achar por assunto); sem ele, o titulo continua sendo o
    # antigo $taskLabel, que nesse caso NAO se repete como subtitulo (senao
    # duplicaria a mesma linha 2x). $taskLabel sempre aparece como
    # subtitulo quando titulo_busca existe - "titulo atual vira subtitulo".
    $cardTitle = if ($card.TituloBusca) { $card.TituloBusca } else { $taskLabel }
    $headHtml = Get-CardHeadHtml $cardTitle "$resumoBtnHtml`n      $starHtml"
    $subtitlesHtml = Get-CardSubtitlesHtml $taskLabel ([bool]$card.TituloBusca) $card.Repo
    $footHtml = Get-CardFootHtml $updatedHtml $btnsHtml $chevronIcon

    return @"
<div class="card" data-search="$searchBlob" data-repo="$repoLower" data-id="$cardId">
$headHtml
$subtitlesHtml
  $extLinksHtml
  <p class="func">$(Esc $card.Function)</p>
  <div class="chips">
$chipsHtml
  </div>
  $posHtml
$footHtml
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
$sharedCss
  :root { --current: #d97b3f; --current-glow: rgba(217, 123, 63, 0.28); }
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
  <h2>Status por camada (caixa "Pendencias" do card ativo)</h2>
  <div class="swatch-row"><div class="layer-row layer-done"><span class="layer-dot"></span><span class="layer-label">Backend</span><span class="layer-state">feito</span></div><code>.layer-done</code></div>
  <div class="swatch-row"><div class="layer-row layer-pending"><span class="layer-dot"></span><span class="layer-label">Frontend</span><span class="layer-state">pendente</span></div><code>.layer-pending</code></div>
  <div class="swatch-row"><div class="layer-row layer-na"><span class="layer-dot"></span><span class="layer-label">Migrations</span><span class="layer-state">nao necessario</span></div><code>.layer-na</code></div>
</section>

<section>
  <h2>Botoes de acao</h2>
  <div class="swatch-row"><button class="copy-btn">Retomar task</button><code>.copy-btn</code></div>
  <div class="swatch-row"><button class="copy-btn qa-btn">Reabrir p/ QA</button><code>.copy-btn.qa-btn</code></div>
</section>

<section>
  <h2>Icones</h2>
  <div class="swatch-row"><span class="icon-sample">$starIcon Estrela (normal)</span><code>.star-icon</code></div>
  <div class="swatch-row"><span class="icon-sample current">$starIcon Estrela (favorita/atual)</span><code>.card-current .star-icon</code></div>
  <div class="swatch-row"><span class="icon-sample">$bookIcon Ver resumo</span><code>.resumo-btn</code></div>
  <div class="swatch-row"><span class="icon-sample">$chevronIcon Expandir/recolher card</span><code>.expand-btn</code></div>
  <div class="swatch-row"><span class="icon-sample">$backendIcon PR de backend (repo termina em -backend)</span><code>Get-PrKindInfo</code></div>
  <div class="swatch-row"><span class="icon-sample">$frontendIcon PR de frontend (repo mfe-/mobile-)</span><code>Get-PrKindInfo</code></div>
  <div class="swatch-row"><span class="icon-sample">$migrationIcon PR de migration (gbm-app-migrations)</span><code>Get-PrKindInfo</code></div>
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
$sharedCss
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
$sharedCss
  :root {
    --azure-bg: #1f2a33; --azure-text: #7fa8c2; --azure-border: #3d5566;
    --claude-bg: #2e1f16; --claude-border: #a85a35; --claude-bright: #d97757;
  }
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
      <label class="nt-optional" for="nt-azure">Link do work item (opcional)</label>
      <input type="text" id="nt-azure" placeholder="https://dev.azure.com/.../_workitems/edit/12345" autocomplete="off">
      <label class="nt-optional" for="nt-parent">Link do item pai (opcional)</label>
      <input type="text" id="nt-parent" placeholder="https://dev.azure.com/.../_workitems/edit/12000" autocomplete="off">
      <p class="hint">Pode deixar em branco - o Claude acha o parent sozinho via MCP do Azure DevOps, se estiver conectado.</p>
    </section>

    <section class="nt-section">
      <h2>Repositorio</h2>
      <label class="nt-optional" for="nt-repo">Repositorio (opcional)</label>
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
$launchButtonJs
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

// "Biblioteca" nao mora em reposBasePath (e' a raiz do proprio repo da
// Biblioteca) - mesmo caso especial do seletor "Abrir Claude" do header
// (ver __LIB_ROOT_PATH__ no $foot). Repo em branco cai solto na pasta que
// contem todos os repos, igual o header - nao bloqueia mais o lancamento.
function getTargetPath(repo) {
  if (repo.toLowerCase() === 'biblioteca') { return '$hubRootJs'; }
  return repo ? ('$reposBasePathJs\\' + repo) : '$reposBasePathJs';
}

function updatePathHint() {
  var repo = repoEl.value.trim();
  pathHint.textContent = 'Vai abrir em: ' + getTargetPath(repo);
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
  var repo = repoEl.value.trim();
  var desc = descEl.value.trim();
  if (!desc) {
    e.preventDefault();
    warn.textContent = 'Preencha ao menos a descricao.';
    return;
  }
  warn.textContent = '';
  var promptOneLine = promptEl.value.trim().replace(/\r\n|\r|\n/g, '\\n').replace(/"/g, "'");
  var escapedPhrase = promptOneLine.replace(/'/g, "''");
  var cmd = 'powershell -NoProfile -Command "cd \'' + getTargetPath(repo) + '\'; claude \'' + escapedPhrase + '\'"';

  rawOutput.value = cmd;
  biblLaunch(launch, cmd);
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
        $taskLabel = if ($c.Task -match '^\d+$') { "#$($c.Task)" } elseif ($c.Cluster) { if ($c.PseudoTask) { "$($c.Cluster) (#$($c.PseudoTask))" } else { $c.Cluster } } else { $c.Task }
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
$sharedCss
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

# Pre-computa, por task numerica, quais rodadas de QA viram card unico
# (rodada N + mesma data no heading) entre QUALQUER combinacao das 3
# camadas (backend/frontend/migrations - 2 ou 3 juntas, nao so' o par
# backend+frontend) e quais ficam solo (so' 1 camada tocou aquela
# rodada). Guarda o resultado por RepPath do card "dono" do bloco (pra
# uniao, sempre a camada que vem primeiro na ordem fixa abaixo) - o loop
# de render mais adiante so' consulta esse mapa, nao recalcula nada.
# Processar por task (nao por card) e' o que evita duplicar: sem isso,
# cada camada tentaria renderizar a MESMA rodada unificada por conta
# propria.
$layerOrder = @{ backend = 0; frontend = 1; migrations = 2 }
$roundBlocksByRepPath = @{}
$processedQaTasks = New-Object System.Collections.Generic.HashSet[string]
foreach ($c in $cards) {
    if ($c.Task -notmatch '^\d+$') { continue }
    if (-not $processedQaTasks.Add($c.Task)) { continue }

    $siblings = Get-TaskSiblings $c
    $layerCards = @{}
    foreach ($layer in $layerOrder.Keys) {
        $found = @($siblings | Where-Object { (Get-RepoLayer $_.Repo) -eq $layer } | Select-Object -First 1)
        if ($found.Count -gt 0) { $layerCards[$layer] = $found[0] }
    }
    if ($layerCards.Count -eq 0) { continue }

    # Agrupa toda rodada de toda camada presente por "numero|data" - cada
    # grupo com 2+ camadas vira 1 card unificado, grupo com 1 so' fica
    # como card solo (Build-QaRoundCard, comportamento de sempre).
    $roundGroups = @{}
    foreach ($layer in $layerCards.Keys) {
        $layerCard = $layerCards[$layer]
        $layerLabel = $script:RepoLayerLabels[$layer]
        foreach ($r in (Get-QaRounds $layerCard)) {
            $key = "$($r.RoundNum)|$($r.DateLabel)"
            if (-not $roundGroups.ContainsKey($key)) { $roundGroups[$key] = New-Object System.Collections.Generic.List[object] }
            $roundGroups[$key].Add([PSCustomObject]@{ Card = $layerCard; Round = $r; LayerLabel = $layerLabel; LayerOrder = $layerOrder[$layer] })
        }
    }

    foreach ($key in $roundGroups.Keys) {
        $entries = @($roundGroups[$key] | Sort-Object LayerOrder)
        $ownerRepPath = $entries[0].Card.RepPath
        if (-not $roundBlocksByRepPath.ContainsKey($ownerRepPath)) { $roundBlocksByRepPath[$ownerRepPath] = New-Object System.Collections.Generic.List[string] }
        if ($entries.Count -ge 2) {
            $roundBlocksByRepPath[$ownerRepPath].Add((Build-UnifiedQaRoundCard $entries))
        } else {
            $roundBlocksByRepPath[$ownerRepPath].Add((Build-QaRoundCard $entries[0].Card $entries[0].Round))
        }
    }
}
# Cards `general`/cluster (sem task numerica) nunca entram na uniao -
# sempre solo, mesmo fluxo de sempre.
foreach ($c in $cards) {
    if ($c.Task -match '^\d+$') { continue }
    foreach ($r in (Get-QaRounds $c)) {
        if (-not $roundBlocksByRepPath.ContainsKey($c.RepPath)) { $roundBlocksByRepPath[$c.RepPath] = New-Object System.Collections.Generic.List[string] }
        $roundBlocksByRepPath[$c.RepPath].Add((Build-QaRoundCard $c $r))
    }
}

# Cada card de repo e' seguido, na mesma secao (Ativas/Completas), pelos
# blocos de rodada de QA pre-computados acima - ficam adjacentes ao card
# "pai" no HTML final, mas NAO entram no array $cards (evita afetar
# contagem/sweep/favorito, pensados pra card de repo).
function Build-CardWithQaRounds([PSCustomObject]$card) {
    $blocks = New-Object System.Collections.Generic.List[string]
    $blocks.Add((Build-Card $card))
    if ($roundBlocksByRepPath.ContainsKey($card.RepPath)) {
        foreach ($b in $roundBlocksByRepPath[$card.RepPath]) { $blocks.Add($b) }
    }
    return $blocks -join "`n"
}
$activeHtml = ($activeCards | ForEach-Object { Build-CardWithQaRounds $_ }) -join "`n"
$doneHtml = ($doneCards | ForEach-Object { Build-CardWithQaRounds $_ }) -join "`n"
if (-not $activeHtml) { $activeHtml = '<p class="empty">Nenhuma task ativa.</p>' }
if (-not $doneHtml) { $doneHtml = '<p class="empty">Nenhuma task completa.</p>' }

$today = Get-Date -Format 'dd/MM/yyyy HH:mm'

# "Lombada de estante" - faixa horizontal no header, 1 segmento por tipo
# de doc, largura proporcional a quantos docs existem de cada tipo hoje
# na Biblioteca. Preenche o espaco vazio do header com dado real (nao so
# decoracao) - mesmas 5 cores ja usadas nos chips dos cards, pra ficar
# consistente com o resto do app.
$spineTypes = @(
    @{ Type = 'task-code'; Label = 'Task code'; Color = '#d9b568' }
    @{ Type = 'task-planning'; Label = 'Task planning'; Color = '#7cbfc4' }
    @{ Type = 'testes'; Label = 'Testes'; Color = '#86b894' }
    @{ Type = 'handover-tecnico'; Label = 'Handover tecnico'; Color = '#c184a0' }
    @{ Type = 'rules'; Label = 'Regras'; Color = '#a89484' }
)
$spineTotal = 0
$spineData = foreach ($t in $spineTypes) {
    $typeKey = $t.Type
    $count = @($all | Where-Object { $_.Type -eq $typeKey }).Count
    $spineTotal += $count
    [PSCustomObject]@{ Type = $typeKey; Label = $t.Label; Color = $t.Color; Count = $count }
}
$spineHtml = ''
if ($spineTotal -gt 0) {
    $visibleTypes = @($spineData | Where-Object { $_.Count -gt 0 })
    $segs = ($visibleTypes | ForEach-Object {
        $pct = [math]::Round(($_.Count / $spineTotal) * 100, 2)
        "<span class=`"spine-seg`" data-type=`"$(Esc $_.Type)`" style=`"width:$pct%;background:$($_.Color)`"></span>"
    }) -join ''
    # 1 caixa so' com todos os tipos (nao 1 tooltip por segmento - obrigava
    # passar o mouse em cada um pra ver tudo). No mouseover de um segmento
    # especifico, JS destaca so' a linha correspondente dentro da caixa.
    $legendRows = ($visibleTypes | ForEach-Object {
        "<div class=`"legend-row`" data-type=`"$(Esc $_.Type)`"><i style=`"background:$($_.Color)`"></i>$(Esc $_.Label): $($_.Count)</div>"
    }) -join ''
    $spineHtml = "<div class=`"lib-spine`">$segs<div class=`"spine-legend`">$legendRows</div></div>"
}

$head = @'
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Dashboard</title>
<style>
$sharedCss
  :root {
    --input-bg: #262931;
    --current: #d97b3f;
    --current-glow: rgba(217, 123, 63, 0.28);
    /* Teste: verde (do logo/livro, #22c55e) em vez do terracota - os 2
       botoes do header ficam verde+dourado, as 2 cores da propria marca
       da Biblioteca, junto no mesmo lugar. So' esta pagina usa esses
       valores (cada pagina gerada tem seu proprio :root extra alem do
       bloco de CSS compartilhado) - nao muda .claude-btn em
       nova-task.html/outras paginas. */
    --claude-bg: #16281c;
    --claude-border: #2f6b45;
    --claude-bright: #4ade80;
  }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0;
    padding: 24px 32px 64px;
  }
  /* 2 linhas, nao 1 - a 1a tentativa (divisor de 1px entre 3 grupos numa
     linha so) nao criava fronteira visual perceptivel nenhuma numa fileira
     ja cheia de botao/pill colorido. Separar por LINHA (identidade+nav de
     referencia acima, barra de ferramentas de busca/acao abaixo) resolve
     sem depender de um traco fino que ninguem nota. Ordem dos itens dentro
     de cada linha continua a mesma de antes. */
  .top-header { display: flex; flex-direction: column; gap: 14px; border-bottom: 2px solid var(--gold-border); padding-bottom: 16px; margin-bottom: 22px; }
  .header-row { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
  /* Linha da barra de ferramentas (busca/repo/acoes) usa gap menor que a
     linha de identidade+nav - era o valor original do .quick-open (6px),
     padronizado agora pros 4 itens da linha, nao só entre repo/Abrir Claude. */
  /* Experimento: barra de ferramentas alinhada a direita, embaixo do
     grupo de nav (que tambem fica a direita na linha 1), em vez de
     embaixo do bloco de identidade a esquerda. Sem flex-grow no
     search-wrap aqui - com grow:1 ele ocupava o espaco livre e o
     justify-content:flex-end nao tinha sobra nenhuma pra empurrar. */
  .header-row-tools { gap: 6px; justify-content: flex-end; }
  /* Lombada de estante - preenche o espaco vazio entre identidade e nav
     com dado real (composicao da Biblioteca por tipo), nao decoracao.
     Sem overflow:hidden no container - clipava a legenda que precisa
     "escapar" pra cima. Arredondado so nas pontas (1o/ultimo segmento),
     nao via overflow do container. Precisa de position:relative pra ser
     a ancora da legenda (que e' 1 filho a mais, nao 1 por segmento). */
  .lib-spine { display: flex; align-items: center; height: 8px; flex: 1 1 auto; margin: 0 24px; background: var(--card-border); border-radius: 999px; position: relative; }
  .spine-seg { height: 100%; }
  .spine-seg:first-child { border-radius: 999px 0 0 999px; }
  .spine-seg:last-child { border-radius: 0 999px 999px 0; }
  .spine-seg:only-child { border-radius: 999px; }
  .spine-seg:not(:last-child) { border-right: 1px solid var(--bg); }
  /* 1 legenda so' com todos os tipos (nao 1 tooltip por segmento - tinha
     que passar o mouse em cada um pra ver tudo). Aparece embaixo da
     lombada, acoplada a posicao X do cursor (JS atualiza `left` no
     mousemove, ver <script> no fim da pagina) - o :hover so' cuida da
     visibilidade (opacity), a posicao horizontal e' sempre a do cursor.
     Setinha no topo (::before/::after) aponta pra cima, pro cursor. */
  .spine-legend {
    position: absolute; top: 130%; left: 0; transform: translateX(-50%);
    background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 8px;
    padding: 8px 10px; font-size: 0.76rem; white-space: nowrap;
    opacity: 0; pointer-events: none; transition: opacity .12s; z-index: 20;
    display: flex; flex-direction: column; gap: 4px;
  }
  .spine-legend::before, .spine-legend::after {
    content: ''; position: absolute; left: 50%; transform: translateX(-50%);
    border-left: 6px solid transparent; border-right: 6px solid transparent;
  }
  .spine-legend::before { top: -6px; border-bottom: 6px solid var(--card-border); }
  .spine-legend::after { top: -5px; border-bottom: 5px solid var(--card-bg); }
  .lib-spine:hover .spine-legend { opacity: 1; }
  .legend-row { display: flex; align-items: center; gap: 6px; color: var(--text-dim); border-radius: 4px; padding: 2px 5px; }
  .legend-row i { width: 7px; height: 7px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
  .legend-row.active { color: var(--text); background: var(--card-border); font-weight: 600; }
  .header-row-tools .search-wrap { flex: 0 0 320px; }
  .brand-icon { flex-shrink: 0; }
  .brand-icon svg { width: 32px; height: 32px; }
  .util-nav { display: flex; align-items: center; gap: 8px; margin-left: auto; }
  .palette-link {
    color: var(--text-dim); text-decoration: none; font-size: 0.78rem;
    border: 1px solid var(--card-border); border-radius: 999px; padding: 5px 12px;
    display: inline-flex; align-items: center; gap: 5px;
  }
  .palette-link:hover { color: var(--gold-bright); border-color: var(--gold-border); }
  h1 { font-size: 1.6rem; margin: 0; color: #fff; letter-spacing: 0.02em; }
  .sub { color: var(--gold); font-size: 0.85rem; margin: 2px 0 0; }
  /* Stats (ativas/completas) na propria linha, separadas do "Atualizado
     em" - mesma logica de "1 grupo por linha" usada no resto do header.
     --gold (nao --gold-bright) - a versao "bright" ficava vibrante demais
     pra texto corrido, --gold e' o mesmo dourado mais discreto. Os dots
     (verde/cinza) continuam com cor propria, sao sinal de status real. */
  .stats-row { display: flex; align-items: center; gap: 14px; margin: 6px 0 0; font-size: 0.85rem; color: var(--gold); }
  .stat { display: inline-flex; align-items: center; gap: 5px; }
  .dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; display: inline-block; }
  .dot-neutral { background: var(--text-faint); }
  .search-wrap { position: relative; margin: 0; max-width: 480px; flex: 1 1 260px; }
  .search-icon { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--text-faint); pointer-events: none; display: flex; }
  #search {
    width: 100%; max-width: 480px; background: var(--input-bg); border: 1px solid var(--card-border);
    color: var(--text); border-radius: 8px; padding: 10px 30px 10px 34px; font-size: 0.9rem;
  }
  #search:focus-visible { border-color: var(--gold); }
  #search::placeholder { color: var(--text-faint); }
  .clear-btn {
    position: absolute; right: 8px; top: 50%; transform: translateY(-50%);
    width: 18px; height: 18px; border: none; background: none; color: var(--text-faint);
    cursor: pointer; font-size: 1rem; line-height: 1; padding: 0; display: none;
    align-items: center; justify-content: center; border-radius: 50%;
  }
  .clear-btn:hover { color: var(--gold-bright); }
  .clear-btn.visible { display: flex; }
  h2 {
    font-size: 1rem; color: var(--gold-bright); text-transform: uppercase; letter-spacing: 0.08em;
    border-bottom: 1px solid var(--gold-border); padding-bottom: 8px; margin-top: 32px;
  }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 14px; margin-top: 16px; }
  .card {
    background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 10px;
    padding: 12px 14px; display: flex; flex-direction: column; gap: 0;
  }
  /* Ritmo vertical explicito (sem gap generico no .card) - cada elemento
     controla o proprio espaco ABAIXO dele, pra nao empilhar gap+margem
     como acontecia antes (raiz do "espaco morto" entre titulo/subtitulos/
     chip Azure). Ver .card-head/.subtitles/.ext-links/.func/.chips/
     .position/.qa-field-boxes mais abaixo. */
  .card-current {
    border-color: var(--current); box-shadow: 0 0 0 1px var(--current), 0 0 16px -2px var(--current-glow);
  }
  .qa-round-card { border-left: 3px solid #3d5c44; }
  /* Uma caixa por modulo dentro do card de rodada de QA - mesmo visual
     da caixa "Pendencias" (.position: fundo escuro, borda, cantos
     arredondados), so' que uma por modulo em vez de uma lista de
     camadas. Rotulo (.qa-field-box-label) so' aparece quando 2+ caixas
     (Get-QaFieldBoxesHtml decide isso, nao o CSS). */
  .qa-field-boxes { flex-direction: column; gap: 8px; }
  .qa-field-box {
    background: #202225; border: 1px solid #303338; border-radius: 8px; padding: 8px 10px;
  }
  .qa-field-box-label {
    font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.04em;
    color: var(--gold-bright); font-weight: 600; margin: 0 0 4px;
  }
  .qa-field-text { font-size: 0.85rem; color: #c2c4c9; line-height: 1.42; margin: 0; }
  .qa-field-text strong { color: var(--gold-bright); font-weight: 600; }
  .badge-current {
    align-self: flex-start; background: var(--current); color: #2b1d0a; font-weight: 700;
    font-size: 0.66rem; letter-spacing: 0.06em; text-transform: uppercase;
    padding: 3px 8px; border-radius: 999px;
  }
  .card-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 10px; margin-bottom: 8px; }
  .card-head-left { display: flex; align-items: center; min-width: 0; flex: 1 1 auto; }
  .card-head-right { display: flex; align-items: center; gap: 4px; flex: 0 0 auto; }
  .card-title {
    font-weight: 600; font-size: 0.92rem; color: var(--text); width: 100%; line-height: 1.25;
    display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
  }
  .card.expanded .card-title { -webkit-line-clamp: unset; line-clamp: unset; overflow: visible; }
  .task-id {
    font-weight: 500; color: var(--text-dim); font-size: 0.8rem; display: inline-block; max-width: 100%;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap; line-height: 1.2;
  }
  /* Wrapper dos 2 subtitulos (task-id + repo) - zero espaco entre eles,
     um unico bloco compacto entre o titulo e o chip Azure/func. */
  .subtitles { display: flex; flex-direction: column; gap: 0; margin-bottom: 4px; }
  .subtitle-line { margin: 0; }
  .repo {
    font-family: ui-monospace, "SF Mono", monospace; font-size: 0.78rem; color: var(--gold);
    display: inline-block; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; line-height: 1.2;
  }
  .repo-line { margin: 0 0 8px; }
  .subtitles .repo-line { margin: 0; }
  .func {
    font-size: 0.88rem; color: #c2c4c9; margin: 0 0 8px; line-height: 1.35;
  }
  .ext-links { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
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
    flex-shrink: 0; margin-left: auto;
    border: 1px solid var(--card-border); border-radius: 6px; width: 22px; height: 22px;
    justify-content: center; transition: transform .15s, color .15s, border-color .15s;
  }
  .expand-btn:hover { color: var(--gold-bright); border-color: var(--gold-border); }
  .card.expanded .expand-btn { transform: rotate(180deg); }
  .chips, .position, .btns, .qa-field-boxes { display: none; }
  .card.expanded .chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
  .card.expanded .position { display: flex; margin-bottom: 8px; }
  .card.expanded .btns { display: flex; gap: 6px; flex-wrap: wrap; }
  .card.expanded .qa-field-boxes { display: flex; margin-bottom: 8px; }
  /* Hora do "Atualizado": sempre visivel em Ativas, so' ao expandir em
     Completas - card fechado mostra so a data, sem poluir a grade. */
  .updated-time { display: none; }
  #grid-active .updated-time, .card.expanded .updated-time { display: inline; }
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
  /* Status por camada (migrations/backend/frontend/testes), 1 por linha
     (empilhado, nao lado a lado) - verde/vermelho/amarelo tipo semaforo,
     cor propria (nao reaproveita --gold/--current) pra ficar universal. */
  .layer-row { display: flex; align-items: center; gap: 7px; font-size: 0.78rem; }
  .layer-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
  .layer-label { color: #c2c4c9; min-width: 100px; }
  .layer-state { color: var(--text-faint); font-size: 0.72rem; }
  .layer-done .layer-dot { background: #22c55e; }
  .layer-done .layer-state { color: #4ade80; }
  .layer-pending .layer-dot { background: #ef4444; }
  .layer-pending .layer-state { color: #f0908a; }
  .layer-na .layer-dot { background: #eab308; }
  .layer-na .layer-state { color: #d9c069; }
  .card-foot { display: flex; justify-content: space-between; align-items: center; margin-top: auto; padding-top: 6px; gap: 8px; flex-wrap: wrap; }
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
  /* color proprio (nao so' border) - sem isso o texto ficava na cor
     neutra do .copy-btn generico, e o botao lia mais "apagado" que o
     Abrir Claude ao lado (esse usa --claude-bright no texto) mesmo os
     dois tendo o mesmo peso de acao no header. */
  .primary-link { border-color: var(--gold); color: var(--gold-bright); font-weight: 600; }
  .claude-btn {
    background: var(--claude-bg); color: var(--claude-bright); border: 1px solid var(--claude-border);
    font-weight: 600; cursor: pointer; display: inline-block; text-decoration: none;
  }
  .claude-btn:hover { filter: brightness(1.2); }
  .quick-open { display: flex; align-items: center; gap: 6px; margin: 0; flex: 0 0 auto; }
  .quick-repo-wrap { position: relative; display: flex; }
  .quick-open input {
    background: var(--input-bg); border: 1px solid var(--card-border); color: var(--text);
    border-radius: 8px; padding: 10px 30px 10px 14px; font-size: 0.9rem; width: 170px;
  }
  .quick-open input:focus-visible { border-color: var(--gold); }
  .empty { color: var(--text-faint); font-size: 0.85rem; }
</style>
</head>
<body>
'@
# CUIDADO: .Replace('$sharedCss', ...) e' substituicao de texto literal, cega
# a contexto - se algum comentario dentro do heredoc $head/$foot (que sao
# single-quoted, nao interpolam) escrever a string literal "$sharedCss" ou
# "$faviconLink", ela tambem sera trocada (bug real, encontrado e corrigido
# nesta mesma rodada). Nunca escrever esses 2 nomes literalmente em
# comentario dentro de $head/$foot - descrever por extenso em vez disso.
$head = $head.Replace('$faviconLink', $faviconLink).Replace('$sharedCss', $sharedCss)

$foot = @'
<script>
__LAUNCH_BUTTON_JS__
document.querySelectorAll('.copy-btn[data-cmd]').forEach(function (btn) {
  btn.addEventListener('click', function () { biblLaunch(btn, btn.getAttribute('data-cmd')); });
});

// Acesso rapido "Abrir Claude no repo" - o comando depende do repo escolhido
// no navegador, entao e' montado aqui no clique (nao em build-time como os
// outros botoes) - mesmo biblLaunch dos outros, so' calculado tarde.
// __REPOS_BASE_PATH__/__LIB_ROOT_PATH__ sao substituidos por texto literal
// depois (mesma tecnica do $faviconLink no $head - $foot e' single-quoted,
// sem interpolar).
var quickBtn = document.getElementById('quick-open-btn');
if (quickBtn) {
  quickBtn.addEventListener('click', function () {
    var repo = document.getElementById('quick-repo').value.trim();
    // Sem repo escolhido -> abre solto na pasta que contem todos os repos
    // (reposBasePath), em vez de nao fazer nada.
    // "Biblioteca" e' caso especial - a raiz do proprio repo, nao uma pasta
    // dentro de reposBasePath (ver __LIB_ROOT_PATH__).
    var targetPath = repo.toLowerCase() === 'biblioteca' ? '__LIB_ROOT_PATH__' :
      (repo ? ('__REPOS_BASE_PATH__\\' + repo) : '__REPOS_BASE_PATH__');
    var cmd = 'powershell -NoProfile -Command "cd \'' + targetPath + '\'; claude"';
    // -run: aperta Enter sozinho - so abre uma janela solta do Claude, sem
    // disparar nenhuma skill nem gravar nada, diferente dos outros botoes.
    biblLaunch(quickBtn, cmd);
  });
}

// Expandir um card expande a linha visual inteira do grid junto (mesmo
// offsetTop no momento do clique - recalculado a cada clique, nunca
// cacheado, porque a linha muda com resize/filtro/busca). So' cards
// visiveis (offsetParent !== null) entram no grupo.
document.querySelectorAll('.expand-btn').forEach(function (btn) {
  btn.addEventListener('click', function () {
    var card = btn.closest('.card');
    var grid = card.closest('.grid');
    var expand = !card.classList.contains('expanded');
    var rowTop = card.offsetTop;
    var rowCards = grid ? Array.prototype.filter.call(grid.querySelectorAll('.card'), function (c) {
      return c.offsetParent !== null && c.offsetTop === rowTop;
    }) : [card];
    rowCards.forEach(function (c) {
      c.classList.toggle('expanded', expand);
      var b = c.querySelector('.expand-btn');
      if (b) {
        b.title = expand ? 'Recolher' : 'Expandir';
        b.setAttribute('aria-label', b.title);
      }
    });
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
// Botao "x" de limpar - so' aparece com texto digitado, some vazio.
// Limpa o campo, foca de volta e reaplica o filtro na hora (o listener
// 'input' normal do campo nao dispara em mudanca via JS).
function wireClearBtn(input, btn) {
  if (!input || !btn) { return; }
  function sync() { btn.classList.toggle('visible', input.value.length > 0); }
  input.addEventListener('input', sync);
  btn.addEventListener('click', function () {
    input.value = '';
    sync();
    applyFilters();
    input.focus();
  });
  sync();
}
wireClearBtn(search, document.getElementById('search-clear'));
wireClearBtn(quickRepoFilter, document.getElementById('quick-repo-clear'));

if (search) { search.addEventListener('input', applyFilters); }
if (quickRepoFilter) { quickRepoFilter.addEventListener('input', applyFilters); }

// Lombada de estante (header) - 1 legenda so' com todos os tipos; no
// mouseover de um segmento especifico, destaca so' a linha correspondente
// (por data-type) em vez de forcar passar o mouse em cada segmento. A
// caixa acompanha a posicao X do cursor (nao fica fixa num canto).
document.querySelectorAll('.spine-seg').forEach(function (seg) {
  var row = document.querySelector('.legend-row[data-type="' + seg.getAttribute('data-type') + '"]');
  if (!row) { return; }
  seg.addEventListener('mouseenter', function () { row.classList.add('active'); });
  seg.addEventListener('mouseleave', function () { row.classList.remove('active'); });
});
var libSpine = document.querySelector('.lib-spine');
var spineLegend = document.querySelector('.spine-legend');
if (libSpine && spineLegend) {
  libSpine.addEventListener('mousemove', function (e) {
    var rect = libSpine.getBoundingClientRect();
    spineLegend.style.left = (e.clientX - rect.left) + 'px';
  });
}

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
$libRootJs = $root.Replace('\', '\\')
$foot = $foot.Replace('__REPOS_BASE_PATH__', $reposBasePathJs).Replace('__LIB_ROOT_PATH__', $libRootJs).Replace('__LAUNCH_BUTTON_JS__', $launchButtonJs)
if ($bibConfig.reposBasePath) {
    $quickOpenHtml = @"
<div class="quick-open">
  <div class="quick-repo-wrap">
    <input type="text" id="quick-repo" list="quick-repos" placeholder="Repositorio..." autocomplete="off">
    <button type="button" class="clear-btn" id="quick-repo-clear" aria-label="Limpar repositorio" title="Limpar">&times;</button>
  </div>
  <datalist id="quick-repos">
$knownReposOptionsHtml
  </datalist>
  <a class="claude-btn" id="quick-open-btn" href="#">Abrir Claude</a>
</div>
"@
}

$body = @"
<header class="top-header">
  <div class="header-row">
    <span class="brand-icon">$brandIconGreen</span>
    <div>
      <h1>Biblioteca</h1>
      <p class="sub">Atualizado em $today</p>
      <p class="stats-row">
        <span class="stat"><span class="dot"></span>$($activeCards.Count) ativas</span>
        <span class="stat"><span class="dot dot-neutral"></span>$($doneCards.Count) completas</span>
      </p>
    </div>
    $spineHtml
    <nav class="util-nav">
      <a class="palette-link" href="historico-nova-task.md" target="_blank">$archiveIcon Historico</a>
      <a class="palette-link" href="paleta.html" target="_blank">$paletteIcon Paleta de cores</a>
      <a class="palette-link" href="archive.html" target="_blank">$archiveIcon Arquivo</a>
      <a class="palette-link" href="pendencias.html" target="_blank">$pendIcon Pendencias$(if ($pendenciasCount) { " ($pendenciasCount)" })</a>
      <a class="palette-link" href="mock/dashboard-mock.html" target="_blank">$mockIcon Mock</a>
    </nav>
  </div>
  <div class="header-row header-row-tools">
    <div class="search-wrap">
      <span class="search-icon">$searchIcon</span>
      <input id="search" type="text" placeholder="Buscar por task, repo ou descricao..." autocomplete="off">
      <button type="button" class="clear-btn" id="search-clear" aria-label="Limpar busca" title="Limpar">&times;</button>
    </div>
    $quickOpenHtml
    <a class="copy-btn primary-link" href="nova-task.html" target="_blank">+ Nova Task</a>
  </div>
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
# Export publico e' flat: raiz/dashboard-visual/ E' o hub - sem esse guard
# o redirect sobrescreve o proprio dashboard recem-gerado.
$legacyDir = Join-Path $root 'dashboard-visual'
if ([IO.Path]::GetFullPath($legacyDir).TrimEnd('\') -ne [IO.Path]::GetFullPath($hubRoot).TrimEnd('\')) {
    New-Item -ItemType Directory -Force -Path $legacyDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $legacyDir 'dashboard.html'), $legacyRedirect)
}

[System.IO.File]::WriteAllText((Join-Path $hubRoot 'paleta.html'), (Build-PaletteHtml))
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'archive.html'), (Build-ArchiveHtml))
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'pendencias.html'), (Build-PendenciasHtml))
# nova-task.html e' hand-tuned (CSS/layout ajustado interativamente com o
# usuario) - so' cria se ainda nao existir (bootstrap), nunca sobrescreve
# depois (mesmo padrao do historico-nova-task.md abaixo). Sobrescrever
# sempre ja apagou ajustes de layout reais numa sessao anterior.
$novaTaskPath = Join-Path $hubRoot 'nova-task.html'
if (-not (Test-Path $novaTaskPath)) {
    [System.IO.File]::WriteAllText($novaTaskPath, (Build-NovaTaskHtml))
}

# Historico de criacao de tasks (o proprio agente anexa as entradas,
# seguindo a instrucao embutida no prompt de nova-task.html - sem skill
# dedicada) - so' garante que o arquivo existe pra o link "Historico" do
# header nao dar 404 antes da 1a task criada pelo formulario; nunca
# sobrescreve conteudo.
$historicoPath = Join-Path $hubRoot 'historico-nova-task.md'
if (-not (Test-Path $historicoPath)) {
    [System.IO.File]::WriteAllText($historicoPath, "# Historico de criacao de tasks`n`nEntradas anexadas pelo agente (instrucao embutida no prompt de nova-task.html) a cada task criada - append-only, nao editar a mao.`n")
}

# Paginas de resumo standalone - uma por task+repo que tem doc `resumo`
$summariesDir = Join-Path $hubRoot 'summaries'
New-Item -ItemType Directory -Force -Path $summariesDir | Out-Null
$summaryCount = 0
foreach ($card in $cards) {
    if (-not $card.ResumoDoc) { continue }
    $summaryFile = Get-SummaryFileName $card
    $summaryHtml = Build-SummaryHtml $card
    [System.IO.File]::WriteAllText((Join-Path $summariesDir $summaryFile), $summaryHtml)
    $summaryCount++
}

Write-Output "dashboard: $($cards.Count) tasks ($($activeCards.Count) ativas, $($doneCards.Count) completas), $summaryCount resumos -> $outPath"
