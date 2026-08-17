---
number: 01
type: rules
status: completed
repo: geral
task: general
function: Regras da Biblioteca
stub: —
cluster: Regras da Biblioteca
updated: 2026-08-14
author: —
---
# Regras da Biblioteca

<!-- badge:auto -->
✅ **Concluido** | `geral` | 14/08/2026
<!-- /badge:auto -->

Referência humana — resumo condensado. Agentes seguem a versão operacional
completa em `~/.claude/skills/controle-documentacao/SKILL.md`; aqui é só o
que um humano precisa pra se situar rápido.

**Local:** raiz deste repo
**Índice:** [`INDEX.md`](INDEX.md) (tasks em andamento, gerado — não editar)
**Catálogo:** [`CATALOGO.md`](CATALOGO.md) (histórico completo, gerado — não editar)
**Sync:** `scripts/sync-all.ps1`

---

## Estrutura

```
Biblioteca/
├── INDEX.md                  # gerado
├── CATALOGO.md                # gerado
├── 01-regras-biblioteca.md
├── scripts/                   # sync-header, lint-clusters, build-index, sync-all, pre-commit-check
├── _templates/                # task-code, task-planning, testes, resumo, handover-tecnico
├── task-code/{frontend,backend}/
├── task-planning/{frontend,backend}/
├── testes/{frontend,backend}/
├── resumo/{frontend,backend}/
├── handover-tecnico/{frontend,backend}/
├── reqs/                       # REQ/card original verbatim, fora do indice numerado
├── _archive/                   # docs substituidos ou anteriores a esta convencao
└── dashboard-visual/           # dashboard HTML gerado + skills locais (task-hub-*)
```

---

## Tipos

| Tipo | Conteúdo |
|------|----------|
| `task-code` | Card do seu rastreador de tarefas, especificação da branch |
| `task-planning` | Plano de execução; vários planos = seções no mesmo arquivo (`plan_active` indica qual) |
| `testes` | Unitários + manuais no mesmo doc, um por task |
| `resumo` | Dado factual pro dashboard — status/implementado/REQs/falta. **Um por task+repo**, nunca mais de um (ver "Regras de status" abaixo) |
| `handover-tecnico` | Módulo, playbook, contrato, convenções, debug consolidado |
| `reqs` | Card/issue do seu rastreador de tarefas (+ item pai, se houver) colado verbatim — referência crua, fora do índice numerado e do `sync-all.ps1` |

**Camada (`repo:` → pasta):** o valor de `repo:` decide `frontend/` ou `backend/` — ex. `meu-app-frontend` → `.../frontend/`, `meu-app-backend` → `.../backend/`.

---

## Nomenclatura

`{NN}-{tipo}-{slug}-{taskId|general}.md` — ex. `27-testes-101034-aurora-sheet.md`.

Exceção: `reqs/` usa `{taskId}-{slug}.md` — sem número sequencial, sem frontmatter obrigatório (é cópia de referência, não doc de ciclo de vida).

---

## Fluxo obrigatório do agente (criar um doc novo)

```
1. Ler INDEX.md (campo "Próximo número") — não editar
2. Copiar o template do tipo em _templates/
3. Preencher APENAS o frontmatter YAML + corpo (H1 em diante)
4. NÃO escrever a tabela de metadados — é gerada pelo script
5. Salvar em {tipo}/frontend/ ou {tipo}/backend/, conforme repo:
6. Rodar scripts/sync-all.ps1
```

---

## Regras de status

`draft` → `in_progress` → `completed` | `superseded` | `archived`

| Campo/valor | O que é |
|---|---|
| `superseded` | Substituído por outro doc — `related:` aponta pro novo |
| `archived` | Histórico encerrado sem substituto, ou seção antiga dentro de um planning consolidado |
| `cluster:` | Nome curto de agrupamento pra tasks `task: general` — vira o título do card no dashboard E a chave de agrupamento (em vez de "Geral" solto). Mesmo texto em todo doc do mesmo assunto |
| `pr_pending` / `pr_merged` / `pr_rejected` | URL do PR — preenchidos por um sweep automático (`gh pr view`) rodado pelo `build-dashboard.ps1`, não à mão. Ao mergear, o sweep também fecha `status: completed` sozinho |
| `plan_active` | Só em `task-planning` com múltiplos planos — indica qual seção está em execução |

