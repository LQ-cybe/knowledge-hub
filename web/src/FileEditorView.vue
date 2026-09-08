<script setup lang="ts">
// 独立文件编辑器页（替代早期弹窗）：整个页面切换进入，顶栏含文件名 + 保存/关闭
import { ref, watch, nextTick } from 'vue';
import { ElMessage } from 'element-plus';
import { fileUrl, readFileText, saveFile } from './api';

const props = defineProps<{
  id: string;
  title: string;
  ext: string;
  path?: string;
  isImage?: boolean;
}>();

const emit = defineEmits<{ (e: 'close'): void }>();

const content = ref('');
const mdHtml = ref('');
const loading = ref(true);
const saving = ref(false);

/** 是否为 md（左右分栏） */
const isMd = () => props.ext === 'md';

/** 极简 MD 渲染：标题/列表/代码块/行内代码/链接/粗体/分割线（与浏览页预览同款，独立页共用） */
function renderMd() {
  const src = content.value || '';
  const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  let html = esc(src)
    .replace(/```([\s\S]*?)```/g, (_m, c: string) => `<pre><code>${c}</code></pre>`)
    .replace(/`([^`]+)`/g, (_m, c: string) => `<code>${c}</code>`)
    .replace(/^### (.*)$/gm, '<h3>$1</h3>')
    .replace(/^## (.*)$/gm, '<h2>$1</h2>')
    .replace(/^# (.*)$/gm, '<h1>$1</h1>')
    .replace(/^- (.*)$/gm, '<li>$1</li>')
    .replace(/(<li>[\s\S]*?<\/li>)/g, '<ul>$1</ul>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
    .replace(/^---$/gm, '<hr/>')
    .replace(/\n/g, '<br/>');
  mdHtml.value = html;
}

async function load() {
  if (props.isImage) { loading.value = false; return; }
  loading.value = true;
  try {
    content.value = await readFileText(props.id);
    if (isMd()) renderMd();
  } catch (e: any) {
    ElMessage.error('读取失败：' + (e?.message || '服务异常'));
  } finally {
    loading.value = false;
  }
}

async function save() {
  if (saving.value) return;
  saving.value = true;
  try {
    await saveFile(props.id, content.value);
    ElMessage.success('已保存');
    if (isMd()) renderMd();
  } catch (e: any) {
    ElMessage.error('保存失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    saving.value = false;
  }
}

watch(() => props.id, () => { load(); }, { immediate: true });
</script>

<template>
  <div class="fe-page">
    <!-- 顶栏：文件名（左）+ 保存 / 关闭（右） -->
    <div class="fe-head">
      <div class="fe-name" :title="path || title">
        <span class="fe-ico">{{ isImage ? '🖼️' : isMd() ? '📝' : '📄' }}</span>
        {{ title }}
        <span v-if="path" class="fe-path">{{ path }}</span>
      </div>
      <div class="fe-actions">
        <el-button v-if="!isImage" type="primary" :loading="saving" @click="save">保存</el-button>
        <el-button @click="emit('close')">关闭</el-button>
      </div>
    </div>

    <div class="fe-body" v-loading="loading">
      <!-- 图片：整页显示，无四周留白，文件名仅在顶栏 -->
      <div v-if="isImage" class="fe-img-wrap">
        <img :src="fileUrl(id)" :alt="title" />
      </div>

      <!-- md：左右分栏（高度一致，等高 flex） -->
      <div v-else-if="isMd()" class="fe-md">
        <div class="fe-pane">
          <div class="fe-pane-title">编辑</div>
          <textarea v-model="content" class="fe-editor" spellcheck="false" placeholder="在此编辑 Markdown 内容…"></textarea>
        </div>
        <div class="fe-pane">
          <div class="fe-pane-title">预览</div>
          <div class="fe-md-render" v-html="mdHtml"></div>
        </div>
      </div>

      <!-- 其他文本：单编辑框 -->
      <div v-else class="fe-text">
        <textarea v-model="content" class="fe-editor" spellcheck="false" placeholder="在此编辑文件内容…"></textarea>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fe-page { display: flex; flex-direction: column; height: 100vh; box-sizing: border-box; background: var(--el-bg-color-page, #f5f7fa); }
.fe-head {
  display: flex; align-items: center; gap: 12px; flex: none;
  padding: 10px 16px; background: var(--el-bg-color, #fff);
  border-bottom: 1px solid var(--el-border-color, #e5e7eb);
}
.fe-name { display: flex; align-items: center; gap: 8px; font-size: 15px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); min-width: 0; }
.fe-path { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 40vw; }
.fe-actions { margin-left: auto; display: flex; gap: 8px; }
.fe-body { flex: 1; min-height: 0; display: flex; overflow: hidden; }

/* 图片：整页铺满，四周不留白 */
.fe-img-wrap { flex: 1; display: flex; align-items: center; justify-content: center; background: #000; overflow: hidden; }
.fe-img-wrap img { max-width: 100%; max-height: 100%; object-fit: contain; display: block; }

/* md 左右分栏：等高 */
.fe-md { flex: 1; display: flex; min-width: 0; }
.fe-pane { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--el-bg-color, #fff); border-right: 1px solid var(--el-border-color-lighter, #e5e7eb); }
.fe-pane:last-child { border-right: none; }
.fe-pane-title { padding: 8px 14px; font-size: 12px; color: var(--el-text-color-secondary, #6b7280); border-bottom: 1px solid var(--el-border-color-lighter, #ebeef5); flex: none; }

/* 编辑器与预览区均等高撑满（flex:1 + min-height:0） */
.fe-editor {
  flex: 1; min-height: 0; width: 100%; box-sizing: border-box; resize: none; border: none; outline: none;
  padding: 14px 16px; font-family: 'Cascadia Code', Consolas, 'Courier New', monospace;
  font-size: 13px; line-height: 1.7; color: var(--el-text-color-primary, #1f2937);
  background: var(--el-bg-color, #fff);
}
.fe-text { flex: 1; min-height: 0; display: flex; }
.fe-md-render {
  flex: 1; min-height: 0; overflow: auto; padding: 14px 18px; font-size: 14px; line-height: 1.75;
  color: var(--el-text-color-primary, #1f2937); background: var(--el-bg-color, #fff); box-sizing: border-box;
}
.fe-md-render :deep(h1) { font-size: 20px; border-bottom: 1px solid var(--el-border-color-lighter, #e5e7eb); padding-bottom: 6px; }
.fe-md-render :deep(h2) { font-size: 17px; margin-top: 20px; }
.fe-md-render :deep(h3) { font-size: 15px; }
.fe-md-render :deep(pre) { background: var(--el-fill-color-light, #f5f7fa); padding: 10px 12px; border-radius: 6px; overflow: auto; font-size: 12px; }
.fe-md-render :deep(code) { background: var(--el-fill-color-light, #f5f7fa); padding: 1px 5px; border-radius: 4px; font-size: 12px; }
.fe-md-render :deep(pre code) { background: none; padding: 0; }
.fe-md-render :deep(ul) { padding-left: 20px; }
.fe-md-render :deep(a) { color: var(--kh-brand, #409eff); }
.fe-md-render :deep(hr) { border: none; border-top: 1px solid var(--el-border-color-lighter, #e5e7eb); margin: 16px 0; }
</style>
