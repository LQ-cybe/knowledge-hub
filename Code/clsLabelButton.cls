VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsLabelButton"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

'===========================================================================
' clsLabelButton - Label 按钮 hover 效果控制类
' by 知了AI助手，知了修改 20260715
' 创建时自动注册到内部静态容器，防止被垃圾回收
' 使用方式：窗体中声明 Private mManager As clsLabelButton
'           初始化时 Set mManager = New clsLabelButton
'           然后 mManager.Add lblCtrl, 颜色参数...
'===========================================================================
#If VBA7 And Win64 Then
    Private Declare PtrSafe Function LoadCursorBynum Lib "user32" Alias "LoadCursorA" (ByVal hInstance As Long, ByVal lpCursorName As Long) As Long
    Private Declare PtrSafe Function SetCursor Lib "user32" (ByVal hCursor As Long) As Long
    Private Declare PtrSafe Function GetAsyncKeyState Lib "user32" (ByVal vKey As Long) As Integer
#Else
    Private Declare Function LoadCursorBynum Lib "user32" Alias "LoadCursorA" (ByVal hInstance As Long, ByVal lpCursorName As Long) As Long
    Private Declare Function SetCursor Lib "user32" (ByVal hCursor As Long) As Long
    Private Declare Function GetAsyncKeyState Lib "user32" (ByVal vKey As Long) As Integer
#End If

Private Const IDC_HAND = 32649&
Private Const VK_LBUTTON = &H1

' 绑定到具体的 Label 控件
Public WithEvents btnLabel As MSForms.Label
Attribute btnLabel.VB_VarHelpID = -1

' 颜色配置
Public NormalBackColor As Long
Public HoverBackColor As Long
Public NormalBorderColor As Long
Public HoverBorderColor As Long
Public NormalForeColor As Long
Public HoverForeColor As Long
Public Margin As Single

' 窗体回调支持
Public ownerForm As Object
Public ctrlTag As String

' 宿主容器（自动绑定 MouseMove，用于兜底还原颜色）
Public WithEvents m_hostForm As MSForms.UserForm
Attribute m_hostForm.VB_VarHelpID = -1
Public WithEvents m_hostFrame As MSForms.Frame
Attribute m_hostFrame.VB_VarHelpID = -1
Public WithEvents m_hostMultiPage As MSForms.MultiPage
Attribute m_hostMultiPage.VB_VarHelpID = -1

Private isHovered As Boolean
Private savedBackColor As Long
Private savedBorderColor As Long
Private isPressed As Boolean
Public PressDarkenFactor As Single

' 激活状态（导航栏使用）
Public isActive As Boolean
Public ActiveBackColor As Long
Public ActiveBorderColor As Long
Public ActiveForeColor As Long

'===========================================================================
' 全局容器（借宿 ThisWorkbook，避免新增标准模块）
'===========================================================================
Private Function GlobalKeeper() As Collection
    If zClsBtnKeeper.gBtnKeeper Is Nothing Then Set zClsBtnKeeper.gBtnKeeper = New Collection
    Set GlobalKeeper = zClsBtnKeeper.gBtnKeeper
End Function

'===========================================================================
' 初始化：自动注册到全局中心，防止被垃圾回收
'===========================================================================
Private Sub Class_Initialize()
    GlobalKeeper.Add Me
    PressDarkenFactor = 0.7
End Sub

'===========================================================================
' 释放所有按钮实例
'===========================================================================
Public Sub ReleaseAll()
    If GlobalKeeper Is Nothing Then Exit Sub
    Do While GlobalKeeper.count > 0
        GlobalKeeper.Remove 1
    Loop
End Sub

'===========================================================================
' 颜色转换：#RRGGBB → VBA Long
'===========================================================================
Private Function HexToColor(ByVal hexColor As String) As Long
    Dim r As Long, g As Long, b As Long
    hexColor = Replace(hexColor, "#", "")
    r = CLng("&H" & Mid(hexColor, 1, 2))
    g = CLng("&H" & Mid(hexColor, 3, 2))
    b = CLng("&H" & Mid(hexColor, 5, 2))
    HexToColor = RGB(r, g, b)
End Function

