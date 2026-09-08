# MarkItDown 文档转 Markdown

- 唯一标识：`hub-markitdown`
- 显示名称：MarkItDown 文档转 Markdown
- 能力摘要：使用 Microsoft MarkItDown 将多种文档、演示、表格、网页和媒体文件转换为结构化 Markdown，提供适合检索、审阅和 LLM 处理的文本表示。

## 案例素材

1. 法务团队要将旧版合同集中检索。该 skill 会批量转换 PDF 与 Word 文档，保留标题、表格和页级来源信息，对扫描件先标记 OCR 质量而不假定转换结果无误。
2. 知识库助手需要摄入培训课件。该 skill 会把 PPTX、XLSX 和网页转为 Markdown，按文档和章节切分，保留原文件链接供回答时追溯。
3. 用户上传含图片的技术报告。该 skill 会选择是否生成图像描述，限制不可信文件的解析环境，并在人类复核前避免把转换文本当成原始数据的完整替代。
