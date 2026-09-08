<script setup lang="ts">
import { onMounted, ref, nextTick, watch, onBeforeUnmount } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import {
  getTree, getResourcesPage, getTags, createTag, updateTag, deleteTag, setResourceTags,
  search as apiSearch, fileUrl, rescan, moveResource, setPending, setPin,
  type Resource, type TagItem, type TreeNode,
} from './api';

/** 独立编辑器事件：文本/图片预览 → 整页切换（App.vue 全屏渲染 FileEditorView） */
const emit = defineEmits<{ (e: 'open-editor', p: { id: string; title: string; ext: string; path: string; isImage: boolean }): void }>();

// ---------- 左侧：文件结构树 ----------
const treeData = ref<TreeNode[]>([]);
const treeRef = ref();
const sideWidth = ref(200); // 默认按最窄宽度，用户可拖宽
const allFolderIds = ref<string[]>([]);
const rootId = ref<string | null>(null);
const expandedKeys = ref<string[]>([]);
const treeKey = ref(0); // 展开/折叠按钮强制重建树（el-tree 的 expanded-keys 外部赋值不驱动展开）
const currentFolderId = ref<string | null>(null);
const treeLoading = ref(true);

/** 仅 .py 文件用 ri:code-block 图标 */
function isCodeFile(d: TreeNode) {
  return d.type === 'file' && /\.py$/i.test(d.title);
}

/** 文件类型图标（非 py 代码类） */
function fileIcon(name: string) {
  const ext = (name.toLowerCase().match(/\.([a-z0-9]+)$/)?.[1]) || '';
  if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'webp', 'ico'].includes(ext)) return '🖼️';
  if (ext === 'pdf') return '📕';
  if (['xlsx', 'xls', 'csv'].includes(ext)) return '📗';
  if (['docx', 'doc'].includes(ext)) return '📘';
  if (['pptx', 'ppt'].includes(ext)) return '📙';
  if (['zip', 'rar', '7z', 'gz'].includes(ext)) return '📦';
  if (['txt', 'md', 'bas', 'cls', 'frm', 'vba', 'json', 'xml', 'html', 'htm'].includes(ext)) return '📄';
  return '📎';
}
function nodeIcon(d: TreeNode) { return d.type === 'folder' ? '📁' : fileIcon(d.title); }

function collectFolders(nodes: TreeNode[], acc: string[] = []) {
  for (const n of nodes) {
    if (n.type === 'folder') {
      acc.push(n.id);
      collectFolders(n.children, acc);
    }
  }
  return acc;
}

async function loadTree() {
  treeLoading.value = true;
  try {
    const raw = await getTree();
    const root = raw.find(n => !n.parent_id) || raw[0];
    rootId.value = root?.id ?? null;
    // Code 为主目录（根容器），直接展示其子项为顶级，根节点本身不显示
    treeData.value = root?.children ?? raw;
    allFolderIds.value = collectFolders(treeData.value);
    // 默认全部折叠（只显示主目录下的顶级项）
    expandedKeys.value = [];
    // 默认加载根目录内容
    currentFolderId.value = rootId.value;
    await loadResources();
  } finally {
    treeLoading.value = false;
  }
}

function expandAll() {
  expandedKeys.value = [...allFolderIds.value];
  treeKey.value++;
}
function collapseAll() {
  expandedKeys.value = [];
  treeKey.value++;
}
/** 用户手动展开/折叠节点时同步状态（供后续重建树时保持） */
function onNodeExpand(d: TreeNode) {
  if (!expandedKeys.value.includes(d.id)) expandedKeys.value.push(d.id);
}
function onNodeCollapse(d: TreeNode) {
  expandedKeys.value = expandedKeys.value.filter(k => k !== d.id);
}

/** 拖拽调宽 */
function startDrag(e: MouseEvent) {
  e.preventDefault();
  const startX = e.clientX;
  const startW = sideWidth.value;
  const onMove = (ev: MouseEvent) => {
    sideWidth.value = Math.min(460, Math.max(200, startW + ev.clientX - startX));
  };
  const onUp = () => {
    document.removeEventListener('mousemove', onMove);
    document.removeEventListener('mouseup', onUp);
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
  };
  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
  document.body.style.cursor = 'col-resize';
  document.body.style.userSelect = 'none';
}

async function onTreeClick(d: TreeNode) {
  if (d.type === 'folder') {
    currentFolderId.value = d.id;
    searchMode.value = false;
    filters.value.q = '';
    page.value = 1;
    await loadResources();
  } else {
    // 文件：定位显示（搜索该文件名）
    currentFolderId.value = null;
    searchMode.value = false;
    filters.value.q = d.title;
    page.value = 1;
    await loadResources();
  }
}

// ---------- 右侧：表格 / 卡片 ----------
const filters = ref<{ type: string; q: string; tag: string }>({ type: '', q: '', tag: '' });
const orderBy = ref('updated_at');
const orderDir = ref<'asc' | 'desc'>('desc');
const page = ref(1);
const pageSize = ref(50);
const list = ref<Resource[]>([]);
const total = ref(0);
const tags = ref<TagItem[]>([]);
const loading = ref(false);
const selection = ref<Resource[]>([]);
const viewMode = ref<'table' | 'grid'>('table');
const searchMode = ref(false);
const searchKeyword = ref('');
/** 搜索范围：name=按文件名（当前目录内 title/path 匹配）；content=按内容（FTS 全库） */
const searchScope = ref<'name' | 'content'>('name');
/** 待整理筛选（pending=1）；工具栏「待整理」按钮切换 */
const pendingOnly = ref(false);
/** 卡片视图选中 id 集合（表格用 el-table 原生勾选；卡片自维护，框选两种视图共用） */
const gridSelected = ref<Set<string>>(new Set());
const tableRef = ref();

// ---------- 框选（表格/卡片通用）：空白或任意处按下左键拖拽出选区，松开后与行/卡相交即选中 ----------
const boxSel = ref({ active: false, x1: 0, y1: 0, x2: 0, y2: 0 });
const boxOrigin = ref({ x: 0, y: 0, ctrl: false });
const boxDragging = ref(false);

