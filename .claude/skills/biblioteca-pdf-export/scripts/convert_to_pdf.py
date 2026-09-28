#!/usr/bin/env python3
"""Biblioteca -> PDF (tema escuro). Uso: python convert_to_pdf.py <arquivo.md> [saida.pdf]

Motor unico: wkhtmltopdf (build "patched Qt", suporta --header-html/
--footer-html com fundo colorido). weasyprint foi testado e descartado
nesta maquina - falha ao carregar libgobject mesmo com o runtime GTK3
oficial instalado (2 tentativas: pacote winget GtkD.GtkPlusRuntime.x64
e o instalador oficial tschoonj/GTK-for-Windows-Runtime-Environment-
Installer, ambas com o mesmo erro). Nao reintroduzir o fallback duplo
sem motivo novo - decisao deliberada de manter 1 caminho so.
"""
import sys, re, os, subprocess, html, shutil, tempfile, glob
import yaml

THEME = {
    "bg": "#1c1e21", "card": "#24262a", "card_alt": "#202226",
    "border": "#34363b", "text": "#eceeef", "muted": "#9a9da3", "dim": "#6f7278",
    "gold": "#d9b568", "gold_bright": "#d9b26a", "green": "#86b894", "teal": "#7cbfc4",
    "pink": "#c184a0", "purple": "#9a83c9", "blue": "#6f9bd1", "brown": "#a89484",
    "red": "#ef4444", "yellow": "#eab308",
    "code_bg": "#141517",
}

# Cores por tipo = MESMAS cores dos chips do dashboard real
# (_ferramenta/dashboard-visual/scripts/build-dashboard.ps1, .chip-*) -
# nao inventar paleta paralela. reqs/resumo nao tem chip no dashboard
# (resumo e' o doc "representante" do card, reqs nem entra no sync-all),
# cor propria so' pra dar uma identidade visual no PDF.
TYPE_ACCENT = {
    "task-code": THEME["gold"],
    "task-planning": THEME["teal"],
    "testes": THEME["green"],
    "handover-tecnico": THEME["pink"],
    "rules": THEME["brown"],
    "reqs": THEME["blue"],
    "resumo": THEME["purple"],
}
DEFAULT_ACCENT = THEME["gold_bright"]

# Vocabulario real de status da Biblioteca (01-regras-biblioteca.md /
# controle-documentacao) - "blocked" nao existe, nao inventar.
STATUS_LABEL = {
    "draft": "Rascunho", "in_progress": "Em andamento", "completed": "Concluído",
    "superseded": "Substituído", "archived": "Arquivado",
}


def split_frontmatter(text):
    m = re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.DOTALL)
    if not m:
        return {}, text
    return yaml.safe_load(m.group(1)) or {}, m.group(2)


def build_pr_html(fm):
    """Junta pr_merged (sempre) + pr_pending (marcado como pendente) - um
    doc in_progress com PR aberto tambem deve aparecer no PDF, nao so
    o que ja foi mergeado."""
    parts = []
    for url in (fm.get("pr_merged") or "").split():
        parts.append(f'<a href="{html.escape(url)}">PR</a>')
    for url in (fm.get("pr_pending") or "").split():
        parts.append(f'<a href="{html.escape(url)}">PR (pendente)</a>')
    if not parts:
        return ""
    return f'<div class="pr-line"><span class="meta-label">PRs</span>&nbsp; {" &nbsp;•&nbsp; ".join(parts)}</div>'


