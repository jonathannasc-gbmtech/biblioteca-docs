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

Set shell = CreateObject("WScript.Shell")
shell.Run "cmd.exe /k", 1, False
WScript.Sleep 400
shell.AppActivate "cmd.exe"
WScript.Sleep 100
shell.SendKeys EscapeSendKeys(decoded)
If autoEnter Then shell.SendKeys "{ENTER}"

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
