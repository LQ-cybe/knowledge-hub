/** 独立扫描命令：npm run scan —— 把 storage_root 全量扫描入库（只读） */
import { scanLibrary } from './scanner.js';
import { closeDb } from './db.js';

const t0 = Date.now();
const r = scanLibrary();
console.log(`扫描完成，耗时 ${Date.now() - t0}ms`);
console.log(`文件夹 ${r.folders} 个 | 文件 ${r.files} 个 | 已建全文索引 ${r.textIndexed} 个 | 忽略 ${r.skipped} 项`);
closeDb();
