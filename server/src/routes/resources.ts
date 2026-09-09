import { Router, type Request } from 'express';
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { getDb } from '../db.js';
import { STORAGE_ROOT } from '../config.js';

const router = Router();

/** 扩展名 -> MIME（预览用） */
const MIME: Record<string, string> = {
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif',
  '.bmp': 'image/bmp', '.svg': 'image/svg+xml', '.webp': 'image/webp', '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8', '.md': 'text/markdown; charset=utf-8',
  '.bas': 'text/plain; charset=utf-8', '.cls': 'text/plain; charset=utf-8', '.frm': 'text/plain; charset=utf-8',
  '.vba': 'text/plain; charset=utf-8', '.html': 'text/html; charset=utf-8', '.htm': 'text/html; charset=utf-8',
  '.json': 'application/json', '.xml': 'application/xml', '.csv': 'text/csv; charset=utf-8',
};

interface ResourceRow {
  id: string;
  type: string;
  title: string;
  path: string;
  parent_id: string | null;
  created_at: string;
  updated_at: string;
  done: number;
  content?: string;
  pinned?: number;
}

/** GET /api/resources —— 资源列表（可按 type/parentId/status/q/tag 过滤 + 排序 + 分页）
 *  带 page 参数时返回 { list, total }（数据库视图用）；否则兼容返回数组（浏览页用） */
router.get('/resources', (req: Request, res) => {
  const db = getDb();
  const { type, parentId, status = 'active', q, tag, id, orderBy = 'updated_at', orderDir = 'desc' } = req.query as Record<string, string>;
  const page = req.query.page !== undefined ? Math.max(1, parseInt(String(req.query.page), 10) || 1) : null;
  const pageSize = Math.min(200, Math.max(1, parseInt(String(req.query.pageSize || '50'), 10) || 50));

  const where: string[] = ['r.status = @status'];
  const params: Record<string, unknown> = { status };
  if (type) {
    // 支持逗号分隔多类型（如 note,bookmark → 书签笔记合并页）
    const types = String(type).split(',').map(s => s.trim()).filter(Boolean);
    if (types.length > 1) { where.push(`r.type IN (${types.map((_, i) => `@type${i}`).join(',')})`); types.forEach((t, i) => { params[`type${i}`] = t; }); }
    else { where.push('r.type = @type'); params.type = types[0]; }
  }
  if (id) { where.push('r.id = @id'); params.id = id; }
  if (parentId === 'root') {
    // 主目录视图：根文件夹 + 全局自建资源（笔记/书签/待办，无文件系统归属）
    where.push(`(r.parent_id IS NULL AND r.type = 'folder') OR r.type IN ('note','bookmark','todo')`);
  } else if (parentId !== undefined) {
    where.push('r.parent_id = @parentId'); params.parentId = parentId;
  }
  if (q) { where.push('(r.title LIKE @like OR r.path LIKE @like)'); params.like = `%${q}%`; }
  if (tag) {
    where.push('EXISTS (SELECT 1 FROM resource_tags rt WHERE rt.resource_id = r.id AND rt.tag_id = @tag)');
    params.tag = tag;
  }
  if (req.query.pending === '1') {
    where.push(`json_extract(r.meta, '$.pending') = 1`);
  }

  const orderCols: Record<string, string> = {
    title: 'r.title', created_at: 'r.created_at', updated_at: 'r.updated_at',
    size: 'r.size', type: 'r.type',
  };
  const orderCol = orderCols[orderBy] || 'r.updated_at';
  const orderDirSql = orderDir.toLowerCase() === 'asc' ? 'ASC' : 'DESC';
  // 排序：文件夹先、再按所选排序字段（置顶功能已从文件页移除，不再按 pinned 优先排序）
  const orderSql = `ORDER BY CASE r.type WHEN 'folder' THEN 0 ELSE 1 END, ${orderCol} ${orderDirSql}`;

  // 标签聚合（数据库视图显示用；子查询走 resource_tags 主键索引，仅对返回行执行）
  const tagNamesSub = `(SELECT GROUP_CONCAT(t.name, '|') FROM resource_tags rt JOIN tags t ON t.id = rt.tag_id WHERE rt.resource_id = r.id)`;
  const tagIdsSub = `(SELECT GROUP_CONCAT(t.id, '|') FROM resource_tags rt JOIN tags t ON t.id = rt.tag_id WHERE rt.resource_id = r.id)`;
  const cols = `r.id, r.type, r.title, r.path, r.parent_id, r.done, r.size, r.source_url, r.created_at, r.updated_at,
                json_extract(r.meta, '$.pinned') AS pinned,
                ${tagNamesSub} AS tag_names, ${tagIdsSub} AS tag_ids`;

  if (page == null) {
    const rows = db.prepare(
      `SELECT ${cols} FROM resources r WHERE ${where.join(' AND ')} ${orderSql} LIMIT 500`
    ).all(params) as ResourceRow[];
    res.json({ code: 0, data: rows });
    return;
  }

  const total = (db.prepare(
    `SELECT COUNT(*) AS n FROM resources r WHERE ${where.join(' AND ')}`
  ).get(params) as { n: number }).n;
  const rows = db.prepare(
    `SELECT ${cols} FROM resources r WHERE ${where.join(' AND ')} ${orderSql}
     LIMIT @limit OFFSET @offset`
  ).all({ ...params, limit: pageSize, offset: (page - 1) * pageSize }) as ResourceRow[];
  res.json({ code: 0, data: { list: rows, total } });
});

