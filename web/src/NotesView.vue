<script setup lang="ts">
// 笔记视图：独立 tab 入口，列出全部笔记（数据库自建资源 type=note）
// 单击行打开 Markdown 编辑器（mode=note）；右键菜单：编辑 / 删除（回收站）
import { onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getResourcesPage, createResource, deleteResource, type Resource } from './api';

const emit = defineEmits<{ (e: 'open-editor', p: { id: string; title: string; ext: string; path: string; isImage: boolean; mode?: 'file' | 'note' }): void }>();

const list = ref<Resource[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(50);
const loading = ref(false);
const q = ref('');

async function load() {
  loading.value = true;
  try {
    const res = await getResourcesPage({
      page: String(page.value), pageSize: String(pageSize.value),
      type: 'note', q: q.value.trim(), orderBy: 'updated_at', orderDir: 'desc', status: 'active',
    });
    list.value = res.list;
    total.value = res.total;
  } catch (e: any) {
    ElMessage.error('加载失败：' + (e?.message || '服务异常'));
  } finally {
    loading.value = false;
  }
}
onMounted(load);

function fmtTime(s: string) {
  if (!s) return '';
  const d = new Date(s.replace(' ', 'T'));
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

// ---------- 新建笔记 ----------
const createDialog = ref({ visible: false, title: '', content: '', saving: false });
function openCreate() { createDialog.value = { visible: true, title: '', content: '', saving: false }; }
async function doCreate() {
  const d = createDialog.value;
  if (!d.title.trim()) { ElMessage.warning('请输入笔记标题'); return; }
  d.saving = true;
  try {
    const r = await createResource('note', d.title.trim(), d.content);
    d.visible = false;
    ElMessage.success('笔记已创建');
    await load();
    emit('open-editor', { id: r.id, title: r.title, ext: 'md', path: '', isImage: false, mode: 'note' });
  } catch (e: any) {
    ElMessage.error('创建失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.saving = false;
  }
}

function openNote(row: Resource) {
  emit('open-editor', { id: row.id, title: row.title, ext: 'md', path: '', isImage: false, mode: 'note' });
}

// ---------- 右键菜单 ----------
const ctx = ref({ visible: false, x: 0, y: 0, row: null as Resource | null });
function onCtx(e: MouseEvent, row: Resource) {
  e.preventDefault();
  ctx.value = { visible: true, x: e.clientX, y: e.clientY, row };
}
function closeCtx() { ctx.value.visible = false; }
async function onCtxCmd(cmd: string) {
  const row = ctx.value.row;
  ctx.value.visible = false;
  if (!row) return;
  if (cmd === 'edit') { openNote(row); return; }
  try {
    await ElMessageBox.confirm(`将笔记「${row.title}」移入回收站？回收站资源 30 天后自动清理。`, '移入回收站', { type: 'warning' });
  } catch { return; }
  try {
    await deleteResource(row.id);
    ElMessage.success('已移入回收站（30 天后自动清理）');
    await load();
  } catch (e: any) {
    ElMessage.error('删除失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  }
}
onMounted(() => document.addEventListener('click', closeCtx));
</script>

<template>
  <div class="notes-view">
    <div class="nv-head">
      <div class="nv-title">📝 笔记<small>（共 {{ total }} 条）</small></div>
      <el-input v-model="q" placeholder="按标题搜索" clearable style="width: 220px;" @keyup.enter="page = 1; load()" @clear="page = 1; load()" />
      <el-button type="primary" size="default" @click="openCreate">📝 新建笔记</el-button>
      <div class="nv-count">共 {{ total }} 条</div>
    </div>

    <div class="nv-body" v-loading="loading">
      <el-table :data="list" size="small" height="100%" stripe @row-click="openNote" @row-contextmenu="onCtx">
        <el-table-column label="标题" min-width="260">
          <template #default="{ row }">
            <span class="nv-name"><span class="nv-ico">📝</span>{{ row.title }}</span>
          </template>
        </el-table-column>
        <el-table-column label="更新时间" width="150">
          <template #default="{ row }">{{ fmtTime(row.updated_at) }}</template>
        </el-table-column>
        <el-table-column label="标签" min-width="140">
          <template #default="{ row }">
            <span v-if="row.tag_names" class="nv-tags" :title="row.tag_names">{{ row.tag_names.replace(/\|/g, ' ') }}</span>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <div class="nv-foot">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :total="total"
        :page-sizes="[50, 100, 200]"
        layout="total, sizes, prev, pager, next"
        @current-change="load" @size-change="page = 1; load()"
      />
    </div>

    <!-- 新建笔记 -->
    <el-dialog v-model="createDialog.visible" title="新建笔记" width="560">
      <div class="nv-field">
        <label>标题</label>
        <el-input v-model="createDialog.title" placeholder="笔记标题" maxlength="200" @keyup.enter="doCreate" />
      </div>
      <div class="nv-field">
        <label>内容（Markdown）</label>
        <el-input v-model="createDialog.content" type="textarea" :rows="10" placeholder="在此输入笔记内容，支持 Markdown 语法…" />
      </div>
      <template #footer>
        <el-button @click="createDialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="createDialog.saving" @click="doCreate">创建并编辑</el-button>
      </template>
    </el-dialog>

    <!-- 右键菜单 -->
    <Teleport to="body">
      <div v-if="ctx.visible" class="ctx-menu" :style="{ left: ctx.x + 'px', top: ctx.y + 'px' }" @contextmenu.prevent>
        <div class="ctx-item" @click="onCtxCmd('edit')">编辑</div>
        <div class="ctx-item danger" @click="onCtxCmd('delete')">删除（回收站）</div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.notes-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.nv-head { display: flex; align-items: center; gap: 10px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.nv-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.nv-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }
.nv-count { margin-left: auto; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.nv-body { flex: 1; min-height: 0; background: var(--el-bg-color, #fff); margin: 12px 16px 0; border-radius: 10px; border: 1px solid var(--el-border-color, #e5e7eb); overflow: hidden; }
.nv-body :deep(.el-table td.el-table__cell) { padding: 2px 0; }
.nv-body :deep(.el-table th.el-table__cell) { padding: 4px 0; }
.nv-body :deep(.el-table .cell) { padding: 0 8px; line-height: 1.5; }
.nv-name { display: flex; align-items: center; gap: 8px; overflow: hidden; }
.nv-ico { flex: none; font-size: 15px; }
.nv-tags { font-size: 11px; color: var(--el-text-color-secondary, #6b7280); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%; }
.nv-foot { display: flex; justify-content: flex-end; padding: 8px 16px 12px; }
.nv-field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 12px; }
.nv-field label { font-size: 12px; color: var(--el-text-color-secondary, #6b7280); }
.ctx-menu { position: fixed; z-index: 3000; min-width: 120px; padding: 4px; border-radius: 8px; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12); }
.ctx-item { padding: 6px 12px; font-size: 13px; border-radius: 5px; cursor: pointer; color: var(--el-text-color-primary, #1f2937); }
.ctx-item:hover { background: var(--kh-brand, #409eff); color: #fff; }
.ctx-item.danger { color: #f56c6c; }
.ctx-item.danger:hover { background: #f56c6c; color: #fff; }
</style>
