# Funcoes puras de build-dashboard.ps1, extraidas pra dar pra testar sem
# rodar o script inteiro (que gera arquivo e escreve disco de ponta a
# ponta). Nenhuma delas tem side-effect - so' recebem dado e devolvem
# valor/string. Ver test-dashboard-lib.ps1.

function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

# $task (opcional, task numerica do card) filtra links de PR que sao
# CITACAO a outra task, nao PR proprio dela - convencao comum nos docs
# da Biblioteca e' citar trabalho relacionado tipo "...achado ao
# investigar o equivalente X (task 104691, PR [...](...))". Sem esse
# filtro, o PR citado vazava pro card da task ERRADA (bug real,
# 2026-08-25: PR #288 da task 104691 aparecendo no card da task 104689
# so' por ter sido citado la como referencia). So' exclui quando a
# citacao "task NNNNN" aparece pouco antes do link E o numero diverge
# do card - citacao de PR da MESMA task (ex.: migration espelho, PR de
# outro repo mas mesma task) nunca tem esse prefixo "task NNNNN" antes
# (a convencao so' cita "task N" pra apontar OUTRA task), entao continua
# passando normalmente.
function Get-Signals($docs, $task) {
    $prLinks = New-Object System.Collections.Generic.List[string]
    foreach ($d in $docs) {
        foreach ($m in [regex]::Matches($d.Body, 'https?://github\.com/\S*?/pull/\d+')) {
            if ($task -and $task -match '^\d+$') {
                $precedingStart = [Math]::Max(0, $m.Index - 80)
                $preceding = $d.Body.Substring($precedingStart, $m.Index - $precedingStart)
                if ($preceding -match 'task\s+(\d+)' -and $Matches[1] -ne $task) { continue }
            }
            if (-not $prLinks.Contains($m.Value)) { $prLinks.Add($m.Value) }
        }
    }
    return [PSCustomObject]@{
        PRs = @($prLinks | Select-Object -First 10)
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
function Get-LaunchUri([string]$cmdText, [switch]$AutoRun) {
    $scheme = if ($AutoRun) { 'biblioteca-cmd-run:' } else { 'biblioteca-cmd:' }
    return $scheme + [Uri]::EscapeDataString($cmdText)
}

function Get-CardCommands([PSCustomObject]$card) {
    # Envolvido em "powershell -NoProfile -Command" pra funcionar colado tanto
    # no cmd.exe (onde ; nao separa comandos, quebrava o cd) quanto no
    # PowerShell - independe do shell padrao do usuario.
    # $hubRoot vem do escopo de quem dot-source este arquivo (build-dashboard.ps1
    # ja define antes de chamar; test-dashboard-lib.ps1 define um valor de teste).
    $base = "cd '$hubRoot'"
    # Task/Repo vem do frontmatter (so' Trim() em Clean-Field, sem validar
    # caractere) e vai dentro de uma string PowerShell de aspas simples -
    # um apostrofo sem escapar fecharia a string cedo e quebraria o comando
    # gerado. Escapa dobrando a aspas simples, mesmo padrao ja usado em
    # nova-task.html pro mesmo problema.
    $safeTask = "$($card.Task)".Replace("'", "''")
    $safeRepo = "$($card.Repo)".Replace("'", "''")
    $cmds = New-Object System.Collections.Generic.List[PSCustomObject]
    if ($card.Active) {
        $cmd = "powershell -NoProfile -Command `"$base; claude 'retomar task $safeTask no repo $safeRepo'`""
        $cmds.Add([PSCustomObject]@{ Label = 'Retomar task'; Class = 'copy-btn'; Cmd = $cmd; Uri = (Get-LaunchUri $cmd -AutoRun) })
    }
    $qaCmd = "powershell -NoProfile -Command `"$base; claude 'ajustar qa task $safeTask no repo $safeRepo'`""
    $cmds.Add([PSCustomObject]@{ Label = 'Reabrir p/ QA'; Class = 'copy-btn qa-btn'; Cmd = $qaCmd; Uri = (Get-LaunchUri $qaCmd -AutoRun) })
    return $cmds
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

# Pedacos de HTML compartilhados pelas 3 funcoes que montam um card
# (Build-Card, Build-QaRoundCard, Build-UnifiedQaRoundCard, em
# build-dashboard.ps1) - cabecalho/subtitulos/rodape sao IDENTICOS nos 3
# tipos de card, so' o conteudo do meio muda (chips normais vs campos de
# QA). Antes cada funcao escrevia esse HTML na mao, em 3 copias
# independentes - foi assim que o titulo_busca ficou faltando no card de
# QA (2026-09-10) ate o usuario notar, e o botao de expandir precisou de
# find-and-replace em 3 lugares pra mudar de posicao. Qualquer ajuste
# visual de cabecalho/subtitulos/rodape entra AQUI, nunca direto dentro
# de Build-Card/Build-QaRoundCard/Build-UnifiedQaRoundCard - se um dia
# precisar de mais um tipo de card, ele tambem chama essas 3 funcoes, nao
# escreve o HTML de novo.

function Get-CardHeadHtml([string]$title, [string]$rightIconsHtml) {
    return @"
  <div class="card-head">
    <div class="card-head-left">
      <span class="card-title" title="$(Esc $title)">$(Esc $title)</span>
    </div>
    <div class="card-head-right">
      $rightIconsHtml
    </div>
  </div>
"@
}

# $label = o "titulo antigo" (Task NNN - Layer, ou o label de QA#N) -
# $showLabel controla se ele aparece como subtitulo (so' quando o card
# tem titulo_busca preenchido, senao seria a mesma linha repetida 2x).
function Get-CardSubtitlesHtml([string]$label, [bool]$showLabel, [string]$repo) {
    $labelHtml = if ($showLabel) { "<div class=`"subtitle-line`"><span class=`"task-id`" title=`"$(Esc $label)`">$(Esc $label)</span></div>" } else { '' }
    return @"
  <div class="subtitles">
    $labelHtml
    <div class="repo-line"><span class="repo" title="$(Esc $repo)">$(Esc $repo)</span></div>
  </div>
"@
}

function Get-CardFootHtml([string]$updatedHtml, [string]$btnsHtml, [string]$chevronIcon) {
    return @"
  <div class="card-foot">
    $updatedHtml
    $btnsHtml
    <button class="expand-btn" type="button" title="Expandir" aria-label="Expandir">$chevronIcon</button>
  </div>
"@
}
