@echo off
chcp 65001 >nul
set "PYTHON=python"
set "PIP=pip"
echo ========================================
echo HAMLOG HTTP API Server Setup
echo ========================================
echo.

REM HAMLOG確認
REM 環境変数が未設定ならデフォルトパスを設定
if "%HAMLOG_EXE%"=="" (
    set "HAMLOG_EXE=C:\HAMLOG\hamlogw.exe"
)

if not exist "%HAMLOG_EXE%" (
    echo [ERROR] HAMLOG not found at %HAMLOG_EXE%
    echo Please install HAMLOG from https://hamlog.sakura.ne.jp/
    echo Or set HAMLOG_EXE environment variable to the correct path
    pause
    exit /b 1
)

REM HAMLOG二重起動チェック
tasklist /FI "IMAGENAME eq hamlogw.exe" 2>NUL | find /I /N "hamlogw.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [INFO] HAMLOG is already running
) else (
    echo [INFO] Starting HAMLOG...
    start "" "%HAMLOG_EXE%"
    timeout /t 2 /nobreak >nul
)

REM Python確認
%PYTHON% --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found
    echo Please install Python 3.8+ from https://www.python.org/
    pause
    exit /b 1
)

echo [OK] Python found

REM Flask確認・インストール
%PYTHON% -c "import flask" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Installing Flask...
    %PIP% install flask
    if errorlevel 1 (
        echo [ERROR] Failed to install Flask
        pause
        exit /b 1
    )
)

echo [OK] Flask installed

REM Flask-CORS確認・インストール
%PYTHON% -c "import flask_cors" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Installing Flask-CORS...
    %PIP% install flask-cors
    if errorlevel 1 (
        echo [ERROR] Failed to install Flask-CORS
        pause
        exit /b 1
    )
)

echo [OK] Flask-CORS installed

REM AutoHotkey確認
if not exist "C:\Program Files\AutoHotkey\AutoHotkey.exe" (
    echo [WARNING] AutoHotkey not found at default location
    echo Please install from https://www.autohotkey.com/
    echo Or update the path in hamlog_api_server.py
    pause
)

echo [OK] AutoHotkey found

REM 設定確認
echo.
echo ========================================
echo Configuration Check
echo ========================================
echo.
echo Please verify the following paths in hamlog_api_server.py:
echo   - AHK_SCRIPT: Path to hamlog_api.ahk
echo   - AUTOHOTKEY: Path to AutoHotkey.exe
echo.
echo Current directory: %CD%
echo.

REM サーバー起動確認
echo ========================================
echo Ready to Start Server
echo ========================================
echo.
echo.
echo Starting server at http://localhost:8669
echo Press Ctrl+C to stop
echo.
%PYTHON% hamlog_api_server.py