import axios from 'axios';

const http = axios.create({ baseURL: '/api', timeout: 10000 });

export interface Resource {
  id: string;
  type: 'bookmark' | 'note' | 'file' | 'todo' | 'report' | 'folder';
  title: string;
  path: string;
  parent_id: string | null;
  done: number;
  size?: number;
  created_at: string;
  updated_at: string;
  highlight?: string;
  tag_names?: string;
  tag_ids?: string;
}

export interface FolderNode {
  id: string;
  title: string;
  path: string;
  parent_id: string | null;
  children: FolderNode[];
}

/** 文件结构树节点（含文件叶子） */
export interface TreeNode {
  id: string;
  type: 'folder' | 'file';
  title: string;
  path: string;
  parent_id: string | null;
  children: TreeNode[];
}

export const getStats = () => http.get('/stats').then(r => r.data.data);
export const getFolders = () => http.get('/folders').then(r => r.data.data);
export const getTree = () => http.get('/tree').then(r => r.data.data as TreeNode[]);
export const getResources = (params: Record<string, string>) =>
  http.get('/resources', { params }).then(r => r.data.data as Resource[]);
export const search = (q: string) => http.get('/search', { params: { q } }).then(r => r.data.data as Resource[]);

/** 工作台聚合数据 */
export interface TopFolderStat {
  id: string; title: string; path: string; files: number; subFolders: number; bytes: number;
}
export interface TopTagStat { id: string; name: string; color: string; n: number }
export interface DashboardData {
  total: number;
  byType: { type: string; n: number }[];
  tagCount: number;
  topFolders: TopFolderStat[];
  recent: Resource[];
  topTags: TopTagStat[];
}
export const getDashboard = () => http.get('/dashboard').then(r => r.data.data as DashboardData);

/** 数据库视图：分页 + 筛选 + 排序 */
export interface PageResult<T> { list: T[]; total: number }
export interface TagItem { id: string; name: string; color: string; count: number }
export const getResourcesPage = (params: Record<string, string>) =>
  http.get('/resources', { params }).then(r => r.data.data as PageResult<Resource>);
export const getTags = () => http.get('/tags').then(r => r.data.data as TagItem[]);
export const createTag = (name: string, color?: string) =>
  http.post('/tags', { name, color }).then(r => r.data.data as TagItem);
export const updateTag = (id: string, patch: { name?: string; color?: string }) =>
  http.put(`/tags/${id}`, patch).then(r => r.data.data as TagItem);
export const deleteTag = (id: string) => http.delete(`/tags/${id}`).then(r => r.data.data);
export const setResourceTags = (resourceId: string, tagIds: string[], recursive = false) =>
  http.put(`/resources/${resourceId}/tags`, { tagIds, recursive }).then(r => r.data.data);

/** 文件内容读取地址（供预览/图片缩略图） */
export const fileUrl = (id: string) => `/api/file/${id}`;

export interface GraphNode {
  id: string;
  name: string;
  label: string;
  category: string;
  symbolSize: number;
}
export interface GraphLink {
  source: string;
  target: string;
  value?: number;
}
export interface GraphData {
  nodes: GraphNode[];
  links: GraphLink[];
}
export const getGraph = (dimension: string) =>
  http.get('/graph', { params: { dimension } }).then(r => r.data.data as GraphData);

/** 时间线：按创建时间倒序的资源流 */
export const getTimeline = (type = '') =>
  http.get('/timeline', { params: { type } }).then(r => r.data.data as Resource[]);

/** 报表中心 */
export interface ReportGenResult {
  content: string;
  period_start: string;
  period_end: string;
  total: number;
}
export interface ReportItem {
  id: string;
  title: string;
  period_start: string | null;
  period_end: string | null;
  created_at: string;
}
export const generateReport = (type: string, ref = '') =>
  http.post('/reports/generate', { type, ref }).then(r => r.data.data as ReportGenResult);
export const saveReport = (title: string, content: string, period_start: string, period_end: string) =>
  http.post('/reports/save', { title, content, period_start, period_end }).then(r => r.data.data as { id: string; title: string; created_at: string });
export const getReports = () => http.get('/reports').then(r => r.data.data as ReportItem[]);
