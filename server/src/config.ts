import { fileURLToPath } from 'node:url';
import path from 'node:path';

/** 文件库主目录（storage_root）—— 首次启动时设定，目录外文件一律不接受 */
export const STORAGE_ROOT = 'D:\\Office办公\\VBE2021\\Code';

/** SQLite 数据库文件位置（server/data/knowledge.db） */
export const DB_PATH = fileURLToPath(new URL('../data/knowledge.db', import.meta.url));

/** 服务端口 */
export const PORT = 5177;
