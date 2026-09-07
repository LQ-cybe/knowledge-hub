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