def build_header(fm, doc_title):
    accent = TYPE_ACCENT.get(fm.get("type", ""), DEFAULT_ACCENT)
    # titulo_busca e' o titulo primario (convencao do dashboard, 2026-09-11
    # - card mostra titulo_busca em destaque, function vira subtitulo). Sem
    # titulo_busca, function vira o titulo sozinho (sem subtitulo).
    titulo_busca = fm.get("titulo_busca")
    function = fm.get("function")
    primary = titulo_busca or function or doc_title
    subtitle = function if (titulo_busca and function) else None

    status = fm.get("status", "")
    label = STATUS_LABEL.get(status, status)
    fields = [("task", "Task"), ("type", "Tipo"), ("repo", "Repositório"), ("author", "Autor"), ("updated", "Atualizado")]
    items = "".join(
        f'<span class="meta-item"><span class="meta-label">{html.escape(l)}</span>'
        f'<span class="meta-value">{html.escape(str(fm.get(k)))}</span></span>'
        for k, l in fields if fm.get(k)
    )
    subtitle_html = f'<div class="doc-subtitle">{html.escape(subtitle)}</div>' if subtitle else ""
    pr_html = build_pr_html(fm)
    return f'''
    <div class="doc-header" style="border-bottom:2px solid {accent}">
      <div class="doc-header-top">
        <span class="doc-number">#{fm.get("number", "")}</span>
        <span class="status-badge" style="color:{accent};background:{accent}22;border:1px solid {accent}55">{html.escape(label)}</span>
        <span class="type-tag" style="color:{accent}">{html.escape(fm.get("type", ""))}</span>
      </div>
      <h1 class="doc-title">{html.escape(primary)}</h1>
      {subtitle_html}
      <div class="meta-grid">{items}</div>
      {pr_html}
    </div>'''


