@echo off
title Witcher 3 launcher (GPU fix)
cd /d "%~dp0"

tasklist /fi "imagename eq steam.exe" | find /i "steam.exe" >nul
if errorlevel 1 (
  echo Steam isn't running. Start Steam, then run this again.
  pause
  exit /b 1
)

tasklist /fi "imagename eq witcher3.exe" | find /i "witcher3.exe" >nul
if not errorlevel 1 (
  echo Witcher 3 is already running. Quit it first, then run this again.
  pause
  exit /b 1
)

if not exist "force_witcher_gpu.py" (
  echo force_witcher_gpu.py isn't in this folder. See README.md.
  pause
  exit /b 1
)

echo Launching Witcher 3 with the GPU fix. Leave this window open until you quit the game.
python -u force_witcher_gpu.py
if errorlevel 1 (
  echo.
  echo The launcher hit an error. See the message above.
  pause
)
