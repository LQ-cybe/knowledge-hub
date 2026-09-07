Attribute VB_Name = "JSX"
Dim Style_name As String
Dim namestring As String

'JSX脚本导入后处理1
'查找包含特定字符串的内容并设置为指定样式
Sub SetParagraphStyle1()
    ' 关闭屏幕刷新，提高处理性能
    Application.ScreenUpdating = False

    ' 定义要查找的字符串
    Dim searchString As String
    searchString = ".onClick = function () " ' 请将此处替换为你要查找的实际字符串

    ' 定义自定义样式名称
    Dim customStyleName As String
    customStyleName = Style_name ' 请确保该样式在文档中已经存在

    ' 遍历文档中的每个段落
    Dim para As Paragraph
    For Each para In ActiveDocument.Paragraphs
        ' 检查段落内容是否包含指定字符串
        If InStr(1, para.Range.text, searchString, vbTextCompare) > 0 Then
            ' 如果包含指定字符串，则将该段落的样式设置为自定义样式
            para.style = customStyleName
        End If
    Next para

    ' 打开屏幕刷新
    Application.ScreenUpdating = True
End Sub

'JSX脚本导入后处理2
'把当前文档中含【//】字符开头的设置为指定样式，
Sub SetParagraphStyle2()
Application.ScreenUpdating = False
    Dim para As Paragraph
    Dim startStr As String
    Dim strLength As Integer
    ' 设置要查找的起始字符串
    startStr = "//"
    strLength = Len(startStr)
    ' 检查文档中是否有内容
    If ActiveDocument.Paragraphs.Count = 0 Then
        MsgBox "文档中没有段落！", vbExclamation
        Exit Sub
    End If
    ' 关闭屏幕更新以提高性能
    Application.ScreenUpdating = False
    ' 遍历文档中的每个段落
    For Each para In ActiveDocument.Paragraphs
        ' 检查段落是否以指定字符串开头
        If Left(para.Range.text, strLength) = startStr Then
            ' 应用标题2样式
            para.style = ActiveDocument.Styles(Style_name)
        End If
    Next para
    ' 恢复屏幕更新
    Application.ScreenUpdating = True
'    MsgBox "已完成所有符合条件段落的样式设置！", vbInformation
End Sub

'---------------------------------------------------------------------------
'JSX脚本导出处理步骤1
' 2.在标题3的行首插入{//字符的过程
Sub SetHeadingsToTitle_Export1()
Application.ScreenUpdating = False
    Dim wordApp As Word.Application
    Dim wordDoc As Word.Document
    Dim para As Word.Paragraph
    Dim prefix As String
    Debug.Print Style_name
   '定义要插入的字符变量
    prefix = "{"
    On Error Resume Next
   '尝试获取已打开的Word应用程序实例
    Set wordApp = GetObject(, "Word.Application")
    If wordApp Is Nothing Then
       '如果未找到，则创建一个新的Word应用程序实例
        Set wordApp = New Word.Application
    End If
    On Error GoTo 0
   '假设当前活动文档为目标文档
    Set wordDoc = wordApp.ActiveDocument
    For Each para In wordDoc.Paragraphs
        If para.style.NameLocal = Style_name Then
           '在标题3行首插入字符
            para.Range.InsertBefore prefix
        End If
    Next para
    '这里不关闭文档和退出应用程序，因为是当前活动文档，避免影响用户正在进行的操作
    Set para = Nothing
    Set wordDoc = Nothing
    Set wordApp = Nothing
    Application.ScreenUpdating = True
End Sub

