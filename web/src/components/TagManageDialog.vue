<script setup lang="ts">
// 通用「加标签 / 打标」弹窗（截图样式）：可勾选标签、输入新建（可关）、删除标签、可选递归。
// 仅负责「选择集」编辑态与标签的新建/删除；父级在 @save 时自行调用 setResourceTags 持久化并刷新。
import { ref, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { getTags, createTag, deleteTag, type TagItem } from '../api';

const props = defineProps<{
  modelValue: boolean;            // 是否显示
  ids?: string[];                 // 已选标签 id 集合（打开时快照）
  title?: string;                 // 标题文案，默认「添加标签」
  allowCreate?: boolean;          // 是否显示「输入新标签名 + 新建」区，默认 true
  recursiveLabel?: string;        // 传则显示递归复选框
  recursive?: boolean;            // 递归初始值
  allowDelete?: boolean;          // 是否显示标签「×」删除按钮，默认 true（表单内选择时建议 false）
}>();
const emit = defineEmits<{
  (e: 'update:modelValue', v: boolean): void;
  (e: 'update:recursive', v: boolean): void;
  (e: 'save', ids: string[], recursive: boolean): void;
}>();

const tags = ref<TagItem[]>([]);
const checked = ref<string[]>([]);
const newName = ref('');
const rec = ref(false);

async function loadTags() {
  try { tags.value = await getTags(); } catch { tags.value = []; }
}

watch(() => props.modelValue, (open) => {
  if (open) {
    rec.value = !!props.recursive;
    checked.value = [...(props.ids || [])];
    newName.value = '';
    loadTags();
  }
});

function toggle(id: string) {
  const i = checked.value.indexOf(id);
  if (i >= 0) checked.value.splice(i, 1); else checked.value.push(id);
}
async function doCreate() {
  const name = newName.value.trim();
  if (!name) { ElMessage.warning('请输入新标签名'); return; }
  if (tags.value.some(t => t.name === name)) { ElMessage.warning('标签已存在'); return; }
  try {
    const t = await createTag(name);
    await loadTags();
    if (!checked.value.includes(t.id)) checked.value.push(t.id);
    newName.value = '';
    ElMessage.success(`标签「${t.name}」已创建并勾选`);
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.msg || e?.message || '创建失败');
  }
}
async function removeTag(t: TagItem) {
  try { await ElMessageBox.confirm(`删除标签「${t.name}」？将同时从所有资源上移除。`, '确认删除', { type: 'warning' }); }
  catch { return; }
  try {
    await deleteTag(t.id);
    const i = checked.value.indexOf(t.id);
    if (i >= 0) checked.value.splice(i, 1);
    await loadTags();
    ElMessage.success('标签已删除');
  } catch (e: any) { ElMessage.error(e?.response?.data?.msg || e?.message || '删除失败'); }
}
function close() { emit('update:modelValue', false); }
function save() {
  // 关闭由父级 v-model 控制；父级 @save 内自行持久化并刷新。此处同步关窗，避免"保存后窗口仍开着"。
  emit('save', [...checked.value], rec.value);
  close();
}
</script>

<template>
  <el-dialog :model-value="modelValue" :title="title || '添加标签'" width="440"
    @update:model-value="(v: boolean) => emit('update:modelValue', v)" :close-on-click-modal="false">
    <div v-if="allowCreate !== false" class="tg-new">
      <el-input v-model="newName" placeholder="输入新标签名直接创建" style="flex: 1;" @keyup.enter="doCreate" />
      <el-button type="primary" plain @click="doCreate">新建标签</el-button>
    </div>
    <div class="tg-tags">
      <el-tag
        v-for="t in tags" :key="t.id"
        :effect="checked.includes(t.id) ? 'dark' : 'plain'"
        :closable="props.allowDelete !== false"
        @click.stop="toggle(t.id)"
        @close="removeTag(t)"
      >{{ t.name }}</el-tag>
      <p v-if="tags.length === 0" class="tg-empty">{{ props.allowCreate !== false ? '暂无标签，输入上方名称直接创建' : '暂无标签' }}</p>
    </div>
    <el-checkbox v-if="recursiveLabel" v-model="rec" class="tg-recursive">{{ recursiveLabel }}</el-checkbox>
    <template #footer>
      <el-button @click="close">取消</el-button>
      <el-button type="primary" @click="save">确定</el-button>
    </template>
  </el-dialog>
</template>

<style scoped>
.tg-new { display: flex; gap: 8px; }
.tg-tags { display: flex; flex-wrap: wrap; gap: 6px; max-height: 240px; overflow-y: auto; margin-top: 10px; }
.tg-empty { width: 100%; text-align: center; color: var(--el-text-color-secondary, #909399); font-size: 12px; margin: 6px 0; }
.tg-recursive { margin-top: 10px; }
</style>