/** GET /api/tags —— 标签列表（含各标签资源数；数据库视图标签筛选/标签维度图谱用） */
router.get('/tags', (_req, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT t.id, t.name, COUNT(rt.resource_id) AS count
     FROM tags t LEFT JOIN resource_tags rt ON rt.tag_id = t.id
     GROUP BY t.id ORDER BY t.name`
  ).all();
  res.json({ code: 0, data: rows });
});

/** GET /api/folders —— 文件夹树（嵌套层级，供树视图/文件夹维度链图） */
router.get('/folders', (_req, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT id, title, path, parent_id FROM resources WHERE type = 'folder' AND status = 'active'`
  ).all() as { id: string; title: string; path: string; parent_id: string | null }[];

  const byId = new Map<string, typeof rows[number] & { children: unknown[] }>();
  rows.forEach(r => byId.set(r.id, { ...r, children: [] }));

  const roots: (typeof rows[number] & { children: unknown[] })[] = [];
  for (const node of byId.values()) {
    if (node.parent_id && byId.has(node.parent_id)) {
      byId.get(node.parent_id)!.children.push(node);
    } else {
      roots.push(node);
    }
  }
  res.json({ code: 0, data: roots });
});

/** GET /api/tree —— 文件结构树（文件夹 + 文件叶子，浏览页左侧树用） */
router.get('/tree', (_req, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT id, type, title, path, parent_id FROM resources
     WHERE status = 'active' ORDER BY CASE WHEN type='folder' THEN 0 ELSE 1 END, title COLLATE NOCASE`
  ).all() as { id: string; type: string; title: string; path: string; parent_id: string | null }[];

  const byId = new Map<string, typeof rows[number] & { children: unknown[] }>();
  rows.forEach(r => byId.set(r.id, { ...r, children: [] }));

  const roots: (typeof rows[number] & { children: unknown[] })[] = [];
  for (const node of byId.values()) {
    if (node.parent_id && byId.has(node.parent_id)) {
      byId.get(node.parent_id)!.children.push(node);
    } else {
      roots.push(node);
    }
  }
  res.json({ code: 0, data: roots });
});

/** GET /api/stats —— 全局统计（工作台数据源 + 待整理计数） */
router.get('/stats', (_req, res) => {
  const db = getDb();
  const total = db.prepare(`SELECT COUNT(*) AS n FROM resources WHERE status = 'active'`).get() as { n: number };
  const pending = db.prepare(
    `SELECT COUNT(*) AS n FROM resources WHERE status = 'active' AND json_extract(meta, '$.pending') = 1`
  ).get() as { n: number };
  const byType = db.prepare(
    `SELECT type, COUNT(*) AS n FROM resources WHERE status = 'active' GROUP BY type`
  ).all();
  res.json({ code: 0, data: { total: total.n, pending: pending.n, byType } });
});

/** GET /api/dashboard —— 工作台聚合数据（顶层目录统计 + 最近更新 + 类型分布） */
router.get('/dashboard', (_req, res) => {
  const db = getDb();
  const total = (db.prepare(`SELECT COUNT(*) AS n FROM resources WHERE status = 'active'`).get() as { n: number }).n;
  const byType = db.prepare(
    `SELECT type, COUNT(*) AS n FROM resources WHERE status = 'active' GROUP BY type`
  ).all() as { type: string; n: number }[];
  const tagCount = (db.prepare(`SELECT COUNT(*) AS n FROM tags`).get() as { n: number }).n;
  // 顶层目录 = 根（parent_id IS NULL）的直接子文件夹；文件数按 path 前缀递归统计
  const root = db.prepare(
    `SELECT id FROM resources WHERE type='folder' AND parent_id IS NULL AND status='active'`
  ).get() as { id: string } | undefined;
  const topFolders = root ? db.prepare(
    `SELECT f.id, f.title, f.path,
       (SELECT COUNT(*) FROM resources r WHERE r.status='active' AND r.type='file' AND r.path LIKE f.path || '/%') AS files,
       (SELECT COUNT(*) FROM resources r WHERE r.status='active' AND r.type='folder' AND r.path LIKE f.path || '/%') AS subFolders,
       (SELECT COALESCE(SUM(r.size),0) FROM resources r WHERE r.status='active' AND r.type='file' AND r.path LIKE f.path || '/%') AS bytes
     FROM resources f
     WHERE f.type='folder' AND f.parent_id = ? AND f.status='active'
     ORDER BY f.title`
  ).all(root.id) as { id: string; title: string; path: string; files: number; subFolders: number; bytes: number }[] : [];
  const recent = db.prepare(
    `SELECT id, type, title, path, updated_at FROM resources
     WHERE status='active' AND type='file' ORDER BY updated_at DESC LIMIT 12`
  ).all() as { id: string; type: string; title: string; path: string; updated_at: string }[];
  // 常用标签（按资源数排序，工作台"常用标签"卡片）
  const topTags = db.prepare(
    `SELECT t.id, t.name, t.color, COUNT(rt.resource_id) AS n
     FROM tags t LEFT JOIN resource_tags rt ON rt.tag_id = t.id
     GROUP BY t.id ORDER BY n DESC, t.name LIMIT 10`
  ).all() as { id: string; name: string; color: string; n: number }[];
  res.json({ code: 0, data: { total, byType, tagCount, topFolders, recent, topTags } });
});

/** GET /api/today —— 今日新增计数（工作台"今日新增"卡片用）
 *  统计 created_at 落在本地今天 00:00 之后的资源，按类型拆分；导图来自独立 mindmaps 表 */
router.get('/today', (_req, res) => {
  const db = getDb();
  const today = (db.prepare(`SELECT date('now','localtime') AS d`).get() as { d: string }).d;
  const counts = db.prepare(
    `SELECT type, COUNT(*) AS n FROM resources
     WHERE status='active' AND date(created_at) = @today GROUP BY type`
  ).all({ today }) as { type: string; n: number }[];
  const map: Record<string, number> = { note: 0, bookmark: 0, file: 0, todo: 0 };
  for (const c of counts) if (c.type in map) map[c.type] += c.n;
  const mindmap = (db.prepare(
    `SELECT COUNT(*) AS n FROM mindmaps WHERE date(created_at) = @today`
  ).get({ today }) as { n: number }).n;
  const total = map.note + map.bookmark + map.file + map.todo + mindmap;
  res.json({ code: 0, data: { note: map.note, bookmark: map.bookmark, file: map.file, todo: map.todo, mindmap, total, date: today } });
});

/** GET /api/timeline?type=&tag= —— 垂直时间线：按创建时间倒序的资源流（前端按天分组，含大小/标签辅助信息） */
router.get('/timeline', (req, res) => {
  const db = getDb();
  const type = (req.query.type as string || '').trim();
  const tag = (req.query.tag as string || '').trim();
  const rows = db.prepare(
    `SELECT r.id, r.type, r.title, r.path, r.parent_id, r.created_at, r.updated_at, r.size,
       (SELECT GROUP_CONCAT(t.name, ',') FROM resource_tags rt JOIN tags t ON t.id = rt.tag_id WHERE rt.resource_id = r.id) AS tag_names
     FROM resources r
     WHERE r.status='active' AND (? = '' OR r.type = ?)
       AND (? = '' OR EXISTS (SELECT 1 FROM resource_tags rt WHERE rt.resource_id = r.id AND rt.tag_id = ?))
     ORDER BY r.created_at DESC LIMIT 500`
  ).all(type, type, tag, tag) as { id: string; type: string; title: string; path: string; parent_id: string | null; created_at: string; updated_at: string; size: number | null; tag_names: string | null }[];
  // 文件：检测磁盘是否仍存在（删除/改名 → 历史卡片浅色提示）
  // 注意：resources.path 存的是相对 STORAGE_ROOT 的路径，需拼接后检测
  const out = rows.map(r => {
    let missing = false;
    if (r.type === 'file' && r.path) {
      const full = path.isAbsolute(r.path) ? r.path : path.join(STORAGE_ROOT, r.path);
      missing = !fs.existsSync(full);
    }
    return { ...r, missing };
  });
  res.json({ code: 0, data: out });
});

/** GET /api/search?q= —— FTS5 全文检索（跨 title/content） */
router.get('/search', (req, res) => {
  const db = getDb();
  const q = (req.query.q as string || '').trim();
  if (!q) { res.json({ code: 0, data: [] }); return; }

  // unicode61 下英文/数字直接短语匹配；中文按单字 token 可匹配相邻双字，更长需 M2 分词优化
  const like = `%${q}%`;
  const matchQ = `"${q.replace(/"/g, '')}"*`;
  const rows = db.prepare(
    `SELECT * FROM (
      SELECT resources.id, resources.type, resources.title, resources.path, resources.parent_id,
             resources.created_at, resources.updated_at,
             snippet(resources_fts, 1, '[', ']', '…', 12) AS highlight
      FROM resources_fts
      JOIN resources ON resources.rowid = resources_fts.rowid
      WHERE resources_fts MATCH @q
      UNION
      SELECT resources.id, resources.type, resources.title, resources.path, resources.parent_id,
             resources.created_at, resources.updated_at, '' AS highlight
      FROM resources
      WHERE resources.status = 'active' AND (resources.title LIKE @like OR resources.path LIKE @like)
        AND resources.id NOT IN (
          SELECT resources.id FROM resources_fts
          JOIN resources ON resources.rowid = resources_fts.rowid
          WHERE resources_fts MATCH @q
        )
    )
    ORDER BY
      CASE type WHEN 'file' THEN 0 WHEN 'note' THEN 1 WHEN 'bookmark' THEN 2 WHEN 'todo' THEN 3 WHEN 'report' THEN 4 ELSE 5 END,
      CASE WHEN title LIKE @like THEN 0 ELSE 1 END,
      created_at DESC
    LIMIT 100`
  ).all({ q: matchQ, like }) as unknown[];
  res.json({ code: 0, data: rows });
});

