---
name: biblioteca-pdf-export
description: Exporta documentos markdown da Biblioteca pessoal de documentação técnica (task-code/, task-planning/, testes/, handover-tecnico/, reqs/, resumo/, cada .md com frontmatter YAML: number, type, status, repo, task, author, updated, titulo_busca, function, pr_merged/pr_pending) para PDF em tema escuro, na paleta real do dashboard da Biblioteca. Use sempre que o usuário pedir para "exportar pra PDF", "gerar PDF", "converter documento da Biblioteca", "mandar handover pro PO" ou mencionar um número de task/arquivo da Biblioteca junto com PDF. Também use proativamente quando o usuário disser que vai compartilhar um `handover-tecnico` ou `testes` com alguém fora do time técnico.
license: Personal use
---

# Biblioteca PDF Export

Converte um documento markdown da Biblioteca (frontmatter YAML padrão) para
PDF em tema escuro, replicando a paleta real do dashboard. Roda 100% local
via CLI — sem enviar nada pra fora.

## Motor: só wkhtmltopdf (decisão fechada, não reabrir sem motivo novo)

Testado nesta máquina em 2026-09-11: `weasyprint` falha ao importar mesmo
com o runtime GTK3 instalado (2 tentativas — pacote `GtkD.GtkPlusRuntime.x64`
do winget e o instalador oficial recomendado pela própria documentação do
weasyprint, `tschoonj/GTK-for-Windows-Runtime-Environment-Installer` — as
duas com o mesmo erro `cannot load library 'libgobject-2.0-0'`). Não é um
problema de instalação malfeita, é incompatibilidade de fundo do weasyprint
com Windows nativo — não insistir de novo sem um motivo concreto novo (ex.:
nova versão do weasyprint que resolva isso).

`wkhtmltopdf` (build **"patched Qt"**, confirmada com `wkhtmltopdf
--version`) funciona de ponta a ponta pro corpo do documento. Margem nativa
fica em 0 (fundo escuro cobre a página até a borda via CSS, não via
`--header-html`/`--footer-html` — ver "Fundo até a última página" abaixo
pra por que essa ideia foi abandonada).

## Dependências — não checar antes de converter

Python, pandoc, `wkhtmltopdf`, `poppler` e as libs Python (`pyyaml`,
`pillow`) — instaladas uma vez por máquina (comandos em
"Reinstalar/diagnosticar" no fim). **Ir direto pra "Uso" abaixo** — não
rodar `winget install`, `pip install` nem comando de verificação de versão
antes de converter, isso é passo repetido à toa a cada pedido de PDF. O próprio script já
resolve os binários sozinho, mesmo se o PATH da sessão atual estiver
desatualizado (comum no meio de uma sessão do Claude Code — `wkhtmltopdf`,
`pdfinfo` e `pdftoppm` têm fallback embutido pro path de instalação do
winget, `find_wkhtmltopdf`/`find_poppler_tool` no script). Se a conversão
falhar com um erro real de "não encontrado", **aí sim** trocar pra
diagnosticar — ver "Reinstalar/diagnosticar" no fim deste doc.

## Uso

```powershell
python ".claude\skills\biblioteca-pdf-export\scripts\convert_to_pdf.py" <caminho\do\documento.md> [caminho\de\saida.pdf]
```

(path relativo à raiz da Biblioteca — a skill mora no próprio repo.)

