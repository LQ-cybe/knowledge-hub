# 「轻笺类」本地 Web 知识管理软件设计方案

> 版本：V1.1 ｜ 日期：2026-09-07 ｜ 参考对象：轻笺（boluo66.top / GitHub VeteranBoLuo/light-note）
> 架构取向：**本地单机 Web 架构**（浏览器 UI + 本地后端 + SQLite）
> 范围：轻笺非网络核心功能 + 链图/桑基图渲染 + 日周月季年报表 + 垂直时间线 + 配置化采集 + 文件库模式

---

## 1. 项目定位

**一句话**：在本地电脑上运行的"轻笺类"知识管理软件——书签、笔记、文件、待办统一管理，标签跨类型串联，全局检索、图谱、报表、时间线一应俱全，**数据 100% 留在本地**。

**设计原则**：
- 数据层优先：所有功能建立在统一资源模型上，表结构定稿 = 软件定了 70%
- 渲染层复用：图表/界面全部用现成 Web 组件（ECharts、Vue/React）
- 砍掉网络依赖：不做云盘、不做多端同步、不做在线协作、**采集自研本地**（AI 后期可选接本地 Ollama）
- 浏览器架构理由：界面美观现代化、拖拽交互天然支持、图表库全现成、天然可打印导出

---

## 2. 总体架构

```
┌─────────────────────────────────────────────┐
│                浏览器（UI 层）                │
│   Vue3/React 前端 · ECharts · 拖拽 · 富文本    │
└──────────────────┬──────────────────────────┘
                   │ HTTP / WebSocket（localhost）
┌──────────────────┴──────────────────────────┐
│              本地后端服务（Node/Python）        │
│   API 路由 · 业务规则 · 采集管线 · 报表引擎     │
└──────────────────┬──────────────────────────┘
                   │ SQL / 文件系统
┌──────────────────┴──────────────────────────┐
│      数据层（SQLite 单文件 + 文件库目录）         │
│   resources / tags / resource_tags /          │
│   note_links / reports + FTS5 全文索引 +       │
│   storage_root（文件库主目录）                  │
└─────────────────────────────────────────────┘
```

**载体选择**（待决策）：① 纯本地 Web 服务（后端启动 + 浏览器访问 localhost，最简）② Tauri/Electron 桌面壳（系统托盘/开机启动）。

---

## 3. 核心数据模型（统一资源模型 + 文件库模式）

### 3.1 表结构

```
resources（统一资源表）——书签/笔记/文件/待办/文件夹 都是它的一行
├─ id          TEXT PK（UUID）
├─ type        bookmark | note | file | todo | report | folder
├─ title       标题（显示名）
├─ content     正文（笔记 Markdown / 书签摘要 / 文件元数据）
├─ source_url  来源 URL（采集的网页/微信文章、书签地址）
├─ path        相对路径（file 类型，相对 storage_root；folder 类型为空）
├─ parent_id   → resources.id（自引用：folder 的层级关系，file 所属文件夹）
├─ status      状态（active / archived / trashed）
├─ done        是否完成（todo 用）
├─ due_at      截止时间（todo 用）
├─ meta        JSON（扩展字段：图片列表、采集配置、报表参数等）
├─ created_at / updated_at

tags（标签表）
├─ id TEXT PK
├─ name（唯一）
├─ color / icon（图谱/卡片显示用）

resource_tags（资源↔标签 多对多）——统一标签的底层
├─ resource_id → resources.id（ON DELETE CASCADE）
├─ tag_id      → tags.id
└─ UNIQUE(resource_id, tag_id)

note_links（笔记↔笔记 双链/引用，存 ID 免疫改名断链）
├─ source_id → resources.id
├─ target_id → resources.id
└─ UNIQUE(source_id, target_id)

reports（报表，可保存可修改）
├─ id TEXT PK
├─ type        day | week | month | quarter | year
├─ title
├─ period_start / period_end   统计区间
├─ content     Markdown（生成后可编辑）
├─ created_at / updated_at

attachments（附件映射，文件资源与磁盘文件的对应）
├─ id TEXT PK
├─ resource_id → resources.id
├─ rel_path    相对 storage_root 的路径
├─ size / mime_type / hash
```

### 3.2 文件库模式（主目录约束）

**规则（架构级约束）**：
- 首次启动设定 **storage_root**（如 `D:\知识库`），此后文件管理只在这个根目录内运作
- **导入文件 = 复制进库**：把文件复制到 storage_root（可选自动按分类建子目录），**目录外的文件一律不接受**（不引用外部路径）
- 文件在库内移动/重命名由软件管理（同步更新相对路径）
- 文件夹本身 = `type=folder` 的资源，`parent_id` 自引用形成**目录树**
- 删除资源 = 移入回收站（文件同时移到库内 `.trash` 目录），可恢复

