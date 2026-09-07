# Knowledge Hub — 轻笺类本地知识管理软件

本地单机 Web 架构的知识管理软件（以轻笺为参考对象）。数据 100% 留在本地：SQLite 单文件数据库 + 文件库主目录。

## 当前状态：M1 完成 ✅

- [x] 统一资源模型建表（resources / tags / resource_tags / note_links / reports / attachments）
- [x] FTS5 全文索引 + 触发器（英文/数字全文检索可用；中文分词优化在 M2）
- [x] 目录扫描入库（storage_root = `D:\Office办公\VBE2021\Code`，只读，不动原文件）
- [x] 后端 API：stats / folders 树 / resources 列表 / search
- [x] 前端验证页：文件夹树 + 资源列表 + 全文搜索

扫描结果：1331 文件 + 132 文件夹入库，793 个文本文件已建全文索引。

## 一键启动

双击 `start.bat`，自动启动前后端并打开浏览器（http://localhost:5178）。

手动启动：

```bat
cd server && npm run start   # 后端 127.0.0.1:5177
cd web && npm run dev        # 前端 localhost:5178
```

重新扫描（目录文件变化后）：`cd server && npm run scan`

## 项目结构

```
knowledge-hub/
├── start.bat            # 一键启动
├── server/              # Node.js + TypeScript + Express + better-sqlite3
│   ├── src/
│   │   ├── config.ts    # storage_root / DB 路径 / 端口
│   │   ├── db.ts        # 建表 SQL + FTS5 + 连接
│   │   ├── scanner.ts   # 目录扫描入库（只读）
│   │   ├── scan.ts      # 扫描 CLI
│   │   └── routes/      # API 路由
│   └── data/knowledge.db
└── web/                 # Vue3 + Element Plus + Vite
    └── src/App.vue      # 验证页（文件夹树 + 列表 + 搜索）
```

## 下一步（M2）

- 资源中心：中文分词优化（jieba/trigram）、跨类型分栏检索
- 标签体系：tags CRUD + resource_tags 批量打标签
- 图谱多维度：标签/文件夹/引用 × graph/sankey/tree
