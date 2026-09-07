<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import {
  getResourcesPage, getTags, createTag, updateTag, deleteTag, setResourceTags,
  type Resource, type TagItem,
} from './api';

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

// 行内打标对话框
const tagDialog = ref({ visible: false, resourceId: '', resourceTitle: '', checked: [] as string[] });
// 批量打标对话框
const batchDialog = ref({ visible: false, checked: [] as string[] });
// 标签管理对话框
const manageDialog = ref({ visible: false, newName: '', editing: null as { id: string; name: string } | null });

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
const typeIcons: Record<string, string> = { folder: '📂', file: '📄', note: '📝', bookmark: '🔖', todo: '✅', report: '📊' };

const tagColor = (id: string) => tags.value.find(t => t.id === id)?.color || '#8BC8EA';

async function load() {
  loading.value = true;
  try {
    const res = await getResourcesPage({
      page: String(page.value),
      pageSize: String(pageSize.value),
      type: filters.value.type,
      q: filters.value.q.trim(),
      tag: filters.value.tag,
      orderBy: orderBy.value,
      orderDir: orderDir.value,
    });
    list.value = res.list;
    total.value = res.total;
  } finally {
    loading.value = false;
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

function onFilterChange() { page.value = 1; load(); }
function onSortChange() { page.value = 1; load(); }
function onPageChange() { load(); }

function rowTagNames(r: Resource): string[] {
  return (r.tag_names || '').split('|').filter(Boolean);
}

/** 行内打标 */
function openTagDialog(row: Resource) {
  tagDialog.value = {
    visible: true,
    resourceId: row.id,
    resourceTitle: row.title,
    checked: (row.tag_ids || '').split('|').filter(Boolean),
  };
}

async function saveTagDialog() {
  const d = tagDialog.value;
  await setResourceTags(d.resourceId, d.checked);
  d.visible = false;
  ElMessage.success('标签已更新');
  load();
  refreshTags();
}

/** 批量打标（追加，保留原有标签） */
function openBatchDialog() {
  if (selection.value.length === 0) {
    ElMessage.warning('请先在表格中勾选要打标的资源');
    return;
  }
  batchDialog.value = { visible: true, checked: [] };
}

async function saveBatchDialog() {
  const add = batchDialog.value.checked;
  if (add.length === 0) { ElMessage.warning('请选择要添加的标签'); return; }
  let n = 0;
  for (const row of selection.value) {
    const cur = (row.tag_ids || '').split('|').filter(Boolean);
    const merged = [...new Set([...cur, ...add])];
    await setResourceTags(row.id, merged);
    n++;
  }
  batchDialog.value.visible = false;
  ElMessage.success(`已为 ${n} 个资源添加标签`);
  load();
  refreshTags();
}

/** 标签管理 */
async function createNewTag() {
  const name = manageDialog.value.newName.trim();
  if (!name) { ElMessage.warning('请输入标签名'); return; }
  try {
    await createTag(name);
    manageDialog.value.newName = '';
    await refreshTags();
    ElMessage.success('标签已创建');
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.msg || '创建失败');
  }
}

async function renameTag(t: TagItem) {
  manageDialog.value.editing = { id: t.id, name: t.name };
}

async function saveRename() {
  const e = manageDialog.value.editing;
  if (!e) return;
  const name = e.name.trim();
  if (!name) { ElMessage.warning('标签名不能为空'); return; }
  try {
    await updateTag(e.id, { name });
    manageDialog.value.editing = null;
    await refreshTags();
    load();
    ElMessage.success('已重命名');
  } catch (err: any) {
    ElMessage.error(err?.response?.data?.msg || '重命名失败');
  }
}

async function removeTag(t: TagItem) {
  try {
    await ElMessageBox.confirm(`删除标签「${t.name}」？将同时从所有资源上移除。`, '确认删除', { type: 'warning' });
  } catch {
    return;
  }
  await deleteTag(t.id);
  await refreshTags();
  load();
  ElMessage.success('标签已删除');
}

function onSelectionChange(rows: Resource[]) { selection.value = rows; }

watch([() => filters.value.type, () => filters.value.tag, orderBy, orderDir], onSortChange);

onMounted(async () => {
  await refreshTags();
  load();
});
</script>

<template>
  <div class="db-view">
    <div class="db-toolbar">
      <el-select v-model="filters.type" style="width: 130px;" @change="onFilterChange">
        <el-option v-for="t in typeOptions" :key="t.value" :label="t.label" :value="t.value" />
      </el-select>
      <el-input
        v-model="filters.q"
        placeholder="按标题/路径筛选"
        clearable
        style="width: 220px;"
        @keyup.enter="onFilterChange"
        @clear="onFilterChange"
      />
      <el-select v-model="filters.tag" placeholder="按标签筛选" clearable style="width: 160px;" @change="onFilterChange">
        <el-option v-for="t in tags" :key="t.id" :label="`${t.name}（${t.count}）`" :value="t.id" />
      </el-select>
      <el-select v-model="orderBy" style="width: 130px;" @change="onSortChange">
        <el-option v-for="o in orderOptions" :key="o.value" :label="`按${o.label}`" :value="o.value" />
      </el-select>
      <el-radio-group v-model="orderDir" size="default" @change="onSortChange">
        <el-radio-button value="desc">↓ 降序</el-radio-button>
        <el-radio-button value="asc">↑ 升序</el-radio-button>
      </el-radio-group>
      <el-button type="primary" plain @click="openBatchDialog">批量打标</el-button>
      <el-button @click="manageDialog.visible = true">管理标签</el-button>
      <el-button @click="onFilterChange">刷新</el-button>
      <span class="total">共 {{ total }} 项</span>
    </div>

    <div class="table-wrap" v-loading="loading">
      <el-table :data="list" size="small" height="100%" stripe @selection-change="onSelectionChange">
        <el-table-column type="selection" width="40" />
        <el-table-column label="类型" width="88">
          <template #default="{ row }">
            <span>{{ typeIcons[row.type] || '📄' }} {{ typeLabels[row.type] || row.type }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="200" show-overflow-tooltip />
        <el-table-column prop="path" label="路径" min-width="240" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="path">{{ row.path || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="标签" min-width="160">
          <template #default="{ row }">
            <div class="tag-cell">
              <el-tag
                v-for="(n, i) in rowTagNames(row)"
                :key="i"
                size="small"
                :color="tagColor((row.tag_ids || '').split('|').filter(Boolean)[i] || '')"
                class="cell-tag"
              >{{ n }}</el-tag>
              <el-button size="small" text type="primary" @click="openTagDialog(row)">打标</el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="大小" width="90" align="right">
          <template #default="{ row }">{{ row.type === 'file' ? fmtSize(row.size) : '-' }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="160">
          <template #default="{ row }">{{ (row.created_at || '').slice(0, 16).replace('T', ' ') }}</template>
        </el-table-column>
        <el-table-column label="更新时间" width="160">
          <template #default="{ row }">{{ (row.updated_at || '').slice(0, 16).replace('T', ' ') }}</template>
        </el-table-column>
      </el-table>
    </div>

    <div class="db-footer">
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

    <!-- 行内打标 -->
    <el-dialog v-model="tagDialog.visible" :title="`打标：${tagDialog.resourceTitle}`" width="420">
      <el-checkbox-group v-model="tagDialog.checked">
        <el-checkbox v-for="t in tags" :key="t.id" :value="t.id" style="width: 33%; margin: 4px 0;">
          {{ t.name }}
        </el-checkbox>
      </el-checkbox-group>
      <template #footer>
        <el-button @click="tagDialog.visible = false">取消</el-button>
        <el-button type="primary" @click="saveTagDialog">保存</el-button>
      </template>
    </el-dialog>

    <!-- 批量打标 -->
    <el-dialog v-model="batchDialog.visible" title="批量添加标签" width="420">
      <p class="dlg-hint">已选 {{ selection.length }} 个资源，将追加以下标签（保留原有标签）：</p>
      <el-checkbox-group v-model="batchDialog.checked">
        <el-checkbox v-for="t in tags" :key="t.id" :value="t.id" style="width: 33%; margin: 4px 0;">
          {{ t.name }}
        </el-checkbox>
      </el-checkbox-group>
      <template #footer>
        <el-button @click="batchDialog.visible = false">取消</el-button>
        <el-button type="primary" @click="saveBatchDialog">应用</el-button>
      </template>
    </el-dialog>

    <!-- 标签管理 -->
    <el-dialog v-model="manageDialog.visible" title="标签管理" width="460">
      <div class="tag-manage">
        <div class="tm-new">
          <el-input v-model="manageDialog.newName" placeholder="新标签名" style="flex: 1;" @keyup.enter="createNewTag" />
          <el-button type="primary" @click="createNewTag">新建</el-button>
        </div>
        <div v-for="t in tags" :key="t.id" class="tm-row">
          <el-tag size="small" :color="t.color">{{ t.name }}</el-tag>
          <span class="tm-count">{{ t.count }} 项</span>
          <template v-if="manageDialog.editing?.id === t.id">
            <el-input v-model="manageDialog.editing.name" size="small" style="width: 140px;" @keyup.enter="saveRename" />
            <el-button size="small" type="primary" @click="saveRename">保存</el-button>
            <el-button size="small" @click="manageDialog.editing = null">取消</el-button>
          </template>
          <template v-else>
            <el-button size="small" @click="renameTag(t)">重命名</el-button>
            <el-button size="small" type="danger" plain @click="removeTag(t)">删除</el-button>
          </template>
        </div>
        <p v-if="tags.length === 0" class="tm-empty">暂无标签，先新建一个</p>
      </div>
    </el-dialog>
  </div>
</template>

<style scoped>
.db-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.db-toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.db-toolbar .total { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-left: auto; }
.table-wrap { flex: 1; min-height: 0; background: var(--el-bg-color, #fff); margin: 12px 16px 0; border-radius: 10px; border: 1px solid var(--el-border-color, #e5e7eb); overflow: hidden; }
.path { color: var(--el-text-color-secondary, #9ca3af); font-size: 12px; }
.tag-cell { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.cell-tag { max-width: 90px; }
.db-footer { display: flex; justify-content: flex-end; padding: 8px 16px 12px; }
.dlg-hint { margin: 0 0 10px; font-size: 13px; color: var(--el-text-color-secondary, #6b7280); }
.tag-manage { display: flex; flex-direction: column; gap: 8px; }
.tm-new { display: flex; gap: 8px; margin-bottom: 4px; }
.tm-row { display: flex; align-items: center; gap: 8px; }
.tm-count { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.tm-empty { color: var(--el-text-color-secondary, #9ca3af); font-size: 13px; text-align: center; padding: 16px 0; }
</style>
