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

/** 全量扫描 storage_root 入库（幂等：先清空 folder/file 记录再重建；只读原目录，不动文件） */
export function scanLibrary(): ScanResult {
  const db = getDb();
  const result: ScanResult = { folders: 0, files: 0, textIndexed: 0, skipped: 0 };
  const now = new Date().toISOString();
  const idByDir = new Map<string, string>(); // 绝对路径 -> folder 资源 id

  const insert = db.prepare(`
    INSERT INTO resources (id, type, title, content, path, parent_id, status, size, created_at, updated_at)
    VALUES (@id, @type, @title, @content, @path, @parentId, 'active', @size, @now, @now)
  `);

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

      if (ent.isDirectory()) {
        const id = randomUUID();
        insert.run({
          id, type: 'folder', title: ent.name, content: '',
          path: toRel(abs), parentId, now, size: 0,
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
        insert.run({
          id: randomUUID(), type: 'file', title: ent.name, content,
          path: toRel(abs), parentId, now, size,
        });
        result.files++;
        if (isText && content) result.textIndexed++;
      }
      // 其他类型（符号链接等）忽略
    }
  };

  const tx = db.transaction(() => {
    db.prepare(`DELETE FROM resources WHERE type IN ('folder','file')`).run();
    // 根目录本身也作为顶层 folder 节点，parent_id 为空
    const rootId = randomUUID();
    insert.run({ id: rootId, type: 'folder', title: path.basename(STORAGE_ROOT), content: '', path: '', parentId: null, now, size: 0 });
    idByDir.set(STORAGE_ROOT, rootId);
    result.folders++;
    walk(STORAGE_ROOT, rootId);
  });
  tx();

  return result;
}
