<template>
  <div class="mm-view">
    <!-- ============ 导图库 ============ -->
    <div v-if="view === 'library'" class="mm-library">
      <div class="ml-head">
        <h3>📐 思维导图库</h3>
        <div class="ml-head-right">
          <el-button size="small" text :class="{ 'recycle-on': showRecycle }" title="回收站：删除的导图将保留 30 天，超期自动清理" @click="toggleRecycle">
            🗑 回收站<template v-if="recycleInfo.count">（{{ recycleInfo.count }}）</template>
          </el-button>
          <div class="ml-views">
            <el-button size="small" text :class="{ 'view-on': libView === 'grid' }" title="卡片视图" @click="libView = 'grid'">▦ 卡片</el-button>
            <el-button size="small" text :class="{ 'view-on': libView === 'list' }" title="列表视图" @click="libView = 'list'">☰ 列表</el-button>
          </div>
          <el-dropdown trigger="click" @command="onNewMapCmd">
            <el-button type="primary" size="small">＋ 新建 ▾</el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="new">新建导图</el-dropdown-item>
                <el-dropdown-item command="import">导入导图…</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>

      <!-- 回收站列表 -->
      <template v-if="showRecycle">
        <div class="ml-recycle-tip" v-if="recycleInfo.count">回收站中的导图将在 {{ recycleInfo.clear_at ? fmtTime(recycleInfo.clear_at) : '—' }} 前自动清理（保留 {{ recycleInfo.days }} 天），可手动恢复或彻底删除。</div>
        <div class="ml-recycle-list" v-if="recycleMaps.length">
          <div v-for="m in recycleMaps" :key="m.id" class="ml-row">
            <span class="ml-row-title">{{ m.title }}</span>
            <span class="ml-row-meta">删除于 {{ fmtTime(m.deleted_at) }} · {{ m.node_count }} 节点</span>
            <span class="ml-row-ops">
              <el-button size="small" text type="primary" @click="restoreMap(m.id)">恢复</el-button>
              <el-button size="small" text type="danger" @click="purgeMap(m.id)">彻底删除</el-button>
            </span>
          </div>
        </div>
        <div v-else class="ml-empty">回收站是空的</div>
      </template>

      <!-- 卡片视图 -->
      <template v-else-if="libView === 'grid'">
        <div class="ml-grid">
          <div v-for="m in maps" :key="m.id" class="ml-card" @click="openMap(m.id)" @contextmenu.prevent="showCtxMenu($event, m)">
            <div class="ml-card-pin" v-if="m.pinned">📌</div>
            <div class="ml-title">{{ m.title }}</div>
            <div class="ml-meta">{{ m.node_count }} 节点 · {{ fmtTime(m.updated_at) }}</div>
            <div class="ml-tags" v-if="m.tags">{{ m.tags }}</div>
            <div class="ml-del" @click.stop="delMap(m.id)">✕</div>
          </div>
        </div>
        <div v-if="!maps.length" class="ml-empty">暂无导图，点击右上角「＋ 新建导图」开始</div>
      </template>

      <!-- 列表视图 -->
      <template v-else>
        <div class="ml-list">
          <div v-for="m in maps" :key="m.id" class="ml-row" @click="openMap(m.id)" @contextmenu.prevent="showCtxMenu($event, m)">
            <span class="ml-row-pin">{{ m.pinned ? '📌' : '' }}</span>
            <span class="ml-row-ico" v-html="MAP_ICON"></span>
            <span class="ml-row-title">{{ m.title }}</span>
            <span class="ml-row-tags" v-if="m.tags">{{ m.tags }}</span>
            <span class="ml-row-meta">{{ m.node_count }} 节点 · {{ fmtTime(m.updated_at) }}</span>
          </div>
        </div>
        <div v-if="!maps.length" class="ml-empty">暂无导图，点击右上角「＋ 新建导图」开始</div>
      </template>

      <!-- 右键菜单 -->
      <div v-if="ctxMenu" class="ml-ctx" :style="{ left: ctxMenu.x + 'px', top: ctxMenu.y + 'px' }" @contextmenu.prevent @click.stop>
        <div class="ml-ctx-item" @click="togglePin(ctxMenu.id, ctxMenu.pinned)">{{ ctxMenu.pinned ? '取消置顶' : '置顶' }}</div>
        <div class="ml-ctx-item" @click="editTags(ctxMenu.id, ctxMenu.tags)">添加标签</div>
        <div class="ml-ctx-item" @click="renameMap(ctxMenu.id, ctxMenu.title)">重命名</div>
        <div class="ml-ctx-item danger" @click="delMap(ctxMenu.id)">删除（移入回收站）</div>
      </div>
      <div v-if="ctxMenu" class="ml-ctx-mask" @click="ctxMenu = null" @contextmenu.prevent="ctxMenu = null"></div>
    </div>

    <!-- ============ 编辑器 ============ -->
    <div v-else class="mm-editor">
      <div class="mm-toolbar">
        <el-button size="small" text @click="backToLib">← 返回导图库</el-button>
        <input v-model="mapTitle" class="mm-title-input" @change="markDirty" placeholder="导图标题" />
        <div class="mm-tools">
          <el-button size="small" title="为选中节点添加子主题" @click="addChild">＋子主题</el-button>
          <el-button size="small" title="为选中节点添加同级（根节点除外）" @click="addSibling">＋同级</el-button>
          <el-button size="small" title="概要：Shift 多选同一父节点的两个及以上子节点后点击，直接进入文本框编辑多行说明" :disabled="selCount < 2" @click="addSummary">{}概要</el-button>
          <el-button size="small" title="边界：Shift 多选两个及以上节点后点击，将在所选节点外围创建一个矩形，输入边界名称" :disabled="selCount < 2" @click="addOutline">边界</el-button>
          <el-button size="small" title="关系线：Shift 多选两个节点后点击（多选顺序即连线方向，起点→终点）" :disabled="selCount < 2" @click="addAssoc">关系</el-button>
          <el-dropdown trigger="click" @command="exportMap" class="mm-export">
            <el-button size="small" title="导出导图为图片 / PDF / 文本等格式">导出 ▾</el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="png">PNG 图片</el-dropdown-item>
                <el-dropdown-item command="jpg">JPG 图片</el-dropdown-item>
                <el-dropdown-item command="svg">SVG 矢量图</el-dropdown-item>
                <el-dropdown-item command="pdf">PDF 文档</el-dropdown-item>
                <el-dropdown-item command="md">Markdown</el-dropdown-item>
                <el-dropdown-item command="txt">纯文本</el-dropdown-item>
                <el-dropdown-item command="xmind">XMind</el-dropdown-item>
                <el-dropdown-item command="json">JSON 数据</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          <el-dropdown trigger="click" @command="onImportCmd" class="mm-export">
            <el-button size="small" title="导入导图到新文件">导入 ▾</el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="mm">Freemind（.mm）</el-dropdown-item>
                <el-dropdown-item command="csv">CSV 表格</el-dropdown-item>
                <el-dropdown-item command="md">Markdown</el-dropdown-item>
                <el-dropdown-item command="txt">文本（缩进）</el-dropdown-item>
                <el-dropdown-item command="json">JSON 数据</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
        <div class="mm-zoom">
          <el-button size="small" text @click="zoomOut">－</el-button>
          <span>{{ Math.round(scale * 100) }}%</span>
          <el-button size="small" text @click="zoomIn">＋</el-button>
        </div>
        <el-button size="small" class="mm-save-btn" :type="dirty ? 'primary' : 'default'" :disabled="!dirty" @click="saveNow">保存</el-button>
        <span class="mm-saved" :class="{ err: savedState === 'save-fail' }">
          {{ { idle: '未修改', saving: '未保存', saved: '已保存', 'save-fail': '保存失败' }[savedState] }}
        </span>
      </div>

      <div class="mm-body">
        <!-- 左侧：布局 / 大纲（tab 切换，宽度可拖拽调整） -->
        <div class="mm-side mm-side-left" :style="{ width: sideWidth + 'px' }">
          <div class="ms-tabs">
            <span class="ms-tab" :class="{ on: sideTab === 'layout' }" @click="sideTab = 'layout'">布局</span>
            <span class="ms-tab" :class="{ on: sideTab === 'outline' }" @click="sideTab = 'outline'">大纲</span>
          </div>
          <template v-if="sideTab === 'layout'">
            <div class="ms-title">布局</div>
            <el-radio-group v-model="layoutKey" class="ms-layout-btns" @change="onLayoutChange">
              <el-radio-button value="free"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.free"></span>自由</el-radio-button>
              <el-radio-button value="right"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.right"></span>向右</el-radio-button>
              <el-radio-button value="left"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.left"></span>向左</el-radio-button>
              <el-radio-button value="mind"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.mind"></span>导图</el-radio-button>
              <el-radio-button value="org"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.org"></span>组织</el-radio-button>
              <el-radio-button value="radial"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.radial"></span>放射</el-radio-button>
              <el-radio-button value="fish2"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.fish2"></span>双鱼骨</el-radio-button>
              <el-radio-button value="timeline"><span class="ms-lb-icon" v-html="LAYOUT_ICONS.timeline"></span>时间轴</el-radio-button>
            </el-radio-group>
            <div class="ms-title" style="margin-top: 14px;">主题</div>
            <div class="ms-themes">
              <div v-for="(t, k) in THEMES" :key="k" class="ms-theme" :class="{ on: themeKey === k }" @click="setTheme(k)">
                <span class="mt-swatch" :style="{ background: `linear-gradient(135deg, ${t.rootFill} 0%, ${t.rootFill}88 100%)` }"></span>{{ t.name }}
              </div>
            </div>
            <template v-if="activeNode">
              <div class="ms-title" style="margin-top: 14px;">节点样式</div>
              <div class="ms-label">节点颜色</div>
              <div class="ms-colors">
                <span v-for="c in nodeColors" :key="c" class="ms-color" :class="{ on: curColor === c }" :style="{ background: c }"
                  @click="setNodeColor(c)"></span>
              </div>
              <div class="ms-label" style="margin-top: 10px;">节点形状</div>
              <div class="ms-shapes">
                <span v-for="(s, k) in SHAPES" :key="k" class="ms-shape" :class="{ on: curShape === k }" @click="setNodeShape(k)">{{ s }}</span>
              </div>
              <div class="ms-label" style="margin-top: 10px;">描述</div>
              <el-input v-model="nodeDescText" type="textarea" :rows="3" class="ms-desc-input" placeholder="节点描述，自动换行" @change="saveNodeDesc" />
            </template>
            <div v-else class="ms-tip" style="margin-top: 14px;">单击画布中的节点后，可在此设置颜色、形状与描述</div>
          </template>
          <template v-else>
            <div class="ms-title">大纲 <span class="ms-outline-count">{{ outlineCount }}</span></div>
            <div class="ms-outline" v-if="outlineTree.length">
              <div v-for="o in flatOutline" :key="o.uid" class="ms-o-row" :class="{ on: o.uid === outlineActiveUid }"
                :style="{ paddingLeft: 8 + o.depth * 14 + 'px' }"
                @click="outlineSelect(o.uid)" @dblclick="outlineRename(o)" @contextmenu.prevent="outlineCtx($event, o)">
                <span class="ms-o-text">{{ o.text || '（空）' }}</span>
              </div>
            </div>
            <div v-else class="ms-tip">暂无节点</div>
          </template>
        </div>
        <div class="mm-side-drag" title="拖动调整面板宽度" @mousedown.prevent="startSideDrag"></div>

        <!-- 画布 -->
        <div class="mm-canvas"><div ref="mmEl" class="mm-host"></div></div>
      </div>
    </div>

    <!-- 弹窗与文件选择（置于根层，导图库 / 编辑器共用） -->
    <el-dialog v-model="outlineDialog" :title="outlineEditId ? '修改边界名称' : '添加边界'" width="420" append-to-body :close-on-click-modal="false">
      <p class="mm-dialog-tip">边界将以一个矩形整体包裹所选节点，显示在底层。单击矩形可选中（按 Delete 删除），双击文字可改名。</p>
      <el-input v-model="outlineText" placeholder="边界名称" maxlength="30" />
      <template #footer>
        <el-button size="small" @click="outlineDialog = false">取消</el-button>
        <el-button size="small" type="primary" @click="confirmOutline">{{ outlineEditId ? '保存' : '确定' }}</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="renameDialog" title="重命名导图" width="420" append-to-body :close-on-click-modal="false">
      <el-input v-model="renameText" placeholder="导图名称" maxlength="50" @keyup.enter="confirmRename" />
      <template #footer>
        <el-button size="small" @click="renameDialog = false">取消</el-button>
        <el-button size="small" type="primary" @click="confirmRename">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="tagsDialog" title="添加标签" width="440" append-to-body :close-on-click-modal="false">
      <div class="dlg-new-tag">
        <el-input v-model="tagNewName" placeholder="输入新标签名直接创建" style="flex: 1;" @keyup.enter="createTagInDialog" />
        <el-button type="primary" plain @click="createTagInDialog">新建标签</el-button>
      </div>
      <p class="dlg-hint">点击标签勾选/取消，点 × 删除（将覆盖导图原有标签）：</p>
      <div class="dlg-tags">
        <el-tag
          v-for="t in tagOptions" :key="t.id"
          :effect="tagChecked.includes(t.id) ? 'dark' : 'plain'"
          class="dlg-tag"
          closable
          @click.stop="toggleTagInDialog(t.id)"
          @close="removeTagInDialog(t)"
        >{{ t.name }}</el-tag>
        <p v-if="tagOptions.length === 0" class="tm-empty">暂无标签，输入上方名称直接创建</p>
      </div>
      <template #footer>
        <el-button size="small" @click="tagsDialog = false">取消</el-button>
        <el-button size="small" type="primary" @click="confirmTags">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="nodeEditDialog" title="修改节点文字" width="420" append-to-body :close-on-click-modal="false">
      <el-input v-model="nodeEditText" placeholder="节点文字" @keyup.enter="confirmNodeEdit" />
      <template #footer>
        <el-button size="small" @click="nodeEditDialog = false">取消</el-button>
        <el-button size="small" type="primary" @click="confirmNodeEdit">保存</el-button>
      </template>
    </el-dialog>

    <input ref="importInput" type="file" class="mm-import-input" @change="onImportFile" />

    <!-- 大纲行右键菜单 -->
    <div v-if="outlineCtxMenu" class="ml-ctx" :style="{ left: outlineCtxMenu.x + 'px', top: outlineCtxMenu.y + 'px' }" @contextmenu.prevent @click.stop>
      <div class="ml-ctx-item" @click="ocAddChild">添加子主题</div>
      <div class="ml-ctx-item" @click="ocAddSibling">添加同级</div>
      <div class="ml-ctx-item" @click="ocRename">重命名</div>
      <div class="ml-ctx-item danger" @click="ocRemove">删除节点</div>
    </div>
    <div v-if="outlineCtxMenu" class="ml-ctx-mask" @click="outlineCtxMenu = null" @contextmenu.prevent="outlineCtxMenu = null"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import MindMap from 'simple-mind-map';