def css(accent):
    # margem nativa do wkhtmltopdf fica em 0 (ver render_pdf) - "margem" visual
    # e' esse padding do body, nao flag de linha de comando. Motivo: --header-html/
    # --footer-html (mesmo com build "patched Qt") so' pintam a tira de topo/rodape,
    # as laterais (--margin-left/right) continuam brancas sempre - so da pra ter
    # fundo escuro sangrando ate a borda de verdade fazendo o fundo cobrir a
    # pagina inteira (margem nativa 0) e simulando a margem com padding aqui.
    # Familia e tamanhos alinhados ao padrao real da Biblioteca (dashboard-visual/
    # scripts/build-dashboard.ps1): mesma stack de fonte (system-ui/Segoe UI, nao
    # Helvetica Neue) e mesma stack monoespacada (ui-monospace/SF Mono - Courier
    # New e' mais dificil de ler em corpo pequeno). Tamanhos em pt calculados a
    # partir dos rem do dashboard (1rem tela = 16px = 12pt) com folga de leitura
    # pra papel/PDF - nao e' so' converter 1:1, letra pequena de tela fica ainda
    # menor impressa.
    # "ui-monospace" nao e' nome de fonte de verdade (keyword CSS4) - esse
    # motor antigo (WebKit do wkhtmltopdf) nao resolve direito e cai num
    # substituto sintetico/mal hinted (traco irregular, "fantasma" no texto -
    # visivel no Chrome, mesmo com o PDF tecnicamente correto). Comecar
    # direto com uma fonte real sempre instalada no Windows.
    mono = 'Consolas, "Cascadia Code", "Courier New", monospace'
    return f'''
    html {{ margin:0; padding:0; background:{THEME["bg"]}; }}
    * {{ box-sizing:border-box; }}
    body {{ background:{THEME["bg"]}; color:{THEME["text"]}; font-family:system-ui, -apple-system, "Segoe UI", sans-serif;
            font-size:12pt; line-height:1.65; margin:0; padding:20mm 15mm 16mm 15mm; }}
    /* position:fixed e' repetido pagina a pagina pelo wkhtmltopdf (unico jeito
       real de garantir fundo escuro ate' a ultima pagina - sem isso, a area
       da pagina abaixo de onde o conteudo termina fica branca, porque o
       fundo do body so' cobre a altura que o conteudo realmente ocupa). */
    .page-bg {{ position:fixed; top:0; right:0; bottom:0; left:0; background:{THEME["bg"]}; z-index:-1; }}
    .doc-header {{ padding-bottom:20px; margin-bottom:30px; }}
    .doc-header-top {{ margin-bottom:10px; }}
    .doc-number {{ font-family:{mono}; color:{THEME["dim"]}; font-size:10.5pt; margin-right:12px; }}
    .status-badge {{ display:inline-block; padding:3px 12px; border-radius:14px; font-size:9.5pt; font-weight:600; margin-right:8px; }}
    .type-tag {{ font-family:{mono}; font-size:9.5pt; opacity:0.85; }}
    .doc-title {{ font-size:19pt; margin:10px 0 4px 0; color:#ffffff; line-height:1.35; }}
    .doc-subtitle {{ font-size:12pt; color:{THEME["muted"]}; margin:0 0 16px 0; }}
    .meta-grid {{ margin:0 0 8px 0; }}
    .meta-item {{ display:inline-block; margin:0 30px 6px 0; vertical-align:top; }}
    .meta-label {{ color:{THEME["dim"]}; font-size:8.5pt; text-transform:uppercase; letter-spacing:0.05em; display:block; }}
    .meta-value {{ color:{THEME["text"]}; font-weight:600; font-size:11pt; display:block; margin-top:2px; }}
    .pr-line {{ margin-top:10px; font-size:11pt; color:{THEME["muted"]}; }}
    .pr-line a {{ color:{accent}; text-decoration:none; }}
    h1,h2,h3 {{ color:#ffffff; }}
    /* wkhtmltopdf (WebKit antigo) so' obedece as propriedades page-break-*
       classicas - break-inside/break-after (nome novo da spec de fragmentacao
       CSS3) sao ignoradas silenciosamente nesse motor. As duas juntas (h2/h3
       com page-break-after:avoid + a tabela/bloco seguinte com
       page-break-inside:avoid) e' o que faz o motor empurrar o subtitulo
       INTEIRO com o bloco pra proxima pagina em vez de deixar o subtitulo
       orfao no rodape ou quebrar o bloco no meio. */
    h2 {{ font-size:15pt; margin-top:34px; margin-bottom:14px; padding-bottom:6px;
          border-bottom:1px solid {THEME["border"]}; page-break-after:avoid; break-after:avoid; }}
    h3 {{ font-size:13pt; color:{accent}; margin-top:22px; margin-bottom:8px; page-break-after:avoid; break-after:avoid; }}
    p {{ margin:9px 0; orphans:3; widows:3; }}
    ul, ol {{ margin:9px 0; padding-left:24px; }}
    li {{ margin:4px 0; }}
    table {{ border-collapse:collapse; width:100%; margin:16px 0; font-size:10.5pt; page-break-inside:avoid; break-inside:avoid; }}
    caption {{ caption-side:top; text-align:left; font-size:13pt; font-weight:600; color:{accent}; margin-bottom:8px; }}
    thead {{ display:table-header-group; }}
    th, td {{ border:1px solid {THEME["border"]}; padding:7px 10px; text-align:left; vertical-align:top; }}
    th {{ background:{THEME["card_alt"]}; color:{accent}; font-weight:600; }}
    td {{ background:{THEME["card"]}; }}
    tr {{ page-break-inside:avoid; break-inside:avoid; }}
    .keep-together {{ page-break-inside:avoid; break-inside:avoid; }}
    code {{ font-family:{mono}; background:{THEME["code_bg"]}; color:{THEME["gold_bright"]};
            padding:2px 5px; border-radius:3px; font-size:10.5pt; }}
    pre {{ background:{THEME["code_bg"]}; color:#d8dadd; padding:14px 16px; border-radius:8px;
           overflow-x:auto; font-size:10pt; margin:14px 0; border:1px solid {THEME["border"]}; page-break-inside:avoid; break-inside:avoid; }}
    pre code {{ background:none; color:inherit; padding:0; }}
    blockquote {{ border-left:3px solid {accent}; margin:14px 0; padding:8px 16px; color:{THEME["muted"]};
                  background:{THEME["card"]}; border-radius:0 6px 6px 0; page-break-inside:avoid; break-inside:avoid; }}
    details {{ border:1px solid {THEME["border"]}; border-radius:8px; padding:12px 16px; margin:20px 0;
               background:{THEME["card"]}; page-break-inside:avoid; break-inside:avoid; }}
    summary {{ font-weight:600; color:{accent}; cursor:pointer; }}
    strong {{ color:#ffffff; }}
    hr {{ border:none; border-top:1px solid {THEME["border"]}; margin:26px 0; }}
    a {{ color:{THEME["teal"]}; }}
    .footer-note {{ margin-top:36px; padding-top:12px; border-top:1px solid {THEME["border"]};
                    font-size:8.5pt; color:{THEME["dim"]}; }}
    '''