/** GET /api/file/:id —— 读取文件库内文件内容（只读；严格防路径穿越，仅限 storage_root 内） */
router.get('/file/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(
    `SELECT path FROM resources WHERE id = ? AND type = 'file' AND status = 'active'`
  ).get(req.params.id) as { path: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '文件记录不存在' }); return; }

  const rel = row.path;
  if (!rel || rel.split(/[\\/]/).includes('..')) {
    res.status(400).json({ code: 1, msg: '非法路径' });
    return;
  }
  const abs = path.join(STORAGE_ROOT, rel.split('/').join(path.sep));
  if (!fs.existsSync(abs)) { res.status(404).json({ code: 1, msg: '磁盘文件不存在' }); return; }

  const ext = path.extname(abs).toLowerCase();
  res.setHeader('Content-Type', MIME[ext] || 'application/octet-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.sendFile(abs);
});

/** PUT /api/file/:id —— 保存文本文件内容（写回磁盘 + 更新 FTS；仅限文本类扩展名，防二进制破坏） */
router.put('/file/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(
    `SELECT path FROM resources WHERE id = ? AND type = 'file' AND status = 'active'`
  ).get(req.params.id) as { path: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '文件记录不存在' }); return; }
  const rel = row.path;
  if (!rel || rel.split(/[\\/]/).includes('..')) {
    res.status(400).json({ code: 1, msg: '非法路径' });
    return;
  }
  const ext = path.extname(rel).toLowerCase();
  const TEXT_OK = new Set(['.txt', '.md', '.bas', '.cls', '.frm', '.vba', '.json', '.xml', '.html', '.htm', '.csv', '.js', '.ts', '.py', '.sql', '.ini', '.cfg', '.log', '.bat', '.ps1', '.vbs', '.sh', '.yaml', '.yml']);
  if (!TEXT_OK.has(ext)) { res.status(400).json({ code: 1, msg: '该文件类型不支持在线编辑' }); return; }
  const content = String(req.body?.content ?? '');
  const abs = path.join(STORAGE_ROOT, rel.split('/').join(path.sep));
  try {
    fs.writeFileSync(abs, content, 'utf8');
    const st = fs.statSync(abs);
    db.prepare(`UPDATE resources SET content = ?, size = ?, updated_at = ? WHERE id = ?`)
      .run(content, st.size, new Date().toISOString(), req.params.id);
    res.json({ code: 0, data: { ok: true, size: st.size } });
  } catch (e: any) {
    res.status(500).json({ code: 1, msg: '保存失败：' + (e?.message || e) });
  }
});

