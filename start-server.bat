@echo off
title Executive Project Tracker - Local Server
echo ==========================================================
echo    Starting Executive Project Tracker Local Server...
echo ==========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
