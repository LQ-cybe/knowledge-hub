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
}

/** GET /api/resources —— 资源列表（可按 type/parentId/status/q/tag 过滤 + 排序 + 分页）
 *  带 page 参数时返回 { list, total }（数据库视图用）；否则兼容返回数组（浏览页用） */
router.get('/resources', (req: Request, res) => {
  const db = getDb();
  const { type, parentId, status = 'active', q, tag, orderBy = 'updated_at', orderDir = 'desc' } = req.query as Record<string, string>;
  const page = req.query.page !== undefined ? Math.max(1, parseInt(String(req.query.page), 10) || 1) : null;
  const pageSize = Math.min(200, Math.max(1, parseInt(String(req.query.pageSize || '50'), 10) || 50));

  const where: string[] = ['r.status = @status'];
  const params: Record<string, unknown> = { status };
  if (type) { where.push('r.type = @type'); params.type = type; }
  if (parentId !== undefined) { where.push('r.parent_id = @parentId'); params.parentId = parentId === 'root' ? null : parentId; }
  if (q) { where.push('(r.title LIKE @like OR r.path LIKE @like)'); params.like = `%${q}%`; }
  if (tag) {
    where.push('EXISTS (SELECT 1 FROM resource_tags rt WHERE rt.resource_id = r.id AND rt.tag_id = @tag)');
    params.tag = tag;
  }

  const orderCols: Record<string, string> = {
    title: 'r.title', created_at: 'r.created_at', updated_at: 'r.updated_at',
    size: 'r.size', type: 'r.type',
  };
  const orderCol = orderCols[orderBy] || 'r.updated_at';
  const orderDirSql = orderDir.toLowerCase() === 'asc' ? 'ASC' : 'DESC';
  const orderSql = `ORDER BY CASE r.type WHEN 'folder' THEN 0 ELSE 1 END, ${orderCol} ${orderDirSql}`;

  // 标签聚合（数据库视图显示用；子查询走 resource_tags 主键索引，仅对返回行执行）
  const tagNamesSub = `(SELECT GROUP_CONCAT(t.name, '|') FROM resource_tags rt JOIN tags t ON t.id = rt.tag_id WHERE rt.resource_id = r.id)`;
  const tagIdsSub = `(SELECT GROUP_CONCAT(t.id, '|') FROM resource_tags rt JOIN tags t ON t.id = rt.tag_id WHERE rt.resource_id = r.id)`;
  const cols = `r.id, r.type, r.title, r.path, r.parent_id, r.done, r.size, r.created_at, r.updated_at,
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

/** GET /api/stats —— 全局统计（工作台数据源） */
router.get('/stats', (_req, res) => {
  const db = getDb();
  const total = db.prepare(`SELECT COUNT(*) AS n FROM resources WHERE status = 'active'`).get() as { n: number };
  const byType = db.prepare(
    `SELECT type, COUNT(*) AS n FROM resources WHERE status = 'active' GROUP BY type`
  ).all();
  res.json({ code: 0, data: { total: total.n, byType } });
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

/** GET /api/timeline?type= —— 垂直时间线：按创建时间倒序的资源流（前端按天分组） */
router.get('/timeline', (req, res) => {
  const db = getDb();
  const type = (req.query.type as string || '').trim();
  const rows = db.prepare(
    `SELECT id, type, title, path, parent_id, created_at FROM resources
     WHERE status='active' AND (? = '' OR type = ?)
     ORDER BY created_at DESC LIMIT 500`
  ).all(type, type) as { id: string; type: string; title: string; path: string; parent_id: string | null; created_at: string }[];
  res.json({ code: 0, data: rows });
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
    `SELECT resources.id, resources.type, resources.title, resources.path, resources.parent_id,
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

/** PUT /api/resources/:id/tags —— 设置资源标签（全量替换；recursive=true 且为文件夹时，子树全部资源合并追加这些标签） */
router.put('/resources/:id/tags', (req, res) => {
  const db = getDb();
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

export default router;
