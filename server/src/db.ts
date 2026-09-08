import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import { DB_PATH } from './config.js';

const SCHEMA_SQL = `
-- ============ 统一资源模型 ============
CREATE TABLE IF NOT EXISTS resources (
  id          TEXT PRIMARY KEY,
  type        TEXT NOT NULL CHECK (type IN ('bookmark','note','file','todo','report','folder')),
  title       TEXT NOT NULL DEFAULT '',
  content     TEXT NOT NULL DEFAULT '',
  source_url  TEXT NOT NULL DEFAULT '',
  path        TEXT NOT NULL DEFAULT '',
  parent_id   TEXT REFERENCES resources(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','trashed')),
  done        INTEGER NOT NULL DEFAULT 0,
  due_at      TEXT,
  meta        TEXT NOT NULL DEFAULT '{}',
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_resources_type_status ON resources(type, status);
CREATE INDEX IF NOT EXISTS idx_resources_parent     ON resources(parent_id);
CREATE INDEX IF NOT EXISTS idx_resources_created    ON resources(created_at);

CREATE TABLE IF NOT EXISTS tags (
  id    TEXT PRIMARY KEY,
  name  TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL DEFAULT '#8BC8EA',
  icon  TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS resource_tags (
  resource_id TEXT NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
  tag_id      TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (resource_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_resource_tags_tag ON resource_tags(tag_id);

CREATE TABLE IF NOT EXISTS note_links (
  source_id TEXT NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
  target_id TEXT NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
  PRIMARY KEY (source_id, target_id)
);
CREATE INDEX IF NOT EXISTS idx_note_links_target ON note_links(target_id);

CREATE TABLE IF NOT EXISTS reports (
  id           TEXT PRIMARY KEY,
  type         TEXT NOT NULL,
  title        TEXT NOT NULL DEFAULT '',
  period_start TEXT,
  period_end   TEXT,
  content      TEXT NOT NULL DEFAULT '',
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attachments (
  id          TEXT PRIMARY KEY,
  resource_id TEXT NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
  rel_path    TEXT NOT NULL,
  size        INTEGER NOT NULL DEFAULT 0,
  mime_type   TEXT NOT NULL DEFAULT '',
  hash        TEXT NOT NULL DEFAULT ''
);

-- ============ 思维导图（独立导图工作区） ============
CREATE TABLE IF NOT EXISTS mindmaps (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  layout     TEXT NOT NULL DEFAULT 'right',  -- free自由/right向右/left向左/org组织图/radial放射
  theme      TEXT NOT NULL DEFAULT 'nexa-light', -- nexa-light/nexa-dark/classic/azure
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS mindmap_nodes (
  id         TEXT PRIMARY KEY,
  map_id     TEXT NOT NULL REFERENCES mindmaps(id) ON DELETE CASCADE,
  parent_id  TEXT,                           -- 树结构（自由布局也保留父子语义用于编辑）
  title      TEXT NOT NULL DEFAULT '',
  kind       TEXT NOT NULL DEFAULT 'node',   -- node/boundary概要边界/summary概要
  x          REAL NOT NULL DEFAULT 0,        -- 自由布局坐标
  y          REAL NOT NULL DEFAULT 0,
  color      TEXT,                           -- 覆盖色（null=跟随主题）
  shape      TEXT NOT NULL DEFAULT 'auto',   -- auto/rect/round/ellipse
  sort       INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_mm_nodes_map ON mindmap_nodes(map_id);
CREATE TABLE IF NOT EXISTS mindmap_links (
  id        TEXT PRIMARY KEY,
  map_id    TEXT NOT NULL REFERENCES mindmaps(id) ON DELETE CASCADE,
  source_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  label     TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_mm_links_map ON mindmap_links(map_id);
-- 边界/概要包含的成员节点
CREATE TABLE IF NOT EXISTS mindmap_members (
  group_id TEXT NOT NULL,
  node_id  TEXT NOT NULL,
  PRIMARY KEY (group_id, node_id)
);

-- ============ FTS5 全文索引 ============
CREATE VIRTUAL TABLE IF NOT EXISTS resources_fts USING fts5(
  title, content,
  content='resources', content_rowid='rowid',
  tokenize='unicode61'
);

CREATE TRIGGER IF NOT EXISTS resources_ai AFTER INSERT ON resources BEGIN
  INSERT INTO resources_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
END;
CREATE TRIGGER IF NOT EXISTS resources_ad AFTER DELETE ON resources BEGIN
  INSERT INTO resources_fts(resources_fts, rowid, title, content)
  VALUES ('delete', old.rowid, old.title, old.content);
END;
CREATE TRIGGER IF NOT EXISTS resources_au AFTER UPDATE ON resources BEGIN
  INSERT INTO resources_fts(resources_fts, rowid, title, content)
  VALUES ('delete', old.rowid, old.title, old.content);
  INSERT INTO resources_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
END;
`;

let db: Database.Database | null = null;

/** 轻量迁移：按列存在性补列（SQLite 不支持 ADD COLUMN IF NOT EXISTS） */
function migrate(db: Database.Database): void {
  const cols = db.prepare(`PRAGMA table_info(resources)`).all() as { name: string }[];
  if (!cols.some(c => c.name === 'size')) {
    db.exec(`ALTER TABLE resources ADD COLUMN size INTEGER NOT NULL DEFAULT 0`);
  }
  const mcols = db.prepare(`PRAGMA table_info(mindmaps)`).all() as { name: string }[];
  if (!mcols.some(c => c.name === 'pinned')) {
    db.exec(`ALTER TABLE mindmaps ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0`);
  }
  if (!mcols.some(c => c.name === 'tags')) {
    db.exec(`ALTER TABLE mindmaps ADD COLUMN tags TEXT NOT NULL DEFAULT ''`);
  }
  if (!mcols.some(c => c.name === 'deleted_at')) {
    // 回收站软删除：NULL=正常；有值=已移入回收站（记录删除时间，超期自动清理）
    db.exec(`ALTER TABLE mindmaps ADD COLUMN deleted_at TEXT`);
  }
  const ncols = db.prepare(`PRAGMA table_info(mindmap_nodes)`).all() as { name: string }[];
  if (!ncols.some(c => c.name === 'desc')) {
    // 节点描述（幕布式：标题下方自动换行的说明文字，独立于标题存储）
    db.exec(`ALTER TABLE mindmap_nodes ADD COLUMN desc TEXT NOT NULL DEFAULT ''`);
  }
}

/** 获取全局数据库连接（单例，初始化建表） */
export function getDb(): Database.Database {
  if (db) return db;
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.exec(SCHEMA_SQL);
  migrate(db);
  return db;
}

/** 关闭数据库（供测试/退出使用） */
export function closeDb(): void {
  if (db) { db.close(); db = null; }
}
