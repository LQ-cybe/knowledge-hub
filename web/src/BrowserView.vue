<script setup lang="ts">
import { onMounted, ref, nextTick, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import {
  getTree, getResourcesPage, getTags, createTag, updateTag, deleteTag, setResourceTags,
  search as apiSearch, fileUrl,
  type Resource, type TagItem, type TreeNode,
} from './api';

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
    treeData.value = await getTree();
    const root = treeData.value.find(n => !n.parent_id) || treeData.value[0];
    rootId.value = root?.id ?? null;
    allFolderIds.value = collectFolders(treeData.value);
    // 默认展开根 + 一级目录
    const firstLevel = root?.children?.map(c => c.id) ?? [];
    expandedKeys.value = [root?.id, ...firstLevel].filter((x): x is string => !!x);
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
  expandedKeys.value = rootId.value ? [rootId.value] : [];
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
    if (currentFolderId.value) params.parentId = currentFolderId.value;
    const res = await getResourcesPage(params);
    list.value = res.list;
    total.value = res.total;
  } finally {
    loading.value = false;
  }
}

/** 全文搜索（跨全库，非当前目录） */
async function onSearch() {
  const q = searchKeyword.value.trim();
  if (!q) { searchMode.value = false; return; }
  try {
    loading.value = true;
    const rows = await apiSearch(q);
    list.value = rows;
    total.value = rows.length;
    searchMode.value = true;
  } finally {
    loading.value = false;
  }
}
function exitSearch() {
  searchMode.value = false;
  searchKeyword.value = '';
  loadResources();
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
defineExpose({ openFolder, openTag });
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
        <el-input
          v-model="filters.q"
          placeholder="当前目录内按标题/路径筛选"
          clearable
          style="width: 200px;"
          @keyup.enter="onFilterChange"
          @clear="onFilterChange"
        />
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
        <el-input
          v-model="searchKeyword"
          placeholder="全文搜索（FTS5）"
          clearable
          style="width: 200px;"
          @keyup.enter="onSearch"
          @clear="exitSearch"
        >
          <template #append><el-button @click="onSearch">搜索</el-button></template>
        </el-input>
        <el-button v-if="searchMode" @click="exitSearch">退出搜索</el-button>
        <el-radio-group v-model="viewMode" size="default">
          <el-radio-button value="table">表格</el-radio-button>
          <el-radio-button value="grid">卡片</el-radio-button>
        </el-radio-group>
        <div class="tb-sep"></div>
        <el-button type="primary" plain @click="openBatchDialog">批量打标</el-button>
        <span class="total">共 {{ total }} 项</span>
      </div>

      <!-- 表格视图 -->
      <div v-if="viewMode === 'table'" class="table-wrap" v-loading="loading">
        <el-table :data="list" size="small" height="100%" stripe @selection-change="(rows: Resource[]) => selection = rows">
          <el-table-column type="selection" width="38" />
          <el-table-column label="类型" width="74">
            <template #default="{ row }">
              <span :title="typeLabels[row.type] || row.type">{{ typeIcons[row.type] || '📄' }}</span>
            </template>
          </el-table-column>
          <el-table-column prop="title" label="标题" min-width="200" show-overflow-tooltip />
          <el-table-column prop="path" label="路径" min-width="220" show-overflow-tooltip>
            <template #default="{ row }"><span class="path">{{ row.path || '-' }}</span></template>
          </el-table-column>
          <el-table-column label="标签" min-width="150">
            <template #default="{ row }">
              <div class="tag-cell">
                <el-tag v-for="(n, i) in rowTagNames(row)" :key="i" size="small"
                  :color="tagColor(rowTagIds(row)[i] || '')" class="cell-tag">{{ n }}</el-tag>
                <el-button size="small" text type="primary" @click="openTagDialog(row)">打标</el-button>
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

      <!-- 卡片视图 -->
      <div v-else class="grid" v-loading="loading">
        <div v-if="list.length === 0" class="empty" style="grid-column: 1 / -1;">无结果</div>
        <div v-for="r in list" :key="r.id" class="card">
          <div class="thumb" :class="{ 'thumb-img': isImage(r) }">
            <img v-if="isImage(r)" :src="fileUrl(r.id)" loading="lazy" :alt="r.title" />
            <span v-else class="thumb-icon">{{ typeIcons[r.type] || '📄' }}</span>
          </div>
          <div class="card-title" :title="r.title">{{ r.title }}</div>
          <div class="card-meta">{{ r.type === 'file' ? r.path : typeLabels[r.type] }}</div>
          <div class="card-tags">
            <el-tag v-for="(n, i) in rowTagNames(r)" :key="i" size="small" :color="tagColor(rowTagIds(r)[i] || '')">{{ n }}</el-tag>
          </div>
        </div>
      </div>

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
  </div>
</template>

<style scoped>
.browser { display: flex; height: 100%; min-height: 0; position: relative; }

.side { overflow: hidden; background: var(--el-bg-color, #fff); border-right: 1px solid var(--el-border-color, #e5e7eb); padding: 12px 0 12px 14px; box-sizing: border-box; position: relative; flex: none; display: flex; flex-direction: column; }
.side-title { display: flex; align-items: center; justify-content: space-between; font-size: 13px; color: var(--el-text-color-secondary, #6b7280); margin-bottom: 8px; padding-right: 10px; }
.tree-actions { display: flex; gap: 2px; }
.tree-actions .el-button { padding: 0 4px; margin: 0; }
.tree-wrap { flex: 1; min-height: 0; overflow: auto; padding-right: 8px; }
.file-tree { --el-tree-node-content-height: 28px; }
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
.path { color: var(--el-text-color-secondary, #9ca3af); font-size: 12px; }
.tag-cell { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.cell-tag { max-width: 90px; }

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
</style>