function onBoxMouseDown(e: MouseEvent) {
  // 不拦截：按钮 / 输入框 / 标签 / 复选框 / 树 / 分页等控件上的按下
  const t = e.target as HTMLElement;
  if (t.closest('button, input, textarea, .el-checkbox, .el-select, .el-pagination, .el-radio, .add-tag-btn, .el-dropdown, .el-tree, .el-dialog, .cell-tag')) return;
  if (e.button !== 0) return;
  boxDragging.value = false;
  boxOrigin.value = { x: e.clientX, y: e.clientY, ctrl: e.ctrlKey || e.metaKey };
  boxSel.value = { active: true, x1: e.clientX, y1: e.clientY, x2: e.clientX, y2: e.clientY };
  document.body.style.userSelect = 'none';
}
function onBoxMouseMove(e: MouseEvent) {
  if (!boxSel.value.active) return;
  boxSel.value.x2 = e.clientX;
  boxSel.value.y2 = e.clientY;
  const dx = Math.abs(e.clientX - boxOrigin.value.x);
  const dy = Math.abs(e.clientY - boxOrigin.value.y);
  if (!boxDragging.value && Math.max(dx, dy) > 6) boxDragging.value = true;
}
function onBoxMouseUp() {
  if (!boxSel.value.active) return;
  boxSel.value.active = false;
  document.body.style.userSelect = '';
  if (!boxDragging.value) { boxSel.value = { active: false, x1: 0, y1: 0, x2: 0, y2: 0 }; return; }
  boxDragging.value = false;
  // 计算与各行/卡的矩形相交 → 选中；按下时若未按 Ctrl，先清空原选择
  if (!boxOrigin.value.ctrl) {
    if (viewMode.value === 'table') tableRef.value?.clearSelection();
    gridSelected.value.clear();
    selection.value = [];
  }
  const rect = {
    minX: Math.min(boxSel.value.x1, boxSel.value.x2),
    maxX: Math.max(boxSel.value.x1, boxSel.value.x2),
    minY: Math.min(boxSel.value.y1, boxSel.value.y2),
    maxY: Math.max(boxSel.value.y1, boxSel.value.y2),
  };
  const isHit = (el: Element) => {
    const r = el.getBoundingClientRect();
    return !(r.right < rect.minX || r.left > rect.maxX || r.bottom < rect.minY || r.top > rect.maxY);
  };
  if (viewMode.value === 'table') {
    // .browse-row 渲染顺序 = 当前页 list 顺序（分页后 el-table 只渲染当前页行）
    const rows = Array.from(document.querySelectorAll('.browse-row'));
    rows.forEach((rowEl, idx) => {
      const row = list.value[idx];
      if (row && isHit(rowEl)) tableRef.value?.toggleRowSelection(row, true);
    });
  } else {
    const cards = Array.from(document.querySelectorAll('.card[data-id]'));
    cards.forEach(cardEl => {
      const id = cardEl.getAttribute('data-id')!;
      if (isHit(cardEl)) {
        gridSelected.value.add(id);
        const r = list.value.find(x => x.id === id);
        if (r && !selection.value.some(s => s.id === id)) selection.value.push(r);
      }
    });
  }
  boxSel.value = { active: false, x1: 0, y1: 0, x2: 0, y2: 0 };
  // 抑制随后触发的行单击（防止框选后误打开文件）
  suppressNextOpen.value = true;
  setTimeout(() => { suppressNextOpen.value = false; }, 260);
}

/** 卡片视图勾选切换（点击卡片左上角复选框） */
function toggleGridSelect(r: Resource) {
  if (gridSelected.value.has(r.id)) {
    gridSelected.value.delete(r.id);
    selection.value = selection.value.filter(s => s.id !== r.id);
  } else {
    gridSelected.value.add(r.id);
    selection.value.push(r);
  }
}

/** 待整理入口：切换筛选 */
function onPendingToggle() {
  pendingOnly.value = !pendingOnly.value;
  page.value = 1;
  loadResources();
}

onMounted(() => {
  document.addEventListener('mousemove', onBoxMouseMove);
  document.addEventListener('mouseup', onBoxMouseUp);
});
onBeforeUnmount(() => {
  document.removeEventListener('mousemove', onBoxMouseMove);
  document.removeEventListener('mouseup', onBoxMouseUp);
});

const typeOptions = [
  { value: '', label: '全部类型' },
  { value: 'file', label: '文件' },
  { value: 'folder', label: '文件夹' },
  { value: 'note', label: '笔记' },
  { value: 'bookmark', label: '书签' },
  { value: 'todo', label: '待办' },
  { value: 'report', label: '报表' },
];
const orderOptions = [
  { value: 'updated_at', label: '更新时间' },
  { value: 'created_at', label: '创建时间' },
  { value: 'title', label: '标题' },
  { value: 'size', label: '大小' },
  { value: 'type', label: '类型' },
];
const typeLabels: Record<string, string> = { file: '文件', folder: '文件夹', note: '笔记', bookmark: '书签', todo: '待办', report: '报表' };
const typeIcons: Record<string, string> = { folder: '📁', file: '📄', note: '📝', bookmark: '🔖', todo: '✅', report: '📊' };
const IMAGE_EXT = /\.(png|jpe?g|gif|bmp|svg|webp|ico)$/i;

const tagColor = (id: string) => tags.value.find(t => t.id === id)?.color || '#8BC8EA';

async function loadResources() {
  loading.value = true;
  try {
    const params: Record<string, string> = {
      page: String(page.value),
      pageSize: String(pageSize.value),
      type: filters.value.type,
      q: filters.value.q.trim(),
      tag: filters.value.tag,
      orderBy: orderBy.value,
      orderDir: orderDir.value,
      status: 'active',
    };
    // 待整理筛选
    if (pendingOnly.value) params.pending = '1';
    if (currentFolderId.value) params.parentId = currentFolderId.value;
    const res = await getResourcesPage(params);
    list.value = res.list;
    total.value = res.total;
  } finally {
    loading.value = false;
  }
}

