---
name: controle-documentacao
description: >-
  Controle de documentacao na Biblioteca. Use para handover, handoff, task-code, plano de execucao,
  testes (unitarios+manuais no mesmo doc), ou doc tecnica para agentes. NUNCA gravar corpo completo
  em docs/ do repo do projeto — so biblioteca + stub. Apos salvar qualquer documento, rodar
  scripts/sync-all.ps1. NUNCA editar INDEX.md nem tabela manualmente.
---

# Controle de documentacao

**Regras detalhadas:** `01-regras-biblioteca.md` (raiz deste repo)
**Templates:** `_templates/{tipo}.md`

## Fluxo obrigatorio do agente

```
1. Ler INDEX.md (proximo numero) — nao editar
2. Copiar template do tipo em _templates/
3. Preencher APENAS frontmatter YAML + corpo (H1 em diante)
4. NAO escrever tabela de metadados — gerada pelo script
5. Salvar em `{tipo}/frontend/` ou `{tipo}/backend/` conforme `repo`
6. Rodar: powershell -ExecutionPolicy Bypass -File scripts/sync-all.ps1
```

## Buscar/pesquisar na Biblioteca (custo de tokens)

`INDEX.md` só traz o cabeçalho (proximo numero) + "Em andamento agora" (pequeno,
so ativas) — nao ler por completo pra achar histórico, cresce pra sempre. Catálogo
completo (tudo, agrupado por tipo) mora em `CATALOGO.md`, separado — só grep/busca
pontual ali, nunca leitura integral por padrão.

Pra achar o que já foi feito sobre um assunto, **buscar em `resumo/` primeiro** —
é o tipo desenhado pra isso (compacto, factual, já formatado pra consumo por
máquina, não precisa ler prosa de handover/planning pra entender o essencial). Só
cair pro conjunto completo (`task-code`+`task-planning`+`testes`+`handover-tecnico`)
se o resumo não tiver a resposta.

## Tipos de documento

| Tipo | Pasta | Quando |
|------|-------|--------|
| `task-code` | `task-code/{frontend\|backend}/` | Card/issue do seu rastreador de tarefas / spec da branch |
| `task-planning` | `task-planning/{frontend\|backend}/` | Plano de execucao; multiplos planos = secoes no mesmo arquivo |
| `testes` | `testes/{frontend\|backend}/` | **Um doc por task** — unitarios + manuais juntos |
| `resumo` | `resumo/{frontend\|backend}/` | **Um doc por task+repo** — dado factual pro dashboard visual (`dashboard-visual/`, dentro da propria Biblioteca): Status atual / O que foi implementado / REQs seguidas / O que falta. Nao precisa de prosa polida como os outros tipos — bullets factuais bastam, quem le e o gerador de HTML, nao um humano direto no `.md`. Atualizado a cada gatilho que toca a documentacao da task (ver Gatilhos automaticos), nao so no inicio/fim — fica fresco o tempo todo, nao so na conclusao. |
| `handover-tecnico` | `handover-tecnico/{frontend\|backend}/` | Playbook, modulo, contrato API, convencoes |
| `rules` | raiz | So `01-regras-biblioteca.md` |
| `reqs` | `reqs/` (plano, sem split frontend/backend) | Card/issue original verbatim, incluindo o item pai (feature/epic ou equivalente) quando houver — referencia crua, fora do indice numerado e do `sync-all.ps1` |

**Camada:** `repo: meu-app-frontend` → `.../frontend/` · `repo: meu-app-backend` → `.../backend/`

Exemplo: `testes/frontend/27-testes-101034-aurora-sheet.md`

**Nome:** `{NN}-{tipo}-{slug}-{taskId|general}.md`

Exceção: `reqs` usa `{taskId}-{slug}.md`, sem prefixo numerico e sem YAML frontmatter obrigatorio — e copia de referencia, nao doc de ciclo de vida. Um unico arquivo por task, com secoes:

```markdown
# REQ {reqId} — {titulo}

{texto do card colado verbatim}

## Parent — {parentId}

{texto do item pai colado verbatim, se o REQ tiver um}
```

