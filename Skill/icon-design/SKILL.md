---
name: icon-design
description: >
  图标检索、SVG 回传与成品图导出 skill。用户需要为网页、应用、按钮、品牌 logo 选图标，或需要按 uniqueKey 返回 SVG / PNG / ICO 时触发。
version: "0.2.3"
author: agent
agent_created: true
platform: windows
triggers:
  - "图标"
  - "icon"
  - "svg"
  - "png"
  - "ico"
  - "logo"
  - "标识"
  - "按钮图标"
  - "品牌图标"
  - "搜索图标"
when_to_use: >
  用户提到需要找图标、找 logo、挑选 SVG、为网页或应用配图标、按 uniqueKey 拿某个图标 SVG / PNG / ICO 时触发。
  先检索并生成 HTML 结果页，再根据用户确认的 uniqueKey 返回原始 SVG 或导出成品图片。
internal_ref: "90a0e9c8-fcd180a9-fec7d8f0-a597b62d-2b360c74-2aff0d70-03477d60"
---

# icon-design

面向零门槛用户的本地图标检索 skill。

核心目标：

- 把图标源整理成 skill 内部的 `catalog` 与搜索索引
- 让 AI 用关键词做实用检索，而不是一上来全库全量搜索
- 输出一个排版美观的 HTML 结果页，方便用户人工挑选
- 用户确认后，再按 `uniqueKey` 返回对应 SVG 原文或导出对应图片文件

## 何时使用

遇到以下场景时直接使用：

- 用户说"给我找一个搜索图标 / 用户图标 / 下载图标 / 品牌 logo"
- 用户需要先看多个候选，再决定最终用哪个图标
- 用户需要把结果直接变成 HTML 文件预览
- 用户已经知道图标名，需要直接拿某个 SVG 源码
- 用户已经知道图标名，需要直接导出某个 PNG / ICO
- 用户只给了中文词、英文词、近义词、模糊描述，需要在图标库里近似搜索
- 用户想顺手问一下“这个图标适合什么颜色”“参考图这种风格该用什么图标色”

## 🚫 核心禁令 — 绝对不允许的操作

1. **绝对禁止** 直接读取 `./data/` 目录下的任何文件（JSON 索引、catalog、倒排索引等）
2. **绝对禁止** 用 read_file / search_content / grep 等工具翻阅或搜索 `./data/` 下的数据文件
3. **绝对禁止** 自行遍历图标库源文件（`.svg` 文件）来查找图标
4. **绝对禁止** 从数据文件里手动解析 uniqueKey、图标名称或 SVG 内容

**`./data/` 目录是 skill 的内部私有实现，仅供脚本运行时读取。AI 对图标数据的读写只有三段脚本这一个合法入口，没有例外。**

违反以上禁令的后果：
- 多图库存在大量同名图标，直接读文件必然返回错误 SVG
- 无法正确应用用户指定的颜色和尺寸参数
- 用户无法通过 HTML 结果页预览候选，体验归零

## 主流程

### 1. 需要找图标时

执行：

`./scripts/search_icons.ps1 -Keyword 搜索,放大镜 -OutputHtml D:\MyProject\temp\icon-search.html`

如果已经知道优先库，优先加上 `-Library`：

`./scripts/search_icons.ps1 -Keyword github,logo,brand -Library simple-icons,devicon -OutputHtml D:\MyProject\temp\brand-search.html`

作用：

- 用关键词、近义词、中文标题、分类、标签、英文文件名做检索
- 返回 JSON 结果
- 如未启用 `-NoHtml`，必须通过 `-OutputHtml` 把结果页写入用户项目里的外部绝对路径
- HTML 结构与样式来自 `./templates/search-icons-preview.html`，后续维护优先改模板文件，不要再把大段 HTML 塞回 PowerShell

注意：

- HTML 中会展示图片名称（即 `uniqueKey`）
- 真正取 SVG 时，不要依赖页面序号，要使用 `uniqueKey`
- 用户最好直接复制 HTML 卡片里的图片名称告诉 AI
- 如果未传 `-Library`，脚本会按关键词自动挑选更合适的图库，而不是默认全库搜索