/** 合并搜索：按文件名（当前目录内 title/path 筛选）或按内容（FTS 全库） */
async function onSearch() {
  const q = searchKeyword.value.trim();
  if (!q) { exitSearch(); return; }
  if (searchScope.value === 'name') {
    // 按文件名：复用资源列表 q（当前目录内），不做跨库跳转
    searchMode.value = false;
    filters.value.q = q;
    page.value = 1;
    await loadResources();
  } else {
    // 按内容：FTS 全库检索
    try {
      loading.value = true;
      const rows = await apiSearch(q);
      list.value = rows;
      total.value = rows.length;
      searchMode.value = true;
    } catch (e) {
      ElMessage.error('搜索失败：' + ((e as Error).message || '服务异常'));
    } finally {
      loading.value = false;
    }
  }
}
function exitSearch() {
  searchMode.value = false;
  searchKeyword.value = '';
  filters.value.q = '';
  loadResources();
}

/** 返回上一级（当前目录非根目录时可用） */
function currentFolderNode(): TreeNode | null {
  const find = (nodes: TreeNode[], id: string): TreeNode | null => {
    for (const n of nodes) {
      if (n.id === id) return n;
      const r = find(n.children, id);
      if (r) return r;
    }
    return null;
  };
  return find(treeData.value, currentFolderId.value || '');
}
async function goParent() {
  if (!currentFolderId.value || currentFolderId.value === rootId.value) return;
  const cur = currentFolderNode();
  const pid = cur?.parent_id || rootId.value;
  currentFolderId.value = pid;
  searchMode.value = false;
  filters.value.q = '';
  searchKeyword.value = '';
  page.value = 1;
  await loadResources();
}

/** 置顶/取消置顶（列表图标前 + 卡片右上角图标单击切换；置顶资源排序优先） */
async function togglePin(r: Resource) {
  const pinned = !r.pinned;
  try {
    await setPin(r.id, pinned);
    r.pinned = pinned ? 1 : 0;
    await loadResources(); // 排序变化，刷新保持顺序一致
  } catch (e) {
    ElMessage.error('置顶失败：' + ((e as Error).message || '服务异常'));
  }
}

async function refreshTags() {
  try { tags.value = await getTags(); } catch { tags.value = []; }
}

function fmtSize(n: number) {
  if (!n) return '-';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB';
  return (n / 1024 / 1024).toFixed(2) + ' MB';
}

function onFilterChange() { page.value = 1; loadResources(); }
function onSortChange() { page.value = 1; loadResources(); }
function onPageChange() { loadResources(); }

function rowTagNames(r: Resource): string[] {
  return (r.tag_names || '').split('|').filter(Boolean);
}
function rowTagIds(r: Resource): string[] {
  return (r.tag_ids || '').split('|').filter(Boolean);
}

