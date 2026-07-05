: << 'CMDBLOCK'
@echo off
REM Polyglot wrapper (CMD + bash) — 借鉴 superpowers run-hook.cmd
REM CMD 路径：Git for Windows 提供 bash.exe + cygpath
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_NAME=%~1"
if "%SCRIPT_NAME%"=="" (
  echo [run-hook] missing script name ^(e.g. run-hook.cmd pre_tool_use^) >&2
  exit /b 1
)
REM hook name 可不带 .sh；CMD 与 bash 分支都自动补后缀
set "HOOK_SCRIPT=%SCRIPT_NAME%"
if /I not "%HOOK_SCRIPT:~-3%"==".sh" set "HOOK_SCRIPT=%HOOK_SCRIPT%.sh"

REM 找 bash.exe：优先 CLAUDE_CODE_GIT_BASH_PATH（Claude Code 设），fallback 默认位置 + PATH
set "BASH_EXE=%CLAUDE_CODE_GIT_BASH_PATH%"
if "%BASH_EXE%"=="" set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_EXE%" (
  for /f "delims=" %%i in ('where bash.exe 2^>nul') do (set "BASH_EXE=%%i" & goto :found)
  echo [run-hook] bash.exe not found. Install Git for Windows or set CLAUDE_CODE_GIT_BASH_PATH >&2
  exit /b 127
)
:found
"%BASH_EXE%" -l -c "cd \"$(cygpath -u \"%SCRIPT_DIR%\")\" && \"./%HOOK_SCRIPT%\""
exit /b %errorlevel%
CMDBLOCK
# Unix shell runs from here (CMD skipped the heredoc above)
# bash 路径：: 是 no-op，<< 'CMDBLOCK' 是 heredoc，消费掉 CMD 代码
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="${1:?用法: run-hook.cmd <hook-name> [args...]（hook-name 可不带 .sh，wrapper 自动补）}"
shift
case "$SCRIPT_NAME" in
    *.sh) HOOK_SCRIPT="$SCRIPT_NAME" ;;
    *) HOOK_SCRIPT="${SCRIPT_NAME}.sh" ;;
esac
exec "${SCRIPT_DIR}/${HOOK_SCRIPT}" "$@"
