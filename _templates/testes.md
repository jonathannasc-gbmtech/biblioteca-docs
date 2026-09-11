---
number: NN
type: testes
status: in_progress
repo: nome-do-seu-repo
task: TASK_ID
function: Testes unitarios e manuais - resumo
titulo_busca: Fix wagons.trainId em lote com arrival mista  # obrigatorio - palavras-chave da tarefa, curto (bater o olho e entender)
stub: —
related:
  - task-planning/TASK_ID-{slug}.md
updated: YYYY-MM-DD
author: —
---

# Testes — {titulo}

Um único documento por task: unitários + manuais. Só o essencial — **como
foi testado e o resultado**. Sem causa raiz/detalhe de bug (isso vai no
`handover-tecnico` se valer a pena registrar pra outro dev entender depois).

Vai para terceiros: tom profissional, sem gírias/contrações informais e
sem citar ou parafrasear o pedido de quem solicitou o teste — descrever
o achado/resultado como fato técnico, não como resposta a uma instrução.
Sem "nós"/"nosso" — voz neutra ("o fix corrige X"), a documentação é do
usuário, não de quem ajudou a escrever.

## Resultado geral

**Veredito:** ✅ Passou | ❌ Falhou | ⚠️ Passou com ressalvas

1-2 linhas: o que foi validado e o resultado final.

## Testes unitários

### Comando

```bash
npm test
```

### Resultado

| Teste | Resultado |
|-------|-----------|

## Testes manuais

| Teste | Resultado |
|-------|-----------|

## Notas

Só pendências/follow-ups pra próxima rodada — não é log de bug.

<!-- Resultado: ✅ passou / ❌ falhou / ⚠️ ressalva. Se falhou/ressalva,
completar com 1 linha curta na própria célula (ex. "❌ retornou 404 —
falta rota"), não uma coluna extra de causa/observado. -->
