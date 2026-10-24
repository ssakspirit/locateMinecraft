@echo off
rem Minecraft world folder finder - double-click to run
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0LocateMinecraft.ps1"
