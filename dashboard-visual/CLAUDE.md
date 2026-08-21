# dashboard-visual

Camada visual da própria **Biblioteca** — não é um projeto
separado, é a pasta `dashboard-visual/` dentro do repo da Biblioteca. Não tem
código de produto, só existe pra navegar/retomar tasks sem abrir cada repo
de projeto manualmente. O `dashboard.html` gerado aqui costuma ser salvo direto
nos favoritos do navegador — abrir por lá, sem precisar passar por
`claude` toda vez só pra ver o estado das tasks.

## Estrutura

- **Agrupamento e título do card para `task: general`**: por padrão agrupa
  por path/`related` (frágil — duas tasks "Geral" no mesmo repo só ficam
  separadas pelo path, sem id real) e mostra "Geral" no título. Campo opcional
  `cluster:` no frontmatter do doc (ver `controle-documentacao`) resolve as
  duas coisas: vira a **chave de agrupamento** (`cluster+repo`, mesma lógica
  de `task+repo` das tasks numéricas — mesmo assunto em repos diferentes
  continua card separado por repo) e o **título do card** no lugar de "Geral".
  `scripts/lint-clusters.ps1` (roda dentro do `sync-all.ps1`) avisa se dois
  docs do mesmo grupo tiverem `cluster` divergente, ou se um doc `general`
  novo não tiver `cluster` nenhum (aviso, não bloqueia — cai em "Geral" até
  alguém rotular).
- `dashboard.html` — visão principal, fora do chat. Header com o nome
  "Biblioteca" (ícone de livro + linha dourada separando do resto), tema
  cinza escuro de fundo + paleta quente ("estante de livros": dourado/
  latão como accent geral, e cada tipo de documento com uma cor própria —
  task-code dourado, task-planning terracota, testes verde, handover-
  tecnico vinho, rules marrom; destaque de favorito em âmbar alaranjado,
  distinto do dourado geral). Todas as tasks (Ativas/Completas), campo de
  busca no topo (filtra por task/repo/descrição, client-side).
- **Cards compactos por padrão, expandem ao clicar.** Estado fechado
  mostra só cabeçalho (task/repo/estrela/ícone de resumo), a descrição em
  1 linha, os links externos (Azure/PR — sempre visíveis, é o dado mais
  importante de bater o olho) e a data de atualização. Um botãozinho
  (seta) no canto inferior direito do card expande — só aí aparecem os
  chips de documentos, o bloco de Pendências e os botões de ação (Copiar
  comando/Ajustes QA). Não persiste entre reloads (sempre
  abre fechado). Vale pras duas seções, mesmo `Build-Card`.
- **Todo card** (ativo ou completo, expandido) mostra o botão **Ajustes
  QA** — cenário: task já concluída/mergeada, retorno do QA chegou depois;
  o botão copia um comando que reativa o repositório (branch) sem reabrir
  o status da task na Biblioteca (ver `task-hub-qa` abaixo). Tasks ativas
  ganham mais um botão — **Retomar task**. Não existe botão de
  "marcar concluída": o sweep de `pr_pending` (checa estado real do PR via
  `gh`) fecha a task sozinho quando o PR mergeia — um botão manual ficaria
  redundante. Comandos vêm de `Get-CardCommands` em `build-dashboard.ps1`,
  reaproveitada também pela página de resumo, pra não duplicar as strings
  de comando em dois lugares. Gerado por `scripts/build-dashboard.ps1` e
  mantido atualizado a cada sessão pelo hook.
- **Estrela de favorito** (canto superior direito de cada task ativa) é
  100% client-side (`localStorage` do navegador, sem comando/skill) —
  clique tem efeito imediato na página: badge "TRABALHANDO ATUALMENTE",
  borda destacada, card sobe pro topo de Ativas. Casa por um id único por
  card (o path do doc representativo) — nunca por task+repo, porque duas
  tasks "Geral" podem compartilhar os dois e isso já causou bug de marcar
  duas ao mesmo tempo. Sem lógica de git envolvida, é só preferência de
  UI. Se a task marcada sai de "Ativas" (foi concluída), a marcação some
  sozinha na próxima carga da página.
