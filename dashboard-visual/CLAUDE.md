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
  ganham mais um botão — **Copiar comando** (retomar). Não existe botão de
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
  os botões de ação (Copiar comando quando ativa, Ajustes QA sempre). Uma
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

## Protocolo de seleção

**Caminho principal:** abrir `dashboard.html` (favoritado no navegador) →
buscar/achar a task → expandir o card (seta no canto inferior direito) →
clicar "Copiar comando" ou "Ajustes QA" (ou abrir a
caixa de ações na página de resumo) → colar o comando copiado num
terminal. Cada um abre `claude "<frase>"` reconhecida por uma skill
específica (`retomar`/`concluir`/`ajustar qa` + task + repo) — vai direto
ao fluxo certo, sem menu. A estrela de favorito não copia nada — o efeito
já acontece na própria página (ver acima).

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