'JSX脚本导出处理步骤2
' 1.在标题3前一行（正文）后面插入}字符的过程
Sub SetHeadingsToTitle_Export2()
Application.ScreenUpdating = False
    Dim wordApp As Object
    Dim wordDoc As Object
    Dim para As Object
    Dim suffix As String
   '定义要插入的字符变量
    suffix = "}"
    On Error Resume Next
   '尝试获取已打开的Word应用程序实例
    Set wordApp = GetObject(, "Word.Application")
    If wordApp Is Nothing Then
       '如果未找到，则创建一个新的Word应用程序实例
        Set wordApp = CreateObject("Word.Application")
    End If
    If wordApp Is Nothing Then
       '如果仍然无法获取Word应用程序实例，给出提示并退出
        MsgBox "无法启动Word应用程序。请确保已安装Word。"
        Exit Sub
    End If
    On Error GoTo 0
   '假设当前活动文档为目标文档
    Set wordDoc = wordApp.ActiveDocument
    If wordDoc Is Nothing Then
       '如果无法获取活动文档，给出提示并退出
        MsgBox "无法获取当前活动文档。"
        wordApp.Quit
        Set wordApp = Nothing
        Exit Sub
    End If
    For Each para In wordDoc.Paragraphs
        If para.style.NameLocal = Style_name Then
           '在标题3前插入字符和换行符
            para.Range.InsertBefore suffix & vbCrLf
           '获取上一行段落并设置为正文样式
            Dim prevPara As Object
            Set prevPara = para.Previous
            prevPara.style = wordDoc.Styles("正文")
        End If
    Next para
    '这里不关闭文档和退出应用程序，因为是当前活动文档，避免影响用户正在进行的操作
    Set para = Nothing
    Set wordDoc = Nothing
    Set wordApp = Nothing
    Application.ScreenUpdating = True
End Sub

'JSX脚本导出处理步骤3
'获取指定样式的标题个数
Function GetTitle3Count() As Long
    Application.ScreenUpdating = False
    Dim wdApp As Object
    Dim wdDoc As Object
    Dim para As Object
    Dim title3Count As Long
    Dim titleStyle As String
   '定义标题样式名称变量，方便修改
    titleStyle = Style_name

    On Error Resume Next
   '尝试获取已打开的Word应用程序实例
    Set wdApp = GetObject(, "Word.Application")
    If wdApp Is Nothing Then
       '如果未找到，则创建一个新的Word应用程序实例
        Set wdApp = CreateObject("Word.Application")
    End If
    If wdApp Is Nothing Then
       '如果仍然无法获取Word应用程序实例，给出提示并退出
        MsgBox "无法启动Word应用程序。请确保已安装Word。"
        Exit Function
    End If
    On Error GoTo 0

   '假设当前活动文档为目标文档
    Set wdDoc = wdApp.ActiveDocument
    If wdDoc Is Nothing Then
       '如果无法获取活动文档，给出提示并退出
        MsgBox "无法获取当前活动文档。"
        wdApp.Quit
        Set wdApp = Nothing
        Exit Function
    End If

    For Each para In wdDoc.Paragraphs
        If para.style.NameLocal = titleStyle Then
            title3Count = title3Count + 1
        End If
    Next para

    GetTitle3Count = title3Count
    Debug.Print "当前样式：" & titleStyle & "丨有" & GetTitle3Count & "个"
    '这里不关闭文档和退出应用程序，因为是当前活动文档，避免影响用户正在进行的操作
    Set para = Nothing
    Set wdDoc = Nothing
    Set wdApp = Nothing
    Application.ScreenUpdating = True
End Function

'导入后处理
Sub JSX_script()
namestring = ".onClick = function () "
Style_name = "标题3"
Call SetParagraphStyle1  '把单击事件这一行设置为3级标题
Call SetParagraphStyle2    '把//开头的行设置为3级标题（面板备注信息）

End Sub
'导出前处理
Sub JSX_Export()
Style_name = "标题4"
'SetHeadingsToTitle_Export1  '在标题3的行首插入{//字符，实现标题为备注的功能
'SetHeadingsToTitle_Export2  '在标题3和前面的正文之间插入}右大括号（与上面的配对）
GetTitle3Count              '提取标题3的个数
End Sub