**物理组织 vs 虚拟组织并存**：
| 维度 | 机制 | 用途 |
|---|---|---|
| 文件夹（物理） | parent_id 目录树，导入时可选目标文件夹 | 按分类逐级存放 |
| 标签（虚拟） | resource_tags 多对多 | 跨文件夹批量组织、图谱串联 |

### 3.3 索引设计

- `resources.id` 主键索引（精确定位）
- `resources.type` + `resources.status` 复合索引（分类浏览/整理中心筛选）
- `resources.parent_id` 索引（目录树、文件夹维度图谱）
- `resources.created_at` 索引（时间线、报表统计）
- `resource_tags(tag_id)` 索引（标签图谱、按标签筛选）
- **FTS5 全文索引**：`content` + `title`（资源中心内容搜索；中文分词是唯一需要专门处理的点）

---

## 4. 功能模块设计

### 4.1 资源管理（书签 / 笔记 / 文件 / 待办）

| 类型 | 核心能力 |
|---|---|
| 📌 书签 | 粘贴链接自动抓取标题/图标/摘要、网页快照、标签、批量导入导出（HTML/CSV） |
| 📝 笔记 | Markdown 编辑、模板、@提及资源 + 反向引用、导出 MD/HTML |
| 📁 文件 | **库模式**（主目录约束 + 复制导入 + 相对路径）、按文件夹/标签管理、批量打标签、元数据级管理（首版不做二进制内容预览，见 4.7） |
| 📂 文件夹 | 资源化（type=folder），parent_id 层级树，增删改/拖拽移动 |
| ✅ 待办 | 列表/议程/日历三视图、优先级、截止时间、完成状态、周期提醒（本地通知） |

### 4.2 工作台（概览看板）

- 统计卡：各类型数量、本周新增、待办待办数、未整理数
- 趋势图：近 30 天新增资源曲线（ECharts line）
- 类型分布：环形图（ECharts pie）
- 最近资源列表、快速新建入口

### 4.3 资源中心（全局检索）

- 统一搜索框：关键词 + 标签联合检索（FTS5 + tag 过滤）
- 结果分栏：书签 / 笔记 / 文件 / 待办分栏聚合展示
- 点击跳转详情；支持按类型、标签、文件夹、时间范围筛选
- 本质是"搜索引擎落地页"

### 4.4 整理中心（收件箱队列 + 批量操作）

- 未整理资源队列（无标签/未归档）
- 批量操作：批量打标签、批量归档、批量移动到文件夹、批量删除（事务性，可撤销）
- 拖拽归类：把资源拖到标签/文件夹
- 与待办联动

### 4.5 标签体系与图谱（多视图 × 多维度渲染）

**统一标签**：跨书签/笔记/文件/待办/报表使用，一个标签体系串起所有资源。

**图谱维度化**（链图的"边"可选来源）——核心抽象：`get_edges(dimension)`：

| 维度 | 边的来源 | 场景 |
|---|---|---|
| **标签**（默认） | resource_tags 共同标注 → 相关标签自动推导 | 虚拟组织网络 |
| **文件夹** | resources.parent_id 包含关系 | 目录树即图谱（文件按分类逐级存放时最直观） |
| **引用** | note_links | 笔记间双链 |

**图谱多视图**（同一维度数据，渲染层任意套用）：

| 视图 | 图表类型 | 场景 |
|---|---|---|
| 关系图（默认） | ECharts graph | 整体网络 |
| 节点聚焦 | ECharts **sankey** | 单节点：左列=入边，右列=出边（value=引用次数/共同标签数） |
| 层级展开 | ECharts tree | 文件夹树、标签树 |
| 环形布局 | ECharts graph（circular） | 小规模关系网 |

**交互**：点击节点跳转资源详情、右键增删标签/链接、维度切换器（标签/文件夹/引用）、图例筛选类型。首版仅查看 + 轻交互。

### 4.6 待办与日程视图

| 视图 | 范式 | 实现要点 |
|---|---|---|
| 列表 | 平铺列表 | 排序/筛选 |
| **议程** | 一维线性流（今天→明天→本周→更晚，按时间分组） | `GROUP BY` 日期分组渲染（简单） |
| **日历** | 二维网格（日/周/月粒度缩放，原理相同） | 网格布局 + 跨天 + 重叠布局算法（较难） |

### 4.7 文件预览（首版基础版）

| 类型 | 方案 | 成本 |
|---|---|---|
| PDF / 图片 / 文本 / MD | 浏览器原生 iframe / pdf.js（可选中复制） | 白送 |
| Word docx | **Mammoth.js** 纯前端 docx→HTML（阅读级） | 半天 |
| Excel / PPT | 首版不做（元数据级管理） | 二期 |
| QuickLook | **不集成**（GPL-3.0 + 独立窗口无法嵌入）；可选"外部打开"按钮 | — |