/** POST /api/resources/:id/move —— 移动文件/文件夹到指定目录（物理移动 + 更新 DB 路径与父子关系） */
router.post('/resources/:id/move', (req, res) => {
  const db = getDb();
  const { targetParentId } = req.body as { targetParentId?: string };
  const row = db.prepare(
    `SELECT id, type, title, path, parent_id FROM resources WHERE id = ? AND status = 'active'`
  ).get(req.params.id) as { id: string; type: string; title: string; path: string; parent_id: string | null } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '资源不存在' }); return; }
  // 目标目录
  let targetPath = ''; // 相对 STORAGE_ROOT 的目录（'' = 根）
  if (targetParentId) {
    const t = db.prepare(`SELECT id, path FROM resources WHERE id = ? AND type = 'folder' AND status = 'active'`)
      .get(targetParentId) as { id: string; path: string } | undefined;
    if (!t) { res.status(404).json({ code: 1, msg: '目标文件夹不存在' }); return; }
    targetPath = t.path;
  }
  // 防移动到自身/子孙
  if (row.type === 'folder' && targetParentId === row.id) { res.status(400).json({ code: 1, msg: '不能移动到自身' }); return; }
  const oldRel = row.path;
  const newRel = targetPath ? `${targetPath}/${row.title}` : row.title;
  if (newRel.toLowerCase() === oldRel.toLowerCase()) { res.status(400).json({ code: 1, msg: '目标位置相同' }); return; }
  // 物理移动
  const oldAbs = path.join(STORAGE_ROOT, oldRel.split('/').join(path.sep));
  const newAbs = path.join(STORAGE_ROOT, newRel.split('/').join(path.sep));
  if (!fs.existsSync(oldAbs)) { res.status(404).json({ code: 1, msg: '磁盘上不存在该资源' }); return; }
  try {
    fs.mkdirSync(path.dirname(newAbs), { recursive: true });
    fs.renameSync(oldAbs, newAbs);
  } catch (e: any) {
    res.status(500).json({ code: 1, msg: '移动失败：' + (e?.message || e) });
    return;
  }
  const tx = db.transaction(() => {
    db.prepare(`UPDATE resources SET path = ?, parent_id = ?, updated_at = ? WHERE id = ?`)
      .run(newRel, targetParentId || null, new Date().toISOString(), row.id);
    // 子文件夹/文件的 path 前缀同步更新
    if (row.type === 'folder') {
      const prefix = oldRel ? oldRel + '/' : '';
      const newPrefix = newRel + '/';
      db.prepare(`UPDATE resources SET path = ? || substr(path, ?), updated_at = ? WHERE path LIKE ? AND status = 'active'`)
        .run(newPrefix, prefix.length + 1, new Date().toISOString(), prefix + '%');
    }
  });
  tx();
  res.json({ code: 0, data: { ok: true, path: newRel } });
});

