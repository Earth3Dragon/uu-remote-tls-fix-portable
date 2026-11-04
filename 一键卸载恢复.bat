@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ==============================================
echo   UU Remote TLS Fix (Portable) - Uninstall
echo ==============================================
echo.
echo A UAC prompt will appear. Click YES to continue.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0uninstall.ps1' -Verb RunAs"
echo.
echo Uninstaller launched in a separate window.
timeout /t 3 >nul
exit /b 0
