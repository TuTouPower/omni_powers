: << 'CMDBLOCK'
@echo off
REM Polyglot wrapper (CMD + bash) — 借鉴 superpowers run-hook.cmd
REM CMD 路径：Git for Windows 提供 bash.exe + cygpath
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_NAME=%~1"
if "%SCRIPT_NAME%"=="" (
  echo [run-hook] missing script name ^(e.g. run-hook.cmd pre_tool_use.sh^) >&2
  exit /b 1
)
"C:\Program Files\Git\bin\bash.exe" -l -c "cd \"$(cygpath -u \"%SCRIPT_DIR%\")\" && \"./%SCRIPT_NAME%\""
exit /b %errorlevel%
CMDBLOCK
# Unix shell runs from here (CMD skipped the heredoc above)
# bash 路径：: 是 no-op，<< 'CMDBLOCK' 是 heredoc，消费掉 CMD 代码
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="${1:?用法: run-hook.cmd <hook-name> [args...]（hook-name 不带 .sh，wrapper 自动补）}"
shift
exec "${SCRIPT_DIR}/${SCRIPT_NAME}.sh" "$@"