/** GET /api/graph?dimension=folder|tag|link —— 图谱数据（统一 nodes+links，渲染层自由选择图表形态） */
router.get('/graph', (req, res) => {
  const db = getDb();
  const dimension = (req.query.dimension as string) || 'folder';

  if (dimension === 'folder') {
    const folders = db.prepare(
      `SELECT id, title, path, parent_id FROM resources WHERE type='folder' AND status='active'`
    ).all() as { id: string; title: string; path: string; parent_id: string | null }[];
    // name 用唯一 path（文件夹可重名），显示名经 label.formatter 用 title
    const nodes = folders.map(f => ({ id: f.id, name: f.path || f.title, label: f.title, category: 'folder', symbolSize: 18 }));
    const links = folders.filter(f => f.parent_id)
      .map(f => ({ source: f.parent_id!, target: f.id, value: 1 }));
    res.json({ code: 0, data: { nodes, links } });
    return;
  }

  if (dimension === 'tag') {
    const tags = db.prepare(`SELECT id, name FROM tags`).all() as { id: string; name: string }[];
    const rts = db.prepare(
      `SELECT rt.resource_id, rt.tag_id, r.title FROM resource_tags rt
       JOIN resources r ON r.id = rt.resource_id`
    ).all() as { resource_id: string; tag_id: string; title: string }[];
    const tagIds = new Set(tags.map(t => t.id));
    // 同一资源打了多个标签时 rts 会有多行，必须按 resource_id 去重节点
    // （ECharts graph 不允许重复 name/id，否则渲染直接抛错）
    const resMap = new Map<string, { id: string; name: string; label: string; category: string; symbolSize: number }>();
    for (const r of rts) {
      if (!tagIds.has(r.tag_id)) continue;
      if (!resMap.has(r.resource_id)) {
        resMap.set(r.resource_id, {
          id: 'res_' + r.resource_id, name: 'res_' + r.resource_id, label: r.title || '资源', category: 'resource', symbolSize: 8,
        });
      }
    }
    const nodes = [
      ...tags.map(t => ({ id: t.id, name: t.name, label: t.name, category: 'tag', symbolSize: 22 })),
      ...resMap.values(),
    ];
    const links = rts.filter(r => tagIds.has(r.tag_id))
      .map(r => ({ source: r.tag_id, target: 'res_' + r.resource_id, value: 1 }));
    res.json({ code: 0, data: { nodes, links } });
    return;
  }

  // dimension === 'link'：笔记双链（当前为空表，结构就位）
  const links = db.prepare(`SELECT source_id, target_id FROM note_links`).all();
  res.json({ code: 0, data: { nodes: [], links } });
});

/** GET /api/graph/hierarchy —— 文件夹层级树（含每级文件数与总字节），供矩形树图/旭日图/打包图等层级图表 */
router.get('/graph/hierarchy', (_req, res) => {
  const db = getDb();
  const folders = db.prepare(
    `SELECT id, title, parent_id FROM resources WHERE type='folder' AND status='active'`
  ).all() as { id: string; title: string; parent_id: string | null }[];
  const files = db.prepare(
    `SELECT parent_id, size FROM resources WHERE type='file' AND status='active'`
  ).all() as { parent_id: string | null; size: number | null }[];
  const fileCount = new Map<string, number>();
  const fileBytes = new Map<string, number>();
  for (const f of files) {
    if (!f.parent_id) continue;
    fileCount.set(f.parent_id, (fileCount.get(f.parent_id) || 0) + 1);
    fileBytes.set(f.parent_id, (fileBytes.get(f.parent_id) || 0) + (f.size || 0));
  }
  // 每个文件夹 = { id, title, value(含子树文件数), size(含子树字节), children }
  const nodeMap = new Map<string, any>();
  for (const f of folders) nodeMap.set(f.id, { id: f.id, name: f.title, value: 0, size: 0, children: [] as any[] });
  const roots: any[] = [];
  for (const f of folders) {
    const n = nodeMap.get(f.id);
    const parent = f.parent_id ? nodeMap.get(f.parent_id) : null;
    if (parent) parent.children.push(n);
    else roots.push(n);
  }
  // 自底向上累加文件数与字节
  const acc = (n: any): { files: number; bytes: number } => {
    let files = fileCount.get(n.id) || 0;
    let bytes = fileBytes.get(n.id) || 0;
    for (const c of n.children) {
      const r = acc(c);
      files += r.files;
      bytes += r.bytes;
    }
    n.value = files;
    n.size = bytes;
    return { files, bytes };
  };
  roots.forEach(acc);
  res.json({ code: 0, data: roots });
});

