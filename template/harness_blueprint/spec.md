# 技术规格总纲

> 全局总纲 + specs/ 目录索引。需求变更时改。
> 各功能当前生效规格在 specs/{feature}.md，每 task 闭环时整理更新。

## 技术栈
- Web: {前端框架/语言}
- API: {后端框架/语言}
- DB: {数据库}

## 架构分层
（简要，详见 architecture.md）

## 安全边界
- 浏览器/客户端不接触后端高权限密钥（service key 等）
- API Key 加密存储，不明文返回
- secret 由环境提供，不硬编码

## 功能规格索引

> 示例格式（占位，真实项目按 task 闭环时生成 specs/ 下文件后填真实链接）。

| 功能 | 规格 | 负责 task |
|---|---|---|
| 注册登录 | specs/auth.md | T5, T26, T32 |
| 用户设置 | specs/user_settings.md | T6 |
| ... | ... | ... |