// ---------- 刷新（重扫磁盘增量入库） ----------
const refreshing = ref(false);
async function onRefresh() {
  if (refreshing.value) return;
  refreshing.value = true;
  try {
    const r = await rescan();
    ElMessage.success(`扫描完成：新增 ${r.added}，移除 ${r.removed}，文件 ${r.files}`);
    await refreshTags();
    await loadTree();
  } catch (e: any) {
    ElMessage.error('扫描失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    refreshing.value = false;
  }
}

// ---------- 单击打开：文件夹进目录，文本/图片整页编辑器，其他提示 ----------
const TEXT_PREVIEW_EXT = /\.(txt|md|bas|cls|frm|vba|json|xml|html|htm|csv|js|ts|py|sql|ini|cfg|log|bat|ps1|vbs|sh|yaml|yml)$/i;

function isTextPreview(r: Resource) {
  return r.type === 'file' && TEXT_PREVIEW_EXT.test(r.title);
}
async function onRowClick(row: Resource) {
  // 框选拖拽后抬起时禁止触发打开（由 boxSelect 内部在拖拽结束后抑制一次 click）
  if (suppressNextOpen.value) { suppressNextOpen.value = false; return; }
  if (row.type === 'folder') {
    // 文件夹：进入目录
    currentFolderId.value = row.id;
    searchMode.value = false;
    filters.value.q = '';
    page.value = 1;
    await loadResources();
    return;
  }
  if (row.type !== 'file') { ElMessage.info('该类型暂不支持预览'); return; }
  if (isImage(row) || isTextPreview(row)) {
    const ext = (row.title.toLowerCase().match(/\.([a-z0-9]+)$/)?.[1]) || '';
    emit('open-editor', { id: row.id, title: row.title, ext, path: row.path || '', isImage: isImage(row) });
    return;
  }
  ElMessage.info('该文件类型暂不支持预览');
}

/** 框选拖拽结束后抑制随后的行单击（避免框选完误打开文件） */
const suppressNextOpen = ref(false);

// ---------- 批量操作：移动位置 / 加入待整理 ----------
const batchMenu = ref({ visible: false });
const moveDialog = ref({
  visible: false, ids: [] as string[], names: [] as string[], targetId: '', target: [] as TreeNode[], loading: false,
});
function openMoveDialog() {
  if (selection.value.length === 0) { ElMessage.warning('请先勾选要移动的资源'); return; }
  moveDialog.value = {
    visible: true,
    ids: selection.value.map(r => r.id),
    names: selection.value.map(r => r.title),
    targetId: '', target: treeData.value, loading: false,
  };
}
async function doMove() {
  const d = moveDialog.value;
  if (!d.targetId) { ElMessage.warning('请选择目标文件夹（不选 = 移动到根目录）'); return; }
  d.loading = true;
  try {
    for (const id of d.ids) await moveResource(id, d.targetId);
    ElMessage.success('移动完成');
    d.visible = false;
    await loadTree();
    await loadResources();
  } catch (e: any) {
    ElMessage.error('移动失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.loading = false;
  }
}
async function markPending(pending: boolean) {
  if (selection.value.length === 0) { ElMessage.warning('请先勾选资源'); return; }
  try {
    const r: any = await setPending(selection.value.map(r => r.id), pending);
    const d = r?.data?.data;
    if (pending) {
      const added = d?.count ?? selection.value.length;
      const skipped = d?.skipped ?? 0;
      ElMessage.success(skipped > 0 ? `已加入待整理 ${added} 项（已在待整理中的 ${skipped} 项跳过）` : `已将 ${added} 项加入待整理（文件夹含全部子项）`);
    } else {
      ElMessage.success('已取消待整理标记');
    }
    loadResources();
  } catch (e: any) {
    ElMessage.error('操作失败：' + (e?.message || '服务异常'));
  }
}
function onBatchCmd(cmd: string) {
  if (cmd === 'tag') openBatchDialog();
  else if (cmd === 'move') openMoveDialog();
  else if (cmd === 'pending') markPending(true);
  else if (cmd === 'unpending') markPending(false);
}

// ---------- 打标对话框（行内 / 批量共用，可直接新建标签；文件夹可选递归） ----------
const tagDialog = ref({
  visible: false, mode: 'single' as 'single' | 'batch',
  resourceId: '', resourceTitle: '', resourceType: '',
  checked: [] as string[], newName: '', recursive: false,
});

function openTagDialog(row: Resource) {
  tagDialog.value = {
    visible: true, mode: 'single', resourceId: row.id, resourceTitle: row.title,
    resourceType: row.type, checked: rowTagIds(row), newName: '', recursive: false,
  };
}
function openBatchDialog() {
  if (selection.value.length === 0) {
    ElMessage.warning('请先在表格中勾选要打标的资源');
    return;
  }
  tagDialog.value = {
    visible: true, mode: 'batch', resourceId: '', resourceTitle: '',
    resourceType: '', checked: [], newName: '', recursive: false,
  };
}

/** 打标弹窗是否显示"包含子项"选项（勾选的资源里有文件夹时才需要） */
function dialogHasFolder() {
  if (tagDialog.value.mode === 'single') return tagDialog.value.resourceType === 'folder';
  return selection.value.some(r => r.type === 'folder');
}

/** 在打标弹窗内直接新建标签 */
async function createTagInDialog() {
  const name = tagDialog.value.newName.trim();
  if (!name) { ElMessage.warning('请输入新标签名'); return; }
  try {
    const t = await createTag(name);
    await refreshTags();
    if (!tagDialog.value.checked.includes(t.id)) tagDialog.value.checked.push(t.id);
    tagDialog.value.newName = '';
    ElMessage.success(`标签「${t.name}」已创建并勾选`);
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.msg || '创建失败');
  }
}

/** 点击标签切换勾选 */
function toggleTagInDialog(id: string) {
  const i = tagDialog.value.checked.indexOf(id);
  if (i >= 0) tagDialog.value.checked.splice(i, 1);
  else tagDialog.value.checked.push(id);
}

/** 在打标弹窗内直接删除标签（含确认，同时从所有资源上移除） */
async function removeTagFromDialog(t: TagItem) {
  try {
    await ElMessageBox.confirm(`删除标签「${t.name}」？将同时从所有资源上移除。`, '确认删除', { type: 'warning' });
  } catch {
    return;
  }
  await deleteTag(t.id);
  const i = tagDialog.value.checked.indexOf(t.id);
  if (i >= 0) tagDialog.value.checked.splice(i, 1);
  await refreshTags();
  loadResources();
  ElMessage.success('标签已删除');
}

async function saveTagDialog() {
  const d = tagDialog.value;
  if (d.mode === 'single') {
    await setResourceTags(d.resourceId, d.checked, d.recursive);
  } else {
    const add = d.checked;
    if (add.length === 0) { ElMessage.warning('请选择要添加的标签'); return; }
    for (const row of selection.value) {
      const merged = [...new Set([...rowTagIds(row), ...add])];
      // 文件夹 + 勾选递归 → 递归应用到整个子树（子资源合并追加）；其余全量替换
      await setResourceTags(row.id, merged, d.recursive && row.type === 'folder');
    }
  }
  d.visible = false;
  ElMessage.success(d.recursive && dialogHasFolder() ? '标签已更新（含所有子项）' : '标签已更新');
  loadResources();
  refreshTags();
}

function isImage(r: Resource) {
  return r.type === 'file' && IMAGE_EXT.test(r.title);
}

watch([() => filters.value.type, () => filters.value.tag, orderBy, orderDir], onSortChange);

onMounted(async () => {
  await refreshTags();
  await loadTree();
});

/** 供工作台跳转调用 */
async function openFolder(id: string) {
  searchMode.value = false;
  searchKeyword.value = '';
  currentFolderId.value = id;
  filters.value.q = '';
  page.value = 1;
  await loadResources();
  await nextTick();
  // 只展开目标目录（并收起其余），让结构一目了然
  expandedKeys.value = [id];
  treeKey.value++;
}

/** 供工作台"常用标签"跳转：按标签筛选浏览 */
async function openTag(tagId: string) {
  searchMode.value = false;
  searchKeyword.value = '';
  currentFolderId.value = null; // 全局（不限目录）
  filters.value.tag = tagId;
  filters.value.q = '';
  filters.value.type = '';
  page.value = 1;
  await loadResources();
}
/** 供编辑器关闭后刷新列表（App.closeEditor 调用） */
async function reload() {
  await loadResources();
  await loadTree();
}
defineExpose({ openFolder, openTag, reload });
</script>

<template>
  <div class="browser">
    <!-- 左：文件结构树 -->
    <aside class="side" :style="{ width: sideWidth + 'px' }" v-loading="treeLoading">
      <div class="side-title">
        <span>🗂️ 文件结构</span>
        <span class="tree-actions">
          <el-button text size="small" @click="expandAll" title="全部展开">
            <svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true"><path d="M10 2C10.5523 2 11 2.44772 11 3V7C11 7.55228 10.5523 8 10 8H8V10H13V9C13 8.44772 13.4477 8 14 8H20C20.5523 8 21 8.44772 21 9V13C21 13.5523 20.5523 14 20 14H14C13.4477 14 13 13.5523 13 13V12H8V18H13V17C13 16.4477 13.4477 16 14 16H20C20.5523 16 21 16.4477 21 17V21C21 21.5523 20.5523 22 20 22H14C13.4477 22 13 21.5523 13 21V20H7C6.44772 20 6 19.5523 6 19V8H4C3.44772 8 3 7.55228 3 7V3C3 2.44772 3.44772 2 4 2H10ZM19 18H15V20H19V18ZM19 10H15V12H19V10ZM9 4H5V6H9V4Z"/></svg>
          </el-button>
          <el-button text size="small" @click="collapseAll" title="全部折叠">
            <svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true"><path d="M8 4H21V6H8V4ZM4.5 6.5C3.67157 6.5 3 5.82843 3 5C3 4.17157 3.67157 3.5 4.5 3.5C5.32843 3.5 6 4.17157 6 5C6 5.82843 5.32843 6.5 4.5 6.5ZM4.5 13.5C3.67157 13.5 3 12.8284 3 12C3 11.1716 3.67157 10.5 4.5 10.5C5.32843 10.5 6 11.1716 6 12C6 12.8284 5.32843 13.5 4.5 13.5ZM4.5 20.4C3.67157 20.4 3 19.7284 3 18.9C3 18.0716 3.67157 17.4 4.5 17.4C5.32843 17.4 6 18.0716 6 18.9C6 19.7284 5.32843 20.4 4.5 20.4ZM8 11H21V13H8V11ZM8 18H21V20H8V18Z"/></svg>
          </el-button>
        </span>
      </div>
      <div class="tree-wrap">
        <el-tree
          ref="treeRef"
          :key="treeKey"
          class="file-tree"
          :data="treeData"
          node-key="id"
          :props="{ label: 'title', children: 'children' }"
          :default-expanded-keys="expandedKeys"
          :expand-on-click-node="false"
          @node-click="onTreeClick"
          @node-expand="onNodeExpand"
          @node-collapse="onNodeCollapse"
        >
          <template #default="{ data }">
            <span class="tn">
              <span v-if="isCodeFile(data)" class="tn-icon">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" aria-hidden="true"><path d="M3.41436 5.99995L5.70726 3.70706L4.29304 2.29285L0.585938 5.99995L4.29304 9.70706L5.70726 8.29285L3.41436 5.99995ZM9.58594 5.99995L7.29304 3.70706L8.70726 2.29285L12.4144 5.99995L8.70726 9.70706L7.29304 8.29285L9.58594 5.99995ZM14.0002 2.99995H21.0002C21.5524 2.99995 22.0002 3.44767 22.0002 3.99995V20C22.0002 20.5522 21.5524 21 21.0002 21H3.00015C2.44787 21 2.00015 20.5522 2.00015 20V12H4.00015V19H20.0002V4.99995H14.0002V2.99995Z"/></svg>
              </span>
              <span v-else class="tn-icon">{{ nodeIcon(data) }}</span>
              <span class="tn-text" :title="data.title">{{ data.title }}</span>
            </span>
          </template>
        </el-tree>
      </div>
      <div class="resizer" @mousedown="startDrag"></div>
    </aside>

    <!-- 右：内容区 -->
    <main class="main">
      <div class="toolbar">
        <el-button v-if="currentFolderId && currentFolderId !== rootId" size="default" @click="goParent" title="返回上一级目录">← 返回</el-button>
        <el-input
          v-model="searchKeyword"
          placeholder="按文件名或内容搜索"
          clearable
          style="width: 260px;"
          @keyup.enter="onSearch"
          @clear="exitSearch"
        >
          <template #prepend>
            <el-select v-model="searchScope" style="width: 86px;">
              <el-option value="name" label="文件名" />
              <el-option value="content" label="内容" />
            </el-select>
          </template>
          <template #append><el-button @click="onSearch">搜索</el-button></template>
        </el-input>
        <el-button v-if="searchMode || filters.q" @click="exitSearch">清除</el-button>
        <el-select v-model="filters.type" style="width: 120px;" @change="onFilterChange">
          <el-option v-for="t in typeOptions" :key="t.value" :label="t.label" :value="t.value" />
        </el-select>
        <el-select v-model="filters.tag" placeholder="按标签筛选" clearable style="width: 150px;" @change="onFilterChange">
          <el-option v-for="t in tags" :key="t.id" :label="`${t.name}（${t.count}）`" :value="t.id" />
        </el-select>
        <el-select v-model="orderBy" style="width: 120px;" @change="onSortChange">
          <el-option v-for="o in orderOptions" :key="o.value" :label="`按${o.label}`" :value="o.value" />
        </el-select>
        <el-radio-group v-model="orderDir" size="default" @change="onSortChange">
          <el-radio-button value="desc">↓</el-radio-button>
          <el-radio-button value="asc">↑</el-radio-button>
        </el-radio-group>
        <div class="tb-sep"></div>
        <el-radio-group v-model="viewMode" size="default">
          <el-radio-button value="table">表格</el-radio-button>
          <el-radio-button value="grid">卡片</el-radio-button>
        </el-radio-group>
        <div class="tb-sep"></div>
        <el-dropdown @command="onBatchCmd">
          <el-button type="primary" plain :disabled="selection.length === 0">批量操作 ▾</el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="tag">批量打标</el-dropdown-item>
              <el-dropdown-item command="move">移动位置</el-dropdown-item>
              <!-- 待整理筛选下的资源均已标记待整理，无需再"加入"；移出后自动离开列表 -->
              <el-dropdown-item v-if="!pendingOnly" command="pending">加入待整理</el-dropdown-item>
              <el-dropdown-item command="unpending">移出待整理</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
        <el-button :type="pendingOnly ? 'warning' : 'default'" @click="onPendingToggle" :title="pendingOnly ? '退出待整理筛选' : '只显示已标记待整理的资源'">
          {{ pendingOnly ? '待整理 ✕' : '待整理' }}
        </el-button>
        <el-button :loading="refreshing" @click="onRefresh" title="重新扫描磁盘（新增文件/文件夹入库）">刷新</el-button>
        <span class="total">共 {{ total }} 项</span>
      </div>

      <!-- 表格视图（支持框选：在空白/行上按住左键拖出选区） -->
      <div v-if="viewMode === 'table'" class="table-wrap" v-loading="loading" @mousedown="onBoxMouseDown">
        <el-table ref="tableRef" :data="list" size="small" height="100%" stripe highlight-current-row
          @selection-change="(rows: Resource[]) => { selection = rows; gridSelected.value = new Set(rows.map(r => r.id)); }"
          @row-click="onRowClick" :row-class-name="() => 'browse-row'">
          <el-table-column type="selection" width="38" @click.stop />
          <el-table-column label="名称" min-width="200">
            <template #default="{ row }">
              <span class="name-cell">
                <span v-if="row.pinned" class="pin-ico on" title="置顶中" @click.stop="togglePin(row)">
                  <svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor" aria-hidden="true"><path d="M16 3l5 5-2.1 2.1-2.2-.5-3.8 3.8.5 2.2L11.3 18 6 12.7l-.6 3.9 1.9 1.9L6 21l-3-3 2.5-1.3 1.9 1.9 3.9-.6L9 11l2.2-.5 3.8-3.8-.5-2.2L16 3z"/></svg>
                </span>
                <span v-else class="pin-ico" title="置顶（单击置顶到最前）" @click.stop="togglePin(row)">
                  <svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor" aria-hidden="true"><path d="M16 3l5 5-2.1 2.1-2.2-.5-3.8 3.8.5 2.2L11.3 18 6 12.7l-.6 3.9 1.9 1.9L6 21l-3-3 2.5-1.3 1.9 1.9 3.9-.6L9 11l2.2-.5 3.8-3.8-.5-2.2L16 3z"/></svg>
                </span>
                <span class="name-ico" :title="typeLabels[row.type] || row.type">{{ row.type === 'file' ? fileIcon(row.title) : typeIcons[row.type] || '📄' }}</span>
                <span class="name-text" :title="row.title">{{ row.title }}</span>
              </span>
            </template>
          </el-table-column>
          <el-table-column prop="path" label="路径" min-width="220" show-overflow-tooltip>
            <template #default="{ row }"><span class="path">{{ row.path || '-' }}</span></template>
          </el-table-column>
          <el-table-column label="标签" min-width="140">
            <template #default="{ row }">
              <div class="tag-cell" v-if="rowTagNames(row).length > 0">
                <span v-for="(n, i) in rowTagNames(row)" :key="i" class="cell-tag" :title="n">{{ n }}</span>
              </div>
              <div class="tag-cell" v-else>
                <el-button size="small" text type="primary" class="add-tag-btn" @click.stop="openTagDialog(row)">加标签</el-button>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="大小" width="82" align="right">
            <template #default="{ row }">{{ row.type === 'file' ? fmtSize(row.size ?? 0) : '-' }}</template>
          </el-table-column>
          <el-table-column label="更新时间" width="150">
            <template #default="{ row }">{{ (row.updated_at || '').slice(0, 16).replace('T', ' ') }}</template>
          </el-table-column>
        </el-table>
      </div>

      <!-- 卡片视图（支持框选；卡片左上角复选框可单选） -->
      <div v-else class="grid" v-loading="loading" @mousedown="onBoxMouseDown">
        <div v-if="list.length === 0" class="empty" style="grid-column: 1 / -1;">无结果</div>
        <div v-for="r in list" :key="r.id" class="card" :data-id="r.id"
          :class="{ 'card-sel': gridSelected.has(r.id) }" @click="onRowClick(r)">
          <span class="card-check" :class="{ on: gridSelected.has(r.id) }" @click.stop="toggleGridSelect(r)">
            <svg v-if="gridSelected.has(r.id)" viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 8.5L6.5 12L13 4.5"/></svg>
          </span>
          <span class="card-pin" :class="{ on: r.pinned }" :title="r.pinned ? '置顶中（单击取消）' : '置顶（单击置顶到最前）'" @click.stop="togglePin(r)">
            <svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor" aria-hidden="true"><path d="M16 3l5 5-2.1 2.1-2.2-.5-3.8 3.8.5 2.2L11.3 18 6 12.7l-.6 3.9 1.9 1.9L6 21l-3-3 2.5-1.3 1.9 1.9 3.9-.6L9 11l2.2-.5 3.8-3.8-.5-2.2L16 3z"/></svg>
          </span>
          <div class="thumb" :class="{ 'thumb-img': isImage(r) }">
            <img v-if="isImage(r)" :src="fileUrl(r.id)" loading="lazy" :alt="r.title" />
            <span v-else class="thumb-icon">{{ r.type === 'file' ? fileIcon(r.title) : typeIcons[r.type] || '📄' }}</span>
          </div>
          <div class="card-title" :title="r.title">{{ r.title }}</div>
          <div class="card-meta">{{ r.type === 'file' ? r.path : typeLabels[r.type] }}</div>
          <div class="card-tags">
            <span v-for="(n, i) in rowTagNames(r)" :key="i" class="cell-tag" :title="n">{{ n }}</span>
            <el-button v-if="rowTagNames(r).length === 0" size="small" text type="primary" class="add-tag-btn" @click.stop="openTagDialog(r)">加标签</el-button>
          </div>
        </div>
      </div>

      <!-- 框选层（拖拽中显示半透明选区） -->
      <div v-if="boxSel.active && boxDragging" class="box-select"
        :style="{
          left: Math.min(boxSel.x1, boxSel.x2) + 'px',
          top: Math.min(boxSel.y1, boxSel.y2) + 'px',
          width: Math.abs(boxSel.x2 - boxSel.x1) + 'px',
          height: Math.abs(boxSel.y2 - boxSel.y1) + 'px',
        }"></div>

      <div class="footer">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="pageSize"
          :total="total"
          :page-sizes="[50, 100, 200]"
          layout="total, sizes, prev, pager, next, jumper"
          @current-change="onPageChange"
          @size-change="onPageChange"
        />
      </div>
    </main>

    <!-- 打标（行内/批量共用，可直接新建/删除标签） -->
    <el-dialog
      v-model="tagDialog.visible"
      :title="tagDialog.mode === 'single' ? `打标：${tagDialog.resourceTitle}` : `批量添加标签（${selection.length} 项）`"
      width="440"
    >
      <div class="dlg-new-tag">
        <el-input v-model="tagDialog.newName" placeholder="输入新标签名直接创建" style="flex: 1;" @keyup.enter="createTagInDialog" />
        <el-button type="primary" plain @click="createTagInDialog">新建标签</el-button>
      </div>
      <p class="dlg-hint">点击标签勾选/取消，点 × 删除：</p>
      <div class="dlg-tags">
        <el-tag
          v-for="t in tags" :key="t.id"
          :effect="tagDialog.checked.includes(t.id) ? 'dark' : 'plain'"
          class="dlg-tag"
          closable
          @click.stop="toggleTagInDialog(t.id)"
          @close="removeTagFromDialog(t)"
        >{{ t.name }}</el-tag>
        <p v-if="tags.length === 0" class="tm-empty">暂无标签，输入上方名称直接创建</p>
      </div>
      <el-checkbox
        v-if="dialogHasFolder()"
        v-model="tagDialog.recursive"
        class="dlg-recursive"
      >同时应用到所有子文件和子文件夹</el-checkbox>
      <template #footer>
        <el-button @click="tagDialog.visible = false">取消</el-button>
        <el-button type="primary" @click="saveTagDialog">保存</el-button>
      </template>
    </el-dialog>

    <!-- 移动位置：选择目标文件夹 -->
    <el-dialog v-model="moveDialog.visible" title="移动位置" width="440">
      <p class="dlg-hint">将 {{ moveDialog.names.length }} 项移动到：</p>
      <div class="move-tree">
        <el-tree
          :data="moveDialog.target"
          node-key="id"
          :props="{ label: 'title', children: 'children' }"
          highlight-current
          :default-expand-all="false"
          @node-click="(d: TreeNode) => moveDialog.targetId = d.type === 'folder' ? d.id : ''"
        >
          <template #default="{ data }">
            <span class="tn">
              <span class="tn-icon">{{ nodeIcon(data) }}</span>
              <span class="tn-text">{{ data.title }}</span>
            </span>
          </template>
        </el-tree>
      </div>
      <p class="dlg-hint" style="margin-top: 8px;">不选择任何文件夹 = 移动到根目录</p>
      <template #footer>
        <el-button @click="moveDialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="moveDialog.loading" @click="doMove">移动</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.browser { display: flex; height: 100%; min-height: 0; position: relative; }

