@echo off
setlocal
pushd "%~dp0"

echo.
echo  Starting the electron cache watcher.
echo  Keep this window OPEN, then double-click Hermes-Setup.exe.
echo  Close this window only after the installer reaches "complete".
echo.

set "REPOPATH="
if exist "%~dp0._repopath.txt" (
  set /p REPOPATH=<"%~dp0._repopath.txt"
  echo Using repo path from step 1: %REPOPATH%
)
if defined REPOPATH (
  powershell -ExecutionPolicy Bypass -File "%~dp0watch-electron-cache.ps1" -RepoRoot "%REPOPATH%"
) else (
  powershell -ExecutionPolicy Bypass -File "%~dp0watch-electron-cache.ps1"
)

popd
pause