/** GET /api/tags —— 标签列表（含各标签资源数；数据库视图标签筛选/标签维度图谱用） */
router.get('/tags', (_req, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT t.id, t.name, t.color, COUNT(rt.resource_id) AS count
     FROM tags t LEFT JOIN resource_tags rt ON rt.tag_id = t.id
     GROUP BY t.id ORDER BY t.name`
  ).all();
  res.json({ code: 0, data: rows });
});

/** POST /api/tags —— 创建标签 */
router.post('/tags', (req, res) => {
  const db = getDb();
  const { name, color } = req.body as { name?: string; color?: string };
  const n = (name || '').trim();
  if (!n) { res.status(400).json({ code: 1, msg: '标签名不能为空' }); return; }
  const exists = db.prepare(`SELECT id FROM tags WHERE name = ?`).get(n) as { id: string } | undefined;
  if (exists) { res.status(400).json({ code: 1, msg: '标签已存在' }); return; }
  const id = randomUUID();
  const c = color || '#8BC8EA';
  db.prepare(`INSERT INTO tags (id, name, color) VALUES (?, ?, ?)`).run(id, n, c);
  res.json({ code: 0, data: { id, name: n, color: c, count: 0 } });
});

/** PUT /api/tags/:id —— 重命名 / 改色 */
router.put('/tags/:id', (req, res) => {
  const db = getDb();
  const { name, color } = req.body as { name?: string; color?: string };
  const row = db.prepare(`SELECT id, name, color FROM tags WHERE id = ?`).get(req.params.id) as { id: string; name: string; color: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '标签不存在' }); return; }
  const newName = (name ?? row.name).trim();
  if (!newName) { res.status(400).json({ code: 1, msg: '标签名不能为空' }); return; }
  const dup = db.prepare(`SELECT id FROM tags WHERE name = ? AND id != ?`).get(newName, row.id) as { id: string } | undefined;
  if (dup) { res.status(400).json({ code: 1, msg: '标签名已存在' }); return; }
  const newColor = color || row.color;
  db.prepare(`UPDATE tags SET name = ?, color = ? WHERE id = ?`).run(newName, newColor, row.id);
  res.json({ code: 0, data: { id: row.id, name: newName, color: newColor } });
});

/** DELETE /api/tags/:id —— 删除标签（resource_tags 级联清理） */
router.delete('/tags/:id', (req, res) => {
  const db = getDb();
  const info = db.prepare(`DELETE FROM tags WHERE id = ?`).run(req.params.id);
  if (info.changes === 0) { res.status(404).json({ code: 1, msg: '标签不存在' }); return; }
  res.json({ code: 0, data: { id: req.params.id } });
});

/** GET /api/resources/:id/tags —— 单资源标签 */
router.get('/resources/:id/tags', (req, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT t.id, t.name, t.color FROM resource_tags rt
     JOIN tags t ON t.id = rt.tag_id WHERE rt.resource_id = ?`
  ).all(req.params.id);
  res.json({ code: 0, data: rows });
});

/** POST /api/resources/pending —— 批量标记/取消"待整理"（meta.pending；工作台/浏览页可筛选）
 *  加入方向：已标记待整理的资源自动跳过（不重复加入）；文件夹递归其下全部子文件夹与文件 */
