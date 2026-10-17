@echo off
REM 在一台已经装好 Hermes 的机器上，把它倒成离线包（约 4 GB）。
REM 双击即可，无需参数。输出默认在本目录下的 HermesOffline\。
REM 换输出位置：把这一行改成
REM   powershell -ExecutionPolicy Bypass -File "%%~dp0export.ps1" -Output D:\HermesOffline
title Hermes 离线包导出
powershell -ExecutionPolicy Bypass -File "%~dp0export.ps1"
echo.
echo 导出完成。按任意键关闭。
pause >nul