'===========================================================================
' DarkenColor：将颜色加深（HSV 算法），factor 0~1，越小越深
' 内部委托给 AdjustColorHSV，保持色相不变
'===========================================================================
Private Function DarkenColor(ByVal originalColor As Long, ByVal factor As Single) As Long
    Dim hsvFactor As Double
    If factor <= 0 Then factor = 0.01
    hsvFactor = 1# / CDbl(factor)
    DarkenColor = AdjustColorHSV(originalColor, hsvFactor)
End Function

'===========================================================================
' AdjustColorHSV：基于 HSV 模型调整颜色深浅（饱和度和明度联动）
' factor < 1：淡化（提明度降饱和度） | =1：不变 | >1：加深（降明度）
'===========================================================================
Private Function AdjustColorHSV(ByVal originalColor As Long, ByVal factor As Double) As Long
    On Error GoTo ErrorHandler

    Dim r As Double: r = (originalColor Mod 256) / 255#
    Dim g As Double: g = ((originalColor \ 256) Mod 256) / 255#
    Dim b As Double: b = (originalColor \ 65536) / 255#

    Dim maxVal As Double, minVal As Double
    If r >= g And r >= b Then
        maxVal = r: minVal = IIf(g < b, g, b)
    ElseIf g >= r And g >= b Then
        maxVal = g: minVal = IIf(r < b, r, b)
    Else
        maxVal = b: minVal = IIf(r < g, r, g)
    End If
    Dim delta As Double: delta = maxVal - minVal

    Dim H As Double
    If delta = 0 Then
        H = 0
    ElseIf maxVal = r Then
        H = 60# * ((g - b) / delta Mod 6#)
        If H < 0 Then H = H + 360#
    ElseIf maxVal = g Then
        H = 60# * ((b - r) / delta + 2#)
    Else
        H = 60# * ((r - g) / delta + 4#)
    End If
    H = H / 360#

    Dim S As Double
    If maxVal = 0 Then S = 0 Else S = delta / maxVal

    Dim V As Double: V = maxVal

    Dim newV As Double, newS As Double
    If factor = 1 Then
        newV = V: newS = S
    ElseIf factor < 1 Then
        newV = V + (1# - V) * (1# - factor)
        newS = S * factor
    Else
        newV = V * (1# / factor)
        newS = S
    End If

    If newV > 1 Then newV = 1
    If newV < 0 Then newV = 0
    If newS > 1 Then newS = 1
    If newS < 0 Then newS = 0

    Dim newR As Double, newG As Double, newB As Double
    If newS = 0 Then
        newR = newV: newG = newV: newB = newV
    Else
        Dim hh As Double: hh = H * 6#
        Dim i As Integer: i = Int(hh)
        Dim f As Double: f = hh - i
        Dim p As Double: p = newV * (1# - newS)
        Dim q As Double: q = newV * (1# - newS * f)
        Dim t As Double: t = newV * (1# - newS * (1# - f))
        Select Case i
            Case 0: newR = newV: newG = t: newB = p
            Case 1: newR = q: newG = newV: newB = p
            Case 2: newR = p: newG = newV: newB = t
            Case 3: newR = p: newG = q: newB = newV
            Case 4: newR = t: newG = p: newB = newV
            Case 5: newR = newV: newG = p: newB = q
        End Select
    End If

    Dim intR As Integer: intR = Round(newR * 255)
    Dim intG As Integer: intG = Round(newG * 255)
    Dim intB As Integer: intB = Round(newB * 255)
    If intR > 255 Then intR = 255 Else If intR < 0 Then intR = 0
    If intG > 255 Then intG = 255 Else If intG < 0 Then intG = 0
    If intB > 255 Then intB = 255 Else If intB < 0 Then intB = 0

    AdjustColorHSV = VBA.RGB(intR, intG, intB)
    Exit Function

ErrorHandler:
    AdjustColorHSV = originalColor
End Function

'===========================================================================
' 配置单个实例的颜色
'===========================================================================
Public Sub Configure(ByVal lbl As MSForms.Label, _
                     ByVal normalBackHex As String, ByVal hoverBackHex As String, _
                     ByVal normalBorderHex As String, ByVal hoverBorderHex As String, _
                     ByVal normalForeHex As String, ByVal hoverForeHex As String)
    Set Me.btnLabel = lbl
    Me.NormalBackColor = HexToColor(normalBackHex)
    Me.HoverBackColor = HexToColor(hoverBackHex)
    Me.NormalBorderColor = HexToColor(normalBorderHex)
    Me.HoverBorderColor = HexToColor(hoverBorderHex)
    Me.NormalForeColor = HexToColor(normalForeHex)
    Me.HoverForeColor = HexToColor(hoverForeHex)
    ' 统一设 Margin，让 MouseMove 事件始终处理悬停检测
    ' 颜色是否变化由调用方控制，类不替开发者做决定
    Me.Margin = 3
End Sub

'===========================================================================
' 统一添加按钮：内部创建实例、配置颜色、设置回调
' ownerForm：接收回调的窗体（需实现 OnLabelEvent）
' 返回值：创建的 clsLabelButton 实例，调用方可保存引用
'===========================================================================
Public Function Add(ByVal lbl As MSForms.Label, _
                    ByVal normalBackHex As String, ByVal hoverBackHex As String, _
                    ByVal normalBorderHex As String, ByVal hoverBorderHex As String, _
                    ByVal normalForeHex As String, ByVal hoverForeHex As String, _
                    Optional ByVal frmOwner As Object = Nothing) As clsLabelButton
    Dim btn As clsLabelButton
    Set btn = New clsLabelButton
    btn.Configure lbl, normalBackHex, hoverBackHex, _
                  normalBorderHex, hoverBorderHex, _
                  normalForeHex, hoverForeHex
    If Not frmOwner Is Nothing Then
        Set btn.ownerForm = frmOwner
        btn.ctrlTag = lbl.Name
        ' 自动绑定宿主容器 MouseMove（有就绑，没有不绑）
        Set btn.m_hostForm = frmOwner
        Dim parentObj As Object
        Set parentObj = lbl.Parent
        Dim parentType As String
        parentType = TypeName(parentObj)
        If parentType = "Frame" Then
            Set btn.m_hostFrame = parentObj
        ElseIf parentType = "Page" Then
            Set btn.m_hostMultiPage = parentObj.Parent
        End If
    End If
    Set Add = btn
End Function

'===========================================================================
' MouseMove：悬停变色 + 小手
'===========================================================================
Private Sub btnLabel_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, _
                               ByVal X As Single, ByVal Y As Single)
    Dim inside As Boolean
    inside = (X >= Margin And X <= btnLabel.Width - Margin And _
              Y >= Margin And Y <= btnLabel.Height - Margin)
    If inside Then Call MouseMoveIcon
    ' 防 MsgBox 卡死：若 isPressed 但左键实际已松开，自动恢复
    'If isPressed Then
        'If (GetAsyncKeyState(VK_LBUTTON) And &H8000) = 0 Then
            'isPressed = False
            'If isHovered Then
                'ApplyHover True
            'Else
                'ApplyHover False
            'End If
        'End If
    'End If
    If Left(btnLabel.Name, 6) = "lblNav" Then
        If inside And Not isHovered Then
            isHovered = True
            If Not isPressed Then ApplyHover True
        ElseIf Not inside And isHovered Then
            isHovered = False
            If Not isPressed Then ApplyHover False
        End If
        Exit Sub
    End If
    If inside And Not isHovered Then
        isHovered = True
        If Not isPressed Then ApplyHover True
    ElseIf Not inside And isHovered Then
        isHovered = False
        If Not isPressed Then ApplyHover False
    End If
End Sub

'===========================================================================
' MouseDown：按下时加深颜色 + 回调窗体
'===========================================================================
Private Sub btnLabel_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, _
                               ByVal X As Single, ByVal Y As Single)
    savedBackColor = btnLabel.backColor
    savedBorderColor = btnLabel.borderColor
    btnLabel.backColor = DarkenColor(btnLabel.backColor, PressDarkenFactor)
    btnLabel.borderColor = DarkenColor(btnLabel.borderColor, PressDarkenFactor)
    isPressed = True
    If Not ownerForm Is Nothing Then
        ownerForm.OnLabelEvent ctrlTag, "MouseDown", X, Y
    End If
End Sub

'===========================================================================
' MouseUp：松开时还原颜色
'===========================================================================
Private Sub btnLabel_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, _
                             ByVal X As Single, ByVal Y As Single)
    isPressed = False
    If isHovered Then
        ApplyHover True
    Else
        ApplyHover False
    End If
    If Not ownerForm Is Nothing Then
        ownerForm.OnLabelEvent ctrlTag, "MouseUp", X, Y
    End If
End Sub

'===========================================================================
' 应用悬停/普通样式
'===========================================================================
Private Sub ApplyHover(ByVal hover As Boolean)
    If isActive Then
        btnLabel.backColor = ActiveBackColor
        btnLabel.borderColor = ActiveBorderColor
        btnLabel.foreColor = ActiveForeColor
    ElseIf hover Then
        btnLabel.backColor = HoverBackColor
        btnLabel.borderColor = HoverBorderColor
        btnLabel.foreColor = HoverForeColor
    Else
        btnLabel.backColor = NormalBackColor
        btnLabel.borderColor = NormalBorderColor
        btnLabel.foreColor = NormalForeColor
    End If
End Sub

'===========================================================================
' RefreshState：刷新按钮显示状态（供外部调用，如切换选中项后）
'===========================================================================
Public Sub RefreshState()
    If isActive Then
        btnLabel.backColor = ActiveBackColor
        btnLabel.borderColor = ActiveBorderColor
        btnLabel.foreColor = ActiveForeColor
    ElseIf isPressed Then
        ' 保持按下状态不覆盖
    ElseIf isHovered Then
        btnLabel.backColor = HoverBackColor
        btnLabel.borderColor = HoverBorderColor
        btnLabel.foreColor = HoverForeColor
    Else
        btnLabel.backColor = NormalBackColor
        btnLabel.borderColor = NormalBorderColor
        btnLabel.foreColor = NormalForeColor
    End If
End Sub

'===========================================================================
' SetNavActiveColor：设置所有导航项的选中高亮色（批量设置）
'===========================================================================
Public Sub SetNavActiveColor(ByVal backColor As Long, ByVal borderColor As Long, ByVal foreColor As Long)
    Dim btn As clsLabelButton
    For Each btn In GlobalKeeper
        If Left(btn.ctrlTag, 6) = "lblNav" Then
            btn.ActiveBackColor = backColor
            btn.ActiveBorderColor = borderColor
            btn.ActiveForeColor = foreColor
        End If
    Next
End Sub

'===========================================================================
' SetActiveNav：设置当前选中的导航项，其余自动取消选中
'===========================================================================
Public Sub SetActiveNav(ByVal navTag As String)
    Dim btn As clsLabelButton
    For Each btn In GlobalKeeper
        If Left(btn.ctrlTag, 6) = "lblNav" Then
            btn.isActive = (btn.ctrlTag = navTag)
            btn.RefreshState
        End If
    Next
End Sub

'===========================================================================
' ResetInactiveLabels：重置所有非激活 Label 的 hover 状态
' 用于 UserForm_MouseMove 中兜底还原，防止鼠标快速划过时颜色残留
' 不会影响 isActive=True 的导航项（选中态保持）
'===========================================================================
Public Sub ResetInactiveLabels()
    Dim btn As clsLabelButton
    For Each btn In GlobalKeeper
        If Not btn.isActive And btn.isHovered Then
            btn.isHovered = False
            btn.RefreshState
        End If
    Next
End Sub

'===========================================================================
' 宿主容器 MouseMove：鼠标进入容器空白区域时还原当前按钮颜色
' 自动绑定，无需用户手动添加事件
'===========================================================================
Private Sub m_hostForm_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    ResetSelf
End Sub

Private Sub m_hostFrame_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    ResetSelf
End Sub

Private Sub m_hostMultiPage_MouseMove(ByVal Index As Long, ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    ResetSelf
End Sub

'===========================================================================
' ResetSelf：只还原当前按钮自身的 hover 状态（轻量调用）
'===========================================================================
Private Sub ResetSelf()
    If Not isActive And isHovered Then
        isHovered = False
        isPressed = False
        RefreshState
    End If
End Sub

Private Function MouseCursor(CursorType As Long) As Long
    Dim lngRet As Long
    lngRet = LoadCursorBynum(0&, CursorType)
    lngRet = SetCursor(lngRet)
End Function

Private Function MouseMoveIcon()
    Call MouseCursor(IDC_HAND)
End Function










