router.post('/resources/pending', (req, res) => {
  const db = getDb();
  const { ids, pending } = req.body as { ids?: unknown; pending?: unknown };
  const idList = Array.isArray(ids) ? [...new Set(ids.map(String))] : [];
  if (idList.length === 0) { res.status(400).json({ code: 1, msg: '未选择资源' }); return; }
  const p = pending ? 1 : 0;
  const now = new Date().toISOString();
  const getRow = db.prepare(`SELECT id, type FROM resources WHERE id = ? AND status='active'`);
  const getKids = db.prepare(`SELECT id, type FROM resources WHERE parent_id = ? AND status='active'`);
  // 已标记待整理的集合（加入方向用于跳过）
  const pendingSet = new Set<string>(
    (db.prepare(`SELECT id FROM resources WHERE json_extract(meta, '$.pending') = 1`).all() as { id: string }[]).map(r => r.id)
  );
  let skipped = 0;
  const tx = db.transaction(() => {
    const upd = db.prepare(
      `UPDATE resources SET meta = json_set(CASE WHEN json_valid(meta) THEN meta ELSE '{}' END, '$.pending', ?), updated_at = ? WHERE id = ?`
    );
    const seen = new Set<string>();
    const targets: string[] = [];
    for (const id of idList) {
      const row = getRow.get(id) as { id: string; type: string } | undefined;
      if (!row) continue;
      const queue: { id: string; type: string }[] = [row];
      while (queue.length) {
        const cur = queue.pop()!;
        if (seen.has(cur.id)) continue;
        seen.add(cur.id);
        if (p === 1 && pendingSet.has(cur.id)) { // 已待整理不重复加入：跳过自身，但文件夹仍继续递归子项（子项可能未标记）
          skipped++;
          if (cur.type === 'folder') {
            queue.push(...(getKids.all(cur.id) as { id: string; type: string }[]));
          }
          continue;
        }
        targets.push(cur.id);
        if (cur.type === 'folder') { // 文件夹递归子文件夹与文件
          queue.push(...(getKids.all(cur.id) as { id: string; type: string }[]));
        }
      }
    }
    for (const id of targets) upd.run(p, now, id);
    return targets.length;
  });
  const count = tx();
  res.json({ code: 0, data: { ok: true, count, skipped, pending: !!pending } });
});

/** POST /api/resources/:id/pin —— 置顶/取消置顶（meta.pinned；当前文件页已移除置顶入口与排序优先，接口保留以备后续扩展） */
router.post('/resources/:id/pin', (req, res) => {
  const db = getDb();
  const pinned = req.body?.pinned ? 1 : 0;
  const row = db.prepare(`SELECT id FROM resources WHERE id = ? AND status='active'`).get(req.params.id);
  if (!row) { res.status(404).json({ code: 1, msg: '资源不存在' }); return; }
  db.prepare(
    `UPDATE resources SET meta = json_set(CASE WHEN json_valid(meta) THEN meta ELSE '{}' END, '$.pinned', ?), updated_at = ? WHERE id = ?`
  ).run(pinned, new Date().toISOString(), req.params.id);
  res.json({ code: 0, data: { ok: true, pinned: !!pinned } });
});

/** PUT /api/resources/:id/tags —— 设置资源标签（全量替换；recursive=true 且为文件夹时，子树全部资源合并追加这些标签） */
router.put('/resources/:id/tags', (req, res) => {  const db = getDb();
  const { tagIds, recursive } = req.body as { tagIds?: unknown; recursive?: unknown };
  const ids = Array.isArray(tagIds) ? [...new Set(tagIds.map(String))] : [];
  const row = db.prepare(`SELECT id, type FROM resources WHERE id = ? AND status='active'`).get(req.params.id) as
    { id: string; type: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '资源不存在' }); return; }
  const tx = db.transaction(() => {
    // 本资源全量替换
    db.prepare(`DELETE FROM resource_tags WHERE resource_id = ?`).run(req.params.id);
    const ins = db.prepare(`INSERT OR IGNORE INTO resource_tags (resource_id, tag_id) VALUES (?, ?)`);
    for (const tid of ids) ins.run(req.params.id, tid);
    // 递归应用到整个子树（仅文件夹支持）：子资源合并追加（保留各自原有标签）
    if (recursive === true && row.type === 'folder' && ids.length > 0) {
      const stack = [row.id];
      while (stack.length) {
        const pid = stack.pop()!;
        const kids = db.prepare(`SELECT id FROM resources WHERE parent_id = ? AND status='active'`).all(pid) as { id: string }[];
        for (const k of kids) {
          for (const tid of ids) ins.run(k.id, tid);
          stack.push(k.id);
        }
      }
    }
  });
  tx();
  res.json({ code: 0, data: { resourceId: req.params.id, tagIds: ids, recursive: recursive === true } });
});

// ============ 自建资源（笔记 / 书签 / 待办）：创建、详情、更新、删除（回收站软删） ============

/** 可自建资源类型（文件/文件夹来自磁盘扫描，不走此路径） */
const SELF_TYPES = new Set(['note', 'bookmark', 'todo']);

/** 清理回收站中超过 30 天的资源（软删 meta.deleted_at 早于 30 天前 → 彻底删除，FTS 由触发器同步） */
function purgeTrashed(db: ReturnType<typeof getDb>): void {
  const cut = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
  db.prepare(
    `DELETE FROM resources WHERE status='trashed' AND json_extract(meta, '$.deleted_at') IS NOT NULL
     AND json_extract(meta, '$.deleted_at') < ?`
  ).run(cut);
}