- `.claude/hooks/session-start.ps1` — hook `SessionStart` (escopado a esta
  pasta via `.claude/settings.json`) que mostra a listagem de texto
  (referência/fallback) e regenera `dashboard.html`.
- `.claude/skills/task-hub-resume/` — resolve a task selecionada (comando
  do dashboard, número digitado, ou menu) e executa a rotina de retomada
  (checkpoint via `git stash`, resolução de branch, releitura dos docs).
  Nome técnico da skill ficou `task-hub-resume` mesmo após a mudança de
  pasta — o path por baixo (`cd "...\dashboard-visual"`) é sempre resolvido
  dinamicamente, nunca hardcoded.
- `.claude/skills/task-hub-complete/` — resolve o comando "concluir task
  X no repo Y" e delega pro gate de fechamento que já existe em
  `controle-documentacao` (last check REQ+parent, cobertura backend+
  frontend, `status: completed`, `sync-all.ps1`) — não reimplementa
  checklist próprio e não marca concluído se algo do gate falhar.
- **Ícone de livro no canto superior direito do card** (ao lado da
  estrela de favorito, nas Ativas; sozinho, no lugar da estrela, nas
  Completas) abre o resumo (`summaries/{arquivo}.html`, nova aba) quando
  existe um doc `resumo` (tipo da Biblioteca, ver `controle-documentacao`)
  pra aquela task+repo — vale pras duas seções. A página usa um layout em
  2 colunas (coluna principal: Status atual + O que foi implementado;
  coluna lateral: REQs seguidas + Testes + Documentos relacionados) pra
  caber numa tela sem scroll na maioria dos casos, mesma paleta quente do
  dashboard. Logo abaixo do título, uma caixa sem nome (`actions-box`,
  mesmo estilo visual das outras seções) reúne as pills de links externos
  (Azure + PR, coloridas por estado — mesma função compartilhada
  `Get-ExtLinksHtml` do dashboard, não mais isoladas ao lado do título) e
  os botões de ação (Retomar task quando ativa, Ajustes QA sempre). Uma
  seção **Testes** só
  aparece se houver algum doc `testes` com `status: completed` pra essa
  task+repo — link direto pro arquivo, sem detalhe de resultado, só "foi
  feito". "O que foi implementado" é escrito com nomes concretos (campos/
  endpoints/telas), não descrição genérica — o critério é dar pra entender
  o que foi feito sem caçar informação. Gerada por
  `scripts/build-dashboard.ps1` junto com o dashboard — o doc `resumo` em
  si **não é editado à mão**, é mantido automaticamente pelas skills
  (`task-hub-resume` garante que existe e mantém "Status atual"/"O que
  falta" frescos; `task-hub-complete` finaliza "O que foi implementado"/
  "REQs seguidas"; `task-hub-qa` toca "Status atual" ao reativar uma task
  pra ajustes de QA; `controle-documentacao` também dá um toque nele em
  qualquer atualização de doc da task, não só nesses momentos).
- `.claude/skills/task-hub-qa/` — resolve o comando "ajustar qa task X no
  repo Y" (botão **Ajustes QA**, em qualquer card expandido ou na página
  de resumo). Reaproveita os passos 1-5 da rotina de retomada do
  `task-hub-resume` (path, checkpoint, branch — convenção normal
  `<tipo>/<taskId>[-slug]`, quase sempre recriada do zero a partir do
  branch base do projeto já que a branch original foi mergeada e deletada —
  restaurar stash, reler docs), mas **não muda `status`** dos docs (task continua
  `completed`, continua em "Completas") — só registra uma nota "Ajustes
  QA" no doc `testes/` dessa task+repo e toca o `resumo`.
- **Branch visível na página de resumo** — campo opcional `branch:` no
  frontmatter do doc `resumo` (ver `controle-documentacao`), gravado por
  `task-hub-resume`/`task-hub-qa` depois de resolver/criar a branch via
  `git` (nunca inventado por quem lê). Aparece no `head-row` da página de
  resumo, ao lado do repo — só lá, não no card compacto do dashboard
  (decisão explícita: manter o card enxuto).