O parent costuma trazer o objetivo de negocio mais amplo que o REQ filho nao repete (ex: "o usuario precisa ver X na tela") — e frequentemente a fonte real do sinal de escopo full-stack ou do formato de artefato esperado. Nao pular a secao `## Parent` so porque o REQ filho parece autoexplicativo.

## Gate — REQ e parent originais antes de task-planning (bloqueia, nao pular)

Antes de criar ou aprovar um `task-planning`, o card/REQ original (seu rastreador de tarefas — Azure DevOps, Jira, Linear, GitHub Issues, etc.) precisa estar salvo em `reqs/{taskId}-{slug}.md`, colado verbatim — e, se o REQ tiver item pai (feature/epic ou equivalente), o texto do item pai colado verbatim na secao `## Parent` do mesmo arquivo. O `task-code` referencia esse arquivo por link no campo `REQ original` — nao copia o texto. Investigacao de codigo nao substitui isso.

- [ ] `reqs/{taskId}-{slug}.md` existe, com o card do REQ colado verbatim — se nao, voltar e pedir ao usuario antes de seguir para `task-planning`
- [ ] Se o REQ tem item pai: secao `## Parent` no mesmo arquivo tem o texto do parent colado verbatim — perguntar ao usuario se ha parent antes de assumir que nao ha
- [ ] Se a demanda gera artefato de arquivo (relatorio/export), o formato esperado esta declarado no `task-code` a partir do REQ ou do parent original — nao inferido por investigacao de codigo
- [ ] **Last check final** (rodar de novo antes de `status: completed`): reabrir `reqs/{taskId}-{slug}.md` (REQ + parent) e confirmar, item por item, que backend E frontend cobrem o que foi pedido

**Excecao — demanda sem REQ/card formal (`task: general`):** nao ha card formal pra colar. Neste caso o gate acima nao bloqueia, mas o pedido original do usuario (o texto que ele digitou no chat, print, mensagem, etc.) ainda precisa ser registrado verbatim em `reqs/{taskId|slug}-{slug}.md` — usar o slug da demanda como identificador quando nao houver taskId numerico. Nao pular a captura so porque "e informal": e' falta de fonte registrada, nao falta de REQ formal, que costuma causar entrega errada (ex.: formato de arquivo errado por falta de registro do pedido original).

## Status — atualizar conforme andamento

| Status | Quando marcar |
|--------|----------------|
| `draft` | Criando task-code ou planning inicial |
| `in_progress` | Implementacao ou testes em curso |
| `completed` | Testes OK + usuario pediu commit/entrega/PR |
| `superseded` | Substituido por outro doc (`related` aponta o novo) |
| `archived` | Secao/plano antigo dentro de um planning consolidado |

### Gatilhos automaticos (agente deve atualizar YAML)

| Evento | Acao |
|--------|------|
| Usuario aprova task-code | `status: in_progress` no `task-code` e no planning |
| Agente inicia implementacao de um plano | `plan_active: plano-N` no task-planning |
| Plano N concluido | Secao com `**Status da secao:** concluido`; proximo plano se houver |
| Testes unitarios rodados | Atualizar doc `testes/` (mesmo arquivo) |
| Testes manuais OK | Preencher resultados no mesmo `testes/` |
| Usuario pede mensagem de commit ou fecha entrega | `status: completed` no `testes/`, no `task-planning` **e no `task-code`** — o `task-code` nao fica preso em `draft`/`Rascunho` so porque nenhum gatilho anterior o tocou |
| Usuario responde "Task resolvida?" = sim (pos-PR) | Registrar link do PR (`related` ou nota); rodar o last check do Gate — REQ e parent; `status: completed` no task-code/planning/testes; `sync-all.ps1`. Se task-code nao existe ainda (fluxo ad-hoc sem spec previo): criar agora, salvando o REQ/pedido original em `reqs/` retroativamente |
| Usuario responde "Task resolvida?" = nao | Perguntar o que falta; manter `status: in_progress`; registrar a lacuna no doc — nao fechar |
| **Qualquer** atualizacao de `task-code`/`task-planning`/`testes`/`handover-tecnico` de uma task (nao so no inicio ou no fim) | Dar um toque no `resumo` dessa task+repo: criar se ainda nao existir, senao atualizar pelo menos **Status atual** e **O que falta** com o que mudou. Nao esperar o fim da task pra manter o resumo fresco — ele e' consultado a qualquer momento (dashboard visual em `dashboard-visual/`), nao so na conclusao. **"Ainda nao existir" e' verificavel, nao suposicao** — antes de criar um `resumo` novo, rodar `grep -rl "^task: {taskId}" resumo/` (task numerica) ou `grep -rln "^cluster: {cluster}" resumo/*/*.md` (task `general`) no repo da Biblioteca; só criar se vier vazio. Pular esse grep e' a causa mais comum de resumos duplicados ficarem escondidos do dashboard (colisao de `cluster`+`repo`) — `build-dashboard.ps1` so mostra 1 resumo por task+repo, sem avisar quando ha mais de um. |

