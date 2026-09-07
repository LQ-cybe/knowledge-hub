<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { generateReport, saveReport, getReports, type ReportItem } from './api';

const typeOptions = [
  { value: 'day', label: '📅 日报' },
  { value: 'week', label: '🗓️ 周报' },
  { value: 'month', label: '📆 月报' },
  { value: 'quarter', label: '📊 季报' },
  { value: 'year', label: '📈 年报' },
];
const typeFilter = ref('week');
const refDate = ref('');
const content = ref('');
const loading = ref(false);
const saved = ref<ReportItem[]>([]);
const period = ref<{ start: string; end: string }>({ start: '', end: '' });

/** 今天日期（YYYY-MM-DD） */
function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

async function generate() {
  loading.value = true;
  try {
    const r = await generateReport(typeFilter.value, refDate.value);
    content.value = r.content;
    period.value = { start: r.period_start, end: r.period_end };
  } catch (e) {
    ElMessage.error('生成失败：' + (e as Error).message);
  } finally {
    loading.value = false;
  }
}

function download(filename: string, text: string, mime: string) {
  const blob = new Blob([text], { type: mime + ';charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function exportMd() {
  const label = typeOptions.find(t => t.value === typeFilter.value)?.label.replace(/^\S+\s/, '') || '报表';
  download(`knowledge-hub-${label}-${today()}.md`, content.value, 'text/markdown');
}

function exportHtml() {
  const label = typeOptions.find(t => t.value === typeFilter.value)?.label.replace(/^\S+\s/, '') || '报表';
  const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const html = `<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<title>${esc(label)} ${today()}</title>
<style>body{font-family:'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;max-width:900px;margin:24px auto;padding:0 16px;color:#1f2937;line-height:1.7}h1{font-size:22px}h2{font-size:16px;border-left:4px solid #409eff;padding-left:8px;margin-top:28px}table{border-collapse:collapse;margin:8px 0}th,td{border:1px solid #e5e7eb;padding:4px 10px;font-size:13px}th{background:#f5f7fa}code{background:#f5f7fa;padding:1px 5px;border-radius:4px;font-size:12px}</style>
</head>
<body>
<pre style="white-space:pre-wrap;font-family:inherit;font-size:13px">${esc(content.value)}</pre>
</body>
</html>`;
  download(`knowledge-hub-${label}-${today()}.html`, html, 'text/html');
}

async function save() {
  if (!content.value.trim()) { ElMessage.warning('请先生成报表'); return; }
  const label = typeOptions.find(t => t.value === typeFilter.value)?.label.replace(/^\S+\s/, '') || '报表';
  const title = `${label} ${period.value.start || today()} ~ ${period.value.end || today()}`;
  try {
    const r = await saveReport(title, content.value, period.value.start, period.value.end);
    saved.value = [{ id: r.id, title: r.title, period_start: period.value.start, period_end: period.value.end, created_at: r.created_at }, ...saved.value];
    ElMessage.success(`已保存：${title}（可在浏览页/时间线查看）`);
  } catch (e) {
    ElMessage.error('保存失败：' + (e as Error).message);
  }
}

onMounted(async () => {
  try { saved.value = await getReports(); } catch { /* 忽略 */ }
});
</script>

<template>
  <div class="rp" v-loading="loading">
    <div class="rp-head">
      <div class="rp-title">📊 报表中心<small>（自动汇总数据 · 可修改 · 可导出/保存）</small></div>
      <el-select v-model="typeFilter" style="width: 130px;" @change="generate">
        <el-option v-for="o in typeOptions" :key="o.value" :value="o.value" :label="o.label" />
      </el-select>
      <el-date-picker v-model="refDate" type="date" placeholder="参考日期（默认今天）"
        value-format="YYYY-MM-DD" :clearable="true" style="width: 190px;" @change="generate" />
      <el-button type="primary" @click="generate">生成</el-button>
      <div class="rp-actions">
        <el-button size="small" :disabled="!content" @click="exportMd">导出 .md</el-button>
        <el-button size="small" :disabled="!content" @click="exportHtml">导出 .html</el-button>
        <el-button size="small" type="success" :disabled="!content" @click="save">保存到知识库</el-button>
      </div>
    </div>

    <div class="rp-main">
      <div class="rp-editor">
        <div class="rp-pane-title">报表内容（可直接编辑）</div>
        <textarea v-model="content" class="rp-text" spellcheck="false"
          placeholder="选择报表类型并点击「生成」，内容将自动汇总；可在此修改后再导出/保存。"></textarea>
      </div>
      <div class="rp-side">
        <div class="rp-pane-title">已保存报表（{{ saved.length }}）</div>
        <div v-if="saved.length === 0" class="rp-none">暂无已保存报表</div>
        <div v-for="s in saved" :key="s.id" class="rp-item" :title="s.created_at">
          <div class="rp-item-title">{{ s.title }}</div>
          <div class="rp-item-time">{{ s.created_at }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.rp { padding: 12px 20px; height: 100%; box-sizing: border-box; display: flex; flex-direction: column; gap: 10px; }
.rp-head {
  display: flex; align-items: center; gap: 10px; flex: none; flex-wrap: wrap;
  padding: 10px 12px; background: var(--el-bg-color, #fff);
  border: 1px solid var(--el-border-color-lighter, #ebeef5); border-radius: 8px;
}
.rp-title { font-size: 15px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); margin-right: 6px; }
.rp-title small { font-size: 12px; font-weight: 400; color: var(--el-text-color-secondary, #9ca3af); margin-left: 6px; }
.rp-actions { margin-left: auto; display: flex; gap: 4px; }
.rp-main { flex: 1; min-height: 0; display: flex; gap: 12px; }
.rp-editor { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color-lighter, #ebeef5); border-radius: 8px; overflow: hidden; }
.rp-pane-title { padding: 8px 12px; font-size: 12px; color: var(--el-text-color-secondary, #6b7280); border-bottom: 1px solid var(--el-border-color-lighter, #ebeef5); flex: none; }
.rp-text {
  flex: 1; min-height: 0; width: 100%; box-sizing: border-box; resize: none; border: none; outline: none;
  padding: 12px 14px; font-family: 'Cascadia Code', Consolas, 'Courier New', monospace;
  font-size: 13px; line-height: 1.7; color: var(--el-text-color-primary, #1f2937);
  background: var(--el-bg-color, #fff);
}
.rp-side { width: 300px; flex: none; display: flex; flex-direction: column; background: var(--el-bg-color, #fff); border: 1px solid var(--el-border-color-lighter, #ebeef5); border-radius: 8px; overflow: hidden; }
.rp-none { padding: 24px 12px; text-align: center; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.rp-item { padding: 8px 12px; border-bottom: 1px solid var(--el-border-color-lighter, #f0f2f5); cursor: pointer; }
.rp-item:hover { background: var(--el-fill-color-light, #f5f7fa); }
.rp-item-title { font-size: 13px; color: var(--el-text-color-primary, #1f2937); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rp-item-time { font-size: 11px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 2px; }
</style>