# (?:(?!</?h[23]\b).)* em vez de .* - sem isso, um heading que NAO e' seguido
# de tabela/bloco (ex.: "### Comando" seguido de <pre>) faz o .*? non-greedy
# atravessar até o PROXIMO heading real (ex.: "### Resultado"), engolindo a
# tag <h3> dele inteira como texto capturado - bug real, encontrado com
# debug.py (virou "<h3 id=\"resultado\">Resultado</caption>" ao inves de so'
# "Resultado</caption>").
_HEADING_TEXT = r'(?:(?!</?h[23]\b).)*?'
_HEADING_PLUS_TABLE_RE = re.compile(r'<h[23][^>]*>(' + _HEADING_TEXT + r')</h[23]>\s*<table>', re.DOTALL)
_HEADING_PLUS_BLOCK_RE = re.compile(
    r'(<h[23][^>]*>' + _HEADING_TEXT + r'</h[23]>)\s*'
    r'(<(?:pre|blockquote|details|p)\b.*?</(?:pre|blockquote|details|p)>)',
    re.DOTALL,
)


def wrap_heading_with_next_block(body_html):
    """h2/h3 seguido direto de tabela/pre/blockquote/details nao pode ficar
    orfao numa pagina enquanto o bloco vai pra proxima - testado com div
    wrapper (page-break-inside:avoid) e o wkhtmltopdf ignorou, deixou o
    subtitulo sozinho na pagina anterior mesmo assim (motor antigo trata
    <table> com paginacao propria, nao respeita o page-break do <div> em
    volta). Fix pra tabela: virar <caption> DENTRO da propria <table> - isso
    e' nativamente inseparavel da tabela em qualquer motor, nao depende de
    page-break funcionar em elemento nenhum. Pre/blockquote/details continuam
    com o wrapper de div (nao tem equivalente a caption, melhor esforco)."""
    body_html = _HEADING_PLUS_TABLE_RE.sub(r'<table><caption>\1</caption>', body_html)
    return _HEADING_PLUS_BLOCK_RE.sub(r'<div class="keep-together">\1\2</div>', body_html)