- **Lançamento automático via protocolo `biblioteca-cmd:`** — cada botão
  de ação (`Retomar task`, `Reabrir p/ QA`, e os novos "Nova Task"/"Abrir
  Claude") é um `<a href="biblioteca-cmd:<comando url-encoded>">` além de
  copiar pro clipboard (comportamento antigo, mantido como fallback). Um
  dois protocolos customizados registrados uma vez por máquina via
  `scripts/register-protocol.ps1` (edição de registro em `HKCU`, nunca
  automática — o usuário roda esse script manualmente quando quiser
  habilitar), ambos entregues pro mesmo `scripts/launch-command.vbs`:
  `biblioteca-cmd:` abre um `cmd` novo e **digita o comando sem apertar
  Enter** (usuário revisa e confirma manualmente) — hoje só usado por
  **Ajustes QA**, ação mais sensível (reabre task já concluída/mergeada).
  `biblioteca-cmd-run:` digita **e aperta Enter sozinho** — usado por
  **Retomar task**, "+ Nova Task" e o botão "Abrir Claude" (header): as
  duas primeiras já têm confirmação embutida no próprio fluxo (a skill
  `task-hub-resume` relê os docs antes de agir; o prompt do Nova Task
  pede confirmação objetiva do work item antes de gravar qualquer coisa),
  então a trava extra de "revisar no terminal antes de apertar Enter"
  virou fricção redundante — decisão do usuário, 2026-08-21. "Abrir
  Claude" nunca teve skill nem grava nada, sempre foi auto-Enter. Sem o
  protocolo registrado, o link simplesmente não faz nada além do
  clipboard de sempre — degrada bem.
- `nova-task.html` — botão **+ Nova Task** do
  header abre essa página numa aba nova (não pergunta nada por chat de
  saída): formulário com link do Azure, link do parent (opcional), repo
  **(também opcional)** (`<datalist>` com os repos já conhecidos + pastas
  reais de `reposBasePath`) e a demanda em texto livre. Ao gerar o
  comando, ele **abre o Claude direto na pasta do repositório escolhido**
  — ou na pasta geral de repos (`reposBasePath`), sem repo escolhido; o
  prompt embutido instrui o Claude a descobrir o repo certo depois de ler
  o work item via MCP e se mover pra lá antes de gravar qualquer doc
  (não mais dentro da própria Biblioteca) com um prompt único e auto-suficiente —
  dump completo (Azure/parent/repo/descrição) + instruções embutidas no
  próprio texto: buscar REQ/parent via MCP `azure-devops` (se conectado) e
  confirmar antes de gravar qualquer doc, mover-se pra pasta certa se essa
  não for o repo esperado, seguir o fluxo global já existente
  (`gbm-triagem` → `criar-task-code` → `plano-acao`, do `CLAUDE.md` do
  usuário — dispara sozinho, sem gatilho especial daqui), e por fim anexar
  uma entrada em `historico-nova-task.md`. **Não existe skill dedicada**
  pra esse fluxo (havia uma, `task-hub-new`, retirada) — o prompt é
  autossuficiente porque abre no repo certo e usa o mesmo gate global que
  já dispara pra qualquer demanda digitada nesse repo. Visual em 3 seções
  (cartão, mesmo estilo de `.resumo-section`): "Origem" (accent azul de
  `.ext-azure`, ícone `$linkIcon` reaproveitado — mesma cor/ícone que já
  representa "Azure" em qualquer outro lugar da Biblioteca), "Repositório"
  (com dica de path absoluto ao vivo conforme digita) e "Demanda". A caixa
  de **Prompt** é editável e sempre reflete os campos ao lado — qualquer
  mudança num campo reescreve a caixa por cima, sem trava de "edição
  manual" (existia um modo que travava a sincronização depois do usuário
  tocar na caixa do prompt, causava a caixa "empacar" e nunca mais
  atualizar sozinha — removido, 2026-08-21). Quem quiser um texto
  diferente do gerado edita a caixa de Prompt direto antes de clicar —
  só dura até o próximo campo mudar. Comando powershell bruto fica
  escondido num `<details>`, não é mais a caixa principal. Botão único
  **Abrir Claude** (`.claude-btn`, cor terracota — mesma da acima) faz
  tudo num clique: valida (só Azure + descrição são obrigatórios), monta
  o comando a partir do texto atual do prompt, copia e lança direto via
  `biblioteca-cmd-run:` (auto-Enter, ver acima).