### 4.8 网页采集模块（配置化后处理管线）★核心

**采集管线**（自研本地，不依赖任何云端服务）：

```
输入 URL（单篇 / 普通网页）
  → ① 抓取：HTTP 请求 + 短链跳转 + UA 伪装 + 图片防盗链处理（referer）
  → ② 提取：Readability 正文提取（微信文章 HTML 内即有正文，直接可抓）
  → ③ 后处理管线：按 capture-pipeline.yaml 配置逐级执行
  → ④ 输出干净 MD：存为 note 资源（title/source_url/meta.images）
```

**配置化后处理**（用户可自由修改，预置"极简/标准/完整"三套模板）：

```yaml
# capture-pipeline.yaml
pipeline:
  - images:        { mode: keep }        # keep 保留 | cover 仅封面 | remove 全部过滤
  - links:         { mode: keep_marked } # keep_marked 保留链接 | plain 转纯文本 | remove 删除
  - code_blocks:   { detect: auto, language: auto, trim_indent: true }  # 代码块识别+语言标注+缩进修复
  - images_local:  { download: true, max_width: 800 }  # 图片下载到本地并压缩
  - clean:         { remove_ads: true, merge_paragraphs: true }  # 去广告、合并零散段落
  - footer:        { add_source: true }   # 文末追加来源链接/作者/日期
  - ai_summary:    { enabled: false }     # 二期：接本地 Ollama 生成摘要
```

目标：**输出即用**——生成的标准 MD 直接可读可用，无需二次修改。

**采集方式对比（调研结论）**：

| 方式 | 原理 | 成本 | 结论 |
|---|---|---|---|
| 自研后端采集 | 抓 HTML → Readability → 管线后处理 | ★★ | ✅ 采用 |
| 微信单篇 | mp.weixin.qq.com 服务端渲染，HTML 内有正文 | ★ | ✅ 首版 |
| 普通网页 | @mozilla/readability | ★ | ✅ 首版 |
| 合集批量（appmsgalbum） | 列表 JS 动态加载，需模拟滚动/内部接口或凭证方案 | ★★★ | ⏸️ 二期（借鉴 wechatDownload 凭证方案） |
| ima 云端（ima-skills） | 腾讯 ima import_urls API | ★（零开发） | ❌ **排除**：消耗云端用量 + 数据在 ima 云端，不符合本地要求 |

**采集入口**：资源中心"采集"按钮（输入 URL）/ 浏览器扩展（二期）。

### 4.9 报表中心（日/周/月/季/年 自动化生成）★核心

**WorkReview 式报表**：自动汇总某时间段"做了什么"，生成可编辑、可导出、可保存的报告。

**报表内容模板**：
1. 概览统计：新增书签/笔记/文件/待办数量、总数量、完成待办数、活跃天数
2. 数据图表：每日新增趋势（line）、类型分布（pie）、标签 Top10（bar）、引用关系（可选 graph）
3. 明细时间线：按日列出的新增/完成事项（调用 4.10 时间线数据）
4. 亮点与总结：自动生成（Top 标签、最活跃日、最长连续活跃天数等）
5. 自由编辑区：手动/AI 补充文字总结

**功能规格**：
- 入口：报表中心 → 选择周期（日/周/月/季/年）→ 选择统计区间 → 一键生成
- 生成物 = Markdown（含 ECharts 图表块），**可在线编辑**（富文本/Markdown）
- 保存：存入 `reports` 表，可在报表中心回顾/再次编辑
- 导出：Markdown / HTML / PDF（打印导出）
- 定时生成（可选二期）：本地 cron 每日/每周自动生成草稿

**实现要点**：数据全部来自 `resources` 聚合查询（COUNT/GROUP BY date），图表复用 ECharts，模板用 Markdown 模板引擎。

### 4.10 垂直时间线视图（轻笺更新日志式）★核心

**形态**：左侧垂直时间轴 + 右侧卡片，卡片只显示**名称 + 类型图标**（不显示完整内容），时间显示在左侧，**按类型筛选**。

```
  09-05        ● 📌 某篇文章的收藏
  09-05        ● 📝 会议记录
  09-06        ● ✅ 完成周报
  09-07        ● 📁 项目文档.pdf
```

**功能规格**：
- 数据源：`resources.created_at`（新增/更新时间可切换）
- 分组：按天分组，同日聚合
- 筛选：类型（笔记/书签/文件/待办/全部）+ 时间范围（今天/本周/本月/自定义）
- 点击卡片 → 跳转资源详情
- 排序：时间倒序（最新在上）
- 实现：一条 `SELECT ... GROUP BY date(created_at)` + 卡片渲染——低成本高价值（1-2 天）

---

## 5. 技术方案

