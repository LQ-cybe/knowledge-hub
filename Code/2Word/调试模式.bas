Attribute VB_Name = "调试模式"
    Option Explicit
    ' 声明 Windows API 函数
    Private Declare PtrSafe Function GetSystemMetrics Lib "user32" (ByVal nIndex As Long) As Long
    Private Declare PtrSafe Function SystemParametersInfo Lib "user32" Alias "SystemParametersInfoA" (ByVal uAction As Long, ByVal uParam As Long, ByRef lpvParam As Any, ByVal fuWinIni As Long) As Long
Private Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type
    ' 主过程 - 调整 word 和 VBE 窗口为左右并排
Sub OPEN_wordwindow()
    ' 调整 Word 窗口
    PositionWordWindowToLeftHalf
    ' 调整 VBE 窗口
    ArrangeVBEWindow
End Sub
Sub PositionWordWindowToLeftHalf()
    Dim screenWidth As Long
    Dim screenHeight As Long
    Dim vbeWidth As Long
    Dim vbeLeft As Long
    Dim workArea As RECT
    screenWidth = GetSystemMetrics(0)
    screenHeight = GetSystemMetrics(1)
    
    On Error Resume Next
    Application.VBE.MainWindow.Visible = True
    On Error GoTo 0
    With Application
        vbeWidth = screenWidth
        vbeLeft = screenHeight
        Application.Top = workArea.Top
        Application.Left = workArea.Left
        .Width = vbeWidth / 2 - 308
        .Height = vbeLeft - 390
    End With
    ' 确保窗口处于可见状态
    Application.Visible = True
End Sub
    ' 调整 VBE 窗口到屏幕右侧
Sub ArrangeVBEWindow()
    Dim screenWidth As Long
    Dim screenHeight As Long
    Dim vbeWidth As Long
    Dim vbeLeft As Long
    Dim workArea As RECT
    screenWidth = GetSystemMetrics(0)
    screenHeight = GetSystemMetrics(1)
    ' 获取工作区域（不包含任务栏）
    If SystemParametersInfo(48, 0, workArea, 0) Then
        vbeWidth = (workArea.Right - workArea.Left) / 2
        vbeLeft = workArea.Left + vbeWidth
        ' 确保 VBE 窗口可见
        On Error Resume Next
        Application.VBE.MainWindow.Visible = True
        On Error GoTo 0
        ' 设置 VBE 窗口位置和大小
        With Application.VBE.MainWindow
            .Left = vbeLeft
            .Top = workArea.Top
            .Width = vbeWidth
            .Height = workArea.Bottom - workArea.Top + 27
        End With
    End If
End Sub

