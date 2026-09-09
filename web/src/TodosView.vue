<script setup lang="ts">
// 待办视图：独立 tab 入口，列出全部待办（type=todo）
// 勾选切换完成状态（done 持久化）；右键删除进回收站；未完成项可划线完成态
import { onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getResourcesPage, createResource, updateResource, deleteResource, type Resource } from './api';

const list = ref<Resource[]>([]);
const total = ref(0);
const loading = ref(false);
const filter = ref<'all' | 'todo' | 'done'>('all');

async function load() {
  loading.value = true;
  try {
    const res = await getResourcesPage({ page: '1', pageSize: '500', type: 'todo', status: 'active' });
    let rows = res.list;
    if (filter.value === 'todo') rows = rows.filter(r => !r.done);
    else if (filter.value === 'done') rows = rows.filter(r => r.done);
    list.value = rows;
    total.value = rows.length;
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

// ---------- 新建待办 ----------
const createDialog = ref({ visible: false, title: '', content: '', saving: false });
function openCreate() { createDialog.value = { visible: true, title: '', content: '', saving: false }; }
async function doCreate() {
  const d = createDialog.value;
  if (!d.title.trim()) { ElMessage.warning('请输入待办内容'); return; }
  d.saving = true;
  try {
    await createResource('todo', d.title.trim(), d.content);
    d.visible = false;
    ElMessage.success('已添加待办');
    await load();
  } catch (e: any) {
    ElMessage.error('添加失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.saving = false;
  }
}

// ---------- 完成状态切换 ----------
const toggling = ref<Set<string>>(new Set());
async function toggleDone(row: Resource) {
  if (toggling.value.has(row.id)) return;
  toggling.value.add(row.id);
  try {
    await updateResource(row.id, { done: !row.done });
    row.done = !row.done;
  } catch (e: any) {
    ElMessage.error('更新失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    toggling.value.delete(row.id);
  }
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
  if (cmd === 'toggle') { toggleDone(row); return; }
  try {
    await ElMessageBox.confirm(`将待办「${row.title}」移入回收站？`, '移入回收站', { type: 'warning' });
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
  <div class="todos-view">
    <div class="tv-head">
      <div class="tv-title">✅ 待办<small>（未完成 {{ list.filter(r => !r.done).length }} 项）</small></div>
      <el-radio-group v-model="filter" size="default" @change="load">
        <el-radio-button value="all">全部</el-radio-button>
        <el-radio-button value="todo">未完成</el-radio-button>
        <el-radio-button value="done">已完成</el-radio-button>
      </el-radio-group>
      <el-button type="primary" size="default" @click="openCreate">✅ 新建待办</el-button>
    </div>

    <div class="tv-body" v-loading="loading">
      <el-table :data="list" size="small" height="100%" stripe @row-contextmenu="onCtx">
        <el-table-column label="" width="52">
          <template #default="{ row }">
            <el-checkbox :model-value="!!row.done" @change="toggleDone(row)" @click.stop />
          </template>
        </el-table-column>
        <el-table-column label="待办内容" min-width="280">
          <template #default="{ row }">
            <span class="tv-name" :class="{ done: !!row.done }">
              <span class="tv-ico">{{ row.done ? '✅' : '⭕' }}</span>{{ row.title }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="150">
          <template #default="{ row }">{{ fmtTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>
      <div v-if="list.length === 0 && !loading" class="tv-empty">暂无待办</div>
    </div>

    <!-- 新建待办 -->
    <el-dialog v-model="createDialog.visible" title="新建待办" width="480">
      <div class="tv-field">
        <label>待办内容</label>
        <el-input v-model="createDialog.title" placeholder="要做什么？" maxlength="200" @keyup.enter="doCreate" />
      </div>
      <div class="tv-field">
        <label>备注（可选）</label>
        <el-input v-model="createDialog.content" type="textarea" :rows="4" placeholder="补充说明…" />
      </div>
      <template #footer>
        <el-button @click="createDialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="createDialog.saving" @click="doCreate">添加</el-button>
      </template>
    </el-dialog>

    <!-- 右键菜单 -->
    <Teleport to="body">
      <div v-if="ctx.visible" class="ctx-menu" :style="{ left: ctx.x + 'px', top: ctx.y + 'px' }" @contextmenu.prevent>
        <div class="ctx-item" @click="onCtxCmd('toggle')">{{ ctx.row?.done ? '标记为未完成' : '标记为完成' }}</div>
        <div class="ctx-item danger" @click="onCtxCmd('delete')">删除（回收站）</div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.todos-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.tv-head { display: flex; align-items: center; gap: 12px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.tv-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.tv-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }
.tv-body { flex: 1; min-height: 0; background: var(--el-bg-color, #fff); margin: 12px 16px 0; border-radius: 10px; border: 1px solid var(--el-border-color, #e5e7eb); overflow: hidden; position: relative; }
.tv-body :deep(.el-table td.el-table__cell) { padding: 2px 0; }
.tv-body :deep(.el-table th.el-table__cell) { padding: 4px 0; }
.tv-body :deep(.el-table .cell) { padding: 0 8px; line-height: 1.5; }
.tv-name { display: flex; align-items: center; gap: 8px; overflow: hidden; }
.tv-name.done { color: var(--el-text-color-secondary, #9ca3af); text-decoration: line-through; }
.tv-ico { flex: none; font-size: 14px; }
.tv-empty { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: var(--el-text-color-secondary, #9ca3af); font-size: 13px; }
.tv-field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 12px; }
.tv-field label { font-size: 12px; color: var(--el-text-color-secondary, #6b7280); }
.ctx-menu { position: fixed; z-index: 3000; min-width: 120px; padding: 4px; border-radius: 8px; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12); }
.ctx-item { padding: 6px 12px; font-size: 13px; border-radius: 5px; cursor: pointer; color: var(--el-text-color-primary, #1f2937); }
.ctx-item:hover { background: var(--kh-brand, #409eff); color: #fff; }
.ctx-item.danger { color: #f56c6c; }
.ctx-item.danger:hover { background: #f56c6c; color: #fff; }
</style>
