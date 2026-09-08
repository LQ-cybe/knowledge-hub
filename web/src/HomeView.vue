<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, nextTick } from 'vue';
import * as echarts from 'echarts';
import { getDashboard, getRecycleInfo, type DashboardData, type RecycleInfo } from './api';

const emit = defineEmits<{ (e: 'open-folder', id: string): void; (e: 'open-tag', id: string): void }>();

const dash = ref<DashboardData | null>(null);
const loading = ref(true);
const recycle = ref<RecycleInfo>({ count: 0, clear_at: null, days: 30 });

const typeIcons: Record<string, string> = {
  folder: '📂', file: '📄', note: '📝', bookmark: '🔖', todo: '✅', report: '📊',
};
const typeLabels: Record<string, string> = {
  folder: '文件夹', file: '文件', note: '笔记', bookmark: '书签', todo: '待办', report: '报表',
};

const barEl = ref<HTMLElement | null>(null);
const pieEl = ref<HTMLElement | null>(null);
let barChart: echarts.ECharts | null = null;
let pieChart: echarts.ECharts | null = null;

function isDark() { return document.documentElement.classList.contains('dark'); }
function textColor() { return isDark() ? '#c9d1d9' : '#4b5563'; }
function gridColor() { return isDark() ? 'rgba(255,255,255,0.1)' : '#e5e7eb'; }
function tooltipBg() { return isDark() ? 'rgba(22,27,34,0.95)' : 'rgba(255,255,255,0.95)'; }
function tooltipText() { return isDark() ? '#c9d1d9' : '#333'; }

function fmtBytes(b: number) {
  if (b >= 1 << 30) return (b / (1 << 30)).toFixed(1) + ' GB';
  if (b >= 1 << 20) return (b / (1 << 20)).toFixed(1) + ' MB';
  if (b >= 1 << 10) return (b / (1 << 10)).toFixed(1) + ' KB';
  return b + ' B';
}

function renderCharts() {
  if (!dash.value) return;
  const d = dash.value;
  // 顶层目录柱状图（文件数）
  if (barEl.value) {
    if (!barChart) barChart = echarts.init(barEl.value);
    barChart.setOption({
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'axis', confine: true,
        backgroundColor: tooltipBg(), textStyle: { color: tooltipText(), fontSize: 12 },
        formatter: (ps: unknown) => {
          const p = (ps as { name: string; value: number }[])[0];
          const t = d.topFolders.find(x => x.title === p.name);
          if (!t) return p.name + '<br/>' + p.value + ' 个文件';
          return `${p.name}<br/>文件 ${t.files} · 子目录 ${t.subFolders}<br/>占用 ${fmtBytes(t.bytes)}`;
        },
      },
      grid: { left: 10, right: 10, top: 20, bottom: 8, containLabel: true },
      xAxis: {
        type: 'category', data: d.topFolders.map(x => x.title),
        axisLabel: { color: textColor(), fontSize: 12 },
        axisLine: { lineStyle: { color: gridColor() } },
        axisTick: { show: false },
      },
      yAxis: {
        type: 'value', minInterval: 1,
        axisLabel: { color: textColor(), fontSize: 11 },
        splitLine: { lineStyle: { color: gridColor() } },
      },
      series: [{
        type: 'bar', barWidth: '46%',
        data: d.topFolders.map(x => x.files),
        itemStyle: { color: '#409EFF', borderRadius: [6, 6, 0, 0] },
        label: { show: true, position: 'top', fontSize: 11, color: textColor() },
      }],
    });
  }
  // 类型分布饼图
  if (pieEl.value) {
    if (!pieChart) pieChart = echarts.init(pieEl.value);
    pieChart.setOption({
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'item', confine: true,
        backgroundColor: tooltipBg(), textStyle: { color: tooltipText(), fontSize: 12 },
        formatter: (p: unknown) => {
          const it = p as { name: string; value: number; percent: number };
          return `${it.name}：${it.value}（${it.percent}%）`;
        },
      },
      legend: {
        bottom: 0,
        textStyle: { color: textColor(), fontSize: 12 },
        icon: 'circle', itemWidth: 8, itemHeight: 8,
      },
      color: ['#409EFF', '#67C23A', '#E6A23C', '#F56C6C', '#909399', '#8BC8EA', '#B37FEB'],
      series: [{
        type: 'pie', radius: ['42%', '68%'], center: ['50%', '44%'],
        label: { color: textColor(), fontSize: 12, formatter: '{b} {c}' },
        labelLine: { lineStyle: { color: gridColor() } },
        itemStyle: { borderColor: isDark() ? '#161b22' : '#fff', borderWidth: 2 },
        data: d.byType.filter(t => t.n > 0).map(t => ({ name: typeLabels[t.type] || t.type, value: t.n })),
      }],
    });
  }
}

