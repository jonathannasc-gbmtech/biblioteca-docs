---
name: task-hub-qa
description: Use quando a primeira mensagem do usuario numa sessao em dashboard-visual (Biblioteca) bater com "ajustar qa task X no repo Y" (comando copiado do botao "Ajustes QA" do dashboard.html ou da pagina de resumo) - reativa o repositorio pra fazer ajustes numa task que ja foi concluida e mergeada, sem duplicar a logica de git do task-hub-resume.
---

# task-hub-qa

## Quando disparar

Todo card do `dashboard.html` (Ativas e Completas) e a página de resumo têm
um botão **"Ajustes QA"** que copia:

```
cd "<pasta-da-biblioteca>\dashboard-visual"; claude "ajustar qa task <task> no repo <repo>"
```

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
  numerando: "Ajustes QA — rodada 2") com data + o que o QA reportou
  (perguntar ao usuário, não inventar) + o que foi corrigido, preenchido
  conforme a conversa avança — não é gerado automaticamente de uma vez.
- **Toca o `resumo`** da task+repo (gatilho já existente em
  `controle-documentacao` pra qualquer atualização de doc da task) —
  atualizar "Status atual" mencionando a rodada de QA em andamento, sem
  mudar `status` do resumo.
- Rodar `scripts\sync-all.ps1` da Biblioteca depois.

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
