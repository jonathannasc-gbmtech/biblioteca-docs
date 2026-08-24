' Handler dos protocolos custom "biblioteca-cmd:"/"biblioteca-cmd-run:"
' registrados via register-protocol.ps1. Recebe a URI clicada no dashboard/
' resumo (<protocolo>:<comando url-encoded>), abre um cmd novo e DIGITA o
' comando decodificado. "biblioteca-cmd:" NUNCA aperta Enter (usuario revisa
' e confirma manualmente - task nova, retomar, ajustar QA). "biblioteca-cmd-
' run:" aperta Enter sozinho - so pra acao sem risco de disparar skill/gravar
' nada (ex: abrir uma janela solta do Claude num repo).
Option Explicit

Dim uri, prefixRun, prefixManual, encoded, decoded, shell, autoEnter

If WScript.Arguments.Count < 1 Then WScript.Quit 1
uri = WScript.Arguments(0)

prefixRun = "biblioteca-cmd-run:"
prefixManual = "biblioteca-cmd:"
autoEnter = False
If LCase(Left(uri, Len(prefixRun))) = prefixRun Then
    encoded = Mid(uri, Len(prefixRun) + 1)
    autoEnter = True
ElseIf LCase(Left(uri, Len(prefixManual))) = prefixManual Then
    encoded = Mid(uri, Len(prefixManual) + 1)
Else
    encoded = uri
End If

decoded = UrlDecode(encoded)

' Allowlist antes de digitar/executar. O registro do protocolo (ver
' register-protocol.ps1) e' global em HKCU - QUALQUER app/pagina do
' sistema pode invocar "biblioteca-cmd-run:<payload>", nao so' o
' dashboard.html local. Sem essa checagem, um payload arbitrario de
' origem nenhuma confiavel seria digitado e executado (com Enter
' automatico na variante -run) sem revisao nenhuma - achado real da
' auditoria de 2026-08-24 (2 de 3 revisores blind apontaram isso
' independentemente). Toda invocacao legitima gerada hoje
' (build-dashboard.ps1 Get-CardCommands/quick-open, nova-task.html)
' comeca exatamente com este prefixo; qualquer coisa fora disso, ou com
' metacaractere de encadeamento do cmd.exe (permitiria rodar um 2o
' comando depois do nosso, mesmo batendo o prefixo), e' bloqueada.
If Not IsAllowedCommand(decoded) Then
    MsgBox "Comando bloqueado - nao bate com o formato esperado do protocolo biblioteca-cmd. Se voce clicou isso a partir do dashboard.html da Biblioteca, isso e' um bug (avise o autor); se veio de outro lugar, o bloqueio e' o comportamento certo.", vbExclamation, "Biblioteca - comando bloqueado"
    WScript.Quit 1
End If

Set shell = CreateObject("WScript.Shell")
shell.Run "cmd.exe /k", 1, False
WScript.Sleep 400
shell.AppActivate "cmd.exe"
WScript.Sleep 100
shell.SendKeys EscapeSendKeys(decoded)
If autoEnter Then shell.SendKeys "{ENTER}"

' Formato exato que todo gerador legitimo usa (Get-CardCommands/
' Get-LaunchUri em build-dashboard.ps1, o builder em nova-task.html):
' powershell -NoProfile -Command "cd '<path>'; claude [...]
Const EXPECTED_PREFIX = "powershell -NoProfile -Command ""cd '"

Function IsAllowedCommand(cmd)
    Dim hasChainChar
    hasChainChar = (InStr(cmd, "&") > 0) Or (InStr(cmd, "|") > 0) _
        Or (InStr(cmd, "<") > 0) Or (InStr(cmd, ">") > 0) _
        Or (InStr(cmd, Chr(13)) > 0) Or (InStr(cmd, Chr(10)) > 0)
    IsAllowedCommand = (Left(cmd, Len(EXPECTED_PREFIX)) = EXPECTED_PREFIX) And (Not hasChainChar)
End Function

Function UrlDecode(s)
    Dim result, i, ch, hex
    result = ""
    i = 1
    Do While i <= Len(s)
        ch = Mid(s, i, 1)
        If ch = "%" And i + 2 <= Len(s) Then
            hex = Mid(s, i + 1, 2)
            result = result & Chr(CLng("&H" & hex))
            i = i + 3
        ElseIf ch = "+" Then
            result = result & " "
            i = i + 1
        Else
            result = result & ch
            i = i + 1
        End If
    Loop
    UrlDecode = result
End Function

' SendKeys trata + ^ % ~ ( ) { } [ ] como especiais - envolver cada um em
' chaves faz literal (regra padrao do SendKeys, ver docs do VBScript).
Function EscapeSendKeys(s)
    Dim i, ch, result
    result = ""
    For i = 1 To Len(s)
        ch = Mid(s, i, 1)
        Select Case ch
            Case "{": result = result & "{{}"
            Case "}": result = result & "{}}"
            Case "+": result = result & "{+}"
            Case "^": result = result & "{^}"
            Case "%": result = result & "{%}"
            Case "~": result = result & "{~}"
            Case "(": result = result & "{(}"
            Case ")": result = result & "{)}"
            Case "[": result = result & "{[}"
            Case "]": result = result & "{]}"
            Case Else: result = result & ch
        End Select
    Next
    EscapeSendKeys = result
End Function