Sem `caminho\de\saida.pdf`, o PDF vai pra `Biblioteca\exportacoes\`, mesmo
nome do `.md` de origem. Pasta `exportacoes/` é versionada no git da
Biblioteca (documento como os outros, mantém histórico de export) — só não
é escaneada pelo `sync-all.ps1` (não é `.md`, o glob já ignora sozinho).

Console informa quando termina:

```
(motor: wkhtmltopdf)
OK: C:\...\exportacoes\108364-classification-metrics-reativacao.pdf
```

Para converter todos os `.md` de uma pasta (ex.: todos os
`handover-tecnico/`):

```powershell
Get-ChildItem "handover-tecnico\*.md" | ForEach-Object {
  python ".claude\skills\biblioteca-pdf-export\scripts\convert_to_pdf.py" $_.FullName
}
```

## Como funciona

1. Lê o frontmatter YAML (`number`, `type`, `status`, `repo`, `task`,
   `author`, `updated`, `titulo_busca`, `function`, `pr_merged`,
   `pr_pending`).
2. Remove `<!-- badge:auto -->` e `<!-- meta:auto -->`/`<!-- related:auto -->`
   do corpo — auto-gerados pelo `sync-header.ps1`, não fazem sentido num
   PDF estático (o `<details>` de metadados não tem como simular
   "abrir/fechar" impresso).
3. Cor de destaque por `type` — **as mesmas cores dos chips do dashboard**
   (`TYPE_ACCENT` no script, ver tabela abaixo), não uma paleta inventada.
4. Título do PDF: `titulo_busca` em destaque (H1) com `function` como
   subtítulo logo abaixo — mesma hierarquia do card do dashboard (título
   grande = do que se trata, subtítulo = identificação da task). Sem
   `titulo_busca`, `function` sozinho vira o título.
5. `<title>` do HTML/PDF (metadado do arquivo, não o texto visível) = nome
   do `.md` de origem sem extensão.
6. Corpo convertido via `pandoc --from=markdown+pipe_tables+fenced_code_blocks --to=html5`.
7. Subtítulo (`h2`/`h3`) imediatamente seguido de tabela vira `<caption>`
   dentro da própria tabela (`wrap_heading_with_next_block`) — inseparável
   dela em qualquer motor, evita subtítulo órfão numa página enquanto a
   tabela vai pra próxima. Seguido de `pre`/`blockquote`/`details`/`p`, os
   dois viram um bloco só (`page-break-inside:avoid`) pelo mesmo motivo.
8. CSS do tema escuro aplicado, renderizado com `wkhtmltopdf` (margem
   nativa 0, fundo cobre a página até a borda via CSS).
9. **Fundo até a última página** (duas passadas): renderiza uma vez, mede
   com `poppler`+`Pillow` (se disponíveis) quanto de branco sobra abaixo do
   último conteúdo real na ÚLTIMA página, e só se sobrar algo relevante
   (`measure_trailing_gap_mm` > 5mm) regenera com um preenchimento do
   tamanho exato medido. Ver "Fundo até a última página" abaixo pra
   entender por que isso precisou de medição real (nada mais simples
   funcionou de forma confiável).

### Cores por tipo (`TYPE_ACCENT` no script — mesmas do dashboard)

| type | cor |
|---|---|
| `task-code` | dourado `#d9b568` |
| `task-planning` | teal `#7cbfc4` |
| `testes` | verde `#86b894` |
| `handover-tecnico` | rosa `#c184a0` |
| `rules` | marrom `#a89484` |
| `reqs` | azul `#6f9bd1` (sem chip no dashboard — cor própria) |
| `resumo` | roxo `#9a83c9` (sem chip no dashboard — cor própria) |

Tipo sem entrada em `TYPE_ACCENT` cai no dourado padrão (`DEFAULT_ACCENT`).
Pra ajustar, editar o dict no topo do script — nada de cor hardcoded no
meio do CSS.

## Fundo até a última página (por que precisou de medição real)

`wkhtmltopdf` tem um limite real: o fundo escuro do `body`/`.page-bg`
(`position:fixed`, repete página a página) cobre certinho as páginas do
meio, mas **não se repete no trecho da última página que sobra além do
conteúdo real** — ali fica branco, e num tema escuro isso salta aos olhos.
Três ideias mais simples foram tentadas e descartadas, nessa ordem:

1. **Calcular via JS** (`altura total do body % altura da página A4`) e
   completar com um filler — errado na prática: o próprio mecanismo de
   manter subtítulo+bloco juntos (`wrap_heading_with_next_block`) já força
   saltos antecipados de página em vários pontos, então "altura total" não
   tem relação simples com o que sobra de verdade na última página. Chegou
   a criar uma página extra quase inteira em branco (overshoot).
2. **Rodapé nativo com margem reservada** (`--footer-html` + `--margin-bottom`
   fixo) — o rodapé em si é confiável em toda página (nunca falha, ao
   contrário do `.page-bg`), mas reservar uma margem fixa reduz o espaço
   útil de conteúdo em TODA página, o que faz o mecanismo de manter bloco
   junto empurrar seções inteiras mais cedo — trocou um vão isolado na
   última página por vãos menores espalhados pelo meio do documento. Pior.
