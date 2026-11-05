@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter SDK was not found. Install Flutter and add it to PATH.
  pause
  exit /b 1
)
if not exist "config\supabase.local.json" (
  echo Missing config\supabase.local.json. Restore your Supabase URL and publishable key.
  pause
  exit /b 1
)
call flutter pub get
if errorlevel 1 (echo Flutter dependencies failed to install.& pause & exit /b 1)
call flutter run -d chrome --web-hostname=localhost --web-port=8080 --dart-define-from-file=config/supabase.local.json
pause
