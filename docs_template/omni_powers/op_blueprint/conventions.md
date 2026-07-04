# 编码约定

> 职责（design §3.3）：**编码独占**——命名/风格/文件组织/浏览器 API/不可变性/日志规则/适配器开发步骤。
> 不在此：技术栈（→ architecture.md）、业务不变量（→ domain.md）。

## 命名
- 变量/函数/文件/目录：snake_case
- 例外：CLAUDE.md / README.md 等大写文件名保持
- 组件：PascalCase；hook：use 前缀

## 风格
- 缩进 4 空格，禁止 tab
- Python 3.13，禁止全局 pip，用 venv
- 日志优先，禁止 print/console.log 调试输出

## 文件组织
- 按功能/领域组织，不按文件类型
- 高 cohesion 低 coupling

## 安全（编码相关）
- secret 由环境提供，不硬编码
- API Key 加密存储
- 浏览器不接触 service key

## 修改代码后
- 检查 docs/ 和 CLAUDE.md 是否受影响，一并更新
