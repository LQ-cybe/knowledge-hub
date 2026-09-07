import { Router } from 'express';
import { randomUUID } from 'node:crypto';
import { getDb } from '../db';

export const mindmapsRouter = Router();

const fmt = (d: Date) => d.toISOString().slice(0, 19).replace('T', ' ');

/** GET /api/mindmaps —— 导图库列表 */
mindmapsRouter.get('/mindmaps', (_req, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT m.id, m.title, m.layout, m.theme, m.updated_at,
       (SELECT COUNT(*) FROM mindmap_nodes n WHERE n.map_id = m.id AND n.kind = 'node') AS node_count
     FROM mindmaps m ORDER BY m.updated_at DESC`
  ).all();
  res.json({ code: 0, data: rows });
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
  const map = db.prepare(`SELECT * FROM mindmaps WHERE id = ?`).get(req.params.id);
  if (!map) { res.status(404).json({ code: 1, msg: '导图不存在' }); return; }
  const nodes = db.prepare(`SELECT * FROM mindmap_nodes WHERE map_id = ? ORDER BY sort, created_at`).all(req.params.id);
  const links = db.prepare(`SELECT * FROM mindmap_links WHERE map_id = ?`).all(req.params.id);
  const members = db.prepare(`SELECT group_id, node_id FROM mindmap_members WHERE group_id IN (SELECT id FROM mindmap_nodes WHERE map_id = ?)`).all(req.params.id);
  res.json({ code: 0, data: { ...map, nodes, links, members } });
});

/** PUT /api/mindmaps/:id —— 更新元信息（title/layout/theme） */
mindmapsRouter.put('/mindmaps/:id', (req, res) => {
  const db = getDb();
  const row = db.prepare(`SELECT id FROM mindmaps WHERE id = ?`).get(req.params.id) as { id: string } | undefined;
  if (!row) { res.status(404).json({ code: 1, msg: '导图不存在' }); return; }
  const { title, layout, theme } = req.body as { title?: string; layout?: string; theme?: string };
  db.prepare(`UPDATE mindmaps SET title = COALESCE(?, title), layout = COALESCE(?, layout), theme = COALESCE(?, theme), updated_at = ? WHERE id = ?`)
    .run(title?.trim() || null, layout || null, theme || null, fmt(new Date()), req.params.id);
  res.json({ code: 0, data: { ok: true } });
});

/** PUT /api/mindmaps/:id/nodes —— 全量批量保存节点（客户端为权威状态） */
mindmapsRouter.put('/mindmaps/:id/nodes', (req, res) => {
  const db = getDb();
  const nodes = (req.body?.nodes || []) as { id: string; parent_id: string | null; title: string; kind: string; x: number; y: number; color: string | null; shape: string; sort: number }[];
  if (!Array.isArray(nodes)) { res.status(400).json({ code: 1, msg: 'nodes 必须是数组' }); return; }
  const tx = db.transaction(() => {
    db.prepare(`DELETE FROM mindmap_nodes WHERE map_id = ?`).run(req.params.id);
    const ins = db.prepare(`INSERT INTO mindmap_nodes (id, map_id, parent_id, title, kind, x, y, color, shape, sort, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
    for (const n of nodes) {
      ins.run(n.id, req.params.id, n.parent_id, n.title || '', n.kind || 'node', n.x || 0, n.y || 0, n.color || null, n.shape || 'auto', n.sort || 0, fmt(new Date()));
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
    const ins = db.prepare(`INSERT OR IGNORE INTO mindmap_members (group_id, node_id) VALUES (?, ?)`);
    for (const m of members) ins.run(m.group_id, m.node_id);
  });
  tx();
  res.json({ code: 0, data: { ok: true } });
});

/** DELETE /api/mindmaps/:id —— 删除导图（级联） */
mindmapsRouter.delete('/mindmaps/:id', (req, res) => {
  const db = getDb();
  db.prepare(`DELETE FROM mindmaps WHERE id = ?`).run(req.params.id);
  res.json({ code: 0, data: { ok: true } });
});
