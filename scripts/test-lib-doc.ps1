# Auto-check do Parse-Frontmatter (ponytail: 1 assert executavel, sem
# framework) - Parse-Frontmatter e' compartilhada por 10+ scripts sem
# nenhum teste; foi a causa raiz do bug que corrompeu 42 docs (commit
# 9a4edaf: $Matches sobrescrito por um -match dentro do foreach que le o
# metaBlock, corrompendo o calculo de $frontmatterLen/.Body). Rodar depois
# de qualquer mudanca em Parse-Frontmatter/Serialize-Frontmatter.
. (Join-Path $PSScriptRoot 'lib-doc.ps1')

$failures = @()
function Assert($cond, [string]$label) {
    if (-not $cond) { $script:failures += $label }
}

# 1. Corpo com varias linhas "chave: valor"/"- item" depois do frontmatter -
# exatamente o padrao que corrompia .Body antes do fix (9a4edaf): o foreach
# interno de Parse-Frontmatter faz -match linha a linha, e ISSO sobrescreve
# a variavel automatica $Matches do match externo se ela for lida depois
# do loop em vez de capturada antes.
$doc1 = @"
---
number: 1
type: testes
related:
  - a/b.md
  - c/d.md
---
# Titulo

- item 1: nao e frontmatter
- item 2: so texto parecido com YAML
outra: linha parecida com chave-valor, mas e' corpo
"@ -replace "`r`n", "`n"
$p1 = Parse-Frontmatter $doc1
Assert ($null -ne $p1) 'doc1: parse nao deve retornar null'
Assert ($p1.Body.TrimStart().StartsWith('# Titulo')) 'doc1: Body deve comecar em "# Titulo" (nao truncado/deslocado)'
Assert ($p1.Body -match 'item 2: so texto parecido com YAML') 'doc1: Body deve conter as linhas depois do frontmatter'

# 2. related: como lista YAML
Assert (@($p1.Meta['related']).Count -eq 2) 'doc1: related deve ter 2 itens'
Assert (@($p1.Meta['related'])[0] -eq 'a/b.md') 'doc1: 1o item de related deve ser a/b.md'

# 3. Doc sem frontmatter -> null, sem excecao
$doc2 = "# Sem frontmatter`nSo corpo, sem YAML na frente."
$p2 = Parse-Frontmatter $doc2
Assert ($null -eq $p2) 'doc2: sem frontmatter deve retornar null'

# 4. Valor escalar com ':' embutido (ex.: URL) nao quebra o parser
$doc3 = @"
---
number: 2
type: resumo
function: Algo com : dois pontos no meio
---
Corpo.
"@ -replace "`r`n", "`n"
$p3 = Parse-Frontmatter $doc3
Assert ($null -ne $p3) 'doc3: parse nao deve retornar null'
Assert ($p3.Meta['function'] -eq 'Algo com : dois pontos no meio') 'doc3: valor com ":" embutido deve ficar intacto'

if ($failures.Count -gt 0) {
    Write-Host "test-lib-doc: $($failures.Count) falha(s):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host 'test-lib-doc: ok (4 casos).'
