<script setup lang="ts">
// 独立文件编辑器页（替代早期弹窗）：整个页面切换进入，顶栏含文件名 + 保存/关闭
// mode='file' 读写磁盘文本文件；mode='note' 读写数据库笔记（resources.content）
import { ref, watch } from 'vue';
import { ElMessage } from 'element-plus';
import { fileUrl, readFileText, saveFile, getResource, updateResource } from './api';

const props = defineProps<{
  id: string;
  title: string;
  ext: string;
  path?: string;
  isImage?: boolean;
  mode?: 'file' | 'note';
}>();

const emit = defineEmits<{ (e: 'close'): void }>();

const content = ref('');
const mdHtml = ref('');
const loading = ref(true);
const saving = ref(false);
/** 编辑框 ref（工具栏/快捷键需要操作光标选区） */
const editor = ref<HTMLTextAreaElement | null>(null);
/** MD 视图模式：edit=仅编辑 / split=分屏 / preview=仅预览 */
const mdMode = ref<'edit' | 'split' | 'preview'>('split');

/** 是否为 md（左右分栏 + 工具栏）；纯文本笔记（txt）走单编辑框 */
const isMd = () => props.ext === 'md';

/** 笔记标题（编辑模式可改名，仅 mode==='note' 生效） */
const savedTitle = ref(props.title);
const titleEdit = ref(props.title);
watch(() => props.title, v => { savedTitle.value = v; titleEdit.value = v; });
async function renameNote() {
  const t = (titleEdit.value || '').trim();
  if (!t) { titleEdit.value = savedTitle.value; return; }
  if (t === savedTitle.value) return;
  const old = savedTitle.value;
  savedTitle.value = t; // 乐观更新
  try {
    await updateResource(props.id, { title: t });
    ElMessage.success('已重命名笔记');
  } catch (e: any) {
    savedTitle.value = old; titleEdit.value = old;
    ElMessage.error('重命名失败：' + (e?.message || '服务异常'));
  }
}

/** 分屏模式：编辑器↔预览 滚动同步 + 可拖动分隔条调节左右宽度 */
const previewEl = ref<HTMLElement | null>(null);
const bodyEl = ref<HTMLElement | null>(null);
const splitRatio = ref(50); // 编辑器占宽百分比（20~80）
let dragging = false;
function startDrag() {
  dragging = true;
  const prevCursor = document.body.style.cursor;
  const prevSelect = document.body.style.userSelect;
  document.body.style.cursor = 'col-resize';
  document.body.style.userSelect = 'none';
  const move = (ev: MouseEvent) => {
    if (!dragging || !bodyEl.value) return;
    const r = bodyEl.value.getBoundingClientRect();
    let pct = ((ev.clientX - r.left) / r.width) * 100;
    pct = Math.max(20, Math.min(80, pct));
    splitRatio.value = pct;
  };
  const up = () => {
    dragging = false;
    document.body.style.cursor = prevCursor;
    document.body.style.userSelect = prevSelect;
    window.removeEventListener('mousemove', move);
    window.removeEventListener('mouseup', up);
  };
  window.addEventListener('mousemove', move);
  window.addEventListener('mouseup', up);
}
let syncing = false;
/** 编辑器滚动 → 预览按相同比例跟随 */
function onEditorScroll() {
  if (syncing || !previewEl.value || !editor.value) return;
  const ta = editor.value;
  const max = ta.scrollHeight - ta.clientHeight;
  const pmax = previewEl.value.scrollHeight - previewEl.value.clientHeight;
  if (max <= 0 || pmax <= 0) return;
  syncing = true;
  previewEl.value.scrollTop = (ta.scrollTop / max) * pmax;
  requestAnimationFrame(() => { syncing = false; });
}
/** 预览滚动 → 编辑器按相同比例跟随（双向同步，syncing 标志防止回环） */
function onPreviewScroll() {
  if (syncing || !previewEl.value || !editor.value) return;
  const ta = editor.value;
  const max = ta.scrollHeight - ta.clientHeight;
  const pmax = previewEl.value.scrollHeight - previewEl.value.clientHeight;
  if (max <= 0 || pmax <= 0) return;
  syncing = true;
  ta.scrollTop = (previewEl.value.scrollTop / pmax) * max;
  requestAnimationFrame(() => { syncing = false; });
}