import 'simple-mind-map/full.js';
import { getMindmaps, createMindmap, deleteMindmap, deleteMindmapPermanent, restoreMindmap, getMindmap, updateMindmap, saveMindmapNodes, saveMindmapLinks, saveMindmapMembers, getRecycleMindmaps, getRecycleInfo, getTags, createTag, deleteTag, type MindmapNode, type MindmapLink, type MindmapMember, type MindmapMeta, type RecycleInfo } from './api';

const VIRT_ROOT = '__VR__';
const LAYOUT_MAP: Record<string, string> = { free: 'mindMap', right: 'logicalStructure', left: 'logicalStructureLeft', mind: 'mindMap', org: 'organizationStructure', radial: 'fishbone', fish2: 'fishbone2', timeline: 'timeline' };
const LAYOUT_REV: Record<string, string> = { mindMap: 'free', logicalStructure: 'right', logicalStructureLeft: 'left', organizationStructure: 'org', fishbone: 'radial' };
const SHAPES: Record<string, string> = { auto: '自动', rect: '矩形', round: '圆角', ellipse: '椭圆', diamond: '菱形', parallelogram: '平行四边形', octagon: '八角', outerTri: '外三角', innerTri: '内三角' };
const SHAPE_MAP: Record<string, string> = {
  auto: 'rectangle', rect: 'rectangle', round: 'roundedRectangle', ellipse: 'ellipse',
  diamond: 'diamond', parallelogram: 'parallelogram', octagon: 'octagonalRectangle',
  outerTri: 'outerTriangularRectangle', innerTri: 'innerTriangularRectangle',
};
const SHAPE_REV: Record<string, string> = {
  rectangle: 'rect', roundedRectangle: 'round', ellipse: 'ellipse', diamond: 'diamond',
  parallelogram: 'parallelogram', octagonalRectangle: 'octagon',
  outerTriangularRectangle: 'outerTri', innerTriangularRectangle: 'innerTri',
};