### 1.1 关键词拆分示例

把用户的模糊意图拆成 2 到 5 个关键词再搜索，天然支持中英文混输：

- "做一个会员中心按钮图标" → `用户,会员,账号,profile`
- "我要一个导出表格的图标" → `导出,下载,excel,file`
- "我要一个像搜索一样的图标" → `搜索,查找,放大镜,find`

### 1.2 选库路由策略

后续 AI 调用时，默认遵守以下顺序：

1. 先判断是 `品牌 logo` 还是 `通用功能图标`
2. 优先只搜 `1 到 2` 个高命中图库
3. 如果用户不满意，再扩到更多相关库
4. 只有用户明确说"再多找一些 / 全部库都搜 / 还是不满意"时，才使用更多库或全库搜索

推荐的默认路由：

- 品牌 logo：优先 `simple-icons`，技术栈 / 开发生态 logo 补 `devicon`
- 中国用户常见通用图标：优先 `iconpark`，补充 `heroicons`
- 后台管理 / SaaS / 控制台：优先 `tabler-icons`，补充 `heroicons`
- 极简线性图标：优先 `tabler-icons,heroicons`
- Windows / Office / 企业内部系统：优先 `fluentui-system-icons`
- 社交 / 品牌彩色图标：优先 `simple-icons`，补充 `devicon`
- 需要更多候选但仍想控制速度：按主题加第 3 个库，不要直接全库

推荐的调用心智：

- 用户说"找 Github、Facebook、微信 logo"：
  先用 `simple-icons`
- 用户说"找 React、Python、Docker、MySQL 这类技术图标 / 技术栈 logo"：
  先用 `devicon`
- 用户说"找搜索、用户、设置、下载这种通用图标"：
  先用 `tabler-icons,heroicons`
- 用户说"做一个企业后台 / 数据面板 / 控制台"：
  先用 `tabler-icons`
- 用户说"做 Windows 风格、Office 风格、企业内部工具"：
  先用 `fluentui-system-icons`
- 用户说"这一批没满意的，再多来一些"：
  再扩到 `iconpark,bootstrap-icons,remixicon`
- 用户明确要求"所有库都搜"：
  再放开全库

当前脚本内置的自动选库逻辑：

- `windows / office / microsoft / 企业桌面工具`：自动使用 `fluentui-system-icons`
- `react / vue / docker / mysql / 技术栈 / 开发 / 数据库`：自动使用 `devicon`
- `logo / brand / 品牌 / 社交平台`：自动使用 `simple-icons`
- `下载 / 导出 / excel / 文件 / 表格`：自动使用 `tabler-icons,bootstrap-icons`
- `会员 / 账号 / 支付 / 钱包 / 订单 / 中文业务词`：自动使用 `tabler-icons,iconpark`
- 其他通用功能图标：默认使用 `tabler-icons,heroicons`

性能优先规则：

- 默认不要把 `fluentui-system-icons`、`material-design-icons`、`remixicon` 当作第一轮搜索库，除非用户场景非常匹配
- 默认第一轮最多搜 `1 到 2` 个库；第二轮再扩到第 `3` 个库
- 对品牌 / 技术 logo 需求，优先走 `simple-icons` 或 `devicon`，不要混入大量通用图标库
- 对通用功能图标，优先走 `tabler-icons`、`heroicons`、`iconpark`，避免先扫超大库

当前库分层：

- 强烈保留：`simple-icons`、`devicon`、`tabler-icons`、`heroicons`、`iconpark`
- 按场景保留：`fluentui-system-icons`、`bootstrap-icons`
- 非默认库：`material-design-icons`、`remixicon`

关于 `material-design-icons` 的定位：

