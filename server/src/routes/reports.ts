import { Router, type Request } from 'express';
import { randomUUID } from 'node:crypto';
import { getDb } from '../db.js';

const router = Router();

const TYPE_LABEL: Record<string, string> = {
  folder: '文件夹', file: '文件', note: '笔记', bookmark: '书签', todo: '待办', report: '报表',
};

/** 计算报表期间 [start, end]，ref 为 YYYY-MM-DD（默认今天） */
function periodOf(type: string, ref: string): { start: string; end: string } {
  const base = ref ? new Date(`${ref}T00:00:00`) : new Date();
  const y = base.getFullYear();
  const m = base.getMonth();
  const d = base.getDate();
  const pad = (n: number) => String(n).padStart(2, '0');
  const iso = (dt: Date) => `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`;
  switch (type) {
    case 'day':
      return { start: iso(base), end: iso(base) };
    case 'week': {
      // 周一为一周开始
      const wd = (base.getDay() + 6) % 7;
      const s = new Date(y, m, d - wd);
      const e = new Date(y, m, d - wd + 6);
      return { start: iso(s), end: iso(e) };
    }
    case 'month': {
      const last = new Date(y, m + 1, 0).getDate();
      return { start: `${y}-${pad(m + 1)}-01`, end: `${y}-${pad(m + 1)}-${pad(last)}` };
    }
    case 'quarter': {
      const q = Math.floor(m / 3);
      const sm = q * 3, em = q * 3 + 2;
      const last = new Date(y, em + 1, 0).getDate();
      return { start: `${y}-${pad(sm + 1)}-01`, end: `${y}-${pad(em + 1)}-${pad(last)}` };
    }
    case 'year':
      return { start: `${y}-01-01`, end: `${y}-12-31` };
    default:
      return { start: iso(base), end: iso(base) };
  }
}

function esc(s: string) {
  return s.replace(/\|/g, '\\|').replace(/\n/g, ' ');
}

/** 格式化为本地时间 YYYY-MM-DD HH:mm（兼容 ISO 与 'YYYY-MM-DD HH:mm:ss' 两种存储） */
function fmtDt(s: string) {
  if (!s) return '';
  const d = new Date(s.includes('T') ? s : s.replace(' ', 'T'));
  if (isNaN(d.getTime())) return s;
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** 统计并生成 Markdown 报表 */
function buildReport(type: string, ref: string) {
  const db = getDb();
  const { start, end } = periodOf(type, ref);
  const typeLabel: Record<string, string> = { day: '日报', week: '周报', month: '月报', quarter: '季报', year: '年报' };

  // 1. 新增资源总数 + 类型分布
  const byType = db.prepare(
    `SELECT type, COUNT(*) AS n FROM resources
     WHERE status='active' AND date(created_at) BETWEEN @s AND @e
     GROUP BY type ORDER BY n DESC`
  ).all({ s: start, e: end }) as { type: string; n: number }[];
  const total = byType.reduce((a, r) => a + r.n, 0);

  // 2. 完成待办（期间内创建的 todo 且已勾选）
  const doneTodo = db.prepare(
    `SELECT COUNT(*) AS n FROM resources
     WHERE type='todo' AND done=1 AND date(created_at) BETWEEN @s AND @e`
  ).get({ s: start, e: end }) as { n: number };

  // 3. 趋势：周/日报按天，月/季/年报按周聚合（周一起始）
  const isShort = type === 'day' || type === 'week';
  const trendKey = isShort ? 'd' : 'w';
  const trendRows = db.prepare(
    `SELECT substr(created_at, 1, 10) AS d, COUNT(*) AS n
     FROM resources WHERE status='active' AND date(created_at) BETWEEN @s AND @e
     GROUP BY d ORDER BY d`
  ).all({ s: start, e: end }) as { d: string; n: number }[];
  const trend: { key: string; n: number }[] = trendRows.map(r => ({ key: r.d.slice(5), n: r.n }));
  if (!isShort) {
    // 聚合成周（按 ISO 周一起始的周序号）
    const weeks = new Map<string, number>();
    for (const r of trendRows) {
      const dt = new Date(`${r.d}T00:00:00`);
      const wd = (dt.getDay() + 6) % 7;
      const monday = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate() - wd);
      const key = `${monday.getMonth() + 1}/${monday.getDate()}`;
      weeks.set(key, (weeks.get(key) || 0) + r.n);
    }
    trend.length = 0;
    for (const [k, n] of [...weeks.entries()].sort()) trend.push({ key: k, n });
  }

  // 4. 热门标签（期间内新增资源关联的标签）
  const topTags = db.prepare(
    `SELECT t.name, COUNT(rt.resource_id) AS n
     FROM resource_tags rt JOIN tags t ON t.id = rt.tag_id
     JOIN resources r ON r.id = rt.resource_id
     WHERE r.status='active' AND date(r.created_at) BETWEEN @s AND @e
     GROUP BY t.id ORDER BY n DESC LIMIT 10`
  ).all({ s: start, e: end }) as { name: string; n: number }[];

  // 5. 明细（前 60 条）
  const detail = db.prepare(
    `SELECT title, type, created_at FROM resources
     WHERE status='active' AND date(created_at) BETWEEN @s AND @e
     ORDER BY created_at DESC LIMIT 60`
  ).all({ s: start, e: end }) as { title: string; type: string; created_at: string }[];

  const now = new Date();
  const nowStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  const periodName = `${typeLabel[type]}（${start} ~ ${end}）`;

  let md = `# 📊 ${periodName}\n\n> 生成时间：${nowStr}\n\n`;
  md += `## 概览\n\n| 指标 | 数值 |\n| --- | --- |\n`;
  md += `| 新增资源 | ${total} |\n`;
  for (const t of byType) {
    md += `| └ ${TYPE_LABEL[t.type] || t.type} | ${t.n} |\n`;
  }
  md += `| 完成待办 | ${doneTodo.n} |\n\n`;

  md += `## 趋势\n\n| ${isShort ? '日期' : '周（周一）'} | 新增 |\n| --- | --- |\n`;
  for (const t of trend) md += `| ${t.key} | ${t.n} |\n`;
  if (trend.length === 0) md += `| （无） | 0 |\n`;
  md += '\n';

  md += `## 热门标签\n\n`;
  if (topTags.length === 0) {
    md += `（期间内新增资源未打标签）\n\n`;
  } else {
    md += `| 标签 | 使用次数 |\n| --- | --- |\n`;
    for (const t of topTags) md += `| ${esc(t.name)} | ${t.n} |\n`;
    md += '\n';
  }

  md += `## 新增明细（前 ${detail.length} 条）\n\n`;
  if (detail.length === 0) {
    md += `（期间内无新增）\n`;
  } else {
    for (const r of detail) {
      md += `- [${TYPE_LABEL[r.type] || r.type}] ${esc(r.title)}（${fmtDt(r.created_at)}）\n`;
    }
  }

  return { md, start, end, total };
}

