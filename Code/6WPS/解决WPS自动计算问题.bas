Attribute VB_Name = "模块21"
Option Explicit

' ==============================================
' 模块21 — 完全手动计算控制 + 防自动计算巡检
'
' 设计目的：
'   1. 禁止一切自动计算（WPS 动不动自己算的问题）
'   2. 按 F9 手动触发计算
'   3. Ctrl+Break 随时中断
'
' 防自动计算的四道防线：
'   Layer 1: Application.Calculation = xlCalculationManual
'   Layer 2: ws.EnableCalculation = False（逐工作表）
'   Layer 3: 定时巡检（每5秒检查 WPS 是否偷偷恢复了自动计算）
'   Layer 4: F9 计算完后强制再设一遍 Manual（清除脏标记）
' ==============================================
' 本作品归公众号 Excel催化剂 所有，仅限授权用户自用
' LicenseId：C18352028118_陈建龙_专用
' ==============================================

Private isCalculating As Boolean
Private enableCalcTemporarily As Boolean
Private nextPatrolTime As Double       ' 下次巡检时间

' ==============================================
' 主入口：禁止一切自动计算 + 启动巡检
' ==============================================
Sub 禁止一切自动计算()
    Dim ws As Worksheet
    
    isCalculating = False
    enableCalcTemporarily = False
    
    Application.EnableCancelKey = xlInterrupt
    
    ' Layer 1 + 2：锁死
    Call 强制锁死所有计算
    
    ' 绑定按键
    Application.OnKey "{F9}", "手动计算一次"
    Application.OnKey "{ESC}", "ESC重置状态"
    
    ' Layer 3：启动定时巡检（每 5 秒检查一次）
    Call 启动巡检
    
    Application.ScreenUpdating = True
    Application.StatusBar = "已禁止自动计算 — 按 F9 手动计算，按 ESC 重置"
End Sub

' ==============================================
' 定时巡检：防止 WPS 偷偷恢复自动计算
' ==============================================
Private Sub 启动巡检()
    nextPatrolTime = Now + TimeSerial(0, 0, 5)   ' 5 秒后
    Application.OnTime EarliestTime:=nextPatrolTime, _
                       Procedure:="模块21.巡检锁死", _
                       Schedule:=True
End Sub

Sub 巡检锁死()
    ' 如果正在手动计算，跳过巡检
    If isCalculating Then GoTo ScheduleNext
    If enableCalcTemporarily Then GoTo ScheduleNext
    
    ' 检查 Application 级别是否被偷偷改回自动
    If Application.Calculation <> xlCalculationManual Then
        Application.Calculation = xlCalculationManual
    End If
    
    ' 检查每个工作表是否被偷偷恢复了计算
    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        If ws.EnableCalculation Then
            ws.EnableCalculation = False
        End If
    Next ws
    
ScheduleNext:
    ' 安排下一次巡检
    If Not isCalculating Then
        nextPatrolTime = Now + TimeSerial(0, 0, 5)
        Application.OnTime EarliestTime:=nextPatrolTime, _
                           Procedure:="模块21.巡检锁死", _
                           Schedule:=True
    End If
End Sub

Sub 停止巡检()
    On Error Resume Next
    Application.OnTime EarliestTime:=nextPatrolTime, _
                       Procedure:="模块21.巡检锁死", _
                       Schedule:=False
    On Error GoTo 0
End Sub

' ==============================================
' F9：手动触发完整计算（可中断）
' ==============================================
Sub 手动计算一次()
    Dim ws As Worksheet
    
    If isCalculating Then Exit Sub
    If ActiveSheet Is Nothing Then
        Application.StatusBar = "无活动工作表，无法计算"
        Exit Sub
    End If
    
    ' 暂停巡检（计算期间不需要巡检）
    Call 停止巡检
    
    isCalculating = True
    enableCalcTemporarily = True
    
    ' 恢复所有工作表计算
    For Each ws In ThisWorkbook.Worksheets
        ws.EnableCalculation = True
    Next ws
    
    Application.ScreenUpdating = True
    Application.Cursor = xlWait
    Application.StatusBar = "正在计算...（可按 Ctrl+Break 中断）"
    
    On Error GoTo Interrupted
    Application.CalculateFullRebuild
    On Error GoTo 0
    
    ' 计算完成，锁死 + 恢复巡检
    Call 强制锁死所有计算
    Call 启动巡检
    
    Application.Cursor = xlDefault
    isCalculating = False
    Application.StatusBar = "计算完成 — 按 F9 再次计算，按 ESC 重置"
    Exit Sub
    
Interrupted:
    Call 强制锁死所有计算
    Call 启动巡检
    Application.Cursor = xlDefault
    isCalculating = False
    Application.StatusBar = "计算已中断 — 按 F9 重新计算，按 ESC 重置"
End Sub

' ==============================================
' 强制锁死：清除一切自动计算的可能
' ==============================================
Private Sub 强制锁死所有计算()
    Dim ws As Worksheet
    
    enableCalcTemporarily = False
    
    ' 设两遍，确保 WPS 内部状态刷新
    Application.Calculation = xlCalculationManual
    Application.CalculateBeforeSave = False
    
    For Each ws In ThisWorkbook.Worksheets
        ws.EnableCalculation = False
    Next ws
    
    ' 再设一遍，清除 CalculateFullRebuild 可能残留的脏标记
    Application.Calculation = xlCalculationManual
End Sub

' ==============================================
' ESC：重置状态
' ==============================================
Sub ESC重置状态()
    Call 强制锁死所有计算
    isCalculating = False
    Application.Cursor = xlDefault
    Application.StatusBar = "已重置 — 按 F9 手动计算"
End Sub

' ==============================================
' 完全恢复默认设置
' ==============================================
Sub 完全恢复默认设置()
    Dim ws As Worksheet
    
    Call 停止巡检
    
    enableCalcTemporarily = False
    isCalculating = False
    
    Application.EnableCancelKey = xlInterrupt
    Application.OnKey "{F9}"
    Application.OnKey "{ESC}"
    
    With Application
        .Calculation = xlCalculationAutomatic
        .ScreenUpdating = True
        .Cursor = xlDefault
        .StatusBar = False
    End With
    
    For Each ws In ThisWorkbook.Worksheets
        ws.EnableCalculation = True
    Next ws
    
    MsgBox "已完全恢复默认设置！", vbInformation, "恢复完成"
End Sub
