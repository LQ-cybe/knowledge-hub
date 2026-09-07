import express from 'express';
import cors from 'cors';
import { PORT } from './config.js';
import { getDb } from './db.js';
import resourcesRouter from './routes/resources.js';
import reportsRouter from './routes/reports.js';

const app = express();
app.use(cors());
app.use(express.json());

// 初始化数据库（建表）
getDb();

app.use('/api', resourcesRouter);
app.use('/api', reportsRouter);

app.get('/api/health', (_req, res) => {
  res.json({ code: 0, msg: 'knowledge-hub server OK' });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`✅ Knowledge Hub 服务已启动: http://127.0.0.1:${PORT}`);
});
