# Setup unico (por maquina) dos protocolos customizados "biblioteca-cmd:" e
# "biblioteca-cmd-run:" - permitem que um link do dashboard/resumo abra
# direto um cmd novo com o comando ja digitado (ver launch-command.vbs), sem
# copiar/colar manual. "biblioteca-cmd:" nunca aperta Enter (usuario revisa);
# "biblioteca-cmd-run:" aperta Enter sozinho - so pra acoes sem risco (abrir
# uma janela solta do Claude num repo). So HKCU (usuario atual), nao precisa
# admin. Idempotente - rodar de novo so sobrescreve as mesmas chaves.
#
# Desfazer: reg delete "HKCU\Software\Classes\biblioteca-cmd" /f
#           reg delete "HKCU\Software\Classes\biblioteca-cmd-run" /f

$vbsPath = Join-Path $PSScriptRoot 'launch-command.vbs'
if (-not (Test-Path $vbsPath)) {
    Write-Error "launch-command.vbs nao encontrado em $vbsPath"
    exit 1
}

function Register-BibliotecaProtocol([string]$scheme, [string]$description) {
    $keyPath = "HKCU:\Software\Classes\$scheme"
    New-Item -Path $keyPath -Force | Out-Null
    Set-ItemProperty -Path $keyPath -Name '(Default)' -Value $description
    Set-ItemProperty -Path $keyPath -Name 'URL Protocol' -Value ''

    $commandKeyPath = Join-Path $keyPath 'shell\open\command'
    New-Item -Path $commandKeyPath -Force | Out-Null
    $command = "wscript.exe `"$vbsPath`" `"%1`""
    Set-ItemProperty -Path $commandKeyPath -Name '(Default)' -Value $command
}

Register-BibliotecaProtocol 'biblioteca-cmd' 'URL:Biblioteca Cmd Protocol'
Register-BibliotecaProtocol 'biblioteca-cmd-run' 'URL:Biblioteca Cmd Run Protocol'

Write-Host "Protocolos 'biblioteca-cmd:' e 'biblioteca-cmd-run:' registrados (HKCU) -> $vbsPath" -ForegroundColor Green
Write-Host 'Pra desfazer:  reg delete "HKCU\Software\Classes\biblioteca-cmd" /f'
Write-Host '               reg delete "HKCU\Software\Classes\biblioteca-cmd-run" /f'
