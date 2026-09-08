import { Router } from 'express';
import { randomUUID } from 'node:crypto';
import { getDb } from '../db';

export const mindmapsRouter = Router();

const fmt = (d: Date) => d.toISOString().slice(0, 19).replace('T', ' ');
/** 回收站保留期限（天）：超过后自动物理清理 */
const RECYCLE_DAYS = 30;

/** 惰性清理：删除超过保留期限的回收站导图（级联删除 nodes/links/members） */
function purgeExpired(db: ReturnType<typeof getDb>): void {
  const cutoff = fmt(new Date(Date.now() - RECYCLE_DAYS * 86400000));
  db.prepare(`DELETE FROM mindmaps WHERE deleted_at IS NOT NULL AND deleted_at < ?`).run(cutoff);
}

/** GET /api/mindmaps —— 导图库列表（仅未删除；置顶优先，再按更新时间倒序；惰性清理过期回收站） */
mindmapsRouter.get('/mindmaps', (_req, res) => {
  const db = getDb();
  purgeExpired(db);
  const rows = db.prepare(
    `SELECT m.id, m.title, m.layout, m.theme, m.pinned, m.tags, m.updated_at,
       (SELECT COUNT(*) FROM mindmap_nodes n WHERE n.map_id = m.id AND n.kind = 'node') AS node_count
     FROM mindmaps m WHERE m.deleted_at IS NULL
     ORDER BY m.pinned DESC, m.updated_at DESC`
  ).all();
  res.json({ code: 0, data: rows });
});

/** GET /api/mindmaps/recycle —— 回收站列表（软删除的导图） */
mindmapsRouter.get('/mindmaps/recycle', (_req, res) => {
  const db = getDb();
  purgeExpired(db);
  const rows = db.prepare(
    `SELECT m.id, m.title, m.layout, m.theme, m.deleted_at, m.updated_at,
       (SELECT COUNT(*) FROM mindmap_nodes n WHERE n.map_id = m.id AND n.kind = 'node') AS node_count
     FROM mindmaps m WHERE m.deleted_at IS NOT NULL
     ORDER BY m.deleted_at DESC`
  ).all();
  res.json({ code: 0, data: rows });
});

/** GET /api/mindmaps/recycle/info —— 回收站统计（工作台显示清理信息用） */
mindmapsRouter.get('/mindmaps/recycle/info', (_req, res) => {
  const db = getDb();
  purgeExpired(db);
  const row = db.prepare(
    `SELECT COUNT(*) AS count, MIN(deleted_at) AS earliest FROM mindmaps WHERE deleted_at IS NOT NULL`
  ).get() as { count: number; earliest: string | null };
  let clearAt: string | null = null;
  if (row.earliest) {
    const t = new Date(row.earliest.replace(' ', 'T') + 'Z').getTime() + RECYCLE_DAYS * 86400000;
    clearAt = fmt(new Date(t));
  }
  res.json({ code: 0, data: { count: row.count, clear_at: clearAt, days: RECYCLE_DAYS } });
});

/** POST /api/mindmaps —— 新建导图（含根节点） */
mindmapsRouter.post('/mindmaps', (req, res) => {
  const db = getDb();
  const title = (req.body?.title as string || '').trim() || '未命名导图';
  const id = randomUUID();
  const now = fmt(new Date());
  db.transaction(() => {
    db.prepare(`INSERT INTO mindmaps (id, title, layout, theme, created_at, updated_at) VALUES (?, ?, 'right', 'nexa-light', ?, ?)`).run(id, title, now, now);
    db.prepare(`INSERT INTO mindmap_nodes (id, map_id, parent_id, title, kind, x, y, color, shape, sort, created_at) VALUES (?, ?, NULL, ?, 'node', 0, 0, NULL, 'auto', 0, ?)`)
      .run(randomUUID(), id, title, now);
  })();
  res.json({ code: 0, data: { id } });
});

/** GET /api/mindmaps/:id —— 导图完整数据（nodes + links + members） */
mindmapsRouter.get('/mindmaps/:id', (req, res) => {
  const db = getDb();
  const map = db.prepare(`SELECT * FROM mindmaps WHERE id = ? AND deleted_at IS NULL`).get(req.params.id);
  if (!map) { res.status(404).json({ code: 1, msg: '导图不存在' }); return; }
  const nodes = db.prepare(`SELECT * FROM mindmap_nodes WHERE map_id = ? ORDER BY sort, created_at`).all(req.params.id);
  const links = db.prepare(`SELECT * FROM mindmap_links WHERE map_id = ?`).all(req.params.id);
  const members = db.prepare(`SELECT group_id, node_id FROM mindmap_members WHERE group_id IN (SELECT id FROM mindmap_nodes WHERE map_id = ?)`).all(req.params.id);
  res.json({ code: 0, data: { ...map, nodes, links, members } });
});

/** PUT /api/mindmaps/:id —— 更新元信息（title/layout/theme/pinned/tags） */
mindmapsRouter.put('/mindmaps/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(`SELECT id FROM mindmaps WHERE id = ? AND deleted_at IS NULL`).get(req.params.id) as { id: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '导图不存在' }); return; }
  const { title, layout, theme, pinned, tags } = req.body as { title?: string; layout?: string; theme?: string; pinned?: number; tags?: string };
  db.prepare(`UPDATE mindmaps SET title = COALESCE(?, title), layout = COALESCE(?, layout), theme = COALESCE(?, theme), pinned = COALESCE(?, pinned), tags = COALESCE(?, tags), updated_at = ? WHERE id = ?`)
    .run(title?.trim() || null, layout || null, theme || null, typeof pinned === 'number' ? (pinned ? 1 : 0) : null, tags ?? null, fmt(new Date()), req.params.id);
  res.json({ code: 0, data: { ok: true } });
});