.side { overflow: hidden; background: var(--el-bg-color, #fff); border-right: 1px solid var(--el-border-color, #e5e7eb); padding: 12px 0 12px 14px; box-sizing: border-box; position: relative; flex: none; display: flex; flex-direction: column; }
.side-title { display: flex; align-items: center; justify-content: space-between; font-size: 13px; color: var(--el-text-color-secondary, #6b7280); margin-bottom: 8px; padding-right: 10px; }
.tree-actions { display: flex; gap: 2px; }
.tree-actions .el-button { padding: 0 4px; margin: 0; }
.tree-wrap { flex: 1; min-height: 0; overflow: auto; padding-right: 8px; }
.file-tree { --el-tree-node-content-height: 26px; }
.tn { display: flex; align-items: center; gap: 5px; min-width: 0; }
.tn-icon { flex: none; font-size: 14px; display: inline-flex; align-items: center; }
.tn-text { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 13px; }
.resizer { position: absolute; top: 0; right: 0; width: 2px; height: 100%; cursor: col-resize; z-index: 5; }
.resizer:hover { background: var(--el-color-primary-light-7, #d9ecff); }

/* 细滚动条（树、卡片网格共用） */
.tree-wrap::-webkit-scrollbar, .grid::-webkit-scrollbar { width: 6px; height: 6px; }
.tree-wrap::-webkit-scrollbar-thumb, .grid::-webkit-scrollbar-thumb { background: rgba(0, 0, 0, 0.18); border-radius: 3px; }
.tree-wrap::-webkit-scrollbar-thumb:hover, .grid::-webkit-scrollbar-thumb:hover { background: rgba(0, 0, 0, 0.32); }
.tree-wrap::-webkit-scrollbar-track, .grid::-webkit-scrollbar-track { background: transparent; }
html.dark .tree-wrap::-webkit-scrollbar-thumb, html.dark .grid::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.22); }
html.dark .tree-wrap::-webkit-scrollbar-thumb:hover, html.dark .grid::-webkit-scrollbar-thumb:hover { background: rgba(255, 255, 255, 0.38); }

.main { flex: 1; display: flex; flex-direction: column; min-width: 0; }
.toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 14px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.tb-sep { width: 1px; height: 20px; background: var(--el-border-color-lighter, #ebeef5); margin: 0 2px; }
.toolbar .total { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-left: auto; }

.table-wrap { flex: 1; min-height: 0; background: var(--el-bg-color, #fff); margin: 12px 14px 0; border-radius: 10px; border: 1px solid var(--el-border-color, #e5e7eb); overflow: hidden; }
/* 表格行高压到正常（内容紧凑单行） */
.table-wrap :deep(.el-table td.el-table__cell) { padding: 2px 0; }
.table-wrap :deep(.el-table th.el-table__cell) { padding: 4px 0; }
.table-wrap :deep(.el-table .cell) { padding: 0 8px; line-height: 1.5; }
.table-wrap :deep(.el-table__empty-block) { min-height: 60px; }
/* 选中行高亮：统一使用全局主色（--kh-brand），与大纲高亮行/右键菜单高亮一致，深色下保证对比度 */
.table-wrap :deep(.el-table__body tr.current-row > td.el-table__cell) {
  background: var(--kh-brand, #409eff) !important;
}
.table-wrap :deep(.el-table__body tr.current-row > td.el-table__cell .cell) {
  color: #fff;
}
.table-wrap :deep(.el-table__body tr.current-row > td.el-table__cell .name-ico),
.table-wrap :deep(.el-table__body tr.current-row > td.el-table__cell .path) {
  color: #fff;
}
/* 结构树行高（变量 + 兜底双重保证） */
.file-tree :deep(.el-tree-node__content) { height: 21px; }
.file-tree { --el-tree-node-content-height: 21px; }
.path { color: var(--el-text-color-secondary, #9ca3af); font-size: 12px; }
.name-cell { display: flex; align-items: center; gap: 8px; overflow: hidden; }
.name-ico { flex: none; font-size: 16px; line-height: 1; }
.name-text { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tag-cell { display: flex; align-items: center; gap: 4px; flex-wrap: nowrap; overflow: hidden; }
.tag-cell .el-button { flex: none; }
/* 标签统一主色蓝底白字（--kh-brand 全局主色参数） */
.cell-tag {
  display: inline-block; flex: 0 1 auto; min-width: 0; max-width: 80px; padding: 1px 8px; border-radius: 4px;
  font-size: 12px; line-height: 18px; color: #fff; background: var(--kh-brand, #409eff);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.card-tags .cell-tag { max-width: 100%; }

.grid { flex: 1; overflow: auto; padding: 12px 14px; display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; align-content: start; }
.card { background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); border-radius: 10px; padding: 8px; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04); transition: box-shadow 0.15s; }
.card:hover { box-shadow: 0 3px 8px rgba(0, 0, 0, 0.1); }
.thumb { display: flex; align-items: center; justify-content: center; background: transparent; border-radius: 6px; overflow: hidden; margin-bottom: 6px; padding: 6px 0; }
.thumb-img { height: 84px; padding: 0; }
.thumb img { max-width: 100%; max-height: 100%; object-fit: contain; }
.thumb-icon { font-size: 30px; line-height: 1; }
.card-title { font-size: 13px; color: var(--el-text-color-primary, #1f2937); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.card-meta { font-size: 11px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.card-tags { display: flex; gap: 4px; margin-top: 4px; flex-wrap: wrap; min-height: 0; }
.card-tags:empty { display: none; }
.empty { color: var(--el-text-color-secondary, #9ca3af); text-align: center; padding: 40px 0; font-size: 13px; }

.footer { display: flex; justify-content: flex-end; padding: 8px 14px 12px; }
.dlg-new-tag { display: flex; gap: 8px; margin-bottom: 10px; }
.dlg-hint { margin: 0 0 8px; font-size: 13px; color: var(--el-text-color-secondary, #6b7280); }
.dlg-tags { display: flex; flex-wrap: wrap; gap: 6px; max-height: 260px; overflow: auto; padding-right: 4px; }
.dlg-tag { cursor: pointer; }
.dlg-recursive { margin-top: 12px; }
.tm-empty { color: var(--el-text-color-secondary, #9ca3af); font-size: 13px; text-align: center; padding: 16px 0; }

/* 行内"加标签"按钮：小号、不撑高行 */
.add-tag-btn { margin: 0; padding: 0 6px; font-size: 12px; }
.table-wrap :deep(.browse-row) { cursor: pointer; }
.tag-cell .el-button { flex: none; }

/* 预览对话框 */
.pv-img-wrap { text-align: center; padding: 8px 0; }
.pv-loading { text-align: center; color: var(--el-text-color-secondary, #9ca3af); padding: 30px 0; }
.pv-text { display: flex; flex-direction: column; }
.pv-md { display: flex; gap: 10px; }
.pv-pane { flex: 1 1 0; min-width: 0; display: flex; flex-direction: column; }
.pv-pane-title { font-size: 12px; color: var(--el-text-color-secondary, #6b7280); margin-bottom: 6px; }
.pv-editor :deep(textarea), .pv-editor-full :deep(textarea) {
  font-family: Consolas, "Courier New", monospace; font-size: 13px; line-height: 1.6;
  background: var(--el-bg-color, #fff); color: var(--el-text-color-primary, #1f2937);
}
.pv-md-render {
  flex: 1; min-height: 0; overflow: auto; border: 1px solid var(--el-border-color, #e5e7eb);
  border-radius: 6px; padding: 12px 16px; font-size: 14px; line-height: 1.8;
  color: var(--el-text-color-primary, #1f2937); background: var(--el-bg-color, #fff);
}
.pv-md-render h1 { font-size: 20px; margin: 10px 0 6px; }
.pv-md-render h2 { font-size: 17px; margin: 8px 0 5px; }
.pv-md-render h3 { font-size: 15px; margin: 6px 0 4px; }
.pv-md-render ul { margin: 4px 0; padding-left: 22px; }
.pv-md-render code { background: var(--el-fill-color, #f0f2f5); border-radius: 4px; padding: 1px 6px; font-family: Consolas, "Courier New", monospace; font-size: 13px; }
.pv-md-render pre { background: var(--el-fill-color, #f0f2f5); border-radius: 6px; padding: 10px 12px; overflow: auto; }
.pv-md-render pre code { background: transparent; padding: 0; }
.pv-md-render hr { border: none; border-top: 1px solid var(--el-border-color, #e5e7eb); margin: 10px 0; }
.pv-md-render a { color: var(--el-color-primary, #409eff); }
.pv-path { flex: 1; color: var(--el-text-color-secondary, #9ca3af); font-size: 12px; text-align: left; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.move-tree { max-height: 320px; overflow: auto; border: 1px solid var(--el-border-color, #e5e7eb); border-radius: 6px; padding: 6px; }
.move-tree .tn { display: flex; align-items: center; gap: 5px; min-width: 0; }
.move-tree .tn-text { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 13px; }

/* ---------- 框选层 ---------- */
.box-select {
  position: fixed; z-index: 3000; pointer-events: none;
  background: rgba(64, 158, 255, 0.14); border: 1px solid var(--kh-brand, #409eff);
}
/* 表格行框选悬停视觉（行本身高亮由 el-table highlight-current-row 承担） */
.browse-row { cursor: default; }

/* ---------- 卡片：勾选复选框（左上角） ---------- */
.card { position: relative; }
.card-check {
  position: absolute; top: 6px; left: 6px; z-index: 2;
  width: 18px; height: 18px; border-radius: 4px;
  border: 1px solid rgba(255, 255, 255, 0.75); background: rgba(0, 0, 0, 0.25);
  display: flex; align-items: center; justify-content: center; cursor: pointer;
  color: #fff; opacity: 0.55; transition: opacity 0.15s;
}
.card:hover .card-check { opacity: 1; }
.card-check.on { background: var(--kh-brand, #409eff); border-color: var(--kh-brand, #409eff); opacity: 1; }
.card-sel { outline: 2px solid var(--kh-brand, #409eff); outline-offset: -2px; }

/* ---------- 置顶图标：列表（图标前）+ 卡片（右上角）单色浅色 ---------- */
.pin-ico {
  flex: none; display: inline-flex; align-items: center; justify-content: center;
  width: 18px; height: 18px; border-radius: 4px; cursor: pointer;
  color: var(--el-text-color-placeholder, #b6c2d1); transition: color 0.15s, background 0.15s;
}
.pin-ico:hover { color: var(--kh-brand, #409eff); background: rgba(64, 158, 255, 0.1); }
.pin-ico.on { color: var(--kh-brand, #409eff); }
.card-pin {
  position: absolute; top: 6px; right: 6px; z-index: 2;
  width: 20px; height: 20px; border-radius: 5px;
  display: flex; align-items: center; justify-content: center; cursor: pointer;
  color: rgba(255, 255, 255, 0.85); background: rgba(0, 0, 0, 0.18);
  opacity: 0.5; transition: opacity 0.15s;
}
.card:hover .card-pin { opacity: 1; }
.card-pin:hover { color: #fff; background: rgba(0, 0, 0, 0.35); }
.card-pin.on { color: var(--kh-brand, #409eff); opacity: 1; background: rgba(255, 255, 255, 0.9); }
</style>
