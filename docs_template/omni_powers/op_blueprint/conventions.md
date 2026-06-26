# 编码约定

> 命名、风格、技术栈约束。全员遵守。

## 命名
- 变量/函数/文件/目录：snake_case
- 例外：CLAUDE.md / README.md 等大写文件名保持
- 组件：PascalCase；hook：use 前缀

## 风格
- 缩进 4 空格，禁止 tab
- Python 3.13，禁止全局 pip，用 venv
- 日志优先，禁止 print/console.log 调试输出

## 技术栈
- Web: {前端框架}
- API: {后端框架}
- DB: {数据库}

## 安全
- secret 由环境提供，不硬编码
- API Key 加密存储
- 浏览器不接触 service key

## 修改代码后
- 检查 docs/ 和 CLAUDE.md 是否受影响，一并更新