def convert(md_path, pdf_path):
    raw = open(md_path, encoding="utf-8").read()
    fm, body = split_frontmatter(raw)
    accent = TYPE_ACCENT.get(fm.get("type", ""), DEFAULT_ACCENT)
    doc_title = os.path.basename(md_path).rsplit(".", 1)[0]

    body = body.replace("<details>", "<details open>")
    body = re.sub(r'<!-- badge:auto -->.*?<!-- /badge:auto -->\n?', '', body, flags=re.DOTALL)
    body = re.sub(r'<!-- related:auto -->.*?<!-- /related:auto -->\n?', '', body, flags=re.DOTALL)
    body = re.sub(r'<!-- meta:auto -->.*?<!-- /meta:auto -->\n?', '', body, flags=re.DOTALL)
    # Emoji que os templates novos usam em tabela (testes.md: Teste|Resultado
    # com nota inline) - so trocar os 3 usados de verdade, nao todo emoji.
    body = body.replace("✅", f'<span style="color:{THEME["green"]}">✔</span>')
    body = body.replace("❌", f'<span style="color:{THEME["red"]}">✘</span>')
    body = body.replace("⚠️", f'<span style="color:{THEME["yellow"]}">⚠</span>')

    body_html = subprocess.run(
        ["pandoc", "--from=markdown+pipe_tables+fenced_code_blocks", "--to=html5"],
        input=body, capture_output=True, text=True, encoding="utf-8").stdout
    body_html = wrap_heading_with_next_block(body_html)

    # <title> = nome do arquivo .md (sem extensao) - metadado do PDF em si
    # (aba do leitor/propriedade do arquivo), separado do H1 visual dentro
    # do documento (que usa titulo_busca/function).
    full_html = f'''<!DOCTYPE html><html><head><meta charset="utf-8"><title>{html.escape(doc_title)}</title><style>{css(accent)}</style></head>
    <body><div class="page-bg"></div>{build_header(fm, doc_title)}{body_html}
    <div class="footer-note">Convertido de {html.escape(os.path.basename(md_path))} — Biblioteca de documentação técnica</div>
    </body></html>'''

    with tempfile.TemporaryDirectory() as tmpdir:
        html_path = os.path.join(tmpdir, doc_title + ".html")
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(full_html)
        render_pdf(html_path, pdf_path)

        # Passadas extras, so' se sobrar vao real: mede o branco de verdade na
        # ULTIMA pagina do PDF ja gerado (via poppler) e completa com um
        # preenchimento - ver measure_trailing_gap_mm pra por que isso
        # substitui o calculo teorico (JS/altura de pagina), que se mostrou
        # errado na pratica. A medicao subestima um pouco o vao real (a
        # transicao anti-serrilhada entre conteudo e branco nao bate 100% com
        # "branco puro") - por isso ITERATIVO: mede de novo depois de
        # preencher e completa o que ainda faltar, em vez de confiar na
        # primeira medicao sozinha. Poucas iteracoes (a diferenca cai rapido
        # a cada rodada); limite de seguranca pra nunca rodar pra sempre.
        filler_mm = 0.0
        for _ in range(3):
            gap_mm = measure_trailing_gap_mm(pdf_path)
            if gap_mm <= 5:
                break
            filler_mm += gap_mm
            filler_html = full_html.replace(
                "</body>",
                f'<div style="height:{filler_mm:.1f}mm;background:{THEME["bg"]}"></div></body>',
            )
            with open(html_path, "w", encoding="utf-8") as f:
                f.write(filler_html)
            render_pdf(html_path, pdf_path)
    print("OK:", pdf_path)


# Caminho de instalacao padrao do winget (wkhtmltopdf.wkhtmltox) - usado
# como fallback quando o binario nao esta no PATH da sessao atual (comum
# logo apos instalar via winget, antes de abrir um terminal novo).
_WKHTMLTOPDF_FALLBACK_PATH = r"C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe"


def find_wkhtmltopdf():
    found = shutil.which("wkhtmltopdf")
    if found:
        return found
    if os.path.exists(_WKHTMLTOPDF_FALLBACK_PATH):
        return _WKHTMLTOPDF_FALLBACK_PATH
    return None


def find_poppler_tool(name):
    """pdfinfo/pdftoppm (poppler) - opcional, so' usado pra medir o vao branco
    real da ultima pagina (ver measure_trailing_gap_mm). Path do winget tem
    numero de versao (muda a cada update do poppler), por isso glob em vez de
    caminho fixo como o _WKHTMLTOPDF_FALLBACK_PATH acima."""
    exe = name + ".exe"
    found = shutil.which(exe)
    if found:
        return found
    pattern = os.path.join(
        os.environ.get("LOCALAPPDATA", ""),
        "Microsoft", "WinGet", "Packages", "oschwartz10612.Poppler_*",
        "poppler-*", "Library", "bin", exe,
    )
    matches = glob.glob(pattern)
    return matches[0] if matches else None