// 四套主题（NexaNote 风格），基于默认主题的覆盖配置
// 关联线全局样式：细线（1.5）+ 主题色；分支节点与父节点同色系（second/node 取 root 的浅色调变体）
const THEMES: Record<string, { name: string; rootFill: string; darkBg: string; cfg: Record<string, any> }> = {
  'nexa-light': {
    name: 'Nexa 明亮', rootFill: '#3b82f6', darkBg: '#20242e',
    cfg: {
      background: '#ffffff', backgroundColor: '#ffffff', lineColor: '#9bb7e8', generalizationLineColor: '#9bb7e8',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#93a4bc', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#64748b',
      root: { fillColor: '#3b82f6', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#dbeafe', color: '#1e3a5f', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#eff6ff', color: '#274b6d', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
  'nexa-dark': {
    name: 'Nexa 深色', rootFill: '#4a8cf7', darkBg: '#1e222b',
    cfg: {
      background: '#1e222b', backgroundColor: '#1e222b', lineColor: '#3d4759', generalizationLineColor: '#3d4759',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#5a6b84', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#8fa3bd',
      root: { fillColor: '#4a8cf7', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#2b3a55', color: '#cfd8e6', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#232f42', color: '#b8c4d6', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
  classic: {
    name: '经典分支', rootFill: '#2563eb', darkBg: '#26211a',
    cfg: {
      background: '#fdf8f2', backgroundColor: '#fdf8f2', lineColor: '#f59e0b', generalizationLineColor: '#f59e0b',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#c2884a', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#9a6b2f',
      root: { fillColor: '#2563eb', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#fdeed0', color: '#7c4a12', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#fef6e4', color: '#8a5a1a', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
  azure: {
    name: '音蓝架构', rootFill: '#1d4ed8', darkBg: '#1c2433',
    cfg: {
      background: '#f0f6ff', backgroundColor: '#f0f6ff', lineColor: '#60a5fa', generalizationLineColor: '#60a5fa',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#7ba7e0', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#4a76b8',
      root: { fillColor: '#1d4ed8', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#dbeafe', color: '#1e3a8a', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#f0f7ff', color: '#334f7c', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
  // 幕布风格配色（第 5 轮新增：结构布局与配色方案方向）
  morandi: {
    name: '莫兰迪', rootFill: '#8d9b6a', darkBg: '#262b20',
    cfg: {
      background: '#f3f1ea', backgroundColor: '#f3f1ea', lineColor: '#a8b39a', generalizationLineColor: '#a8b39a',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#a49e8d', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#7a756a',
      root: { fillColor: '#8d9b6a', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#e2e6d6', color: '#4a5238', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#eeede4', color: '#5c5a4e', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
  blackgold: {
    name: '黑金', rootFill: '#1f2937', darkBg: '#16181d',
    cfg: {
      background: '#111318', backgroundColor: '#111318', lineColor: '#c9a24b', generalizationLineColor: '#c9a24b',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#8a7a52', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#c9b98a',
      root: { fillColor: '#1f2937', color: '#f5d77e', borderColor: '#c9a24b' , borderRadius: 10 },
      second: { fillColor: '#262d3a', color: '#e6d5a3', borderColor: '#c9a24b88' , borderRadius: 10 },
      node: { fillColor: '#1a1f29', color: '#cfc2a0', borderColor: '#c9a24b55' , borderRadius: 10 },
    },
  },
  spring: {
    name: '青碧', rootFill: '#0e9f8f', darkBg: '#14221f',
    cfg: {
      background: '#f0faf8', backgroundColor: '#f0faf8', lineColor: '#5fc9bd', generalizationLineColor: '#5fc9bd',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#6db5ad', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#3f8078',
      root: { fillColor: '#0e9f8f', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#d4f1ec', color: '#0d5f55', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#eafaf6', color: '#24635c', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
  warm: {
    name: '暖橙', rootFill: '#f07c3c', darkBg: '#2b2018',
    cfg: {
      background: '#fff7ef', backgroundColor: '#fff7ef', lineColor: '#f5b183', generalizationLineColor: '#f5b183',
      generalization: { borderRadius: 10 },
      borderRadius: 10,
      associativeLineWidth: 1.5, associativeLineColor: '#d19a6e', associativeLineDasharray: '6,4', associativeLineTextFontSize: 11, associativeLineTextColor: '#a8703f',
      root: { fillColor: '#f07c3c', color: '#ffffff', borderColor: 'transparent' , borderRadius: 10 },
      second: { fillColor: '#fde8d7', color: '#8c4a1d', borderColor: 'transparent' , borderRadius: 10 },
      node: { fillColor: '#fef2e6', color: '#9a5b2a', borderColor: 'transparent' , borderRadius: 10 },
    },
  },
};

// 布局按钮可视化图标（内联 SVG：节点+连线示意，16px）
const LAYOUT_ICONS: Record<string, string> = {
  free: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="3" cy="3" r="1.6" fill="currentColor"/><circle cx="13" cy="4" r="1.6" fill="currentColor"/><circle cx="4" cy="13" r="1.6" fill="currentColor"/><circle cx="12" cy="12" r="1.6" fill="currentColor"/><path d="M4.4 4.2l1.4 2.2M10.9 5.6l-3 1.4M5.4 11.4l2-2M9.9 10.5l.9-3" stroke="currentColor" stroke-width="1" fill="none"/></svg>',
  right: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="3" cy="8" r="1.8" fill="currentColor"/><circle cx="9" cy="4" r="1.5" fill="currentColor"/><circle cx="9" cy="8" r="1.5" fill="currentColor"/><circle cx="9" cy="12" r="1.5" fill="currentColor"/><path d="M4.6 7.7h2.6M9.8 4h2.8M9.8 8h2.8M9.8 12h2.8" stroke="currentColor" stroke-width="1"/></svg>',
  left: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="13" cy="8" r="1.8" fill="currentColor"/><circle cx="7" cy="4" r="1.5" fill="currentColor"/><circle cx="7" cy="8" r="1.5" fill="currentColor"/><circle cx="7" cy="12" r="1.5" fill="currentColor"/><path d="M11.4 7.7h-2.6M6.2 4H3.4M6.2 8H3.4M6.2 12H3.4" stroke="currentColor" stroke-width="1"/></svg>',
  mind: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="3" cy="8" r="1.8" fill="currentColor"/><circle cx="8" cy="3" r="1.5" fill="currentColor"/><circle cx="8" cy="8" r="1.5" fill="currentColor"/><circle cx="8" cy="13" r="1.5" fill="currentColor"/><circle cx="13" cy="6" r="1.5" fill="currentColor"/><circle cx="13" cy="11" r="1.5" fill="currentColor"/><path d="M4.6 7.6h2M8 4.4v2.2M8 9.4v2.2M9.4 8h2.4M9.4 6h2.4M9.4 11h2.4" stroke="currentColor" stroke-width="1"/></svg>',
  org: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="8" cy="2.5" r="1.8" fill="currentColor"/><circle cx="4" cy="8.5" r="1.5" fill="currentColor"/><circle cx="8" cy="8.5" r="1.5" fill="currentColor"/><circle cx="12" cy="8.5" r="1.5" fill="currentColor"/><circle cx="6" cy="13.5" r="1.4" fill="currentColor"/><circle cx="10" cy="13.5" r="1.4" fill="currentColor"/><path d="M7.6 4.2l-2.5 3M8.4 4.2l-.2 2.8M8.4 4.2l2.5 3M5 10v1.8M11 10v1.8M8 10v1.8" stroke="currentColor" stroke-width="1"/></svg>',
  radial: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="3" cy="8" r="1.8" fill="currentColor"/><path d="M4.6 8h10M7 5.4c1.6-.7 3.2-.7 4.8-.2M7 10.6c1.6.7 3.2.7 4.8.2" stroke="currentColor" stroke-width="1" fill="none"/></svg>',
  fish2: '<svg viewBox="0 0 16 16" width="14" height="14"><path d="M2 8h12M4.5 3.5c1.5-1 3-1.5 4.5-1.5M4.5 12.5c1.5 1 3 1.5 4.5 1.5M11.5 4.5c-1-1.2-1.8-2.4-2.3-3.6M11.5 11.5c-1 1.2-1.8 2.4-2.3 3.6" stroke="currentColor" stroke-width="1" fill="none"/><circle cx="2" cy="8" r="1.6" fill="currentColor"/></svg>',
  timeline: '<svg viewBox="0 0 16 16" width="14" height="14"><circle cx="2.5" cy="8" r="1.4" fill="currentColor"/><path d="M4 8h10.5M6.5 5l4.5-2M6.5 11l4.5 2" stroke="currentColor" stroke-width="1" fill="none"/><circle cx="7" cy="8" r="1.2" fill="currentColor"/><circle cx="12" cy="8" r="1.2" fill="currentColor"/></svg>',
};

// 思维导图文件图标（列表视图文件名前）
const MAP_ICON = '<svg viewBox="0 0 16 16" width="14" height="14" style="vertical-align:-2px"><circle cx="3" cy="3" r="1.8" fill="currentColor"/><circle cx="13" cy="4" r="1.5" fill="currentColor"/><circle cx="4" cy="13" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/><path d="M4.4 4.2l1.4 2.2M10.9 5.6l-3 1.4M5.4 11.4l2-2M9.9 10.5l.9-3" stroke="currentColor" stroke-width="1" fill="none"/></svg>';
const view = ref<'library' | 'editor'>('library');
const maps = ref<MindmapMeta[]>([]);
const mapId = ref('');
const mapTitle = ref('');
const layoutKey = ref('right');
const themeKey = ref('nexa-light');
const scale = ref(1);
const savedState = ref<'idle' | 'saving' | 'saved' | 'save-fail'>('idle');
const activeNode = ref<any>(null);
const curColor = ref('#3b82f6');
const curShape = ref('auto');
const nodeColors = ['#3b82f6', '#52c41a', '#f4a261', '#e74c3c', '#9b59b6', '#16a085'];

const mmEl = ref<HTMLElement>();
let mm: any = null;
let dirty = false;
let loading = false;
// 当前选中的有效节点数（驱动概要/边界/关系按钮的可用状态：单选禁用，多选 2 个及以上可用）
const selCount = ref(0);
// 边界（自定义包围盒矩形）：{ id, text, nodeIds }[]
const khBounds = ref<{ id: string; text: string; nodeIds: string[] }[]>([]);
const khActiveBound = ref('');
// 边界名称输入弹窗（新建 / 改名共用）
const outlineDialog = ref(false);
const outlineText = ref('');
const outlineEditId = ref('');

// ---------- 导图库：双视图 + 回收站 + 右键菜单 ----------
const libView = ref<'grid' | 'list'>('grid');
const showRecycle = ref(false);
const recycleMaps = ref<MindmapMeta[]>([]);
const recycleInfo = ref<RecycleInfo>({ count: 0, clear_at: null, days: 30 });
const ctxMenu = ref<{ x: number; y: number; id: string; pinned: number; title: string; tags: string } | null>(null);
const renameDialog = ref(false);
const renameText = ref('');
const renameId = ref('');
const tagsDialog = ref(false);
const tagsId = ref('');

// ---------- 编辑器：左侧布局/大纲 + 右侧设置 ----------
const sideTab = ref<'layout' | 'outline'>('layout');
const sideWidth = ref(170);
interface OutlineNode { uid: string; text: string; depth: number; children: OutlineNode[] }
const outlineTree = ref<OutlineNode[]>([]);
const outlineActiveUid = ref('');
const outlineCount = ref(0);
const flatOutline = ref<{ uid: string; text: string; depth: number }[]>([]);
const nodeEditDialog = ref(false);
const nodeEditText = ref('');
const nodeEditUid = ref('');
const importInput = ref<HTMLInputElement>();
// 大纲行右键菜单
const outlineCtxMenu = ref<{ x: number; y: number; uid: string; text: string } | null>(null);
// 导入（下拉选择格式 → 打开文件选择，导入到新导图文件）
const importType = ref('mm');
const IMPORT_ACCEPT: Record<string, string> = { mm: '.mm', csv: '.csv', md: '.md,.markdown', txt: '.txt', json: '.json' };
// 节点描述（幕布式，独立于标题，自动换行）
const nodeDescText = ref('');

const fmtTime = (s: string) => (s ? s.slice(5, 16).replace('T', ' ') : '');
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : 'n' + Date.now() + Math.random().toString(16).slice(2, 8));
// 富文本 HTML → 纯文本（DB 统一存纯文本；<br>/</p> 转 \n 保留换行，否则多行概要会被压成一行）
const plain = (s: any): string => {
  if (s == null) return '';
  let t = String(s);
  t = t.replace(/<br\s*\/?>/gi, '\n').replace(/<\/p>/gi, '\n').replace(/<\/div>/gi, '\n').replace(/<li[^>]*>/gi, '\n');
  t = t.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  return t.replace(/<[^>]*>/g, '').trim();
};

// ---------- 导图库 ----------
async function loadMaps() {
  maps.value = await getMindmaps();
  refreshRecycle();
}
async function refreshRecycle() {
  try {
    recycleInfo.value = await getRecycleInfo();
    if (showRecycle.value) recycleMaps.value = await getRecycleMindmaps();
  } catch {}
}
function toggleRecycle() {
  showRecycle.value = !showRecycle.value;
  if (showRecycle.value) getRecycleMindmaps().then(r => recycleMaps.value = r).catch(() => {});
}
async function restoreMap(id: string) {
  try { await restoreMindmap(id); ElMessage.success('已恢复'); showRecycle.value = false; await loadMaps(); } catch (e: any) { ElMessage.error('恢复失败：' + (e?.message || e)); }
}
async function purgeMap(id: string) {
  await ElMessageBox.confirm('彻底删除后不可恢复，确定删除该导图？', '彻底删除', { confirmButtonText: '彻底删除', cancelButtonText: '取消', type: 'warning' }).catch(() => { throw 0; });
  try { await deleteMindmapPermanent(id); ElMessage.success('已彻底删除'); refreshRecycle(); } catch (e: any) { ElMessage.error('删除失败：' + (e?.message || e)); }
}
function showCtxMenu(e: MouseEvent, m: MindmapMeta) {
  // 菜单为 position:fixed（相对视口），直接使用视口坐标，不再减去容器偏移（此前减了 .mm-library 偏移导致菜单偏离鼠标）
  ctxMenu.value = {
    x: Math.min(e.clientX, window.innerWidth - 160),
    y: Math.min(e.clientY, window.innerHeight - 160),
    id: m.id, pinned: m.pinned, title: m.title, tags: m.tags || '',
  };
}
async function togglePin(id: string, pinned: number) {
  try { await updateMindmap(id, { pinned: pinned ? 0 : 1 }); await loadMaps(); } catch (e: any) { ElMessage.error('操作失败：' + (e?.message || e)); }
  ctxMenu.value = null;
}
function editTags(id: string, tags: string) {
  tagsId.value = id;
  // 初始化选中：导图现有标签（逗号分隔的名称）匹配到标签库 id
  const names = (tags || '').split(/[,，]/).map(s => s.trim()).filter(Boolean);
  tagChecked.value = tagOptions.value.filter(t => names.includes(t.name)).map(t => t.id);
  tagsDialog.value = true;
  ctxMenu.value = null;
}
// 标签库（供导图打标多选弹窗共用，与浏览页统一交互）
const tagOptions = ref<{ id: string; name: string; color?: string }[]>([]);
const tagChecked = ref<string[]>([]);
const tagNewName = ref('');
async function loadTagOptions() {
  try { tagOptions.value = await getTags(); } catch {}
}
function toggleTagInDialog(id: string) {
  const i = tagChecked.value.indexOf(id);
  if (i >= 0) tagChecked.value.splice(i, 1); else tagChecked.value.push(id);
}
async function createTagInDialog() {
  const n = tagNewName.value.trim();
  if (!n) return;
  try { await createTag(n); tagNewName.value = ''; await loadTagOptions(); } catch (e: any) { ElMessage.error('创建失败：' + (e?.message || e)); }
}
async function removeTagInDialog(t: { id: string; name: string }) {
  try { await deleteTag(t.id); const i = tagChecked.value.indexOf(t.id); if (i >= 0) tagChecked.value.splice(i, 1); await loadTagOptions(); } catch (e: any) { ElMessage.error('删除失败：' + (e?.message || e)); }
}
async function confirmTags() {
  const names = tagOptions.value.filter(t => tagChecked.value.includes(t.id)).map(t => t.name).join(',');
  try {
    await updateMindmap(tagsId.value, { tags: names });
    ElMessage.success('标签已保存'); tagsDialog.value = false; await loadMaps();
  } catch (e: any) { ElMessage.error('保存失败：' + (e?.message || e)); }
}
function renameMap(id: string, title: string) {
  renameId.value = id; renameText.value = title; renameDialog.value = true;
  ctxMenu.value = null;
}
async function confirmRename() {
  const t = renameText.value.trim();
  if (!t) return;
  try { await updateMindmap(renameId.value, { title: t }); renameDialog.value = false; await loadMaps(); } catch (e: any) { ElMessage.error('重命名失败：' + (e?.message || e)); }
}
async function newMap() {
  const title = await ElMessageBox.prompt('请输入导图名称', '新建思维导图', { confirmButtonText: '创建', cancelButtonText: '取消', inputValue: '' }).then(r => r.value.trim()).catch(() => null);
  if (!title) return;
  try {
    await createMindmap(title);
    await loadMaps();
  } catch (e: any) { ElMessage.error('创建失败：' + (e?.message || e)); }
}
// 新建按钮下拉：新建 / 导入
function onNewMapCmd(cmd: string) {
  if (cmd === 'new') newMap();
  else if (cmd === 'import') importFile();
}
async function delMap(id: string) {
  await ElMessageBox.confirm('删除后导图将移入回收站，保留 30 天后自动清理。确定删除？', '移入回收站', { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' }).catch(() => { throw 0; });
  try { await deleteMindmap(id); ElMessage.success('已移入回收站'); ctxMenu.value = null; await loadMaps(); } catch (e: any) { ElMessage.error('删除失败：' + (e?.message || e)); }
}

// ---------- 数据映射：DB → simple-mind-map ----------
// 节点描述（幕布式）：独立字段，不写入 SMM 富文本 text（避免 SMM 富文本序列化转义/污染标题），
// 渲染时在节点下方自绘 foreignObject 显示（自动换行），编辑走右侧描述框
const escHtml = (s: string) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
// 兼容：历史版本可能把"标题+描述"HTML 存进了 title，加载时拆回
function splitNodeText(text: any): { title: string; desc: string } {
  const s = String(text || '');
  if (!s.includes('kh-node-desc')) return { title: plain(s), desc: '' };
  try {
    const doc = new DOMParser().parseFromString('<body>' + s + '</body>', 'text/html');
    let title = '', desc = '';
    doc.body.childNodes.forEach((el: any) => {
      if (el.nodeType === 3) { title += (title && title.trim() ? '\n' : '') + el.textContent; return; }
      const isDesc = el.classList && el.classList.contains('kh-node-desc');
      const txt = (el.textContent || '').trim();
      if (!txt) return;
      if (isDesc) desc += (desc ? '\n' : '') + txt;
      else title += (title ? '\n' : '') + txt;
    });
    return { title: title.trim(), desc };
  } catch { return { title: plain(s), desc: '' }; }
}
// 读取节点的标题与描述（兼容历史 HTML title）
function nodeTitleDesc(n: any): { title: string; desc: string } {
  let title = plain(n.title);
  let desc = (n as any).desc || '';
  const raw = String(n.title || '');
  if (raw.includes('<')) {
    const sp = splitNodeText(raw);
    if (!desc && sp.desc) desc = sp.desc;
    if (sp.title) title = sp.title;
  }
  return { title, desc };
}
function dbToSmm(nodes: MindmapNode[], links: MindmapLink[], members: MindmapMember[]) {
  const byId = new Map(nodes.map(n => [n.id, n]));
  const kids = new Map<string, MindmapNode[]>();
  for (const n of nodes) { if (n.parent_id) { if (!kids.has(n.parent_id)) kids.set(n.parent_id, []); kids.get(n.parent_id)!.push(n); } }
  for (const k of kids.keys()) kids.get(k)!.sort((a, b) => a.sort - b.sort);
  const boundaries = nodes.filter(n => n.kind === 'boundary');
  const memByGroup = new Map<string, string[]>();
  for (const m of members) { if (!memByGroup.has(m.group_id)) memByGroup.set(m.group_id, []); memByGroup.get(m.group_id)!.push(m.node_id); }
  // 边界（自定义包围盒矩形）：从 DB boundary 记录 + 组成员构建（兼容旧 SMM outerFrame 数据）
  khBounds.value = boundaries.map(b => ({
    id: b.id,
    text: plain(b.title) || '边界',
    nodeIds: memByGroup.get(b.id) || [],
  }));
  const build = (n: MindmapNode): any => {
    const { title, desc } = nodeTitleDesc(n);
    const d: any = { data: { text: title, uid: n.id, expand: n.expand !== 0 }, children: (kids.get(n.id) || []).filter(c => c.kind === 'node').map(build) };
    if (desc) d.data.desc = desc;
    if (n.color) { d.data.fillColor = n.color; d.data.color = '#ffffff'; }
    if (n.shape && n.shape !== 'auto') d.data.shape = SHAPE_MAP[n.shape] || 'rectangle';
    // 概要（每行包成独立 <p>：SMM 富文本转换 removeRichTextStyes 会保留多个 <p> 为独立段落，
    // 这样多行概要才能正确撑高节点并换行显示；\n 和 <br> 都会被其吞掉，不能用）
    const sums = nodes.filter(s => s.kind === 'summary' && s.parent_id === n.id);
    if (sums.length) d.data.generalization = sums.map(s => ({ text: plain(s.title).split('\n').map(l => '<p>' + l + '</p>').join(''), richText: true }));
    // 关联线（SMM associativeLineTargets 为 uid 字符串数组）
    const rels = links.filter(l => l.source_id === n.id).map(l => l.target_id);
    if (rels.length) d.data.associativeLineTargets = rels;
    return d;
  };
  const roots = nodes.filter(n => n.kind === 'node' && !n.parent_id).sort((a, b) => a.sort - b.sort);
  if (!roots.length) return { data: { text: '', uid: VIRT_ROOT, expand: true }, children: [] };
  if (roots.length === 1) return build(roots[0]);
  // 多根：包一层虚拟根
  return { data: { text: '知识导图', uid: VIRT_ROOT, expand: true }, children: roots.map(build) };
}

// ---------- 数据映射：simple-mind-map → DB（全量保存） ----------
function smmToDb(root: any) {
  const nodes: MindmapNode[] = [];
  const links: MindmapLink[] = [];
  const members: MindmapMember[] = [];
  let nSort = 0;
  const walk = (d: any, parentId: string | null, isVrChild: boolean) => {
    const data = d.data || {};
    const id = data.uid;
    if (id !== VIRT_ROOT) {
      nodes.push({
        id, parent_id: parentId, title: plain(data.text), desc: data.desc || '', kind: 'node',
        x: 0, y: 0,
        color: data.fillColor || null,
        shape: SHAPE_REV[data.shape] || 'auto',
        expand: data.expand === false ? 0 : 1,
        sort: nSort++,
      });
    }
    const effParent = id === VIRT_ROOT ? parentId : id;
    (data.generalization || []).forEach((g: any, i: number) => {
      nodes.push({ id: 'g_' + id + '_' + i, parent_id: effParent, title: plain(g.text), kind: 'summary', x: 0, y: 0, color: null, shape: 'auto', sort: nSort++ });
    });
    (data.associativeLineTargets || []).forEach((uid: string, i: number) => {
      if (uid) links.push({ id: 'l_' + id + '_' + i, source_id: id, target_id: uid, label: '' });
    });
    (d.children || []).forEach((c: any) => walk(c, effParent, false));
  };
  walk(root, null, true);
  // 边界（自定义包围盒矩形）：直接由运行时状态生成，不依赖 SMM outerFrame
  khBounds.value.forEach((b, i) => {
    nodes.push({ id: b.id, parent_id: null, title: b.text || '边界', kind: 'boundary', x: 0, y: 0, color: null, shape: 'auto', sort: nSort++ });
    b.nodeIds.forEach(nid => members.push({ group_id: b.id, node_id: nid }));
  });
  return { nodes, links, members };
}

// ---------- 编辑器 ----------
async function openMap(id: string) {
  try {
    // 编辑器内切换（如导入到新文件后）：若当前导图有未保存修改，先询问是否保存
    if (view.value === 'editor' && dirty) {
      const ok = await ElMessageBox.confirm('当前导图有未保存的修改，先保存再继续？', '未保存', {
        confirmButtonText: '保存', cancelButtonText: '放弃修改', type: 'warning',
      }).then(() => true).catch(() => false);
      if (ok) await flushSave(); else dirty = false;
    }
    // 从编辑器内重开（如导入到新文件后）：先销毁旧画布实例，避免新旧画布叠加
    destroyMindMap();
    const data = await getMindmap(id);
    mapId.value = id;
    mapTitle.value = data.title;
    view.value = 'editor';
    layoutKey.value = (['free', 'right', 'left', 'mind', 'org', 'radial', 'fish2', 'timeline'].includes(data.layout) ? data.layout : 'right');
    themeKey.value = (THEMES[data.theme] ? data.theme : 'nexa-light');
    activeNode.value = null;
    outlineTree.value = []; outlineActiveUid.value = '';
    await nextTickRender();
    const smmData = dbToSmm(data.nodes, data.links, data.members);
    mm = new MindMap({
      el: mmEl.value!,
      data: smmData,
      layout: LAYOUT_MAP[layoutKey.value] || 'logicalStructure',
      theme: 'default',
      themeConfig: themeCfgFor(themeKey.value),
      enableFreeDrag: true,
      mousewheelAction: 'zoom',
      // 鱼骨（放射）布局角度：默认 45° 会让上下分支横向间距过大，调大后更紧凑（配合主题 second.marginX 缩减）
      fishboneDeg: 72,
      // 分支节点展开/折叠按钮：光标悬停时显示（不常驻）
      alwaysShowExpandBtn: false,
      // 节点文字编辑采用"就地编辑"：编辑框透明无阴影、原文本隐藏，直接在节点文字原位修改（幕布式，避免悬浮白框）
      openRealtimeRenderOnNodeTextEdit: true,
      // 关系线激活时不显示两端拖拽调节锚点（用户不需要调节曲线控制点）
      enableAdjustAssociativeLinePoints: false,
      // 关联线渲染在节点下层，避免遮挡节点内容（默认 true 会盖住节点）
      associativeLineIsAlwaysAboveNode: false,
      // 节点内追加内容：幕布式描述渲染在节点矩形内部底部（替代早期节点外浮层方案）
      // create 返回 { el, width, height }：SMM 将其包成 foreignObject 追加进节点 group；
      // handle 在渲染后回调，可精确定位（节点内底部）；getNodeRect 补丁会把节点宽高撑大以容纳描述
      addCustomContentToNode: {
        create(node: any) {
          const desc = (node?.nodeData?.data?.desc || '').trim();
          if (!desc) return null;
          const el = document.createElement('div');
          el.className = 'kh-node-desc-inner';
          desc.split('\n').forEach(line => {
            const p = document.createElement('div');
            p.textContent = line || ' ';
            el.appendChild(p);
          });
          const parentSvg = node.group?.node || null;
          const maxW = parentSvg ? (parentSvg.getBBox?.()?.width || 180) : 180;
          const fontSize = 11;
          const lines = el.children.length;
          const width = Math.min(320, Math.max(60, ...desc.split('\n').map(l => Math.ceil(l.length * fontSize * 0.95) + 12)));
          const height = lines * (fontSize + 3) + 8;
          return { el, width: Math.max(width, 80), height: Math.min(height, 220) };
        },
        handle({ element, node }: any) {
          try {
            const { paddingX, paddingY } = node.getPaddingVale ? node.getPaddingVale() : { paddingX: 8, paddingY: 6 };
            const descH = node._customContentAddToNodeAdd?.height || 0;
            element.translate(paddingX, node.height - descH - paddingY - 2);
          } catch {}
        },
      },
    });
    applyCanvasBg();
    let fitted = false;
    mm.on('node_tree_render_end', () => {
      scale.value = mm.view.scale || 1;
      if (!fitted) { fitted = true; setTimeout(() => { try { mm.view.fit(); } catch {} }, 30); setTimeout(() => { try { mm.view.fit(); } catch {} }, 200); }
      scheduleRenderBounds();
      refreshOutline();
    });
    bindEvents();
    window.addEventListener('keydown', onEditorKeydown);
    // 吸收打开后的初始化脏标记：900ms 后强制复位为"已保存"（无操作退出不再弹未保存提示）
    absorbDirty = true;
    setTimeout(() => { absorbDirty = false; savedState.value = 'saved'; dirty = false; }, 900);
    savedState.value = 'saved';
    dirty = false;
    sideTab.value = 'layout';
  } catch (e: any) { ElMessage.error('打开导图失败：' + (e?.message || e)); }
}
function nextTickRender() { return new Promise(r => setTimeout(r, 50)); }
async function backToLib() {
  // 有未保存修改时询问（不自动保存）
  if (dirty) {
    const ok = await ElMessageBox.confirm('当前导图有未保存的修改，先保存再返回？', '未保存', {
      confirmButtonText: '保存并返回', cancelButtonText: '放弃修改', type: 'warning',
    }).then(() => true).catch(() => false);
    if (ok) await flushSave(); else dirty = false;
  }
  destroyMindMap();
  view.value = 'library';
  showRecycle.value = false;
  ctxMenu.value = null;
  loadMaps();
}
function destroyMindMap() {
  if (mm) {
    try {
      mm.off('node_active');
      mm.off('node_tree_render_end');
      mm.off('data_change');
      mm.off('view_data_change');
      mm.off('scale');
      mm.destroy();
    } catch {}
    mm = null;
  }
  window.removeEventListener('keydown', onEditorKeydown);
  absorbDirty = false;
  if (themeObserver) { themeObserver.disconnect(); themeObserver = null; }
  khBounds.value = [];
  khActiveBound.value = '';
  outlineTree.value = []; flatOutline.value = []; outlineCount.value = 0; outlineActiveUid.value = '';
}
// Delete/Backspace：优先删除已选中的边界矩形（点击矩形时 SMM 已通过 draw_click 清空节点激活，互不冲突）
function onEditorKeydown(e: KeyboardEvent) {
  if ((e.key === 'Delete' || e.key === 'Backspace') && khActiveBound.value && mm) {
    const id = khActiveBound.value;
    khActiveBound.value = '';
    khBounds.value = khBounds.value.filter(b => b.id !== id);
    renderBounds();
    markDirty();
    ElMessage.success('已删除边界');
  }
}
function bindEvents() {
  mm.on('node_active', (node: any) => {
    const nd = node?.nodeData?.data;
    if (!node || !nd || nd.uid === VIRT_ROOT) { activeNode.value = null; selCount.value = 0; return; }
    activeNode.value = node;
    curColor.value = nd.fillColor || THEMES[themeKey.value].rootFill;
    curShape.value = SHAPE_REV[nd.shape] || 'auto';
    nodeDescText.value = nd.desc || '';
    selCount.value = selNodes().length;
    outlineActiveUid.value = nd.uid;
  });
  mm.on('node_tree_render_end', () => { scale.value = mm.view.scale || 1; });
  mm.on('data_change', () => { markDirty(); refreshOutline(); });
  mm.on('view_data_change', () => { markDirty(); refreshOutline(); });
  mm.on('scale', () => scheduleRenderBounds());
  mm.on('draw_click', () => {
    // 点击画布空白处：取消边界选中
    khActiveBound.value = '';
    renderBounds();
    selCount.value = selNodes().length;
  });
}
// 打开导图后的"吸收期"：SMM 初始渲染/自动布局（fit、setData 回放等）会触发 data_change/view_data_change
// 事件并 markDirty，导致"打开后无任何操作却提示未保存"。打开后 900ms 内忽略脏标记并强制复位。
let absorbDirty = false;
// 标记有未保存的修改（不再自动保存：由工具栏「保存」按钮手动触发 flushSave）
function markDirty() {
  if (!mapId.value || view.value !== 'editor' || absorbDirty) return;
  dirty = true;
  savedState.value = 'saving';
}
async function flushSave() {
  if (!dirty || !mm || !mapId.value) return;
  dirty = false;
  try {
    const root = mm.getData();
    const { nodes, links, members } = smmToDb(root);
    await Promise.all([
      updateMindmap(mapId.value, { title: mapTitle.value, layout: layoutKey.value, theme: themeKey.value }),
      saveMindmapNodes(mapId.value, nodes),
      saveMindmapLinks(mapId.value, links),
      saveMindmapMembers(mapId.value, members),
    ]);
    savedState.value = 'saved';
  } catch (e) { dirty = true; savedState.value = 'save-fail'; console.error(e); ElMessage.error('保存失败：' + (e?.message || e)); }
}
// 工具栏「保存」按钮：手动保存当前导图
async function saveNow() {
  if (!dirty) return;
  await flushSave();
}

// ---------- 工具栏 ----------
function setNodeColor(c: string) {
  if (!activeNode.value) return;
  curColor.value = c;
  mm.execCommand('SET_NODE_STYLE', activeNode.value, 'fillColor', c);
  mm.execCommand('SET_NODE_STYLE', activeNode.value, 'color', c === '#ffffff' ? '#333' : '#ffffff');
  markDirty();
}
function setNodeShape(s: string) {
  if (!activeNode.value) return;
  curShape.value = s;
  mm.execCommand('SET_NODE_SHAPE', activeNode.value, SHAPE_MAP[s] || 'rectangle');
  markDirty();
}
// 保存节点描述（幕布式，自动换行）：写入独立 data.desc 字段，SMM 通过 addCustomContentToNode 钩子渲染在节点内部
function saveNodeDesc() {
  const node = activeNode.value;
  if (!node) return;
  try {
    node.setData({ desc: nodeDescText.value });
    node.reRender();
    markDirty();
    refreshOutline();
  } catch (e: any) { ElMessage.error('保存描述失败：' + (e?.message || e)); }
}

// ---------- 工具栏 ----------
function active() {
  if (activeNode.value) return activeNode.value;
  const l = mm?.renderer?.activeNodeList || [];
  if (l.length && l[0].nodeData?.data && l[0].nodeData.data.uid !== VIRT_ROOT) return l[0];
  return null;
}
// 当前选中的有效节点（支持 Shift 多选）
function selNodes(): any[] {
  const l = mm?.renderer?.activeNodeList || [];
  return l.filter(n => n.nodeData?.data && n.nodeData.data.uid !== VIRT_ROOT);
}
function addChild() {
  const n = active(); if (!n) { ElMessage.warning('请先单击选中一个节点'); return; }
  mm.execCommand('INSERT_CHILD_NODE', true, [n]);
}
function addSibling() {
  const n = active(); if (!n) { ElMessage.warning('请先单击选中一个节点'); return; }
  if (n.isRoot) { ElMessage.warning('根节点不能添加同级'); return; }
  mm.execCommand('INSERT_NODE', true, [n]);
}
// 概要：Shift 多选同一父节点的两个及以上子节点 → 直接进入文本框编辑（无弹窗）
function addSummary() {
  const ns = selNodes();
  if (ns.length < 2) { ElMessage.warning('请按住 Shift 多选同一父节点的两个及以上子节点'); return; }
  if (ns.some(n => n.isRoot || n.isGeneralization)) { ElMessage.warning('根节点 / 概要节点不能添加概要'); return; }
  const p = ns[0].parent;
  if (ns.some(n => n.parent !== p)) { ElMessage.warning('概要只能针对同一父节点的多个子节点'); return; }
  if (ns.some(n => { const d = n.getData ? n.getData('generalization') : null; return d && d.length; })) {
    ElMessage.warning('选中节点已有概要，请先删除旧概要或选择其他节点'); return;
  }
  try {
    mm.execCommand('ADD_GENERALIZATION', { text: '' }, true); // openEdit=true：创建后直接进入文本编辑
    markDirty();
  } catch (e: any) { ElMessage.error('添加概要失败：' + (e?.message || e)); }
}
// 边界：Shift 多选两个及以上节点 → 一个矩形整体包裹所选节点（弹窗输入名称）
function addOutline() {
  const ns = selNodes();
  if (ns.length < 2) { ElMessage.warning('请按住 Shift 多选两个及以上节点'); return; }
  if (ns.some(n => n.isRoot || n.isGeneralization)) { ElMessage.warning('根节点 / 概要节点不能添加边界'); return; }
  outlineEditId.value = '';
  outlineText.value = '边界';
  outlineDialog.value = true;
}
function confirmOutline() {
  const text = outlineText.value.trim();
  if (outlineEditId.value) {
    // 改名
    const b = khBounds.value.find(x => x.id === outlineEditId.value);
    if (b) { b.text = text || '边界'; renderBounds(); markDirty(); }
    outlineDialog.value = false;
    return;
  }
  const ns = selNodes();
  if (ns.length < 2) { outlineDialog.value = false; return; }
  khBounds.value.push({ id: 'b_' + uid(), text: text || '边界', nodeIds: ns.map(n => n.nodeData.data.uid) });
  renderBounds();
  markDirty();
  ElMessage.success('已添加边界');
  outlineDialog.value = false;
}
// 边界渲染层：SVG g 元素插到 svg 顶层（节点容器之下），坐标用 node.getRect()（rbox 视口坐标）
const SVG_NS = 'http://www.w3.org/2000/svg';
let boundsTimer: any = null;
function scheduleRenderBounds() {
  if (boundsTimer) clearTimeout(boundsTimer);
  boundsTimer = setTimeout(renderBounds, 80);
}
function renderBounds() {
  const host = mmEl.value;
  if (!host || !mm) return;
  const svg = host.querySelector('.smm-container svg') || host.querySelector('svg');
  if (!svg) return;
  let layer = host.querySelector('.kh-bound-layer') as SVGGElement | null;
  // 无边界时移除层：空的 <g> 会让 SMM Scrollbar 的 rbox() 崩溃，导致整图渲染中断
  if (!khBounds.value.length) {
    if (layer) layer.remove();
    return;
  }
  if (!layer) {
    layer = document.createElementNS(SVG_NS, 'g');
    layer.setAttribute('class', 'kh-bound-layer');
    svg.insertBefore(layer, svg.firstChild);
  }
  layer.innerHTML = '';
  // renderer.root 是渲染节点树根（MindMapNode 实例，含 nodeData/getRect），递归收集所有节点
  const nodes: any[] = [];
  const walkN = (n: any) => {
    if (!n) return;
    if (n.nodeData?.data && n.nodeData.data.uid !== VIRT_ROOT) nodes.push(n);
    (n.children || []).forEach(walkN);
  };
  walkN(mm.renderer.root);
  const byUid = new Map(nodes.map((n: any) => [n.nodeData?.data?.uid, n]));
  for (const b of khBounds.value) {
    const rects = b.nodeIds.map(id => byUid.get(id)).filter(Boolean).map((n: any) => n.getRect()).filter((r: any) => r);
    if (!rects.length) continue;
    const pad = 14;
    const left = Math.min(...rects.map((r: any) => r.x));
    const top = Math.min(...rects.map((r: any) => r.y));
    const right = Math.max(...rects.map((r: any) => r.x + r.width));
    const bottom = Math.max(...rects.map((r: any) => r.y + r.height));
    const x = left - pad, y = top - pad - 16, w = right - left + pad * 2, h = bottom - top + pad * 2;
    const sel = khActiveBound.value === b.id;
    const grp = document.createElementNS(SVG_NS, 'g');
    grp.setAttribute('class', 'kh-bound');
    const rect = document.createElementNS(SVG_NS, 'rect');
    rect.setAttribute('x', String(x)); rect.setAttribute('y', String(y));
    rect.setAttribute('width', String(w)); rect.setAttribute('height', String(h));
    rect.setAttribute('rx', '10');
    rect.setAttribute('fill', 'rgba(96,165,250,0.05)');
    rect.setAttribute('stroke', sel ? '#e11d48' : '#7ba7e0');
    rect.setAttribute('stroke-width', sel ? '2' : '1.2');
    rect.setAttribute('stroke-dasharray', '7,5');
    const txt = document.createElementNS(SVG_NS, 'text');
    txt.setAttribute('x', String(x + 8)); txt.setAttribute('y', String(y - 5));
    txt.setAttribute('fill', sel ? '#e11d48' : '#64748b');
    txt.setAttribute('font-size', '12');
    txt.textContent = b.text || '边界';
    grp.appendChild(rect); grp.appendChild(txt);
    grp.addEventListener('click', (e) => {
      e.stopPropagation();
      khActiveBound.value = b.id;
      renderBounds();
    });
    grp.addEventListener('dblclick', (e) => {
      e.stopPropagation();
      outlineEditId.value = b.id;
      outlineText.value = b.text || '边界';
      outlineDialog.value = true;
    });
    layer.appendChild(grp);
  }
}
// 关系线：Shift 多选两个节点 → 自动连线（多选顺序即方向：先选为起点，后选为终点）
function addAssoc() {
  const ns = selNodes();
  if (ns.length < 2) { ElMessage.warning('请按住 Shift 多选两个节点（先选的为起点）'); return; }
  try {
    mm.execCommand('ADD_ASSOCIATIVE_LINE', ns[0], ns[1]);
    markDirty();
    ElMessage.success('已创建关联线');
  } catch (e: any) { ElMessage.error('添加关联线失败：' + (e?.message || e)); }
}

// ---------- 布局 / 主题 / 节点样式 ----------
function onLayoutChange() {
  if (!mm) return;
  mm.setLayout(LAYOUT_MAP[layoutKey.value] || 'logicalStructure');
  // 切换布局后画布尺寸变化，自动收拢到可视范围
  setTimeout(() => { try { mm.view.fit(); } catch {} }, 30);
  markDirty();
}
function setTheme(k: string) {
  themeKey.value = k;
  if (mm) mm.setThemeConfig(themeCfgFor(k));
  applyCanvasBg();
  markDirty();
}
// 主题配置：系统深色时画布背景自动切为该主题的深色背景（跟随系统主题）
function themeCfgFor(k: string): Record<string, any> {
  const t = THEMES[k] || THEMES['nexa-light'];
  const isDark = document.documentElement.classList.contains('dark');
  const cfg = { ...t.cfg };
  // 放射（鱼骨）布局：收紧二级节点横向间距（marginX），配合 fishboneDeg 72 进一步压缩横向距离
  if (layoutKey.value === 'radial') {
    cfg.second = { ...(cfg.second || {}), marginX: 10 };
  }
  // SMM 重渲染（切布局等）会用 themeConfig.backgroundColor 覆盖容器背景，必须同时替换该字段
  return isDark ? { ...cfg, backgroundColor: t.darkBg, background: t.darkBg } : cfg;
}
// SMM 用内联样式设置容器背景，需手动应用（themeConfig.background 不会自动同步到容器）
function applyCanvasBg() {
  if (mmEl.value) mmEl.value.style.background = themeCfgFor(themeKey.value).background;
}
// 监听系统主题（html.dark class）变化：重新应用画布背景，避免深色系统下画布仍为浅色
let themeObserver: MutationObserver | null = null;
function watchSystemTheme() {
  if (themeObserver) themeObserver.disconnect();
  themeObserver = new MutationObserver(() => {
    if (mm) { try { mm.setThemeConfig(themeCfgFor(themeKey.value)); } catch {} }
    applyCanvasBg();
  });
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
}
function zoomIn() { mm?.view.enlarge(); }
function zoomOut() { mm?.view.narrow(); }

// ---------- 大纲视图（左侧 tab）：快速查看 / 增删改节点 ----------
function refreshOutline() {
  if (!mm || view.value !== 'editor') return;
  try {
    const root = mm.getData();
    const tree: OutlineNode[] = [];
    const walk = (d: any, depth: number, arr: OutlineNode[]) => {
      const data = d?.data || {};
      if (!data.uid || data.uid === VIRT_ROOT) {
        (d?.children || []).forEach((c: any) => walk(c, depth, arr));
        return;
      }
      const n: OutlineNode = { uid: data.uid, text: plain(data.text), depth, children: [] };
      arr.push(n);
      (d?.children || []).forEach((c: any) => walk(c, depth + 1, n.children));
    };
    walk(root, 0, tree);
    outlineTree.value = tree;
    const flat: { uid: string; text: string; depth: number }[] = [];
    const flatWalk = (arr: OutlineNode[]) => arr.forEach(n => { flat.push({ uid: n.uid, text: n.text, depth: n.depth }); flatWalk(n.children); });
    flatWalk(tree);
    flatOutline.value = flat;
    outlineCount.value = flat.length;
  } catch {}
}
// uid → SMM 节点实例（含概要/边界，供大纲操作）
function uidToNode(uid: string): any {
  if (!mm?.renderer?.root) return null;
  const nodes: any[] = [];
  const walkN = (n: any) => {
    if (!n) return;
    if (n.nodeData?.data && n.nodeData.data.uid) nodes.push(n);
    (n.children || []).forEach(walkN);
  };
  walkN(mm.renderer.root);
  return nodes.find(n => n.nodeData.data.uid === uid) || null;
}
function outlineSelect(uid: string) {
  const node = uidToNode(uid);
  if (!node) return;
  try {
    mm.renderer.activeNodeList.slice().forEach((n: any) => { try { n.deactivate(); } catch {} });
    // 节点实例的 active()：手动激活单个节点（SMM 官方入口），会触发渲染与 node_active 事件
    node.active();
    outlineActiveUid.value = uid;
  } catch {}
}
function outlineAddChild(o: { uid: string }) {
  const node = uidToNode(o.uid);
  if (!node) return;
  mm.execCommand('INSERT_CHILD_NODE', true, [node]);
  setTimeout(refreshOutline, 100);
}
function outlineAddSibling(o: { uid: string }) {
  const node = uidToNode(o.uid);
  if (!node) return;
  if (node.isRoot) { ElMessage.warning('根节点不能添加同级'); return; }
  mm.execCommand('INSERT_NODE', true, [node]);
  setTimeout(refreshOutline, 100);
}
function outlineRemove(o: { uid: string }) {
  const node = uidToNode(o.uid);
  if (!node) return;
  if (node.isRoot) { ElMessage.warning('根节点不能删除'); return; }
  ElMessageBox.confirm('确定删除该节点及其子节点？', '删除节点', { confirmButtonText: '删除', cancelButtonText: '取消', type: 'warning' })
    .then(() => { mm.execCommand('REMOVE_NODE', [node]); setTimeout(refreshOutline, 100); })
    .catch(() => {});
}
function outlineRename(o: { uid: string; text: string }) {
  nodeEditUid.value = o.uid;
  nodeEditText.value = o.text;
  nodeEditDialog.value = true;
}
// 大纲行右键菜单（行内 hover 按钮已移除，操作统一收进右键菜单，避免遮挡内容）
function outlineCtx(e: MouseEvent, o: { uid: string; text: string }) {
  outlineCtxMenu.value = { x: e.clientX, y: e.clientY, uid: o.uid, text: o.text };
}
function ocAddChild() { const m = outlineCtxMenu.value; if (!m) return; outlineCtxMenu.value = null; outlineAddChild({ uid: m.uid }); }
function ocAddSibling() { const m = outlineCtxMenu.value; if (!m) return; outlineCtxMenu.value = null; outlineAddSibling({ uid: m.uid }); }
function ocRename() { const m = outlineCtxMenu.value; if (!m) return; outlineCtxMenu.value = null; outlineRename({ uid: m.uid, text: m.text }); }
function ocRemove() { const m = outlineCtxMenu.value; if (!m) return; outlineCtxMenu.value = null; outlineRemove({ uid: m.uid }); }
function confirmNodeEdit() {
  const node = uidToNode(nodeEditUid.value);
  if (!node) { nodeEditDialog.value = false; return; }
  const t = nodeEditText.value.trim();
  if (!t) { ElMessage.warning('节点文字不能为空'); return; }
  try {
    mm.execCommand('SET_NODE_TEXT', node, t);
    nodeEditDialog.value = false;
    setTimeout(refreshOutline, 100);
  } catch (e: any) { ElMessage.error('修改失败：' + (e?.message || e)); }
}
// 左侧面板宽度拖拽（2px 拖拽条）
let dragStartX = 0;
let dragStartW = 0;
function startSideDrag(e: MouseEvent) {
  dragStartX = e.clientX;
  dragStartW = sideWidth.value;
  const move = (ev: MouseEvent) => {
    const w = Math.min(Math.max(dragStartW + (ev.clientX - dragStartX), 120), 380);
    sideWidth.value = w;
  };
  const up = () => {
    window.removeEventListener('mousemove', move);
    window.removeEventListener('mouseup', up);
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
  };
  window.addEventListener('mousemove', move);
  window.addEventListener('mouseup', up);
  document.body.style.cursor = 'col-resize';
  document.body.style.userSelect = 'none';
}

// ---------- 导出 / 导入 ----------
async function exportMap(type: string) {
  if (!mm) return;
  const name = mapTitle.value?.trim() || '思维导图';
  try {
    await mm.export(type, true, name);
    ElMessage.success('已导出：' + type.toUpperCase());
  } catch (e: any) { ElMessage.error('导出失败：' + (e?.message || e)); }
}
function importFile() { importInput.value?.click(); }
// 导入下拉：选择格式后打开对应文件选择器
function onImportCmd(type: string) {
  importType.value = type;
  if (importInput.value) { importInput.value.accept = IMPORT_ACCEPT[type] || '.mm'; importInput.value.click(); }
}
// 导入到新导图文件（不覆盖当前画布内容）：解析 → 创建导图 → 保存节点 → 打开新导图
function onImportFile(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  const reader = new FileReader();
  reader.onload = async () => {
    const text = String(reader.result || '');
    const ext = importType.value;
    try {
      let data: any = null;
      if (ext === 'json') { data = JSON.parse(text); }
      else if (ext === 'mm') { data = parseFreemind(text); }
      else if (ext === 'csv') { data = parseCsv(text); }
      else if (ext === 'md') { data = parseMarkdown(text); }
      else if (ext === 'txt') { data = parseIndented(text); }
      else { ElMessage.warning('不支持的格式'); return; }
      if (!data || !data.data) { ElMessage.error('导入内容为空或格式无法识别'); return; }
      const base = (file.name.replace(/\.[^.]+$/, '') || '导入导图').trim() || '导入导图';
      const created = await createMindmap(base);
      const stamp = Date.now();
      let nSort = 0;
      const arr: any[] = [];
      const toNodes = (d: any, parentId: string | null) => {
        const uid2 = d.data.uid || ('imp_' + stamp + '_' + nSort);
        d.data.uid = uid2;
        // 跳过解析器生成的虚拟容器根（_virtual 标记），其子节点直接作为一级节点
        if (uid2 !== VIRT_ROOT && !d.data._virtual) {
          arr.push({ id: uid2, parent_id: parentId, title: plain(d.data.text), desc: '', kind: 'node', x: 0, y: 0, color: null, shape: 'auto', sort: nSort++ });
        }
        const eff = uid2 === VIRT_ROOT || d.data._virtual ? parentId : uid2;
        (d.children || []).forEach((c: any) => toNodes(c, eff));
      };
      toNodes(data, null);
      await Promise.all([
        saveMindmapNodes(created.id, arr),
        saveMindmapLinks(created.id, []),
        saveMindmapMembers(created.id, []),
      ]);
      ElMessage.success('已导入到新导图：「' + base + '」');
      await loadMaps();
      openMap(created.id);
    } catch (err: any) {
      ElMessage.error('导入失败：' + (err?.message || err));
    }
  };
  reader.readAsText(file);
}
// Freemind（.mm XML）→ SMM data
function parseFreemind(xml: string): any {
  const doc = new DOMParser().parseFromString(xml, 'application/xml');
  const rootEl = doc.querySelector('map > node');
  if (!rootEl) throw new Error('Freemind 文件中未找到根节点');
  const walk = (el: Element): any => {
    const text = el.getAttribute('TEXT') || '';
    const d: any = { data: { text, uid: uid(), expand: true }, children: [] };
    d.children = Array.from(el.children).filter(c => c.tagName === 'node').map(walk);
    return d;
  };
  const mapEl = rootEl.parentElement;
  const topLevel = mapEl ? Array.from(mapEl.children).filter(c => c.tagName === 'node') : [];
  // 多个一级节点 → 包一层虚拟根（与 DB 多根处理一致；_virtual 标记导入时跳过）
  if (topLevel.length > 1) {
    return { data: { text: '导入导图', uid: uid(), expand: true, _virtual: true }, children: topLevel.map(walk) };
  }
  return walk(rootEl);
}
// CSV：每行「路径,备注」或「路径」；路径用 / 或 \ 分隔 → 层级
function parseCsv(text: string): any {
  const rows = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  const children: any[] = [];
  const byPath = new Map<string, any>();
  const root = { data: { text: '导入导图', uid: uid(), expand: true, _virtual: true }, children };
  for (const row of rows) {
    const segs = row.split(',');
    const path = segs[0].trim().replace(/\\/g, '/');
    const note = segs.slice(1).join(',').trim();
    if (!path) continue;
    const parts = path.split('/').filter(Boolean);
    let cur = root;
    let curPath = '';
    for (let i = 0; i < parts.length; i++) {
      curPath += (curPath ? '/' : '') + parts[i];
      if (!byPath.has(curPath)) {
        const n: any = { data: { text: parts[i], uid: uid(), expand: true }, children: [] };
        byPath.set(curPath, n);
        cur.children.push(n);
      }
      cur = byPath.get(curPath);
    }
    if (note) cur.data.text = parts[parts.length - 1] + '：' + note;
  }
  return root;
}
// Markdown：标题（#）与列表（- * 1.）混合，按层级构建
function parseMarkdown(text: string): any {
  const lines = text.split(/\r?\n/);
  const root = { data: { text: '导入导图', uid: uid(), expand: true, _virtual: true }, children: [] as any[] };
  const stack: { depth: number; node: any }[] = [{ depth: 0, node: root }];
  for (const raw of lines) {
    const line = raw.replace(/\t/g, '  ').replace(/\s+$/, '');
    if (!line.trim()) continue;
    let depth = 0;
    let content = line.trim();
    const h = content.match(/^(#{1,6})\s+(.*)$/);
    if (h) { depth = h[1].length; content = h[2].trim(); }
    else {
      const bullet = content.match(/^([-*+]|\d+[.)])\s+(.*)$/);
      if (bullet) {
        const lead = line.match(/^(\s*)/)![1].length;
        depth = Math.max(1, Math.round(lead / 2));
        content = bullet[2].trim();
      } else {
        const lead = line.match(/^(\s*)/)![1].length;
        depth = Math.max(1, Math.round(lead / 2));
      }
    }
    while (stack.length > 1 && stack[stack.length - 1].depth >= depth) stack.pop();
    const parent = stack[stack.length - 1].node;
    const n: any = { data: { text: content.replace(/[*_`]/g, '').trim(), uid: uid(), expand: true }, children: [] };
    parent.children.push(n);
    stack.push({ depth, node: n });
  }
  return root;
}
// 缩进文本（空格缩进）→ SMM data
function parseIndented(text: string): any {
  const lines = text.split(/\r?\n/).map(l => l.replace(/\t/g, '  ')).filter(l => l.trim());
  const root = { data: { text: '导入导图', uid: uid(), expand: true, _virtual: true }, children: [] as any[] };
  const stack: { depth: number; node: any }[] = [{ depth: -1, node: root }];
  for (const line of lines) {
    const indent = (line.match(/^(\s*)/) || ['', ''])[1].length;
    const content = line.trim().replace(/^([-*+]|\d+[.)])\s+/, '').trim();
    const depth = Math.round(indent / 2);
    while (stack.length > 1 && stack[stack.length - 1].depth >= depth) stack.pop();
    const n: any = { data: { text: content, uid: uid(), expand: true }, children: [] };
    stack[stack.length - 1].node.children.push(n);
    stack.push({ depth, node: n });
  }
  return root;
}

onMounted(() => { loadMaps(); loadTagOptions(); watchSystemTheme(); });
onBeforeUnmount(() => { flushSave(); destroyMindMap(); });
</script>

<style scoped>
.mm-view { height: 100%; display: flex; flex-direction: column; }
.mm-library { padding: 12px 16px; overflow: auto; position: relative; }
.ml-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; gap: 8px; }
.ml-head h3 { margin: 0; font-size: 16px; }
.ml-head-right { display: flex; align-items: center; gap: 8px; }
.ml-views { display: flex; align-items: center; }
.ml-views .view-on { color: var(--kh-brand, #409eff); font-weight: 600; }
.ml-head .recycle-on { color: #e6a23c; font-weight: 600; }
.ml-recycle-tip { font-size: 12px; color: var(--el-text-color-secondary); background: rgba(230, 162, 60, .1); border: 1px solid rgba(230, 162, 60, .3); border-radius: 8px; padding: 8px 12px; margin-bottom: 12px; }
.ml-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; }
.ml-card { position: relative; border: 1px solid var(--el-border-color); border-radius: 10px; padding: 14px; cursor: pointer; background: var(--el-bg-color); transition: box-shadow .15s; }
.ml-card:hover { box-shadow: 0 3px 12px var(--el-box-shadow-light); }
.ml-card-pin { position: absolute; top: 8px; right: 10px; left: auto; font-size: 14px; }
.ml-title { font-weight: 600; margin-bottom: 6px; color: var(--el-text-color-primary); }
.ml-meta { font-size: 12px; color: var(--el-text-color-secondary); }
.ml-tags { margin-top: 6px; display: flex; flex-wrap: wrap; gap: 4px; }
.ml-tags, .ml-row-tags { font-size: 11px; color: var(--kh-brand, #409eff); background: rgba(64, 158, 255, .08); border-radius: 4px; padding: 1px 6px; width: fit-content; }
.ml-del { position: absolute; bottom: 8px; right: 10px; top: auto; color: var(--el-text-color-placeholder); font-size: 12px; display: none; }
.ml-card:hover .ml-del { display: block; }
.ml-empty { color: var(--el-text-color-secondary); text-align: center; padding: 60px 0; }
.ml-list { display: flex; flex-direction: column; border: 1px solid var(--el-border-color); border-radius: 10px; overflow: hidden; }
.ml-row { display: flex; align-items: center; gap: 10px; padding: 7px 12px; border-bottom: 1px solid var(--el-border-color); cursor: pointer; font-size: 13px; line-height: 1.4; }
.ml-row:last-child { border-bottom: none; }
.ml-row:hover { background: rgba(64, 158, 255, .05); }
.ml-row-pin { width: 18px; flex: none; text-align: center; }
.ml-row-ico { flex: none; color: var(--kh-brand, #409eff); display: inline-flex; align-items: center; }
.ml-row-title { font-weight: 500; color: var(--el-text-color-primary); flex: none; max-width: 40%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ml-row-tags { flex: none; }
.ml-row-meta { font-size: 12px; color: var(--el-text-color-secondary); flex: 1; min-width: 0; text-align: right; }
.ml-row-ops { flex: none; display: flex; gap: 2px; }
.ml-recycle-list { display: flex; flex-direction: column; border: 1px solid var(--el-border-color); border-radius: 10px; overflow: hidden; }
.ml-recycle-list .ml-row-title { max-width: none; }
/* 右键菜单 */
.ml-ctx { position: fixed; z-index: 200; background: var(--el-bg-color); border: 1px solid var(--el-border-color); border-radius: 8px; box-shadow: 0 6px 20px rgba(0, 0, 0, .12); padding: 4px; min-width: 150px; }
.ml-ctx-item { padding: 6px 12px; font-size: 13px; border-radius: 5px; cursor: pointer; color: var(--el-text-color-primary); }
/* 高亮行统一全局色（与浏览选中行/大纲高亮行一致） */
.ml-ctx-item:hover { background: var(--kh-brand, #409eff); color: #fff; }
.ml-ctx-item.danger { color: #e74c3c; }
.ml-ctx-item.danger:hover { background: #e74c3c; color: #fff; }
.ml-ctx-mask { position: fixed; inset: 0; z-index: 98; }

.mm-editor { height: 100%; display: flex; flex-direction: column; min-height: 0; }
.mm-toolbar { display: flex; align-items: center; gap: 6px; padding: 6px 12px; border-bottom: 1px solid var(--el-border-color); flex-wrap: nowrap; }
.mm-title-input { width: 170px; border: 1px solid var(--el-border-color); border-radius: 6px; padding: 4px 8px; font-size: 13px; outline: none; background: var(--el-bg-color); color: var(--el-text-color-primary); }
.mm-tools { display: flex; gap: 4px; margin-left: 6px; }
.mm-zoom { display: flex; align-items: center; gap: 2px; margin-left: auto; font-size: 12px; color: var(--el-text-color-regular); }
.mm-saved { font-size: 12px; color: #10b981; margin-left: 8px; white-space: nowrap; }
.mm-saved.err { color: #e74c3c; }

.mm-body { flex: 1; display: flex; min-height: 0; }
.mm-side { width: 170px; flex: none; overflow: auto; padding: 10px 12px; border-right: 1px solid var(--el-border-color); box-sizing: border-box; }
.mm-side-left { width: 170px; }
.mm-side-drag { width: 2px; flex: none; cursor: col-resize; background: var(--el-border-color); opacity: .5; }
.mm-side-drag:hover { opacity: 1; background: var(--kh-brand, #409eff); }
.ms-tabs { display: flex; gap: 2px; margin-bottom: 8px; border-bottom: 1px solid var(--el-border-color); }
.ms-tab { padding: 4px 12px; font-size: 13px; cursor: pointer; color: var(--el-text-color-regular); border-bottom: 2px solid transparent; margin-bottom: -1px; }
.ms-tab.on { color: var(--kh-brand, #409eff); border-bottom-color: var(--kh-brand, #409eff); font-weight: 600; }
.ms-title { font-weight: 600; font-size: 13px; margin-bottom: 10px; color: var(--el-text-color-primary); }
.ms-outline-count { font-weight: 400; color: var(--el-text-color-secondary); font-size: 12px; margin-left: 4px; }
/* 布局切换按钮组（左侧面板，紧凑按钮，正常文字高度） */
.ms-layout-btns { display: flex; flex-wrap: wrap; gap: 4px; width: 100%; }
.ms-layout-btns :deep(.el-radio-button) { flex: 1 1 31%; }
.ms-layout-btns :deep(.el-radio-button__inner) { font-size: 12px; padding: 7px 0; width: 100%; display: flex; align-items: center; justify-content: center; gap: 4px; line-height: 1; }
.ms-lb-icon { display: inline-flex; align-items: center; }
.mm-save-btn { margin-left: 8px; }
.ms-outline { display: flex; flex-direction: column; font-size: 13px; }
.ms-o-row { display: flex; align-items: center; gap: 4px; padding: 3px 6px; border-radius: 5px; cursor: pointer; color: var(--el-text-color-primary); line-height: 1.4; }
.ms-o-row:hover { background: rgba(64, 158, 255, .08); }
/* 大纲高亮行：使用全局标签底色（--kh-brand），白字增强对比度 */
.ms-o-row.on { background: var(--kh-brand, #409eff); color: #fff; }
.ms-o-row.on .ms-o-text { color: #fff; }
.ms-o-text { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ms-themes { display: flex; flex-direction: column; gap: 6px; }
.ms-theme { display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 6px; cursor: pointer; font-size: 13px; border: 1px solid transparent; color: var(--el-text-color-regular); }
.ms-theme.on { border-color: var(--kh-brand, #409eff); background: rgba(64, 158, 255, .06); }
.mt-swatch { width: 22px; height: 22px; border-radius: 6px; flex: none; border: 1px solid rgba(0, 0, 0, .08); box-shadow: 0 1px 3px rgba(0, 0, 0, .12); }
.ms-layout-row { display: flex; flex-wrap: wrap; gap: 2px; }
.ms-layout-row :deep(.el-radio-button__inner) { font-size: 12px; padding: 4px 8px; }
.ms-font-size { width: 100%; }
.ms-colors { display: flex; flex-wrap: wrap; gap: 8px; }
.ms-color { width: 22px; height: 22px; border-radius: 50%; cursor: pointer; border: 2px solid transparent; }
.ms-color.on { border-color: #333; }
.ms-shapes { display: flex; flex-wrap: wrap; gap: 6px; }
.ms-shape { padding: 3px 8px; border: 1px solid var(--el-border-color); border-radius: 6px; font-size: 12px; cursor: pointer; color: var(--el-text-color-regular); }
.ms-shape.on { border-color: var(--kh-brand, #409eff); color: var(--kh-brand, #409eff); }
.ms-tip { font-size: 12px; color: var(--el-text-color-secondary); line-height: 1.7; }
.ms-label { color: var(--el-text-color-regular); }

.mm-canvas { flex: 1; min-width: 0; overflow: hidden; position: relative; background: var(--el-bg-color); }
.mm-host { width: 100%; height: 100%; }
/* 系统深色时画布底色跟随深色主题（SMM 容器默认浅色 #fafafa，需强制覆盖） */
:global(.dark) .mm-host { background: #1e222b; }
.mm-host :deep(.smm-container) { width: 100%; height: 100%; }
.mm-dialog-tip { font-size: 12px; color: var(--el-text-color-secondary); margin: 0 0 10px; line-height: 1.6; }
.mm-export { margin-left: 4px; }
.mm-import-input { display: none; }

/* ===== simple-mind-map 外观修正 ===== */
/* 1) 节点文字垂直居中：消除富文本 <p> 默认上下 margin 导致的文字偏下溢出 */
.mm-host :deep(.smm-node p),
.mm-host :deep(.smm-generalization-node p),
.mm-host :deep(.smm-richtext-node-wrap p) {
  margin: 0;
  line-height: 1.5;
}
.mm-host :deep(.smm-richtext-node-wrap) {
  padding: 0;
  display: flex;
  /* 纵向排列：flex 容器内多个 <p>（多行富文本）需换行堆叠，而不是横向压成一行 */
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  box-sizing: border-box;
  /* 保留 \n 换行（概要/节点含换行文本时按行显示；也让 SMM 测高 div 正确撑高） */
  white-space: pre-line;
}
.mm-host :deep(.smm-richtext-node-wrap > *),
.mm-host :deep(.smm-richtext-node-wrap .smm-richtext-node-content) {
  max-width: 100%;
  word-break: break-word;
}
/* 2) 关联线细线（主题已配置 width=1.5，此处兜底防覆盖） */
.mm-host :deep(.smm-associative-line-container path),
.mm-host :deep(.smm-associative-line-container line) {
  stroke-width: 1.5 !important;
}
/* 激活节点边框调细（hoverRect 默认无 stroke-width，SVG 默认 1；用户反馈偏粗，统一 0.8） */
.mm-host :deep(.smm-hover-node) { stroke-width: 0.8 !important; }
/* 2.1) 关联线点击热区：SMM 的 clickPath 是透明描边 path，SVG 默认 pointer-events
       不命中透明描边，导致无法点选/删除/编辑文字；改为按描边区域接收事件。
       线文字（text）不拦截点击（文字编辑走 clickPath 的 dblclick） */
.mm-host :deep(.smm-associative-line-container path) {
  pointer-events: stroke;
  cursor: pointer;
}
.mm-host :deep(.smm-associative-line-container text) {
  pointer-events: none;
}
/* 3) 概要节点 / 边界文字行高紧凑；概要多行文本（\n）按换行显示
   注：概要节点类名形如 smm-node generalization_{nodeId} */
.mm-host :deep(.smm-node[class*="generalization_"]) { font-size: 12px; }
.mm-host :deep(.smm-node[class*="generalization_"] p),
.mm-host :deep(.smm-node[class*="generalization_"] .smm-richtext-node-wrap) { white-space: pre-line; }
.mm-host :deep(.smm-outer-frame-text) { font-size: 12px; }
.mm-host :deep(.smm-associative-line-text) { font-size: 11px; }
.ms-desc-input { width: 100%; }
.ms-desc-input :deep(.el-textarea__inner) { font-size: 12px; line-height: 1.5; }
</style>

<style>
/* 全局样式：SMM 动态注入的 SVG/foreignObject 元素不受 scoped 作用 */
/* 节点内描述（幕布式）：渲染在节点矩形内部底部，自动换行、弱化样式 */
.kh-node-desc-inner {
  font-size: 11px;
  color: var(--el-text-color-secondary, #8a8f98);
  line-height: 1.45;
  user-select: none;
  pointer-events: none;
  overflow: hidden;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.kh-node-desc-inner div {
  white-space: normal;
  word-break: break-all;
  overflow-wrap: anywhere;
  width: 100%;
}
</style>