function onThemeChange() {
  barChart?.dispose(); barChart = null;
  pieChart?.dispose(); pieChart = null;
  nextTick(renderCharts);
}

function onResize() {
  barChart?.resize();
  pieChart?.resize();
}

let ro: ResizeObserver | null = null;

onMounted(async () => {
  dash.value = await getDashboard();
  loading.value = false;
  await nextTick();
  renderCharts();
  // 切到本 Tab 时容器从 display:none 变为可见，必须观察尺寸变化才能让图表铺满
  if (typeof ResizeObserver !== 'undefined' && barEl.value && pieEl.value) {
    ro = new ResizeObserver(() => { barChart?.resize(); pieChart?.resize(); });
    ro.observe(barEl.value);
    ro.observe(pieEl.value);
  }
  window.addEventListener('resize', onResize);
  window.addEventListener('kh-theme-change', onThemeChange);
  getRecycleInfo().then(r => recycle.value = r).catch(() => {});
});
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize);
  window.removeEventListener('kh-theme-change', onThemeChange);
  ro?.disconnect();
  barChart?.dispose(); barChart = null;
  pieChart?.dispose(); pieChart = null;
});

function fmtTime(s: string) {
  if (!s) return '';
  const d = new Date(s.replace(' ', 'T'));
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}
</script>

<template>
  <div class="home" v-loading="loading">
    <!-- 统计卡片 -->
    <div class="cards">
      <div class="card">
        <div class="card-num">{{ dash?.total ?? 0 }}</div>
        <div class="card-label">资源总数</div>
      </div>
      <div class="card">
        <div class="card-num">{{ dash?.topFolders.reduce((a, f) => a + f.files, 0) ?? 0 }}</div>
        <div class="card-label">文件总数</div>
      </div>
      <div class="card">
        <div class="card-num">{{ dash?.topFolders.reduce((a, f) => a + f.subFolders, 0) ?? 0 }}</div>
        <div class="card-label">文件夹总数</div>
      </div>
      <div class="card">
        <div class="card-num">{{ dash?.tagCount ?? 0 }}</div>
        <div class="card-label">标签数</div>
      </div>
    </div>

    <!-- 回收站清理信息：全局删除约定——删除先移入回收站，超期自动清理 -->
    <div class="recycle-banner" v-if="recycle.count > 0">
      🗑 回收站现有 <b>{{ recycle.count }}</b> 项内容，将在 {{ fmtTime(recycle.clear_at || '') }} 前自动清理（保留 {{ recycle.days }} 天）。
      可在导图库「回收站」中恢复或彻底删除。
    </div>

    <div class="cols">
      <!-- 顶层目录 -->
      <section class="panel">
        <div class="panel-title">📁 顶层目录（点击进入）</div>
        <div ref="barEl" class="chart" style="height: 260px;"></div>
      </section>
      <!-- 类型分布 -->
      <section class="panel">
        <div class="panel-title">🧩 资源类型分布</div>
        <div ref="pieEl" class="chart" style="height: 260px;"></div>
      </section>
    </div>

    <div class="cols">
      <!-- 快捷入口 -->
      <section class="panel">
        <div class="panel-title">🚀 快捷入口</div>
        <div class="quick-grid">
          <button v-for="f in dash?.topFolders ?? []" :key="f.id" class="quick" @click="emit('open-folder', f.id)">
            <div class="quick-name">{{ f.title }}</div>
            <div class="quick-meta">{{ f.files }} 文件 · {{ f.subFolders }} 目录 · {{ fmtBytes(f.bytes) }}</div>
          </button>
        </div>
      </section>
      <!-- 最近更新 -->
      <section class="panel">
        <div class="panel-title">🕐 最近更新</div>
        <div class="recent">
          <div v-for="r in dash?.recent ?? []" :key="r.id" class="recent-row">
            <span class="recent-icon">{{ typeIcons[r.type] || '📄' }}</span>
            <span class="recent-title" :title="r.path">{{ r.title }}</span>
            <span class="recent-time">{{ fmtTime(r.updated_at) }}</span>
          </div>
          <div v-if="!(dash?.recent?.length)" class="empty">暂无文件</div>
        </div>
      </section>
    </div>

    <div class="cols">
      <!-- 常用标签 -->
      <section class="panel">
        <div class="panel-title">🏷️ 常用标签（点击按标签浏览）</div>
        <div class="tag-cloud">
          <button
            v-for="t in dash?.topTags ?? []" :key="t.id"
            class="tag-item" @click="emit('open-tag', t.id)"
          >
            <span class="tag-dot" :style="{ background: t.color || '#409EFF' }"></span>
            <span class="tag-name">{{ t.name }}</span>
            <span class="tag-n">{{ t.n }}</span>
          </button>
          <div v-if="!(dash?.topTags?.length)" class="empty">暂无标签，到浏览页给资源打标后这里会出现</div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.home { padding: 8px 20px 20px; display: flex; flex-direction: column; gap: 14px; }