3. **Medição real, duas passadas** (o que ficou): renderiza uma vez,
   rasteriza só a ÚLTIMA página com `pdftoppm` (poppler) e varre de baixo
   pra cima com `Pillow` procurando onde o branco (a cor do vão, não a cor
   de fundo — cuidado, inverter essa lógica é o bug mais fácil de
   reintroduzir aqui) começa. Só assim sabe o tamanho EXATO do
   preenchimento necessário — sem chute, sem estourar página nova
   (`measure_trailing_gap_mm`, margem de segurança de 3mm pra baixo). A
   medição subestima um pouco o vão real (transição anti-serrilhada entre
   conteúdo e branco) — por isso o loop em `convert()` é **iterativo** (até
   3 rodadas: mede, preenche, mede de novo, completa o que ainda faltar),
   não confia na primeira medição sozinha. Só roda passada extra se o vão
   for > 5mm (documentos que já preenchem a página não pagam o custo extra).

## Ajustar depois

- **Espaçamento**: `line-height`/`margin` de `p`, `h2`, `h3` dentro de `css()`.
- **Quebra de página**: tabela/`pre`/`blockquote`/`details`/`p` logo após
  um `h2`/`h3` viram um bloco só (ver "Como funciona", item 7) — se não
  couber, o bloco pula inteiro pra próxima página, nunca quebra no meio.
- **Novo tipo de documento**: somar entrada em `TYPE_ACCENT`.
- **Não usar `display:flex`** no CSS — `wkhtmltopdf` não renderiza direito.
- **DPI da medição de vão** (`measure_trailing_gap_mm`, param `dpi`): 100 é
  suficiente e rápido; só subir se algum falso positivo aparecer (texto
  muito fino não detectado).

## Problemas conhecidos

- Emoji: só `✅`/`❌`/`⚠️` têm tratamento (viram `✔`/`✘`/`⚠` coloridos via
  CSS — são os 3 usados de verdade nos templates de `testes.md`). Outro
  emoji que aparecer num doc não vai renderizar bem — considerar o mesmo
  tratamento se acontecer.
- `pr_pending` aparece marcado como "(pendente)" na mesma linha de
  `pr_merged` — não tem badge visual diferente, só o texto.
- Sem `poppler`/`Pillow` instalados, o PDF sai correto mas a última página
  pode sobrar com uma tira branca no fim (ver seção acima) — não é erro,
  é a correção automática que não roda sem essas duas dependências.
- No Chrome, pode aparecer uma tira branca **só depois da última página**
  (não entre páginas) mesmo com o PDF correto — confirmado via inspeção
  direta do content stream (`pikepdf`) e renderização via `poppler`: o
  retângulo de fundo cobre a página inteira, sem nenhum fill branco. É
  comportamento do visualizador (espaço reservado após o fim do
  documento), não do arquivo — testar noutro visualizador (Edge, leitor
  padrão do Windows) confirma.

## Reinstalar/diagnosticar (só se a conversão falhar de verdade)

Checar dependências:

```powershell
python --version
pandoc --version
wkhtmltopdf --version
python -c "import yaml; print('pyyaml OK')"
python -c "from PIL import Image; print('Pillow OK')"
pdfinfo -v
```

Instalar o que faltar:

```powershell
winget install --id Python.Python.3.12 -e
winget install --id JohnMacFarlane.Pandoc -e
winget install --id wkhtmltopdf.wkhtmltox -e
winget install --id oschwartz10612.Poppler -e
python -m pip install pyyaml pillow
```

`wkhtmltopdf` **não fica no PATH persistido** nesta máquina (nem usuário
nem sistema — confirmado, 2026-09-11) mesmo depois de instalado; funciona
só por causa do fallback hardcoded no script
(`_WKHTMLTOPDF_FALLBACK_PATH`, aponta pra `C:\Program Files\wkhtmltopdf\bin`).
`pandoc` e `poppler` ficam no PATH do usuário normalmente. Se reinstalar
`wkhtmltopdf` numa versão/pasta diferente, atualizar esse path fixo no
script.

`poppler`/`Pillow` são **opcionais**: sem eles, o script converte
normalmente, só sem a correção de fundo branco no fim da última página.