/** POST /api/reports/generate —— 生成报表（不落库） */
router.post('/reports/generate', (req: Request, res) => {
  const { type = 'week', ref = '' } = req.body as { type?: string; ref?: string };
  const r = buildReport(type, ref);
  res.json({ code: 0, data: { content: r.md, period_start: r.start, period_end: r.end, total: r.total } });
});

/** POST /api/reports/save —— 保存报表到知识库（resources type=report + reports 表） */
router.post('/reports/save', (req: Request, res) => {
  const { title, content, period_start, period_end } = req.body as {
    title?: string; content?: string; period_start?: string; period_end?: string;
  };
  if (!title || !content) {
    res.status(400).json({ code: 400, msg: 'title 与 content 必填' });
    return;
  }
  const db = getDb();
  const nowD = new Date();
  const now = `${nowD.getFullYear()}-${String(nowD.getMonth() + 1).padStart(2, '0')}-${String(nowD.getDate()).padStart(2, '0')} ${String(nowD.getHours()).padStart(2, '0')}:${String(nowD.getMinutes()).padStart(2, '0')}:${String(nowD.getSeconds()).padStart(2, '0')}`;
  const id = randomUUID();
  db.prepare(
    `INSERT INTO resources (id, type, title, content, status, created_at, updated_at)
     VALUES (?, 'report', ?, ?, 'active', ?, ?)`
  ).run(id, title, content, now, now);
  db.prepare(
    `INSERT INTO reports (id, type, title, period_start, period_end, content, created_at, updated_at)
     VALUES (?, 'report', ?, ?, ?, ?, ?, ?)`
  ).run(id, title, period_start || null, period_end || null, content, now, now);
  res.json({ code: 0, data: { id, title, created_at: now } });
});

/** GET /api/reports —— 已保存的报表列表 */
router.get('/reports', (_req: Request, res) => {
  const db = getDb();
  const rows = db.prepare(
    `SELECT id, title, period_start, period_end, created_at FROM reports ORDER BY created_at DESC LIMIT 200`
  ).all() as { id: string; title: string; period_start: string | null; period_end: string | null; created_at: string }[];
  res.json({ code: 0, data: rows });
});

export default router;

