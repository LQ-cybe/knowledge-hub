Attribute VB_Name = "导出pdf"
    'word当前文档导出到桌面PDF文件-不含后缀名
Sub ExportToPDF()
    Dim doc As Document
    Dim desktopPath As String
    Dim pdfPath As String
    Dim fileNameWithoutExt As String
    Dim dotPos As Integer
    ' 获取当前文档
    Set doc = ActiveDocument
    ' 获取桌面路径
    desktopPath = CreateObject("WScript.Shell").SpecialFolders("Desktop")
    ' 获取不含后缀名的文件名
    dotPos = InStrRev(doc.Name, ".")
    If dotPos > 0 Then
        fileNameWithoutExt = Left(doc.Name, dotPos - 1)
    Else
        fileNameWithoutExt = doc.Name
    End If
    ' 生成 PDF 文件的完整路径
    pdfPath = desktopPath & "\" & fileNameWithoutExt & ".pdf"
    ' 导出为 PDF
    doc.ExportAsFixedFormat OutputFileName:=pdfPath, _
            ExportFormat:=wdExportFormatPDF, _
            OpenAfterExport:=False, _
            OptimizeFor:=wdExportOptimizeForPrint, _
            Range:=wdExportAllDocument, _
            Item:=wdExportDocumentContent, _
            IncludeDocProps:=True, _
            KeepIRM:=True, _
            CreateBookmarks:=wdExportCreateNoBookmarks, _
            DocStructureTags:=True, _
            BitmapMissingFonts:=True, _
            UseISO19005_1:=False
    '    MsgBox "pdf文件已导出到桌面！"
    ActiveDocument.Save
    Application.WindowState = wdWindowStateMinimize
End Sub



