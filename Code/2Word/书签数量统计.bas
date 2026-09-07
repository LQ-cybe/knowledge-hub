Attribute VB_Name = "书签数量统计"
'返回当前文档中书签的个数
Sub GetBookmarkCount()
    Dim doc As Document
    Set doc = ActiveDocument
    
    ' 检查文档中是否存在书签
    If doc.Bookmarks.Count > 0 Then
        MsgBox "当前文档中的书签数量为: " & doc.Bookmarks.Count
    Else
        MsgBox "当前文档中没有书签。"
    End If
End Sub