/** GET /api/resources/trash/info —— 回收站信息（工作台显示清理提示） */
router.get('/resources/trash/info', (_req, res) => {
  const db = getDb();
  purgeTrashed(db);
  const row = db.prepare(
    `SELECT COUNT(*) AS n, MIN(json_extract(meta, '$.deleted_at')) AS oldest
     FROM resources WHERE status='trashed'`
  ).get() as { n: number; oldest: string | null };
  // 最早的删除时间 + 30 天 = 自动清理时间（已过期但尚未 purge 的也一并显示）
  const clear_at = row.oldest
    ? new Date(new Date(row.oldest).getTime() + 30 * 24 * 3600 * 1000).toISOString()
    : null;
  res.json({ code: 0, data: { count: row.n, clear_at, days: 30 } });
});

/** POST /api/resources —— 创建自建资源（note/bookmark/todo） */
router.post('/resources', (req, res) => {
  const db = getDb();
  const { type, title, content, source_url } = req.body as {
    type?: string; title?: string; content?: string; source_url?: string;
  };
  if (!type || !SELF_TYPES.has(type)) { res.status(400).json({ code: 1, msg: '仅支持创建笔记/书签/待办' }); return; }
  if (!title || !String(title).trim()) { res.status(400).json({ code: 1, msg: '标题不能为空' }); return; }
  if (type === 'bookmark' && !String(source_url || '').trim()) { res.status(400).json({ code: 1, msg: '书签链接不能为空' }); return; }
  const id = randomUUID();
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO resources (id, type, title, content, source_url, path, parent_id, status, done, meta, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, '', NULL, 'active', 0, '{}', ?, ?)`
  ).run(id, type, String(title).trim(), String(content || ''), String(source_url || ''), now, now);
  res.json({ code: 0, data: { id, type, title: String(title).trim() } });
});

/** GET /api/resources/:id —— 资源详情（含 content/source_url/meta，笔记编辑器与书签编辑用） */
router.get('/resources/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(
    `SELECT id, type, title, content, source_url, path, parent_id, done, meta, created_at, updated_at
     FROM resources WHERE id = ? AND status='active'`
  ).get(req.params.id);
  if (!row) { res.status(404).json({ code: 1, msg: '资源不存在' }); return; }
  res.json({ code: 0, data: row });
});

/** PUT /api/resources/:id —— 更新自建资源（note/bookmark/todo 的标题/内容/链接） */
router.put('/resources/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(`SELECT id, type FROM resources WHERE id = ? AND status='active'`).get(req.params.id) as
    { id: string; type: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '资源不存在' }); return; }
  if (!SELF_TYPES.has(row.type)) { res.status(400).json({ code: 1, msg: '该类型不支持此更新方式' }); return; }
  const { title, content, source_url, done, meta } = req.body as { title?: string; content?: string; source_url?: string; done?: unknown; meta?: unknown };
  const set: string[] = [];
  const params: unknown[] = [];
  if (title !== undefined) {
    if (!String(title).trim()) { res.status(400).json({ code: 1, msg: '标题不能为空' }); return; }
    set.push('title = ?'); params.push(String(title).trim());
  }
  if (content !== undefined) { set.push('content = ?'); params.push(String(content)); }
  if (source_url !== undefined) {
    if (row.type === 'bookmark' && !String(source_url).trim()) { res.status(400).json({ code: 1, msg: '书签链接不能为空' }); return; }
    set.push('source_url = ?'); params.push(String(source_url));
  }
  if (done !== undefined) { set.push('done = ?'); params.push(done ? 1 : 0); }
  // meta：仅整体覆盖（书签图标 icon / 待整理 pending 等）；前端负责合并后传入完整 meta
  if (meta !== undefined) {
    const metaStr = typeof meta === 'string' ? meta : JSON.stringify(meta || {});
    set.push('meta = ?'); params.push(metaStr);
  }
  if (set.length === 0) { res.json({ code: 0, data: { ok: true } }); return; }
  set.push('updated_at = ?'); params.push(new Date().toISOString());
  params.push(req.params.id);
  db.prepare(`UPDATE resources SET ${set.join(', ')} WHERE id = ?`).run(...params);
  res.json({ code: 0, data: { ok: true } });
});

/** DELETE /api/resources/:id —— 删除自建资源（软删进回收站，30 天后自动清理） */
router.delete('/resources/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(`SELECT id, type FROM resources WHERE id = ? AND status='active'`).get(req.params.id) as
    { id: string; type: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '资源不存在' }); return; }
  if (!SELF_TYPES.has(row.type)) { res.status(400).json({ code: 1, msg: '该类型不支持删除' }); return; }
  const now = new Date().toISOString();
  db.prepare(
    `UPDATE resources SET status='trashed', meta = json_set(CASE WHEN json_valid(meta) THEN meta ELSE '{}' END, '$.deleted_at', ?), updated_at = ? WHERE id = ?`
  ).run(now, now, req.params.id);
  purgeTrashed(db); // 顺带清理超期回收站
  res.json({ code: 0, data: { ok: true } });
});

export default router;