- 它不是不推荐使用，而是**不推荐放进第一轮默认搜索**
- 原因不是质量问题，而是它体量很大，当前约 `10610` 个图标；在 `搜索`、`用户`、`设置`、`下载` 这类高频通用图标上，和 `tabler-icons`、`heroicons`、`iconpark` 的重叠度较高
- 它真正的价值在于 `Google / Android / Material 风格` 场景，以及很多别的库没有覆盖完整的长尾系统图标
- 更适合在以下情况手动指定或第二轮扩库：
  - 用户明确说 `Android`、`Google`、`Material Design`
  - 需要 `地图 / 导航 / 设备 / 系统设置 / 权限 / 传感器 / 状态` 这类长尾图标
  - 第一轮通用库没找到满意候选，想补一个更全的大库
- 推荐用法：
  - 直接指定 `-Library material-design-icons`
  - 或第二轮扩到 `tabler-icons,heroicons,material-design-icons`

### 2. 让用户确认

搜索生成了 HTML 结果页后，这样对用户说：

- "我已经给你生成了一份候选图标 HTML 文件，你看一下要哪一个。"
- "你直接复制卡片里的图片名称（uniqueKey）给我，我会按这个唯一键返回 SVG 给你。"

用户把 uniqueKey 发回来后，处理逻辑：

1. 从用户消息中提取 `uniqueKey`
2. 判断用户只要原始 SVG、按样式返回 SVG，还是还需要颜色、尺寸、格式
3. 只要原始矢量图 → 调用 `get_icon_svg.ps1 -Key <uniqueKey>`
4. 已经从结果页复制了完整样式参数 JSON，想直接拿应用样式后的 SVG → 调用 `get_icon_svg.ps1 -StylePreset '<JSON>'`
5. 需要成品文件 → 调用 `export_icon_asset.ps1 -Key <uniqueKey> -Color <颜色> -Format <格式> -Size <尺寸>`

### 2.1 轻量配色指导

这个 skill 可以补充**图标相关的轻量配色建议**，但不要扩成完整品牌配色服务。

适合处理：

- 用户问“这个图标用什么颜色更合适”
- 用户想做网页、后台、按钮、数据看板，顺手想确定图标颜色
- 用户给了参考图，希望 AI 根据参考图判断偏冷、偏暖、偏科技、偏克制，再给图标颜色建议
- 用户想先在 HTML 结果页里试一下颜色风格，再决定导出 PNG / ICO

处理原则：

1. 先判断图标用途：普通功能图标、强调图标、品牌 logo、图表配套图标
2. 再判断页面风格：企业、科技、活泼、深色、浅色
3. 如果有参考图，先总结图的视觉感受，再给 `1 到 3` 组颜色建议
4. 默认优先推荐单色或低彩度方案，不要一上来就给太多高饱和颜色
5. 引导用户先去 HTML 结果页里试色，确认后再导出
6. 当前搜索结果页顶部已经内置“推荐配色”区，会按关键词自动排序并展示更多风格按钮，优先引导用户直接点击试色

推荐话术：

- “我先给你两组图标配色方向，你可以先填到结果页里感受一下风格。”
- “这张参考图整体偏冷、偏科技，图标更适合蓝灰或蓝紫，不建议直接上高饱和暖色。”
- “如果你要更稳重的企业感，图标建议先用中性蓝灰；强调图标再单独上主色。”

详细规则参考：

- `./references/02-icon-color-guidance.md`

⚠️ 不要依赖 HTML 页面里的序号，`uniqueKey` 才是持久 ID。

### 3. 获取 SVG

执行：

`./scripts/get_icon_svg.ps1 -Key iconpark:02102:Base:search`

或：

`./scripts/get_icon_svg.ps1 -Key iconpark:00972:Edit:find`

如果用户已经从搜索结果页复制了完整样式参数 JSON，也可以直接执行：

`./scripts/get_icon_svg.ps1 -StylePreset '{"imageName":"heroicons:20:solid:magnifying-glass","theme":"outline","color":"#2563EB","strokeWidth":2.5}'`

作用：

- 传 `-Key` 时，返回该图标的原始 SVG 文本
- 传 `-StylePreset` 时，`svg` 字段返回应用样式后的 SVG，`originalSvg` 字段保留原始 SVG
- 同时返回 `uniqueKey`、库名、序号、分类、名称