| 项 | 选型 | 说明 |
|---|---|---|
| 前端框架 | Vue3 或 React（待决策） | 组件生态成熟 |
| 后端 | Node.js（Express/Fastify）或 Python（FastAPI） | 与采集模块同语言更顺（Node 优先，cheerio+readability 现成） |
| 数据库 | SQLite（better-sqlite3 / node:sqlite） | 单文件、零运维、支持 FTS5 |
| 全文检索 | FTS5 + 中文分词（trigram / jieba 预分词） | 中文分词是唯一真坑 |
| 图表 | ECharts（graph/sankey/tree/pie/line/bar） | 一套库全覆盖 |
| 富文本 | TipTap / 原生 Markdown + marked | |
| 正文提取 | @mozilla/readability + cheerio | 采集模块 |
| docx 预览 | Mammoth.js | |
| PDF 预览 | pdf.js / iframe | |
| 报表导出 | marked + print（HTML→PDF） | |

---

## 6. 工作量评估（更新版）

| 模块 | 难度 | 预估 |
|---|---|---|
| 数据层（五张表 + FTS5 + 库模式） | ★★ | 2-3 天 |
| 书签/笔记/文件/待办/文件夹 CRUD | ★★ | 3-5 天 |
| 资源中心（检索+分栏） | ★★☆ | 3-5 天 |
| 工作台 | ★ | 1-2 天 |
| 整理中心（批量操作） | ★★ | 2-3 天 |
| 标签体系 + 图谱（多维度 × 多视图） | ★★☆ | 3-5 天 |
| **垂直时间线视图** | ★ | 1-2 天 |
| 待办三视图（含日历网格） | ★★★ | 3-5 天 |
| 文件预览（PDF/图片/Word） | ★ | 1-2 天 |
| **网页采集（配置化管线 + 单篇 + 普通网页）** | ★★ | 3-4 天 |
| **报表中心（日/周/月/季/年 + 编辑/导出/保存）** | ★★☆ | 3-5 天 |
| 合集批量采集（可选二期） | ★★★ | 3-5 天 |
| **合计（含采集管线 + 报表）** | | **约 5-6 周** |

**工作量分布**：核心数据管理约 3-4 周；采集与报表是增量亮点（1-2 周）；合集批量是唯一高风险项。

---

## 7. 开发顺序（里程碑）

```
M1 数据层定稿 + 建表 + CRUD 骨架（资源/标签/文件夹）
M2 资源中心（FTS5 检索 + 分栏）
M3 工作台 + 整理中心
M4 图谱多维度多视图（标签/文件夹/引用 × graph/sankey/tree）
M5 垂直时间线视图
M6 待办三视图（列表/议程/日历）
M7 网页采集（配置化管线 + 单篇 + 普通网页）
M8 报表中心（日/周/月/季/年）
M9 文件预览 + 合集批量采集（可选）
```

每个里程碑产出可运行版本，M1-M5 即可日常自用。

---

## 8. 待决策项（开工前确认）

1. 载体：纯本地 Web 服务（localhost）还是 Tauri/Electron 桌面壳？
2. 前端框架：Vue3 / React？
3. 后端语言：Node.js / Python？（采集库 Node 生态更顺，建议 Node）
4. 文件库 storage_root 放哪个盘/目录？（首次启动设定）
5. 图谱是否需要"图上编辑"（增删关系），还是仅查看 + 跳转？（建议仅查看）
6. 采集：首版做单篇 + 普通网页，合集批量放二期？（建议）
7. 报表定时自动生成是否首版就要？（建议二期）

---

## 9. 参考软件档案摘录

| 软件 | 值得借鉴 | 不建议模仿 |
|---|---|---|
| 轻笺 | 统一标签跨资源、收集箱整理流 | 在线托管架构、弱预览 |
| NexaNote | 桌面版链接直采（标准爬取）、配置化思维 | 云端依赖 |
| Notion | 数据库视图体系、页面嵌套 | 协作/云端成本 |
| Obsidian | 双链存 ID、本地存储、图谱 | 无统一资源模型 |
| wechatDownload | 合集批量凭证方案（二期参考） | 闭源分发模式 |
| ima（ima-skills） | import_urls 抓取思路 | ❌ 数据在云端、消耗用量 |

---

## 附：信息来源

- 轻笺：https://boluo66.top ｜ https://github.com/VeteranBoLuo/light-note ｜ https://boluo66.top/helpCenter
- NexaNote：微博官方发布（2026-08-23）；桌面版单篇采集为"输入链接直接抓取"方案（用户澄清）
- ima-skills：C:\Users\LQ\.codebuddy\skills-marketplace\skills\ima-skills（腾讯 ima OpenAPI 封装，已排除）
- wechatDownload：https://github.com/qiye45/wechatDownload
- Mammoth.js / @mozilla/readability / ECharts：各官方文档
