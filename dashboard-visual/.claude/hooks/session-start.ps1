# Hook SessionStart - escopado a este projeto via .claude/settings.json
# (nao precisa checar cwd - so roda quando o Claude Code abre com este projeto)

# Forcar UTF-8 na saida - sem isso os titulos com acento (lidos em UTF-8 dos
# .md da Biblioteca) saem corrompidos ao cruzar a fronteira de encoding do
# console. Invocar o script direto (sem "powershell -File" filho) tambem
# evita uma segunda fronteira de encoding entre processos.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$statusScript = Join-Path $PSScriptRoot '..\..\..\scripts\status.ps1'
$listing = (& $statusScript -Numbered 2>&1 | Out-String).Trim()

# Mantem o dashboard.html atualizado a cada sessao - caminho principal de
# visualizacao (fora do chat); erro aqui nao deve travar a listagem de texto.
$dashboardScript = Join-Path $PSScriptRoot '..\..\scripts\build-dashboard.ps1'
try { & $dashboardScript *> $null } catch {}

$output = [PSCustomObject]@{
    systemMessage      = $listing
    hookSpecificOutput = [PSCustomObject]@{
        hookEventName     = 'SessionStart'
        additionalContext = $listing
    }
} | ConvertTo-Json -Compress

Write-Output $output