/** PUT /api/mindmaps/:id/nodes —— 全量批量保存节点（客户端为权威状态） */
mindmapsRouter.put('/mindmaps/:id/nodes', (req, res) => {
  const db = getDb();
  const nodes = (req.body?.nodes || []) as { id: string; parent_id: string | null; title: string; desc?: string; kind: string; x: number; y: number; color: string | null; shape: string; sort: number; expand?: number }[];
  if (!Array.isArray(nodes)) { res.status(400).json({ code: 1, msg: 'nodes 必须是数组' }); return; }
  const tx = db.transaction(() => {
    db.prepare(`DELETE FROM mindmap_nodes WHERE map_id = ?`).run(req.params.id);
    const ins = db.prepare(`INSERT INTO mindmap_nodes (id, map_id, parent_id, title, desc, expand, kind, x, y, color, shape, sort, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
    for (const n of nodes) {
      ins.run(n.id, req.params.id, n.parent_id, n.title || '', n.desc || '', n.expand === 0 ? 0 : 1, n.kind || 'node', n.x || 0, n.y || 0, n.color || null, n.shape || 'auto', n.sort || 0, fmt(new Date()));
    }
  });
  tx();
  res.json({ code: 0, data: { ok: true } });
});

/** PUT /api/mindmaps/:id/links —— 全量批量保存关系连线 */
mindmapsRouter.put('/mindmaps/:id/links', (req, res) => {
  const db = getDb();
  const links = (req.body?.links || []) as { id: string; source_id: string; target_id: string; label: string }[];
  if (!Array.isArray(links)) { res.status(400).json({ code: 1, msg: 'links 必须是数组' }); return; }
  const tx = db.transaction(() => {
    db.prepare(`DELETE FROM mindmap_links WHERE map_id = ?`).run(req.params.id);
    const ins = db.prepare(`INSERT INTO mindmap_links (id, map_id, source_id, target_id, label) VALUES (?, ?, ?, ?, ?)`);
    for (const l of links) ins.run(l.id, req.params.id, l.source_id, l.target_id, l.label || '');
  });
  tx();
  res.json({ code: 0, data: { ok: true } });
});

/** PUT /api/mindmaps/:id/members —— 全量批量保存边界/概要成员关系 */
mindmapsRouter.put('/mindmaps/:id/members', (req, res) => {
  const db = getDb();
  const members = (req.body?.members || []) as { group_id: string; node_id: string }[];
  if (!Array.isArray(members)) { res.status(400).json({ code: 1, msg: 'members 必须是数组' }); return; }
  const tx = db.transaction(() => {
    db.prepare(`DELETE FROM mindmap_members WHERE group_id IN (SELECT id FROM mindmap_nodes WHERE map_id = ?)`).run(req.params.id);
    // 清理孤儿组员（历史 boundary 节点已删除但组员残留，避免累积）
    db.prepare(`DELETE FROM mindmap_members WHERE group_id NOT IN (SELECT id FROM mindmap_nodes)`).run();
    const ins = db.prepare(`INSERT OR IGNORE INTO mindmap_members (group_id, node_id) VALUES (?, ?)`);
    for (const m of members) ins.run(m.group_id, m.node_id);
  });
  tx();
  res.json({ code: 0, data: { ok: true } });
});

/** POST /api/mindmaps/:id/restore —— 从回收站恢复导图 */
mindmapsRouter.post('/mindmaps/:id/restore', (req, res) => {
  const db = getDb();
  const r = db.prepare(`UPDATE mindmaps SET deleted_at = NULL, updated_at = ? WHERE id = ? AND deleted_at IS NOT NULL`).run(fmt(new Date()), req.params.id);
  if (!r.changes) { res.status(404).json({ code: 1, msg: '回收站中没有该导图' }); return; }
  res.json({ code: 0, data: { ok: true } });
});

/** DELETE /api/mindmaps/:id —— 删除导图（软删除：移入回收站，记录删除时间，超期自动清理） */
mindmapsRouter.delete('/mindmaps/:id', (req, res) => {
  const db = getDb();
  const r = db.prepare(`UPDATE mindmaps SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL`).run(fmt(new Date()), fmt(new Date()), req.params.id);
  if (!r.changes) { res.status(404).json({ code: 1, msg: '导图不存在或已在回收站' }); return; }
  res.json({ code: 0, data: { ok: true } });
});

/** DELETE /api/mindmaps/:id/permanent —— 彻底删除（回收站内，级联删除 nodes/links/members） */
mindmapsRouter.delete('/mindmaps/:id/permanent', (req, res) => {
  const db = getDb();
  const r = db.prepare(`DELETE FROM mindmaps WHERE id = ? AND deleted_at IS NOT NULL`).run(req.params.id);
  if (!r.changes) { res.status(404).json({ code: 1, msg: '回收站中没有该导图' }); return; }
  res.json({ code: 0, data: { ok: true } });
});
