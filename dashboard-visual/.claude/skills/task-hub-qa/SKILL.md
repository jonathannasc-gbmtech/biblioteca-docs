---
name: task-hub-qa
description: Use quando a primeira mensagem do usuario numa sessao em dashboard-visual (Biblioteca) bater com "ajustar qa task X no repo Y" (comando copiado do botao "Ajustes QA" do dashboard.html ou da pagina de resumo) - reativa o repositorio pra fazer ajustes numa task que ja foi concluida e mergeada, sem duplicar a logica de git do task-hub-resume.
---

# task-hub-qa

## Quando disparar

Todo card do `dashboard.html` (Ativas e Completas) e a página de resumo têm
um botão **"Ajustes QA"** que copia:

```
powershell -NoProfile -Command "cd '<pasta-da-biblioteca>\dashboard-visual'; claude 'ajustar qa task <task> no repo <repo>'"
```

(envolvido em `powershell -NoProfile -Command` pra funcionar colado tanto no
cmd.exe quanto no PowerShell — `;` sozinho quebra no cmd.exe)

Cenário: a task já foi concluída e mergeada (PR fechado, `status: completed`
na Biblioteca), mas o retorno do QA chegou depois — o repositório precisa
ser reativado pra fazer os ajustes. Se a primeira mensagem da sessão bater
com esse padrão (ou variação próxima — "ajustar qa task X no repo Y",
"ajustes de qa na task X repo Y"), extrair `task` e `repo` e seguir o fluxo
abaixo.

## Fluxo — reaproveita a rotina do task-hub-resume, não duplica

**Não reimplementar a lógica de path/branch/stash aqui.** Seguir
exatamente os passos 1-5 da "Rotina de retomada" em
`task-hub-resume/SKILL.md`:

1. Path do repo (`reposBasePath` em `biblioteca.config.json` + `\<repo>`).
2. Checkpoint da task que estava ali antes, se houver mudança não
   commitada e branch diferente da selecionada.
3. Branch da task: mesma convenção `<tipo>/<taskId>[-slug]` — procurar
   local/remota primeiro. Como a task já foi mergeada, a branch quase
   sempre não vai mais existir (local nem remota) — nesse caso, criar a
   partir do branch base do projeto (`defaultBranch` em
   `biblioteca.config.json`, default `main`) seguindo a convenção normal,
   **sem sufixo `-qa` ou prefixo `fix/`** (é uma branch nova, mas com o
   nome de sempre — não uma convenção separada pra QA).
4. Restaurar checkpoint da task selecionada, se sobrar algum stash
   rotulado (raro nesse cenário, mas checar do mesmo jeito).
5. Reler os docs relacionados na Biblioteca (`task-code`/`task-planning`/
   `testes`/`resumo`) e resumir o que foi entregue.

## O que esta skill faz DIFERENTE do task-hub-resume

- **Não altera `status`** de nenhum doc — `task-code`/`task-planning`/
  `testes` continuam `completed`, a task continua aparecendo em
  "Completas" no dashboard. Reabrir pra QA não é reabrir o ciclo de
  entrega.
- **Registra uma nota no doc `testes/`** dessa task+repo (mesmo arquivo —
  regra de "um documento por task" do `controle-documentacao`): uma seção
  `## Ajustes QA` (ou repetir a seção se já existir uma rodada anterior,
  numerando: "Ajustes QA — rodada 2 (data)") — preenchida conforme a
  conversa avança, não gerada automaticamente de uma vez. **A seção
  sempre ABRE com 3 bullets nesse formato exato** (o dashboard
  (`build-dashboard.ps1`, `Get-QaFieldValue`) lê essas 3 linhas pra
  montar o card da rodada — sem elas, o card cai num teaser genérico e
  menos legível):
  ```markdown
  - **Reportado:** o que o QA/PO relatou (perguntar ao usuário, não inventar).
  - **Causa raiz:** o motivo real do problema — se a rodada for pedido de
    feature em vez de bug, usar `N/A (pedido de feature, não bug)`.
  - **Corrigido:** o que foi mudado pra resolver.
  ```
  Detalhe adicional (verificação, tabela de resultado, incidentes,
  causa raiz aprofundada, etc.) é livre e vai **depois** desses 3
  bullets, no mesmo padrão de sempre. Exemplo real já nesse formato:
  `testes/backend/104691-page-relation-fix-migrations-testes.md`.
