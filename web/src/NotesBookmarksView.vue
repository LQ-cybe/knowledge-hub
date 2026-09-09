<script setup lang="ts">
// 书签笔记合并页：笔记(note) + 书签(bookmark) 统一列表
// - 笔记：行点击打开 Markdown 编辑器（mode=note）；可加标签
// - 书签：可加链接/描述/图标/标签；行点击打开书签编辑弹层（可跳转链接）
import { onMounted, ref, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import {
  getResourcesPage, createResource, deleteResource, getResource, updateResource,
  setResourceTags, type Resource,
} from './api';
import TagChips from './components/TagChips.vue';
import TagManageDialog from './components/TagManageDialog.vue';

const emit = defineEmits<{ (e: 'open-editor', p: { id: string; title: string; ext: string; path: string; isImage: boolean; mode?: 'file' | 'note' }): void }>();

const list = ref<Resource[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(50);
const loading = ref(false);
const q = ref('');
const subFilter = ref<'all' | 'note' | 'bookmark'>('all');

async function load() {
  loading.value = true;
  try {
    const type = subFilter.value === 'all' ? 'note,bookmark' : subFilter.value;
    const res = await getResourcesPage({
      page: String(page.value), pageSize: String(pageSize.value),
      type, q: q.value.trim(), orderBy: 'updated_at', orderDir: 'desc', status: 'active',
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
defineExpose({ reload: load });
watch(subFilter, () => { page.value = 1; load(); });

function fmtTime(s: string) {
  if (!s) return '';
  const d = new Date(s.replace(' ', 'T'));
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}
function iconOf(row: Resource) {
  if (row.type === 'bookmark') {
    try { const m = JSON.parse(row.meta || '{}'); if (m.icon) return m.icon; } catch { /* ignore */ }
    return '🔖';
  }
  return '📝';
}
function parseMeta(row: Resource): Record<string, unknown> {
  try { return JSON.parse(row.meta || '{}'); } catch { return {}; }
}

// ---------- 标签 ----------
// 行级：点击列内 chips → 打开「加标签」弹窗（可新建）
const tagDlg = ref({ visible: false, row: null as Resource | null });
function openTagDialog(row: Resource) {
  tagDlg.value = { visible: true, row };
}
async function saveRowTags(ids: string[]) {
  const row = tagDlg.value.row;
  if (!row) return;
  try {
    await setResourceTags(row.id, ids);
    const tags = await getResourcesPage({ page: '1', pageSize: '1', type: row.type, id: row.id, status: 'active' });
    const fresh = tags.list[0];
    if (fresh) { row.tag_names = fresh.tag_names; row.tag_ids = fresh.tag_ids; }
    ElMessage.success('标签已更新');
  } catch (e: any) {
    ElMessage.error('标签更新失败：' + (e?.message || '服务异常'));
  }
}
const rowTagNames = (row: Resource) => (row.tag_names || '').split('|').filter(Boolean);
const rowTagIds = (row: Resource) => (row.tag_ids || '').split('|').filter(Boolean);

// 新建 / 编辑表单内：仅选择已有标签（不新建、不删除），选中回填 tagIds
const formTagDlg = ref({ visible: false, target: 'create' as 'create' | 'bm' });
function openFormTagDialog(target: 'create' | 'bm') { formTagDlg.value = { visible: true, target }; }
function formTagIds() { return formTagDlg.value.target === 'bm' ? bmDialog.value.tagIds : createDialog.value.tagIds; }
function onFormTagSave(ids: string[]) {
  if (formTagDlg.value.target === 'bm') bmDialog.value.tagIds = ids;
  else createDialog.value.tagIds = ids;
  formTagDlg.value.visible = false;
}

// ---------- 新建 ----------
const createDialog = ref({ visible: false, kind: 'note' as 'note' | 'bookmark', title: '', content: '', url: '', format: 'md', icon: '🔖', tagIds: [] as string[], saving: false });
const ICON_CHOICES = ['🔖', '📌', '⭐', '💡', '📄', '🔗', '📁', '📊', '🧩', '⚙️', '📚', '🎯'];
function openCreate(kind: 'note' | 'bookmark') {
  createDialog.value = { visible: true, kind, title: '', content: '', url: '', format: 'md', icon: '🔖', tagIds: [], saving: false };
}
async function doCreate() {
  const d = createDialog.value;
  if (!d.title.trim()) { ElMessage.warning('请输入标题'); return; }
  if (d.kind === 'bookmark' && !d.url.trim()) { ElMessage.warning('请输入书签链接'); return; }
  d.saving = true;
  try {
    const meta = d.kind === 'bookmark' ? JSON.stringify({ icon: d.icon }) : undefined;
    const r = await createResource(d.kind, d.title.trim(), d.content, d.url, meta);
    if (d.tagIds.length) await setResourceTags(r.id, d.tagIds);
    d.visible = false;
    ElMessage.success(d.kind === 'note' ? '笔记已创建' : '书签已创建');
    await load();
    if (d.kind === 'note') emit('open-editor', { id: r.id, title: r.title, ext: d.format, path: '', isImage: false, mode: 'note' });
  } catch (e: any) {
    ElMessage.error('创建失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.saving = false;
  }
}

// ---------- 书签编辑弹层 ----------
const bmDialog = ref({ visible: false, id: '', title: '', url: '', content: '', icon: '🔖', tagIds: [] as string[], saving: false });
async function openBookmarkEdit(row: Resource) {
  const detail = await getResource(row.id) as Resource & { meta?: string };
  const m = parseMeta(detail);
  bmDialog.value = {
    visible: true, id: row.id, title: detail.title,
    url: detail.source_url || '', content: detail.content || '',
    icon: (m.icon as string) || '🔖', tagIds: (row.tag_ids ? row.tag_ids.split('|').filter(Boolean) : []), saving: false,
  };
}
async function saveBookmark() {
  const d = bmDialog.value;
  if (!d.title.trim()) { ElMessage.warning('请输入标题'); return; }
  if (!d.url.trim()) { ElMessage.warning('请输入书签链接'); return; }
  d.saving = true;
  try {
    await updateResource(d.id, { title: d.title.trim(), source_url: d.url.trim(), content: d.content, meta: JSON.stringify({ icon: d.icon }) });
    if (d.tagIds.length) await setResourceTags(d.id, d.tagIds);
    d.visible = false;
    ElMessage.success('书签已保存');
    await load();
  } catch (e: any) {
    ElMessage.error('保存失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    d.saving = false;
  }
}
function openLink(url: string) {
  if (url) window.open(url, '_blank', 'noopener');
}

// ---------- 行点击 / 右键 ----------
function onRowClick(row: Resource) {
  if (row.type === 'note') emit('open-editor', { id: row.id, title: row.title, ext: 'md', path: '', isImage: false, mode: 'note' });
  else openBookmarkEdit(row);
}
const ctx = ref({ visible: false, x: 0, y: 0, row: null as Resource | null });
function onCtx(e: MouseEvent, row: Resource) { e.preventDefault(); ctx.value = { visible: true, x: e.clientX, y: e.clientY, row }; }
function closeCtx() { ctx.value.visible = false; }
async function onCtxCmd(cmd: string) {
  const row = ctx.value.row; ctx.value.visible = false;
  if (!row) return;
  if (cmd === 'edit') { onRowClick(row); return; }
  try {
    await ElMessageBox.confirm(`将「${row.title}」移入回收站？回收站资源 30 天后自动清理。`, '移入回收站', { type: 'warning' });
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
  <div class="nb-view">
    <div class="nb-head">
      <div class="nb-title">📑 书签笔记<small>（共 {{ total }} 条）</small></div>
      <el-radio-group v-model="subFilter" size="default">
        <el-radio-button value="all">全部</el-radio-button>
        <el-radio-button value="note">📝 笔记</el-radio-button>
        <el-radio-button value="bookmark">🔖 书签</el-radio-button>
      </el-radio-group>
      <el-input v-model="q" placeholder="按标题搜索" clearable style="width: 200px;" @keyup.enter="page = 1; load()" @clear="page = 1; load()" />
      <el-button type="primary" size="default" @click="openCreate('note')">📝 新建笔记</el-button>
      <el-button size="default" @click="openCreate('bookmark')">🔖 新建书签</el-button>
      <div class="nb-count">共 {{ total }} 条</div>
    </div>

    <div class="nb-body" v-loading="loading">
      <el-table :data="list" size="small" height="100%" stripe @row-click="onRowClick" @row-contextmenu="onCtx">
        <el-table-column label="标题" min-width="280">
          <template #default="{ row }">
            <span class="nb-name">
              <span class="nb-ico">{{ iconOf(row) }}</span>{{ row.title }}
              <span v-if="row.type === 'bookmark' && row.source_url" class="nb-url" :title="row.source_url" @click.stop="openLink(row.source_url)">🔗</span>
            </span>
          </template>
        </el-table-column>
        <el-table-column label="标签" min-width="180">
          <template #default="{ row }">
            <TagChips :names="rowTagNames(row)" @open="openTagDialog(row)" />
          </template>
        </el-table-column>
        <el-table-column label="更新时间" width="150">
          <template #default="{ row }">{{ fmtTime(row.updated_at) }}</template>
        </el-table-column>
      </el-table>
    </div>

    <div class="nb-foot">
      <el-pagination v-model:current-page="page" v-model:page-size="pageSize" :total="total"
        :page-sizes="[50, 100, 200]" layout="total, sizes, prev, pager, next" @current-change="load" @size-change="page = 1; load()" />
    </div>

    <!-- 新建笔记 / 书签 -->
    <el-dialog v-model="createDialog.visible" :title="createDialog.kind === 'note' ? '新建笔记' : '新建书签'" width="560" destroy-on-close>
      <div class="nb-field">
        <label>标题</label>
        <el-input v-model="createDialog.title" :placeholder="createDialog.kind === 'note' ? '笔记标题' : '书签标题'" maxlength="200" @keyup.enter="doCreate" />
      </div>
      <template v-if="createDialog.kind === 'note'">
        <div class="nb-field">
          <label>格式</label>
          <el-radio-group v-model="createDialog.format">
            <el-radio-button value="md">Markdown</el-radio-button>
            <el-radio-button value="txt">纯文本</el-radio-button>
          </el-radio-group>
        </div>
        <div class="nb-field">
          <label>内容（Markdown）</label>
          <el-input v-model="createDialog.content" type="textarea" :rows="8" placeholder="在此输入笔记内容…" />
        </div>
      </template>
      <template v-else>
        <div class="nb-field">
          <label>链接（必填）</label>
          <el-input v-model="createDialog.url" placeholder="https://…" />
        </div>
        <div class="nb-field">
          <label>描述</label>
          <el-input v-model="createDialog.content" type="textarea" :rows="4" placeholder="补充说明…" />
        </div>
        <div class="nb-field">
          <label>图标</label>
          <div class="nb-icons">
            <button v-for="ic in ICON_CHOICES" :key="ic" class="nb-ic" :class="{ on: ic === createDialog.icon }" @click="createDialog.icon = ic">{{ ic }}</button>
          </div>
        </div>
      </template>
      <div class="nb-field">
        <label>标签</label>
        <TagChips :names="formTagIds()" placeholder="选择标签" @open="openFormTagDialog('create')" />
      </div>
      <template #footer>
        <el-button @click="createDialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="createDialog.saving" @click="doCreate">创建</el-button>
      </template>
    </el-dialog>

    <!-- 书签编辑 -->
    <el-dialog v-model="bmDialog.visible" title="编辑书签" width="560" destroy-on-close>
      <div class="nb-field">
        <label>标题</label>
        <el-input v-model="bmDialog.title" placeholder="书签标题" @keyup.enter="saveBookmark" />
      </div>
      <div class="nb-field">
        <label>链接（必填）</label>
        <el-input v-model="bmDialog.url" placeholder="https://…">
          <template #append><el-button @click="openLink(bmDialog.url)">打开</el-button></template>
        </el-input>
      </div>
      <div class="nb-field">
        <label>描述</label>
        <el-input v-model="bmDialog.content" type="textarea" :rows="4" placeholder="补充说明…" />
      </div>
      <div class="nb-field">
        <label>图标</label>
        <div class="nb-icons">
          <button v-for="ic in ICON_CHOICES" :key="ic" class="nb-ic" :class="{ on: ic === bmDialog.icon }" @click="bmDialog.icon = ic">{{ ic }}</button>
        </div>
      </div>
      <div class="nb-field">
        <label>标签</label>
        <TagChips :names="formTagIds()" placeholder="选择标签" @open="openFormTagDialog('bm')" />
      </div>
      <template #footer>
        <el-button @click="bmDialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="bmDialog.saving" @click="saveBookmark">保存</el-button>
      </template>
    </el-dialog>

    <!-- 行级添加标签 -->
    <TagManageDialog
      v-model="tagDlg.visible"
      :ids="tagDlg.row ? rowTagIds(tagDlg.row) : []"
      title="添加标签"
      @save="saveRowTags"
    />

    <!-- 表单内选择标签（仅选择已存在标签，不新建/删除） -->
    <TagManageDialog
      v-model="formTagDlg.visible"
      :ids="formTagIds()"
      title="选择标签"
      :allow-create="false"
      :allow-delete="false"
      @save="onFormTagSave"
    />

    <Teleport to="body">
      <div v-if="ctx.visible" class="ctx-menu" :style="{ left: ctx.x + 'px', top: ctx.y + 'px' }" @contextmenu.prevent>
        <div class="ctx-item" @click="onCtxCmd('edit')">编辑</div>
        <div class="ctx-item danger" @click="onCtxCmd('delete')">删除（回收站）</div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.nb-view { display: flex; flex-direction: column; height: 100%; min-height: 0; }
.nb-head { display: flex; align-items: center; gap: 10px; padding: 10px 16px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color, #e5e7eb); flex-wrap: wrap; }
.nb-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.nb-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }
.nb-count { margin-left: auto; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.nb-body { flex: 1; min-height: 0; background: var(--el-bg-color, #fff); margin: 12px 16px 0; border-radius: 10px; border: 1px solid var(--el-border-color, #e5e7eb); overflow: hidden; }
.nb-body :deep(.el-table td.el-table__cell) { padding: 2px 0; }
.nb-body :deep(.el-table th.el-table__cell) { padding: 4px 0; }
.nb-body :deep(.el-table .cell) { padding: 0 8px; line-height: 1.5; }
.nb-body :deep(.el-table__row) { cursor: pointer; }
.nb-name { display: flex; align-items: center; gap: 8px; overflow: hidden; }
.nb-ico { flex: none; font-size: 15px; }
.nb-url { flex: none; cursor: pointer; font-size: 13px; }
.nb-url:hover { filter: brightness(1.2); }
.nb-foot { display: flex; justify-content: flex-end; padding: 8px 16px 12px; }
.nb-field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 12px; }
.nb-field label { font-size: 12px; color: var(--el-text-color-secondary, #6b7280); }
.nb-icons { display: flex; gap: 8px; flex-wrap: wrap; }
.nb-ic { width: 34px; height: 34px; font-size: 18px; border: 1px solid var(--el-border-color, #dcdfe6); border-radius: 8px; background: var(--el-bg-color, #fff); cursor: pointer; }
.nb-ic.on { border-color: var(--el-color-primary, #409eff); background: var(--el-color-primary-light-9, #ecf5ff); }
.ctx-menu { position: fixed; z-index: 3000; min-width: 120px; padding: 4px; border-radius: 8px; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color, #e5e7eb); box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12); }
.ctx-item { padding: 6px 12px; font-size: 13px; border-radius: 5px; cursor: pointer; color: var(--el-text-color-primary, #1f2937); }
.ctx-item:hover { background: var(--kh-brand, #409eff); color: #fff; }
.ctx-item.danger { color: #f56c6c; }
.ctx-item.danger:hover { background: #f56c6c; color: #fff; }
</style>
