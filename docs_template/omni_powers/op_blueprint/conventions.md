# 编码约定

> 职责（design §3.3）：**编码独占**——命名/风格/文件组织/浏览器 API/不可变性/日志规则/适配器开发步骤。
> 不在此：技术栈（→ architecture.md）、业务不变量（→ domain.md）。

## 命名
- 变量/函数/文件/目录：snake_case
- 例外：CLAUDE.md / README.md 等大写文件名保持
- 组件：PascalCase；hook：use 前缀

## 风格
- 缩进 4 空格，禁止 tab
- 使用项目既有语言版本与依赖工具；找不到时标 NEEDS CLARIFICATION
- 日志优先，禁止 print/console.log 调试输出

## 文件组织
- 按功能/领域组织，不按文件类型
- 高 cohesion 低 coupling

## 浏览器 API
- {浏览器/运行时 API 使用边界；没有前端则写“不适用”}

## 不可变性
- 优先返回新对象/新集合，避免原地修改
- 必须原地修改时说明原因与影响范围

## 日志规则
- 使用项目既有 logger
- 日志包含排障上下文，不记录 secret/token/password

## 适配器开发步骤
1. 先定义外部系统边界与失败模式
2. 用最小接口封装调用点
3. 加输入/输出校验与错误映射
4. 补测试或验收信号

## 安全（编码相关）
- secret 由环境或 secret manager 提供，不硬编码
- 浏览器不接触 service key
- 外部输入在边界校验

## 修改代码后
- 检查 docs/ 和 CLAUDE.md 是否受影响，一并更新