### 4. 导出成品图

执行：

`./scripts/export_icon_asset.ps1 -Key heroicons:20:solid:magnifying-glass -Color "#2563eb" -Format png -Size 128 -OutputPath D:\MyProject\assets\search-blue.png`

或：

`./scripts/export_icon_asset.ps1 -Key heroicons:20:solid:magnifying-glass -Color "#0f172a" -Format ico -Size 16,32,48,64,128,256 -OutputPath D:\MyProject\assets\app-icon.ico`

如果用户已经从搜索结果页复制了完整参数 JSON，也可以直接把整段 JSON 传给 `-StylePreset`：

`./scripts/export_icon_asset.ps1 -StylePreset '{"imageName":"devicon:gitbook:original","uniqueKey":"devicon:gitbook:original","title":"Gitbook","library":"devicon","theme":"filled","size":48,"color":"#2C40D8","secondaryColor":"#2F88FF","tertiaryColor":"#FFFFFF","quaternaryColor":"#43CCF8","strokeWidth":4,"strokeLinecap":"round","strokeLinejoin":"round","weight":400,"grade":0,"opticalSize":24,"background":"transparent","copySource":"icon-design-search"}' -Format png -OutputPath D:\MyProject\assets\gitbook.png`

或：

`./scripts/export_icon_asset.ps1 -StylePreset '{"imageName":"devicon:gitbook:original","uniqueKey":"devicon:gitbook:original","title":"Gitbook","library":"devicon","theme":"filled","size":48,"color":"#2C40D8","secondaryColor":"#2F88FF","tertiaryColor":"#FFFFFF","quaternaryColor":"#43CCF8","strokeWidth":4,"strokeLinecap":"round","strokeLinejoin":"round","weight":400,"grade":0,"opticalSize":24,"background":"transparent","copySource":"icon-design-search"}' -Format ico -Size 16,32,48,64,128,256 -OutputPath D:\MyProject\assets\gitbook.ico`

如果 Edge 不在默认位置，可显式指定：

`./scripts/export_icon_asset.ps1 -Key heroicons:20:solid:magnifying-glass -Format png -Size 128 -OutputPath D:\MyProject\assets\search-blue.png -EdgePath "C:\Program Files\Microsoft\Edge\Application\msedge.exe"`

作用与参数说明：

- `-Key`：用户确认的 uniqueKey（必传）
- `-StylePreset '<JSON>'`：可直接传搜索结果页复制出来的完整 JSON；如果 JSON 里已经带了 `uniqueKey / imageName / key`，则可以不再单独传 `-Key`
- `-Format png`：按每个指定尺寸各导出一个 PNG
- `-Format ico`：把多个尺寸 PNG 组装成一个 ICO 文件
- `-Format svg,png,ico`：同时导出多种格式
- `-Color "#2563eb"`：替换图标主色（HEX 格式）
- `-Background "#ffffff"`：背景色，默认透明（可选）
- `-Size 128`：单个尺寸；`-Size 16,32,48,64,128,256`：多个尺寸（ICO 建议传此值）
- `-OutputPath`：**必传外部绝对路径**，产物不写入 skill 内部
- `-EdgePath "C:\Program Files\Microsoft\Edge\Application\msedge.exe"`：可选，手工指定 Edge 路径，适用于企业环境或非默认安装位置
- PNG / ICO 依赖本机已安装且可从命令行调用的 Microsoft Edge 无头截图生成；若无法定位 `msedge.exe` 或当前用户无权访问临时目录 / 输出目录，则会导出失败并给出明确报错
- 当传入 `-StylePreset` 时，脚本会先按 JSON 中的主题、颜色、描边、背景等参数生成样式化 SVG，再继续导出 `svg / png / ico`
- 如果同时传了 `-StylePreset` 和独立参数，例如 `-Color`、`-Background`、`-Size`，则以命令行显式参数为最终值

返回实际导出的文件路径列表，方便 AI 直接交付给用户。

导出前可先自检环境：

`./scripts/check_icon_export_environment.ps1`

