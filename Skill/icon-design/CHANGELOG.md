<!-- trace_ref: 0b7611d4-670778b5-651120ec-3e414e31-b0e0f468-b129f56c-9891857c -->
<!-- rev_id: 88fbd7ab-e48abeca-e69ce693-bdcc884e-336d3217-32a43313-1b1c4303 -->
# Changelog

## 0.2.3 - 2026-06-28

- `search_icons.ps1` 会按关键词和当前库给搜索结果页注入 `2 到 3` 组推荐配色
- `templates/search-icons-preview.html` 新增“推荐配色”区，支持一键试色、同步参数控件并复制配色建议说明
- 更新 Skill 文档与示例问法，补充“先试色再导出”的最新交互

## 0.2.2 - 2026-06-28

- 新增 `references/02-icon-color-guidance.md`，补充图标轻量配色建议、参考图判断方式和试色话术
- 更新 `SKILL.md`，允许在图标选型阶段给出轻量颜色建议，并引导用户先在 HTML 结果页中试色
- 更新示例问法，补充“参考图匹配图标颜色”和“先试色再导出”的典型场景

## 0.2.1 - 2026-06-28

- `search_icons.ps1` 新增“无 -Library 时按关键词自动选库”逻辑，默认不再直接走全库搜索
- 搜索结果页 HTML 从 `search_icons.ps1` 中拆出到 `templates/search-icons-preview.html`，后续样式与交互维护改为模板优先
- 同步更新 Skill 文档与示例问法，补充自动选库与模板路径说明

## 0.2.0 - 2026-06-27

- 新增 `export_icon_asset.ps1`，支持按 `uniqueKey` 导出 `svg / png / ico`
- 支持通过参数指定图标颜色、背景色和单尺寸 / 多尺寸输出
- 使用本机 Microsoft Edge 无头截图生成 PNG，并将多尺寸 PNG 组装为 ICO
- 更新 Skill 文档、示例问法和质量门禁

## 0.1.0 - 2026-06-27

- 初始化 `icon-design` skill 标准目录结构
- 新增 Icon Park SVG 收集与索引脚本
- 新增关键词近似匹配与 HTML 结果页生成脚本
- 新增按名称返回 SVG 的脚本
- 新增使用说明、工作流文档与示例问法
