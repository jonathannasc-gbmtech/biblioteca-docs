---
name: task-hub-complete
description: Use quando a primeira mensagem do usuario numa sessao em dashboard-visual (Biblioteca) bater com "concluir task X no repo Y" (comando digitado na mao - o dashboard.html nao tem mais botao "Marcar concluida", o sweep de pr_pending fecha a task sozinho quando o PR mergeia) - fecha a task seguindo o gate ja existente da skill controle-documentacao, nao um checklist proprio.
---

# task-hub-complete

## Quando disparar

O card de cada task ativa no `dashboard.html` tem um botão **"Marcar
concluída"** que copia:

```
cd "<pasta-da-biblioteca>\dashboard-visual"; claude "concluir task <task> no repo <repo>"
```

Se a primeira mensagem da sessão bater com esse padrão (ou variação
próxima — "concluir task X no repo Y", "fechar task X repo Y"), extrair
`task` e `repo` direto da frase e seguir o fluxo abaixo.

## Fluxo — delega pro gate que já existe, não reinventa

**Não recriar o checklist de fechamento aqui.** Invocar a skill
`controle-documentacao` e seguir exatamente o que ela já define para o
evento "Task resolvida? = sim" (tabela de Gatilhos automáticos) e o
"Gate — REQ e parent originais" (seção do mesmo arquivo):

1. Localizar os docs da task na Biblioteca (`task-code`/`task-planning`/
   `testes`, filtrando por `task: <task>` e `repo: <repo>` no frontmatter).
2. Reabrir `reqs/{taskId}-{slug}.md` (REQ + parent, se existir) e confirmar
   item por item que backend E frontend cobrem o que foi pedido — o
   **last check** já documentado no gate. Se a task foi `general` (sem
   REQ formal), confirmar que o pedido original está registrado em
   `reqs/` mesmo assim.
3. Se a demanda envolvia artefato de arquivo (relatório/export), confirmar
   que o formato entregue bate com o declarado no REQ/parent.
4. Registrar o link do PR (se houver — o dashboard já mostra o link
   extraído do doc, na seção "Posição atual" do card) no campo `related`
   ou numa nota do doc.
5. `status: completed` no `task-code`, `task-planning` e `testes` dessa
   task (todos os docs do grupo).
6. **Finalizar o doc `resumo`** (tipo `resumo` de `controle-documentacao`,
   um por task+repo — `task-hub-resume` garante que ele existe ao
   retomar).
   - **O que foi implementado:** bullets com **nomes concretos** — campos,
     endpoints, telas/componentes alterados, nomes de tabela/coluna se
     houver migration. O critério: se alguém te chamar sobre essa task
     daqui a um mês, ler só essa seção já basta pra saber o que foi feito,
     sem abrir o código. "Implementei o backend" não passa; "Endpoint
     `GET /dashboard/kpis` retorna X" passa. Não precisa de exemplo de
     payload/request, só os nomes.
   - **REQs seguidas:** referenciar `reqs/{taskId}-{slug}.md`.
   - **O que falta:** esvaziar/atualizar (vazio se nada ficou pendente, ou
     listar follow-ups conhecidos).
   - `status: completed` nele também.
7. Rodar `scripts\sync-all.ps1` da Biblioteca.

**Se qualquer item acima não puder ser confirmado** (falta cobertura de
uma camada, REQ não localizado, formato de artefato não bate) — **parar e
reportar o que falta**, não marcar `completed` mesmo assim. Isso é
exatamente o motivo de todos esses gates existirem (ver o histórico de
erros — frontend esquecido, Excel entregue como PDF — que motivou criar
esse fluxo).

## Depois de concluir com sucesso

Regenerar o dashboard pra ele já refletir a mudança (a task some de
"Ativas" — se ela estava marcada como "atual" no dashboard, o próprio
JS da página limpa isso sozinho, é local ao navegador, não precisa de
nada aqui):

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\build-dashboard.ps1"
```

(caminho relativo — rodar a partir de `dashboard-visual/`)

Reportar ao usuário: o que foi verificado, o que mudou de status, e que o
dashboard já foi atualizado (a task agora aparece em "Completas").

## O que esta skill NÃO faz

Não duplica o gate de fechamento (isso é `controle-documentacao`) nem a
lógica de retomada de trabalho (isso é `task-hub-resume`). Só traduz o
comando copiado do dashboard pra invocação do gate certo.
