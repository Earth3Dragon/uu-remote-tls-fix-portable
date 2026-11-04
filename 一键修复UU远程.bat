@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ==============================================
echo   UU Remote TLS Fix (Portable) - Install
echo ==============================================
echo.
echo A UAC prompt will appear. Click YES to continue.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0install.ps1' -Verb RunAs"
echo.
echo Installer launched in a separate window.
timeout /t 3 >nul
exit /b 0
