import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { STORAGE_ROOT } from './config.js';
import { getDb } from './db.js';

/** 忽略的目录/文件名（大小写不敏感，匹配任意层） */
const IGNORE_NAMES = new Set([
  '.git', '.svn', '.hg', '.idea', '.vscode', 'node_modules',
  '.trash', '$recycle.bin', 'desktop.ini', 'thumbs.db', '.ds_store',
]);

/** 文本类扩展名：入库时读取内容进 FTS（其余二进制只记元数据） */
const TEXT_EXTS = new Set([
  '.bas', '.cls', '.frm', '.vba', '.txt', '.md', '.csv', '.json', '.xml',
  '.html', '.htm', '.js', '.ts', '.py', '.c', '.cpp', '.h', '.hpp', '.java',
  '.sql', '.ini', '.cfg', '.log', '.bat', '.ps1', '.vbs', '.sh', '.yaml', '.yml',
]);

/** 单文件内容读取上限：超过则只记元数据，避免大文件拖慢扫描 */
const MAX_CONTENT_BYTES = 1_000_000;

export interface ScanResult {
  folders: number;
  files: number;
  textIndexed: number;
  skipped: number;
  added: number;
  removed: number;
}

function toRel(absPath: string): string {
  return path.relative(STORAGE_ROOT, absPath).split(path.sep).join('/');
}

function isIgnored(name: string): boolean {
  return IGNORE_NAMES.has(name.toLowerCase());
}

function readTextIfPossible(absPath: string): string {
  try {
    const st = fs.statSync(absPath);
    if (st.size === 0 || st.size > MAX_CONTENT_BYTES) return '';
    const buf = fs.readFileSync(absPath);
    // 仅当内容是合法 UTF-8 文本才读取；二进制文件会解码失败则跳过
    const s = buf.toString('utf8');
    if (s.includes('\uFFFD')) return ''; // 替换字符说明不是纯文本
    return s;
  } catch {
    return '';
  }
}

/**
 * 增量扫描 storage_root 入库（幂等、保标签）：
 * - 已入库资源按 path 沿用原 id（resource_tags 关联不丢）
 * - 新增磁盘条目插入新记录
 * - 磁盘已删除的 folder/file 记录清除
 * 只读原目录，不动文件。
 */
export function scanLibrary(): ScanResult {
  const db = getDb();
  const result: ScanResult = { folders: 0, files: 0, textIndexed: 0, skipped: 0, added: 0, removed: 0 };
  const idByDir = new Map<string, string>(); // 绝对路径 -> folder 资源 id

  // path -> 现有记录（重扫沿用 id，保留标签）
  const existing = new Map<string, string>();
  (db.prepare(
    `SELECT id, path FROM resources WHERE type IN ('folder','file') AND status = 'active'`
  ).all() as { id: string; path: string }[]).forEach(r => existing.set(r.path.toLowerCase(), r.id));

  const upsert = (row: { type: string; title: string; content: string; path: string; parentId: string | null; size: number; mtime: string }) => {
    const key = row.path.toLowerCase();
    const oldId = existing.get(key);
    const id = oldId || randomUUID();
    if (!oldId) result.added++;
    db.prepare(`
      INSERT INTO resources (id, type, title, content, path, parent_id, status, size, created_at, updated_at)
      VALUES (@id, @type, @title, @content, @path, @parentId, 'active', @size, @ts, @ts)
      ON CONFLICT(id) DO UPDATE SET
        title = @title, content = @content, path = @path, parent_id = @parentId,
        status = 'active', size = @size, updated_at = @ts
    `).run({ id, ...row, ts: row.mtime });
    return id;
  };

  const walk = (dir: string, parentId: string | null) => {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    entries.sort((a, b) => a.name.localeCompare(b.name));

    for (const ent of entries) {
      if (isIgnored(ent.name)) { result.skipped++; continue; }
      const abs = path.join(dir, ent.name);
      const rel = toRel(abs);

      if (ent.isDirectory()) {
        const st = fs.statSync(abs, { throwIfNoEntry: false });
        const id = upsert({
          type: 'folder', title: ent.name, content: '', path: rel, parentId,
          size: 0, mtime: st ? st.mtime.toISOString() : new Date(0).toISOString(),
        });
        idByDir.set(abs, id);
        result.folders++;
        walk(abs, id);
      } else if (ent.isFile()) {
        const ext = path.extname(ent.name).toLowerCase();
        const isText = TEXT_EXTS.has(ext);
        const st = fs.statSync(abs, { throwIfNoEntry: false });
        const size = st ? st.size : 0;
        const content = isText ? readTextIfPossible(abs) : '';
        upsert({
          type: 'file', title: ent.name, content,
          path: rel, parentId, size,
          mtime: st ? st.mtime.toISOString() : new Date(0).toISOString(),
        });
        result.files++;
        if (isText && content) result.textIndexed++;
      }
      // 其他类型（符号链接等）忽略
    }
  };

  const tx = db.transaction(() => {
    // 根目录本身作为顶层 folder 节点
    const rootRel = '';
    let rootId = existing.get('');
    if (!rootId) {
      rootId = randomUUID();
      result.added++;
      db.prepare(`INSERT INTO resources (id, type, title, content, path, parent_id, status, size, created_at, updated_at)
        VALUES (?, 'folder', ?, '', '', NULL, 'active', 0, ?, ?)`).run(rootId, path.basename(STORAGE_ROOT), new Date(0).toISOString(), new Date(0).toISOString());
    }
    idByDir.set(STORAGE_ROOT, rootId);
    result.folders++;
    walk(STORAGE_ROOT, rootId);

    // 清理磁盘上已不存在的记录
    const keep = new Set<string>([rootRel.toLowerCase()]);
    const stack = [STORAGE_ROOT];
    while (stack.length) {
      const d = stack.pop()!;
      let entries: fs.Dirent[] = [];
      try { entries = fs.readdirSync(d, { withFileTypes: true }); } catch { continue; }
      for (const ent of entries) {
        if (isIgnored(ent.name)) continue;
        const abs = path.join(d, ent.name);
        keep.add(toRel(abs).toLowerCase());
        if (ent.isDirectory()) stack.push(abs);
      }
    }
    const stale = db.prepare(
      `SELECT id, path FROM resources WHERE type IN ('folder','file') AND status = 'active'`
    ).all() as { id: string; path: string }[];
    const del = db.prepare(`DELETE FROM resources WHERE id = ?`);
    for (const r of stale) {
      if (!keep.has(r.path.toLowerCase())) {
        del.run(r.id);
        result.removed++;
      }
    }
  });
  tx();

  return result;
}
