import express from 'express';
import cors from 'cors';
import { PORT } from './config.js';
import { getDb } from './db.js';
import resourcesRouter from './routes/resources.js';
import reportsRouter from './routes/reports.js';
import { mindmapsRouter } from './routes/mindmaps.js';
import { scanLibrary } from './scanner.js';

const app = express();
app.use(cors());
// 导图全量节点保存/导入可达数 MB，放宽 JSON body 上限（默认 100kb 会 413）
app.use(express.json({ limit: '50mb' }));

// 初始化数据库（建表）
getDb();

app.use('/api', resourcesRouter);
app.use('/api', reportsRouter);
app.use('/api', mindmapsRouter);

app.get('/api/health', (_req, res) => {
  res.json({ code: 0, msg: 'knowledge-hub server OK' });
});

/** POST /api/rescan —— 重新全量扫描 storage_root 入库（幂等重建 folder/file 记录，保留标签等元数据关联表） */
app.post('/api/rescan', (_req, res) => {
  try {
    const r = scanLibrary();
    res.json({ code: 0, data: r });
  } catch (e: any) {
    res.status(500).json({ code: 1, msg: '扫描失败：' + (e?.message || e) });
  }
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`✅ Knowledge Hub 服务已启动: http://127.0.0.1:${PORT}`);
});