.cards { display: flex; gap: 12px; flex-wrap: wrap; }
.recycle-banner { margin-top: 12px; font-size: 13px; color: var(--el-text-color-regular, #4b5563); background: rgba(230, 162, 60, .1); border: 1px solid rgba(230, 162, 60, .3); border-radius: 10px; padding: 10px 14px; line-height: 1.6; }
.recycle-banner b { color: #e6a23c; }
.card {
  flex: 1 1 160px; min-width: 0; padding: 14px 18px;
  background: var(--el-bg-color, #fff);
  border: 1px solid var(--el-border-color, #e5e7eb);
  border-radius: 10px; box-sizing: border-box;
}
.card-num { font-size: 24px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); line-height: 1.2; }
.card-label { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 4px; }

.cols { display: flex; gap: 14px; flex-wrap: wrap; }
.panel {
  flex: 1 1 0; min-width: 0; padding: 14px 16px;
  background: var(--el-bg-color, #fff);
  border: 1px solid var(--el-border-color, #e5e7eb);
  border-radius: 10px; box-sizing: border-box;
}
.panel-title { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); margin-bottom: 10px; }
.chart { width: 100%; min-width: 0; }

.quick-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 10px; }
.quick {
  text-align: left; padding: 12px 14px; cursor: pointer;
  background: var(--el-fill-color-light, #f5f7fa);
  border: 1px solid var(--el-border-color-lighter, #ebeef5);
  border-radius: 8px; box-sizing: border-box;
  transition: border-color .15s, transform .15s;
  font-family: inherit;
}
.quick:hover { border-color: var(--el-color-primary, #409eff); transform: translateY(-1px); }
.quick-name { font-size: 14px; font-weight: 600; color: var(--el-text-color-primary, #1f2937); }
.quick-meta { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); margin-top: 4px; }

.recent { display: flex; flex-direction: column; max-height: 230px; overflow-y: auto; }
.recent-row {
  display: flex; align-items: center; gap: 10px; padding: 7px 4px;
  border-bottom: 1px dashed var(--el-border-color-lighter, #ebeef5);
}
.recent-icon { font-size: 14px; flex: none; }
.recent-title {
  flex: 1; min-width: 0; font-size: 13px; color: var(--el-text-color-primary, #1f2937);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.recent-time { flex: none; font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
.empty { color: var(--el-text-color-secondary, #9ca3af); text-align: center; padding: 30px 0; font-size: 13px; }

.tag-cloud { display: flex; flex-wrap: wrap; gap: 8px; }
.tag-item {
  display: inline-flex; align-items: center; gap: 7px;
  padding: 7px 12px; cursor: pointer; font-family: inherit;
  background: var(--el-fill-color-light, #f5f7fa);
  border: 1px solid var(--el-border-color-lighter, #ebeef5);
  border-radius: 16px; box-sizing: border-box;
  transition: border-color .15s, transform .15s;
}
.tag-item:hover { border-color: var(--el-color-primary, #409eff); transform: translateY(-1px); }
.tag-dot { width: 9px; height: 9px; border-radius: 50%; flex: none; }
.tag-name { font-size: 13px; color: var(--el-text-color-primary, #1f2937); }
.tag-n { font-size: 12px; color: var(--el-text-color-secondary, #9ca3af); }
</style>
