@echo off
setlocal
cd /d "%~dp0"
where dotnet >nul 2>nul
if errorlevel 1 (
  echo .NET 9 SDK was not found. Install the .NET 9 SDK and add dotnet to PATH.
  pause
  exit /b 1
)
dotnet restore
if errorlevel 1 (echo Restore failed.& pause & exit /b 1)
dotnet run --launch-profile https
pause