/** 极简 MD 渲染：标题/列表/代码块/行内代码/链接/粗体/分割线。
 *  逐行渲染：空行不输出（消除"很多空行"）；连续普通行合为段落（行内用 <br/>）；
 *  列表项合并为一个 <ul>；块级元素之间不加 <br/>。 */
function renderMd() {
  const src = content.value || '';
  const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const inline = (s: string) => esc(s)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
  const lines = src.split('\n');
  const out: string[] = [];
  let i = 0;
  while (i < lines.length) {
    const t = lines[i].trim();
    if (!t) { i++; continue; } // 空行：不输出
    if (t.startsWith('```')) { // 代码块
      const buf: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) { buf.push(lines[i]); i++; }
      i++;
      out.push(`<pre><code>${esc(buf.join('\n'))}</code></pre>`);
      continue;
    }
    const h = t.match(/^(#{1,3})\s+(.*)$/); // 标题
    if (h) { out.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`); i++; continue; }
    if (t === '---') { out.push('<hr/>'); i++; continue; }
    // 表格：| a | b | 行 + 可选 |---|---| 分隔行（第二行）→ 渲染为 HTML 表格
    if (t.startsWith('|') && t.endsWith('|')) {
      const isSep = (s: string) => /^[\s|:-]+$/.test(s) && s.includes('-');
      const rows: string[][] = [];
      while (i < lines.length) {
        const l = lines[i].trim();
        if (!(l.startsWith('|') && l.endsWith('|'))) break;
        // 单元格按 | 切分，忽略转义 \|（简单场景够用）
        const cells = l.slice(1, -1).split(/(?<!\\)\|/).map(c => inline(c.trim().replace(/\\\|/g, '|')));
        rows.push(cells);
        i++;
      }
      if (rows.length >= 2 && isSep(rows[1].join(''))) {
        rows.splice(1, 1); // 去掉分隔行
        const [head, ...body] = rows;
        out.push(
          '<table><thead><tr>' + head.map(c => `<th>${c}</th>`).join('') + '</tr></thead><tbody>' +
          body.map(r => '<tr>' + r.map(c => `<td>${c}</td>`).join('') + '</tr>').join('') +
          '</tbody></table>'
        );
      } else {
        // 不是标准表格结构（缺分隔行）→ 按普通段落输出
        out.push(`<p>${rows.map(r => r.join(' | ')).join('<br/>')}</p>`);
      }
      continue;
    }
    if (t.startsWith('- ')) { // 列表（连续项合并一个 ul）
      const items: string[] = [];
      while (i < lines.length && lines[i].trim().startsWith('- ')) { items.push(inline(lines[i].trim().slice(2))); i++; }
      out.push(`<ul>${items.map(x => `<li>${x}</li>`).join('')}</ul>`);
      continue;
    }
    // 普通段落：连续普通行合并，行内换行用 <br/>
    const buf: string[] = [];
    while (i < lines.length) {
      const l = lines[i].trim();
      if (!l || /^(#{1,3})\s/.test(l) || l.startsWith('- ') || l.startsWith('```') || l === '---' || (l.startsWith('|') && l.endsWith('|'))) break;
      buf.push(inline(lines[i]));
      i++;
    }
    out.push(`<p>${buf.join('<br/>')}</p>`);
  }
  mdHtml.value = out.join('\n');
}

async function load() {
  if (props.isImage) { loading.value = false; return; }
  loading.value = true;
  try {
    if (props.mode === 'note') {
      const d = await getResource(props.id);
      content.value = d.content || '';
    } else {
      content.value = await readFileText(props.id);
    }
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
    if (props.mode === 'note') {
      await updateResource(props.id, { content: content.value });
    } else {
      await saveFile(props.id, content.value);
    }
    ElMessage.success('已保存');
    if (isMd()) renderMd();
  } catch (e: any) {
    ElMessage.error('保存失败：' + (e?.response?.data?.msg || e?.message || '服务异常'));
  } finally {
    saving.value = false;
  }
}

/** 在光标处用 before/after 包裹选区（选区为空时插入占位文本并选中占位） */
function surround(before: string, after: string, placeholder: string) {
  const ta = editor.value;
  if (!ta) return;
  const s = ta.selectionStart, e = ta.selectionEnd;
  const sel = content.value.slice(s, e) || placeholder;
  const newVal = content.value.slice(0, s) + before + sel + after + content.value.slice(e);
  const ns = s + before.length;
  const ne = ns + sel.length;
  // DOM-first：先直接改 textarea 的值与选区，再同步模型。
  // 若先改 content.value（v-model 绑定），Vue 重渲染会把光标重置到末尾 —— 这正是"光标跳到文档末尾"的根因。
  ta.value = newVal;
  ta.setSelectionRange(ns, ne);
  content.value = newVal; // 此刻 el.value 已等于新值，patch 不会重设光标
  ta.focus();
  if (isMd()) renderMd();
}
/** 在当前行的行首添加前缀（标题/引用/列表/任务） */
function prefixLines(prefix: string, placeholder: string) {
  const ta = editor.value;
  if (!ta) return;
  const val = content.value;
  const s = ta.selectionStart, e = ta.selectionEnd;
  const lineStart = val.lastIndexOf('\n', s - 1) + 1;
  const seg = val.slice(lineStart, e);
  const newSeg = seg.split('\n').map(l => (l.startsWith(prefix) ? l : prefix + l)).join('\n') || prefix + placeholder;
  const newVal = val.slice(0, lineStart) + newSeg + val.slice(e);
  const ns = lineStart;
  const ne = lineStart + newSeg.length;
  ta.value = newVal;
  ta.setSelectionRange(ns, ne);
  content.value = newVal;
  ta.focus();
  if (isMd()) renderMd();
}
/** 在光标处插入整块内容（代码块/表格/分割线） */
function insertBlock(text: string) {
  const ta = editor.value;
  if (!ta) return;
  const s = ta.selectionStart, e = ta.selectionEnd;
  const pad = s > 0 && content.value[s - 1] !== '\n' ? '\n' : '';
  const ins = pad + text;
  const newVal = content.value.slice(0, s) + ins + content.value.slice(e);
  const ns = s + ins.length;
  ta.value = newVal;
  ta.setSelectionRange(ns, ns);
  content.value = newVal;
  ta.focus();
  if (isMd()) renderMd();
}
const TABLE_TPL = '| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n| 单元格 | 单元格 | 单元格 |\n| 单元格 | 单元格 | 单元格 |\n';
const CODE_TPL = '```\n代码\n```\n';
/** MD 工具栏按钮 */
const mdTools: { k: string; label: string; t: string; fn: () => void }[] = [
  { k: 'h1', label: 'H1', t: '一级标题', fn: () => prefixLines('# ', '标题') },
  { k: 'h2', label: 'H2', t: '二级标题', fn: () => prefixLines('## ', '标题') },
  { k: 'h3', label: 'H3', t: '三级标题', fn: () => prefixLines('### ', '标题') },
  { k: 'b', label: 'B', t: '加粗 (Ctrl/⌘+B)', fn: () => surround('**', '**', '加粗文本') },
  { k: 'i', label: 'I', t: '斜体 (Ctrl/⌘+I)', fn: () => surround('*', '*', '斜体文本') },
  { k: 's', label: 'S', t: '删除线', fn: () => surround('~~', '~~', '删除文本') },
  { k: 'code', label: '</>', t: '行内代码', fn: () => surround('`', '`', '代码') },
  { k: 'cb', label: '代码块', t: '代码块', fn: () => insertBlock(CODE_TPL) },
  { k: 'quote', label: '❝', t: '引用', fn: () => prefixLines('> ', '引用内容') },
  { k: 'ul', label: '• 列表', t: '无序列表', fn: () => prefixLines('- ', '列表项') },
  { k: 'ol', label: '1. 列表', t: '有序列表', fn: () => prefixLines('1. ', '列表项') },
  { k: 'task', label: '☑ 任务', t: '任务列表', fn: () => prefixLines('- [ ] ', '任务项') },
  { k: 'link', label: '🔗', t: '链接 (Ctrl/⌘+K)', fn: () => surround('[', '](https://)', '链接文字') },
  { k: 'img', label: '🖼', t: '图片', fn: () => surround('![', '](https://)', '图片描述') },
  { k: 'table', label: '▦', t: '表格', fn: () => insertBlock(TABLE_TPL) },
  { k: 'hr', label: '―', t: '分割线', fn: () => insertBlock('---\n') },
];
/** 快捷键：Ctrl/⌘+B 加粗 / +I 斜体 / +K 链接 */
function onKeydown(e: KeyboardEvent) {
  if (!(e.ctrlKey || e.metaKey)) return;
  const k = e.key.toLowerCase();
  if (k === 'b') { e.preventDefault(); surround('**', '**', '加粗文本'); }
  else if (k === 'i') { e.preventDefault(); surround('*', '*', '斜体文本'); }
  else if (k === 'k') { e.preventDefault(); surround('[', '](https://)', '链接文字'); }
}

watch(content, () => { if (isMd()) renderMd(); }, { flush: 'post' });
watch(() => props.id, () => { load(); }, { immediate: true });
</script>

<template>
  <div class="fe-page">
    <!-- 顶栏：文件名（左）+ 保存 / 关闭（右） -->
    <div class="fe-head">
      <div class="fe-name" :title="path || title">
        <span class="fe-ico">{{ isImage ? '🖼️' : isMd() ? '📝' : '📄' }}</span>
        <input v-if="mode === 'note'" v-model="titleEdit" class="fe-title-input" :placeholder="title" title="可在此修改笔记名称，回车或失焦保存" @change="renameNote" @keydown.stop />
        <span v-else class="fe-title-text">{{ title }}</span>
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

      <!-- md：工具栏 + 模式切换（编辑/分屏/预览） + 实时预览 -->
      <div v-else-if="isMd()" class="fe-md">
        <div class="fe-md-bar">
          <div class="fe-md-tools">
            <button v-for="t in mdTools" :key="t.k" class="fe-tool" :title="t.t" @click="t.fn" v-html="t.label"></button>
          </div>
          <el-radio-group v-model="mdMode">
            <el-radio-button value="edit">编辑</el-radio-button>
            <el-radio-button value="split">分屏</el-radio-button>
            <el-radio-button value="preview">预览</el-radio-button>
          </el-radio-group>
        </div>
        <div class="fe-md-body" :class="mdMode" ref="bodyEl">
          <div v-show="mdMode !== 'preview'" class="fe-pane fe-pane-edit" :style="mdMode === 'edit' ? 'flex:1 1 0; min-width:0;' : ('flex:0 0 ' + splitRatio + '%; min-width:0;')">
            <textarea ref="editor" v-model="content" class="fe-editor" @keydown="onKeydown" @scroll="onEditorScroll" spellcheck="false" placeholder="在此编辑 Markdown 内容…"></textarea>
          </div>
          <div v-if="mdMode === 'split'" class="fe-splitter" @mousedown.prevent="startDrag" title="拖动调整左右宽度"></div>
          <div v-show="mdMode !== 'edit'" class="fe-pane fe-preview" style="flex:1 1 0; min-width:0;">
            <div class="fe-md-render" ref="previewEl" v-html="mdHtml" @scroll="onPreviewScroll"></div>
          </div>
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
.fe-title-text { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.fe-title-input {
  font-size: 15px; font-weight: 600; color: var(--el-text-color-primary, #1f2937);
  border: 1px solid transparent; border-radius: 6px; padding: 2px 8px; min-width: 120px; width: 40vw; max-width: 40vw;
  background: transparent; outline: none; box-sizing: border-box;
}
.fe-title-input:hover { border-color: var(--el-border-color, #e5e7eb); }
.fe-title-input:focus { border-color: var(--kh-brand, #409eff); background: var(--el-bg-color, #fff); }
.fe-path { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 40vw; }
.fe-actions { margin-left: auto; display: flex; gap: 8px; }
.fe-body { flex: 1; min-height: 0; display: flex; overflow: hidden; }

/* 图片：整页铺满，四周不留白 */
.fe-img-wrap { flex: 1; display: flex; align-items: center; justify-content: center; background: #000; overflow: hidden; }
.fe-img-wrap img { max-width: 100%; max-height: 100%; object-fit: contain; display: block; }

/* md 左右分栏：等高 */
.fe-md { flex: 1; display: flex; flex-direction: column; min-width: 0; }
.fe-md-bar { display: flex; align-items: center; gap: 10px; padding: 6px 12px; background: var(--el-bg-color, #fff); border-bottom: 1px solid var(--el-border-color-lighter, #e5e7eb); flex: none; flex-wrap: wrap; }
/* 编辑/分屏/预览 切换按钮：高度对齐工具与保存/关闭按钮（均 32px），整体统一 */
.fe-md-bar :deep(.el-radio-button__inner) { height: 32px; line-height: 30px; padding: 0 14px; box-sizing: border-box; }
.fe-md-tools { display: flex; flex-wrap: wrap; gap: 4px; }
/* 工具按钮高度对齐顶栏默认尺寸 el-button（约 32px），统一按钮风格 */
.fe-tool {
  min-width: 32px; height: 32px; padding: 0 10px; border: 1px solid var(--el-border-color, #e5e7eb); border-radius: 6px;
  background: var(--el-bg-color, #fff); color: var(--el-text-color-primary, #1f2937); cursor: pointer;
  font-size: 12px; line-height: 1; display: inline-flex; align-items: center; justify-content: center; box-sizing: border-box;
}
.fe-tool:hover { border-color: var(--kh-brand, #409eff); color: var(--kh-brand, #409eff); }
.fe-md-body { flex: 1; min-height: 0; display: flex; }
.fe-md-body.preview .fe-pane { border-right: none; }
.fe-splitter {
  flex: none; width: 14px; margin: 0 -6px; cursor: col-resize; position: relative; z-index: 2;
}
/* 可见分隔线仅 2px 宽，居中对齐；两侧透明区域仍可拖动 */
.fe-splitter::before {
  content: ''; position: absolute; left: 50%; top: 0; bottom: 0; transform: translateX(-50%);
  width: 2px; background: var(--el-border-color, #dcdfe6); transition: background .15s;
}
.fe-splitter:hover::before, .fe-splitter:active::before { background: var(--kh-brand, #409eff); }
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
.fe-md-render :deep(h1) { font-size: 20px; border-bottom: 1px solid var(--el-border-color-lighter, #e5e7eb); padding-bottom: 6px; margin: 2px 0 8px; }
.fe-md-render :deep(h2) { font-size: 17px; margin: 14px 0 6px; }
.fe-md-render :deep(h3) { font-size: 15px; margin: 10px 0 4px; }
.fe-md-render :deep(p) { margin: 6px 0; }
.fe-md-render :deep(li) { line-height: 1.55; margin: 2px 0; }
.fe-md-render :deep(pre) { background: var(--el-fill-color-light, #f5f7fa); padding: 10px 12px; border-radius: 6px; overflow: auto; font-size: 12px; margin: 8px 0; }
.fe-md-render :deep(code) { background: var(--el-fill-color-light, #f5f7fa); padding: 1px 5px; border-radius: 4px; font-size: 12px; }
.fe-md-render :deep(pre code) { background: none; padding: 0; }
.fe-md-render :deep(ul) { padding-left: 20px; }
.fe-md-render :deep(table) { border-collapse: collapse; margin: 8px 0; font-size: 13px; }
.fe-md-render :deep(th), .fe-md-render :deep(td) { border: 1px solid var(--el-border-color, #dcdfe6); padding: 5px 10px; text-align: left; }
.fe-md-render :deep(th) { background: var(--el-fill-color-light, #f5f7fa); font-weight: 600; }
.fe-md-render :deep(a) { color: var(--kh-brand, #409eff); }
.fe-md-render :deep(hr) { border: none; border-top: 1px solid var(--el-border-color-lighter, #e5e7eb); margin: 16px 0; }
</style>