- **Toca o `resumo`** da task+repo (gatilho já existente em
  `controle-documentacao` pra qualquer atualização de doc da task) —
  **reescrever** "Status atual" pro snapshot do estado atual (branch, PR
  número+estado, o que está pendente — poucas linhas, bullets), sem mudar
  `status` do resumo. **Não acrescentar** mais um parágrafo de narrativa
  da rodada ali — o relato do que o QA achou/causa raiz/fix já foi pro
  `## Ajustes QA` do `testes/` (item acima); duplicar em "Status atual"
  é o que faz esse campo virar um log que só cresce a cada rodada, sem
  nunca refletir só o estado atual (caso real: task 104691, 2 rodadas de
  QA deixaram "Status atual" com 80+ linhas de histórico). Gravar também
  o campo `branch:` com
  o nome resolvido/criado no passo 3 (quase sempre uma branch nova, já
  que a original foi mergeada e deletada) — sobrescreve o valor anterior.
- Rodar `scripts\sync-all.ps1` da Biblioteca depois.

## Bug relacionado achado durante o ajuste — resolve antes de subir, não só documenta

Se, testando o que o QA reportou, aparecer **outro** bug real ligado à
mesma task/tela em geral (endpoint irmão, mesma feature, mesmo fluxo —
não precisa ser o mesmo sintoma nem o mesmo arquivo), ele **não é
"fora de escopo" só por não ser o sintoma original relatado**. Tratar com
a mesma prioridade: investigar causa raiz, propor fix, e resolver na
mesma rodada antes de considerar a task pronta pra subir — não bastar
"documentar e deixar pra depois" por conta própria. Confirmar com o
usuário antes de aplicar o fix (mesmo gate de sempre), mas não empurrar a
decisão de "isso importa?" pra ele sem analisar primeiro — a pergunta
certa é "encontrei X, causa é Y, posso corrigir agora?", não "isso é bug
ou feature, o que eu faço?".

Exemplo real (task 104691, 2026-08-24): QA reportou 404 em 5 endpoints do
dashboard (rota errada). Corrigido. Testando os outros 4 endpoints pra
confirmar o fix, apareceu um `400` num deles (bug de SQL, sem relação
alguma com rota) — inicialmente tratado como "achado separado, fora do
escopo, decide você se quer que eu conserte" — feedback do usuário: isso
deveria ter subido junto da mesma correção, é a mesma tela/task, não um
bug não relacionado. Cada bug real achado numa rodada de QA vira sua
própria branch/PR (não empacotar num só, mantém o diff pequeno e
rastreável — ver PRs #296 e #300 da mesma task), mas todos entram na
mesma rodada de "Ajustes QA", não ficam pendurados pra "depois".

## Depois de reativar

Reportar ao usuário: branch preparada (nova ou reaproveitada), o que foi
relido dos docs, e que a nota de "Ajustes QA" foi registrada — pronto pra
começar os ajustes. Quando os ajustes forem concluídos e um novo PR for
aberto/mergeado, não há comando dedicado de "fechar QA" — a nota já fica
registrada no doc de testes; se o usuário quiser, pode pedir pra atualizar
mais alguma coisa manualmente.

## O que esta skill NÃO faz

Não duplica a lógica de git (path/branch/checkpoint) — isso é
`task-hub-resume`, só referenciado aqui. Não reabre o ciclo de status —
isso é justamente o que diferencia essa skill de retomar uma task ativa.