**Um `resumo` por task+repo — regra, não sugestão.** O dashboard guarda só **um** `resumo` por card (`Select-Object -First 1`); um segundo resumo pro mesmo `cluster`+`repo` (ou `task`+`repo`) fica **invisível no dashboard, sem aviso**. Já aconteceu (8 resumos sumiram silenciosamente em 13/08/2026, regularizado no dia seguinte). Antes de criar um `resumo` novo: `grep -rl "^task: {taskId}" resumo/` ou `grep -rln "^cluster: {cluster}" resumo/*/*.md` — só criar se vier vazio. `scripts/lint-clusters.ps1` bloqueia o `sync-all.ps1` se detectar essa colisão.

---

## Regra absoluta — nunca corpo completo no repo do projeto

| Permitido | Proibido |
|-----------|----------|
| Stub em `docs/{frontend\|backend}/` do repo do projeto (`stub:` no YAML) | Corpo completo de handover/planning/testes/task-code gravado no repo do projeto |

Stub existe pros dois lados — frontend (`docs/frontend/`) e backend (`docs/backend/`), não só frontend.

---

## Buscar na Biblioteca

Não ler `INDEX.md` inteiro pra achar histórico — ele só tem "Próximo número" +
tasks em andamento. Histórico completo é `CATALOGO.md` (grep pontual, não
leitura integral). Pra saber "o que já foi feito sobre X", buscar em
`resumo/` primeiro — é o tipo compacto, factual, feito pra isso. Só cair pro
conjunto completo (`task-code`+`task-planning`+`testes`+`handover-tecnico`)
se o resumo não bastar.

---

## Templates

Campos base de todos os 5 templates em `_templates/`:

```
number, type, status, repo, task, function, stub, related, updated, author
```

`task-planning.md` soma `plan_active`. `cluster` e `pr_pending`/`pr_merged`/
`pr_rejected` **não** vêm nos templates — são exceções aplicadas depois
(cluster na hora de rotular uma task `general`; os `pr_*` só são escritos
pelo sweep automático, nunca à mão).

---

## Automação

| Script | Função |
|--------|--------|
| `sync-header.ps1` | YAML → tabela no corpo |
| `lint-clusters.ps1` | Trava o sync se houver `cluster` divergente num grupo, ou mais de um `resumo` ativo no mesmo cluster/task+repo |
| `build-index.ps1` | Gera `INDEX.md` + `CATALOGO.md` |
| `dashboard-visual/scripts/build-dashboard.ps1` | Gera o dashboard (`dashboard.html`, `paleta.html`, `archive.html`, `summaries/*.html`) |
| `sync-all.ps1` | Roda os 4 acima em ordem (aborta em `sync-header`/`lint-clusters` se achar problema) — sempre rodar depois de editar |
| `.git/hooks/pre-commit` → `pre-commit-check.ps1` | Trava o commit se um `.md` estiver corrompido/anormal — automático, não precisa lembrar |

O agente **não** edita tabela, `INDEX.md` nem `CATALOGO.md` manualmente.

---

## Ver também

[`README.md`](README.md) — visão geral e tour do dashboard, com screenshots.
[`dashboard-visual/CLAUDE.md`](dashboard-visual/CLAUDE.md) — como o dashboard
funciona por dentro (favoritos, resumo, página de Arquivo, skills locais
`task-hub-resume`/`task-hub-complete`/`task-hub-qa`).

<!-- meta:auto -->
<details>
<summary>Metadados</summary>

| Campo | Valor |
|---|---|
| Numero | 01 |
| Tipo | Regras |
| Task | **Geral** |
| Stub | — |
| Autor | — |

</details>
<!-- /meta:auto -->
