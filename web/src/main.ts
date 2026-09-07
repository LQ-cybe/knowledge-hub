import { createApp } from 'vue';
import ElementPlus from 'element-plus';
import 'element-plus/dist/index.css';
import 'element-plus/theme-chalk/dark/css-vars.css';
import './theme'; // 初始化主题（跟随系统/手动三态）
import App from './App.vue';

createApp(App).use(ElementPlus).mount('#app');
