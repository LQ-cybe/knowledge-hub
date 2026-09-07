@echo off
chcp 65001 >nul
title Knowledge Hub 一键启动
cd /d "%~dp0"

echo ============================================
echo   Knowledge Hub - 轻笺类本地知识管理软件
echo ============================================
echo.

echo [1/3] 启动后端服务 (127.0.0.1:5177) ...
start "KnowledgeHub-Server" cmd /k "cd /d %~dp0server && npm run start"
timeout /t 3 /nobreak >nul

echo [2/3] 启动前端界面 (localhost:5178) ...
start "KnowledgeHub-Web" cmd /k "cd /d %~dp0web && npm run dev"
timeout /t 5 /nobreak >nul

echo [3/3] 打开浏览器 ...
start "" http://localhost:5178
echo.
echo ✅ 已启动。关闭时请直接关闭弹出的两个命令行窗口。
echo.
pause