- **MCP `azure-devops` — SÓ LEITURA, 3 camadas de trava.** Servidor
  oficial da Microsoft (`@azure-devops/mcp`, org Trizy), registrado em
  **escopo user** (`claude mcp add --scope user`, em `~/.claude.json` —
  disponível em qualquer repo/sessão, não só na Biblioteca; precisa ser
  assim porque "Nova Task" agora abre direto no repo, não mais aqui).
  Autenticação via PAT com escopo "Work Items: Read" no próprio Azure
  DevOps (variável de ambiente do usuário `PERSONAL_ACCESS_TOKEN`,
  `base64("<email>:<pat>")` — nunca gravado em arquivo de repo nenhum).
  Três camadas, nenhuma sozinha é à prova de falha, juntas cobrem qualquer
  furo: **(1)** o PAT em si — Azure DevOps rejeita qualquer chamada de
  escrita mesmo que uma ferramenta apareça disponível; **(2)**
  `permissions.deny` em `~/.claude/settings.json` (**global**, não mais
  local a esta pasta — o MCP agora vale em qualquer repo) bloqueia
  `wit_work_item_write`, `wit_work_item_comment_write`,
  `wit_work_item_link_write` e `wit_backlog` (esse último bloqueado por
  completo, não só a escrita — mistura leitura/escrita numa única
  ferramenta, sem granularidade pra separar, e não é usado por nenhum
  fluxo aqui); **(3)** a instrução embutida no próprio prompt do
  `nova-task.html` proibindo chamar essas ferramentas mesmo que apareçam
  (antes vivia num SKILL.md dedicado — agora é texto simples no prompt,
  já que não há skill). O filtro `-d core work-items` do comando
  registrado só reduz a lista de ferramentas por área de produto (nem
  repositórios, nem pipelines, nem wiki) — não separa leitura de escrita
  dentro do domínio, por isso não é uma trava por si só.
- `historico-nova-task.md` (raiz desta pasta, link **Histórico** no
  header) — log append-only de toda task criada via `nova-task.html`,
  escrito pelo próprio agente seguindo a instrução embutida no prompt
  (nunca editado à mão, e não existe mais skill dedicada pra isso). Serve
  pra checar rápido, se uma task der problema depois, se a causa já estava
  no que foi capturado/confirmado na criação ou surgiu só na
  implementação — sem precisar reconstruir isso via `git log`/`git blame`
  do `task-code`. `build-dashboard.ps1` só garante que o arquivo existe
  (stub vazio) pra o link não dar 404 antes da primeira task criada.
- **"Abrir Claude" no header** — seletor de repo (`<input>` com
  `<datalist>`, mesma lista de `nova-task.html`, mesma altura da caixa de
  busca ao lado) + botão `.claude-btn` (cor própria — terracota/laranja,
  distinta do dourado geral, só pra sinalizar "isto abre o Claude") que
  abre um `cmd` na pasta daquele repo com `claude` digitado e **Enter
  automático** (`biblioteca-cmd-run:` — é a única ação com auto-Enter, ver
  acima), sem frase nenhuma, sem skill disparando — só uma janela rápida
  pra quem quer conversar sem estar amarrado a nenhuma task. Sem repo
  escolhido no campo, abre solto direto em `reposBasePath` (a pasta que
  contém todos os repos) em vez de não fazer nada. O comando é montado em
  JS no clique (depende do repo escolhido no navegador, não dá pra
  pré-computar em build-time). Só aparece se `reposBasePath` estiver
  configurado em `biblioteca.config.json`. Ordem no header (uma linha só,
  não mais duas): busca → campo de repo → Abrir Claude → + Nova Task →
  Histórico/Paleta/Arquivo/Pendências.
