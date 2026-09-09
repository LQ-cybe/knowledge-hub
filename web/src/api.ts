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
  source_url?: string;
  created_at: string;
  updated_at: string;
  highlight?: string;
  tag_names?: string;
  tag_ids?: string;
  pinned?: number;
  meta?: string;
  /** 时间线专用：文件已在磁盘上删除或改名 */
  missing?: boolean;
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
export const rescan = () => http.post('/rescan').then(r => r.data.data as { folders: number; files: number; textIndexed: number; skipped: number; added: number; removed: number });
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
/** 保存文本文件内容（.txt/.md/代码等） */
export const saveFile = (id: string, content: string) =>
  http.put(`/file/${id}`, { content }).then(r => r.data.data);
/** 读取文本文件内容（供预览编辑） */
export const readFileText = async (id: string) => {
  const r = await http.get(`/file/${id}`, { responseType: 'text' });
  return String(r.data);
};
/** 移动资源到指定文件夹（targetParentId 为空 = 根目录） */
export const moveResource = (id: string, targetParentId: string | null) =>
  http.post(`/resources/${id}/move`, { targetParentId }).then(r => r.data.data);
/** 批量标记/取消"待整理" */
export const setPending = (ids: string[], pending: boolean) =>
  http.post('/resources/pending', { ids, pending }).then(r => r.data.data);
/** 置顶/取消置顶（浏览页列表/卡片图标单击切换） */
export const setPin = (id: string, pinned: boolean) =>
  http.post(`/resources/${id}/pin`, { pinned }).then(r => r.data.data);

// ---------- 自建资源（笔记 / 书签 / 待办） ----------
export interface ResourceDetail {
  id: string;
  type: 'bookmark' | 'note' | 'file' | 'todo' | 'report' | 'folder';
  title: string;
  content: string;
  source_url: string;
  path: string;
  parent_id: string | null;
  done: number;
  meta: string;
  created_at: string;
  updated_at: string;
}
export interface TrashInfo { count: number; clear_at: string | null; days: number }
export const createResource = (type: 'note' | 'bookmark' | 'todo', title: string, content = '', source_url = '', meta?: string) =>
  http.post('/resources', { type, title, content, source_url, meta }).then(r => r.data.data as { id: string; type: string; title: string });
export const getResource = (id: string) =>
  http.get(`/resources/${id}`).then(r => r.data.data as ResourceDetail);
export const updateResource = (id: string, patch: { title?: string; content?: string; source_url?: string; done?: boolean; meta?: string | Record<string, unknown> }) =>
  http.put(`/resources/${id}`, patch).then(r => r.data.data);
export const deleteResource = (id: string) =>
  http.delete(`/resources/${id}`).then(r => r.data.data);
export const getTrashInfo = () =>
  http.get('/resources/trash/info').then(r => r.data.data as TrashInfo);

/** 今日新增计数（工作台"今日新增"卡片） */
export interface TodayCount {
  note: number; bookmark: number; file: number; todo: number; mindmap: number; total: number; date: string;
}
export const getToday = () => http.get('/today').then(r => r.data.data as TodayCount);

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

/** 文件夹层级树（含每级文件数与总字节），供矩形树图/旭日图/打包图使用 */
export interface HierarchyNode {
  id: string;
  name: string;
  value: number;
  size: number;
  children: HierarchyNode[];
}
export const getGraphHierarchy = () =>
  http.get('/graph/hierarchy').then(r => r.data.data as HierarchyNode[]);

/** 时间线：按创建时间倒序的资源流（type/tag 可筛选） */
export const getTimeline = (type = '', tag = '') =>
  http.get('/timeline', { params: { type, tag } }).then(r => r.data.data as Resource[]);

// ---------- 思维导图 ----------
export interface MindmapMeta { id: string; title: string; layout: string; theme: string; pinned: number; tags: string; deleted_at: string | null; updated_at: string; node_count: number }
export interface MindmapNode { id: string; parent_id: string | null; title: string; desc?: string; kind: string; x: number; y: number; color: string | null; shape: string; sort: number; expand?: number }
export interface MindmapLink { id: string; source_id: string; target_id: string; label: string }
export interface MindmapMember { group_id: string; node_id: string }
export interface RecycleInfo { count: number; clear_at: string | null; days: number }
export const getMindmaps = () => http.get('/mindmaps').then(r => r.data.data as MindmapMeta[]);
export const getRecycleMindmaps = () => http.get('/mindmaps/recycle').then(r => r.data.data as MindmapMeta[]);
export const getRecycleInfo = () => http.get('/mindmaps/recycle/info').then(r => r.data.data as RecycleInfo);
export const createMindmap = (title: string) => http.post('/mindmaps', { title }).then(r => r.data.data as { id: string });
export const deleteMindmap = (id: string) => http.delete(`/mindmaps/${id}`).then(r => r.data.data);
export const deleteMindmapPermanent = (id: string) => http.delete(`/mindmaps/${id}/permanent`).then(r => r.data.data);
export const restoreMindmap = (id: string) => http.post(`/mindmaps/${id}/restore`).then(r => r.data.data);
export const getMindmap = (id: string) => http.get(`/mindmaps/${id}`).then(r => r.data.data as MindmapMeta & { nodes: MindmapNode[]; links: MindmapLink[]; members: MindmapMember[] });
export const updateMindmap = (id: string, patch: { title?: string; layout?: string; theme?: string; pinned?: number; tags?: string }) =>
  http.put(`/mindmaps/${id}`, patch).then(r => r.data.data);
export const saveMindmapNodes = (id: string, nodes: MindmapNode[]) =>
  http.put(`/mindmaps/${id}/nodes`, { nodes }).then(r => r.data.data);
export const saveMindmapLinks = (id: string, links: MindmapLink[]) =>
  http.put(`/mindmaps/${id}/links`, { links }).then(r => r.data.data);
export const saveMindmapMembers = (id: string, members: MindmapMember[]) =>
  http.put(`/mindmaps/${id}/members`, { members }).then(r => r.data.data);

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