## Frontmatter (fonte unica — sem duplicar na tabela)

```yaml
---
number: 28
type: task-planning
status: in_progress
repo: meu-app-frontend
task: 101034
function: Resumo de uma linha para o INDEX
stub: —
cluster: —             # opcional, so pra `task: general` — nome curto (2-4 palavras) que o dashboard usa como titulo do card no lugar de "Geral" E como chave de agrupamento (substitui o fallback por `related`/path — ver dashboard-visual/CLAUDE.md). Manter o MESMO texto em todo doc do mesmo assunto — e' isso que agrupa os docs no mesmo card.
pr_pending: —          # opcional — url do PR quando aberto e ainda sem confirmacao de merge (ver dashboard-visual/CLAUDE.md, sweep automatico)
plan_active: plano-1          # so task-planning com multiplos planos
related:
  - task-code/frontend/23-task-code-101034-terminal-side-sheet.md
  - testes/frontend/27-testes-101034-aurora-sheet.md
updated: YYYY-MM-DD
author: —              # preencher com biblioteca.config.json > author
---
```

Corpo comeca com `# Titulo` — **sem** tabela. Script gera tabela + secao `## Documentos relacionados` a partir do YAML.

## Task planning — multiplos planos

Um arquivo, secoes `## Plano 1`, `## Plano 2`, etc.

**Antes de implementar:** ler o arquivo, listar planos e **perguntar ao usuario** qual executar (ou confirmar `plan_active`).

Cada secao:

```markdown
## Plano 2 — CRUD medio

**Status da secao:** estagnado | em andamento | concluido
```

Planos concluidos: nao apagar — marcar secao como concluida.

## Handover tecnico — citar a fonte da regra/decisao

Sempre que um `handover-tecnico` explicar uma regra de negocio (RN) ou
decisao tecnica que vem de um REQ/task-code/parent, citar o trecho
original em blockquote (`>`) logo abaixo do titulo do item — nao so
descrever com as proprias palavras. Formato:

```markdown
**N. "Termo do requirement" → o que foi implementado**

> issue #NNN, AC-XX: "trecho exato entre aspas, com **negrito** na
> parte que motivou a decisao."

Explicacao/motivo/risco depois da citacao.
```

O trecho citado vem de `reqs/{taskId}-{slug}.md` (REQ ou secao `## Parent`,
ver Gate acima) — copiar de la, nao reconstruir de memoria.

Vale tambem pra respostas do PO registradas no mesmo doc (citar a resposta
literal quando fizer diferenca pra quem for ler depois).

## Testes — um documento por task

- Nao criar `test-manual` e `test-unit` separados
- Se ja existe `testes/NN-testes-{task}.md` → **atualizar**, nao criar outro
- Secoes: `## Testes unitarios` e `## Testes manuais`

Se voce tiver skills dedicadas a rodar/registrar testes (unitario, manual) → gravar no mesmo `testes/`.

## Apos salvar (checklist)

- [ ] `updated` no YAML = hoje
- [ ] `status` correto
- [ ] `related` com links relativos na biblioteca
- [ ] Rodar `scripts/sync-all.ps1`
- [ ] Stub no repo se `stub:` preenchido (`docs/{stub}`)

## Regra absoluta — repo

| Permitido | Proibido |
|-----------|----------|
| Stub em `docs/{frontend\|backend}/` | Corpo do handover no repo |

## Novo documento — proximo numero

Consultar `INDEX.md` campo **Proximo numero**. Usar esse valor no `number:` do YAML.