def measure_trailing_gap_mm(pdf_path, dpi=100):
    """Renderiza SO' a ultima pagina do PDF (poppler) e mede, em pixel, quanto
    fundo sobra abaixo do ultimo pixel de conteudo real (nao-fundo) - unico
    jeito confiavel de saber o tamanho exato do preenchimento sem estourar
    pra uma pagina nova (calculo teorico via altura total/altura de pagina
    testado e descartado - a propria logica de manter subtitulo+bloco juntos
    ja cria vaos no MEIO do documento, entao "altura total" nao tem relacao
    simples com o que sobra de verdade na ultima pagina). Sem poppler/Pillow
    instalado, degrada bem: retorna 0 (sem preenchimento, comportamento de
    antes)."""
    pdfinfo, pdftoppm = find_poppler_tool("pdfinfo"), find_poppler_tool("pdftoppm")
    if not pdfinfo or not pdftoppm:
        return 0
    try:
        from PIL import Image
    except ImportError:
        return 0

    info = subprocess.run([pdfinfo, pdf_path], capture_output=True, text=True).stdout
    m = re.search(r'Pages:\s+(\d+)', info)
    if not m:
        return 0
    last_page = int(m.group(1))

    with tempfile.TemporaryDirectory() as tmpdir:
        prefix = os.path.join(tmpdir, "last")
        subprocess.run(
            [pdftoppm, "-png", "-r", str(dpi), "-f", str(last_page), "-l", str(last_page), pdf_path, prefix],
            capture_output=True, text=True,
        )
        pngs = glob.glob(prefix + "*.png")
        if not pngs:
            return 0

        img = Image.open(pngs[0]).convert("RGB")
        width, height = img.size
        pixels = img.load()
        # o vao em branco e' justamente BRANCO - nao bate com o fundo escuro
        # de jeito nenhum, entao "linha que nao e' o fundo" tambem da match
        # na primeira linha (bug real, gap sempre saia 0). O que queremos e'
        # achar onde o branco COMECA, varrendo de baixo pra cima.
        white = (255, 255, 255)
        tolerance = 3

        content_end = height
        for y in range(height - 1, -1, -1):
            row_is_white = all(
                all(abs(pixels[x, y][c] - white[c]) <= tolerance for c in range(3))
                for x in range(0, width, 4)
            )
            if not row_is_white:
                content_end = y + 1
                break

        gap_px = height - content_end
        gap_mm = gap_px / dpi * 25.4
        return max(0, gap_mm - 3)  # margem de seguranca, nao estourar pra pagina nova


def render_pdf(html_path, pdf_path):
    wkhtml = find_wkhtmltopdf()
    if not wkhtml:
        raise RuntimeError(
            "wkhtmltopdf nao encontrado. Instalar: "
            "winget install --id wkhtmltopdf.wkhtmltox "
            "(depois abrir um terminal novo pra pegar o PATH atualizado)."
        )

    # Margem nativa 0 - o fundo escuro do body+.page-bg cobre a pagina inteira
    # ate a borda; a margem visual e' o padding do body em css(). Testado
    # reservar margem nativa de verdade + --footer-html pra fixar um rodape
    # sempre escuro (2026-09-11) - piorou: reduz o espaco util de conteudo em
    # TODA pagina, o que faz o mecanismo de manter subtitulo+bloco juntos
    # empurrar secoes inteiras mais cedo, criando vaos em branco NO MEIO de
    # varias paginas (nao so' na ultima). Revertido - o unico vao residual
    # aceito fica isolado na ultima pagina (ver comentario em
    # wrap_heading_with_next_block).
    result = subprocess.run(
        [wkhtml, "--enable-local-file-access", "--background",
         "--margin-top", "0", "--margin-bottom", "0",
         "--margin-left", "0", "--margin-right", "0",
         "-q", html_path, pdf_path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"wkhtmltopdf falhou: {result.stderr}")
    print("(motor: wkhtmltopdf)")


def default_output_path(md_path):
    """Sem saida explicita, o PDF vai pra Biblioteca/exportacoes/ (ver SKILL.md)
    - doc.md mora sempre em Biblioteca/{tipo}/doc.md (estrutura flat, sem
    frontend/backend), entao exportacoes/ e' irmã da pasta do tipo."""
    biblioteca_root = os.path.dirname(os.path.dirname(os.path.abspath(md_path)))
    basename = os.path.basename(md_path).rsplit(".", 1)[0]
    return os.path.join(biblioteca_root, "exportacoes", basename + ".pdf")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python convert_to_pdf.py <arquivo.md> [saida.pdf]")
        sys.exit(1)
    md = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else default_output_path(md)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    convert(md, out)
