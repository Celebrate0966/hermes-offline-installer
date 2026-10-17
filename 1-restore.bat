@echo off
setlocal
pushd "%~dp0"

echo.
echo  Hermes offline restore
echo  Offline bundle : %~dp0
echo.
echo  Default: repo goes to %%LOCALAPPDATA%%\hermes\hermes-agent
echo.
set "REPOPATH="
set /p CUSTOM=Put the repo on another drive? (y/N): 
if /i "%CUSTOM%"=="y" (
  set /p "REPOPATH=Enter full repo path (e.g. D:\HermesData\hermes-agent): "
  echo %REPOPATH%> "%~dp0._repopath.txt"
  powershell -ExecutionPolicy Bypass -File "%~dp0restore.ps1" -RepoRoot "%REPOPATH%"
) else (
  if exist "%~dp0._repopath.txt" del "%~dp0._repopath.txt"
  powershell -ExecutionPolicy Bypass -File "%~dp0restore.ps1"
)

echo.
popd
pause