- **Campo de repo do "Abrir Claude" também filtra a grade** — digitar/
  escolher um repo nesse campo funciona como um 2º ponto de filtro além da
  busca de texto (`#search`), não como uma ação isolada. `applyFilters()`
  (função única no `$foot` de `build-dashboard.ps1`) combina os dois: texto
  E repo, ambos precisam bater pro card ficar visível. Cada card carrega
  `data-repo` (minúsculo, gerado por `Build-Card`) só pra esse match — não
  reaproveita o `data-search` (esse é fuzzy, cobre task+repo+descrição
  junto; o filtro de repo precisa ser específico). Estado do campo também
  entra no `sessionStorage` do auto-reload (mesmo mecanismo do `#search`),
  não se perde a cada 20s.
- **Ordenação do `<datalist>` de repos** (usado em `nova-task.html` e no
  "Abrir Claude") — não é alfabética pura: `Get-RepoSortKey` em
  `build-dashboard.ps1` agrupa backend + mfe/mobile do mesmo domínio juntos
  (ex.: `gbm-app-settings-backend` do lado de `gbm-mfe-settings`), joga
  domínios sem par (migrations, geral) depois dos pares, e repos de
  skills pessoais (`gbm-ai-skills`, `jow-ai-skills`, `ponytail` — lista
  fixa, não é heurística) sempre por último. Também filtra fora qualquer
  entrada que não pareça nome de pasta de verdade (vírgula/espaço — sinal
  de campo `repo:` de algum doc com 2 valores colados por engano).

## Protocolo de seleção

**Caminho principal:** abrir `dashboard.html` (favoritado no navegador) →
buscar/achar a task → expandir o card (seta no canto inferior direito) →
clicar "Retomar task" ou "Ajustes QA" (ou abrir a
caixa de ações na página de resumo) → um `cmd` novo abre com o comando já
digitado (protocolo `biblioteca-cmd:`, se registrado) ou o texto já está no
clipboard pra colar (fallback) → apertar Enter é sempre manual. Cada
comando abre `claude "<frase>"` reconhecida por uma skill específica
(`retomar`/`concluir`/`ajustar qa` + task + repo) — vai direto ao fluxo
certo, sem menu. A estrela de favorito não copia nada — o efeito já
acontece na própria página (ver acima).

**Task nova (sem task existente ainda):** botão "+ Nova Task" no header →
`nova-task.html` numa aba → preencher e gerar o comando → mesmo lançamento
(protocolo/clipboard), abrindo o Claude direto na pasta do repositório
escolhido → o prompt (auto-suficiente, sem skill dedicada) dispara o gate
global do `CLAUDE.md` do usuário sozinho, igual qualquer demanda digitada
nesse repo (ver acima).

**Alternativa (sem passar pelo dashboard):** a listagem de texto aparece
no início da sessão; digitar o número direto funciona, ou mandar algo
genérico ("menu") abre um `AskUserQuestion` (seta/Enter, paginado de 4 em
4) — só pra retomada, "concluir"/"ajustar qa" sempre precisam da frase
explícita.

## Sobre o claude-mem

Investigado como fonte pra "Posição atual": hoje não tem nada útil — só
registrou observações desta conversa, nenhuma memória
foi construída ainda dentro dos projetos reais. A tool `search` do
claude-mem aceita um parâmetro `project`, então no futuro (se memória
acumular lá) dá pra consultar sem mudar nada aqui. Por enquanto o "Posição
atual" vem só de grep sobre o corpo dos docs da Biblioteca (PRs e
pendências) — sem IA, sem rede.

## O que esta pasta não é

Não duplica lógica de documentação (isso é `controle-documentacao`) nem
convenção própria de branch/commit/PR do seu workflow de Git além do mínimo
usado por `task-hub-resume`. `dashboard-visual` só orquestra a navegação entre
tasks usando o que já existe na Biblioteca — e não é um repo git
próprio: mora dentro do repo da Biblioteca.