或检查指定输出目录与 Edge 路径：

`./scripts/check_icon_export_environment.ps1 -OutputDirectory D:\MyProject\assets -EdgePath "C:\Program Files\Microsoft\Edge\Application\msedge.exe"`

## 主题路由

### 入口与使用说明

- 设计原理与边界：`./references/01-overview.md`
- 图标轻量配色指引：`./references/02-icon-color-guidance.md`

### 示例问法

- 示例提示词：`./examples/index.md`

### 可执行脚本

- 搜索图标并生成 HTML：`./scripts/search_icons.ps1`
- 按 `uniqueKey` 取 SVG：`./scripts/get_icon_svg.ps1`
- 按 `uniqueKey` 导出 SVG / PNG / ICO：`./scripts/export_icon_asset.ps1`

## 目录约定

- `./SKILL.md`：主入口与执行规则
- `./references/`：设计原理（可选阅读）
- `./examples/`：示例问法
- `./scripts/`：PowerShell 5.1 可执行脚本（**查询和取图标的唯一入口**）
- `./templates/`：HTML 结果页模板；搜索页样式和交互优先改这里
- `./data/`：🔒 内部私有数据，仅供脚本内部使用，AI 禁止直接读取
- `./CHANGELOG.md`：版本记录（仅供人类阅读，AI 无需关注）

## 必须遵守

- **⛔ 封装原则：`./data/` 是内部私有数据，AI 绝不能以任何方式直接读取、搜索或解析其中的文件**
- **⛔ 唯一入口：搜索 → `scripts/search_icons.ps1`，取 SVG → `scripts/get_icon_svg.ps1`，导出 → `scripts/export_icon_asset.ps1`。除此之外没有任何合法途径获取图标数据**
- 先确认用户是在"找候选图标"还是"已知图标名直接取 SVG"
- 如果用户还提了颜色、尺寸、最终格式，优先走导出脚本
- 所有产物都必须写到用户显式传入的 skill 外部绝对路径
- 需要给用户挑选时，优先生成 HTML 结果页
- 搜索时默认优先限定 `-Library`；如果未传，脚本会按关键词自动选库，不要误以为它仍然是全库扫描
- HTML 结果里的 `uniqueKey` 才是持久 ID
- 真正返回 SVG 时，优先按 `uniqueKey`
- PowerShell 脚本统一按 Windows PowerShell 5.1 兼容方式维护

## 对后续 AI 的最低执行清单

**⛔ 前置硬约束（以下行为绝对禁止，违反即错误）：**
- 禁止读取 `./data/` 下的任何文件
- 禁止搜索/遍历图标源文件
- 图标查询唯一合法入口：`./scripts/search_icons.ps1`
- SVG 获取唯一合法入口：`./scripts/get_icon_svg.ps1`
- 成品导出唯一合法入口：`./scripts/export_icon_asset.ps1`

**正确执行步骤：**

1. 判断用户是要"搜索候选"还是"直接取某个 SVG / PNG / ICO"
2. 搜索时尽量把用户意图拆成 2 到 5 个关键词
3. 先选 `1 到 2` 个最相关图库，加上 `-Library`
4. 搜索后优先把 HTML 路径和候选 `uniqueKey` 返回给用户
5. 如果用户不满意，再扩到更多库或全库
6. 用户确认后，如果只要矢量图，调用 `./scripts/get_icon_svg.ps1`
7. 如果还要颜色、尺寸、最终格式，调用 `./scripts/export_icon_asset.ps1`
8. 把返回的 SVG 文本或文件路径直接交给上游 AI 或用户使用
## 分发授权说明

- 本分发包已写入多重授权追踪信息，禁止绕过原作者进行二次分发
- LicenseId：lqiang1857_廖强_专用
- WatermarkText：本作品归公众号 Excel催化剂 所有，仅限授权用户自用，禁止任何形式的擅自传播。对于恶意传播、营利性传播行为，我方将保留追究法律责任的权利。
- 如朋友需要，请直接转介绍其向原作者获取授权版本