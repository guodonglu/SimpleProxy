---
name: simpleproxy
description: Manage and control SimpleProxy, the ultra-lightweight native Swift macOS proxy tool. Operate via CLI (`simpleproxy`) or Local REST API on `127.0.0.1:9898/_simpleproxy/api/` — view proxy status, add/toggle/delete proxy rules (Host redirect, Mock API resBody, Remote URL rewrite, Status code 503/404, Headers injection), bulk sync configurations, switch appearance themes (light/dark/system). Use when the user mentions SimpleProxy, simpleProxy, Whistle proxy, local API mocking, domain hosts mapping, web debugging, or asks to configure local macOS proxy rules.
license: MIT
compatibility: Requires macOS with SimpleProxy.app installed and running, and `simpleproxy` CLI (Python 3.9+) in PATH.
metadata:
  repo: "https://github.com/guodonglu/SimpleProxy"
---

# SimpleProxy Skill：极简 Swift 原生 macOS 代理控制

SimpleProxy 是基于 Swift 6.3 原生开发的 macOS 超轻量级代理工具，体积仅 **1.2 MB**，运行内存约 **10 MB**，冷启动 **2.9 ms**，采用 macOS / iOS 27 Liquid Glass（流体毛玻璃）与 HIG 设计规范，完全兼容 Whistle 规则语法。

SimpleProxy 独立监听在 `127.0.0.1:9898`，**绝不侵入 macOS 全局网络设置**，与用户的 Clash / Surge / VPN 代理 100% 隔离安全运行。

本 Skill 支持通过命令行工具 `simpleproxy` 或直接调用本地 REST API 控制 SimpleProxy。

---

## 0. 检查服务状态

```bash
simpleproxy status
```
- 若状态为 `RUNNING`，即可正常执行规则增删改查；
- 若连接失败，可通过 `open SimpleProxy.app` 启动应用。

---

## 1. 常用 CLI 流程

| 场景 | 命令 |
|---|---|
| 查看代理运行状态及命中统计 | `simpleproxy status` |
| 列出当前全部代理规则 | `simpleproxy rules` |
| 快速添加 Host 映射 | `simpleproxy add api.dev.com 127.0.0.1:3000 --type host -c "本地开发"` |
| 快速添加 Mock 接口数据 | `simpleproxy add api.dev.com/user '{"code":0,"msg":"ok"}' --type resBody` |
| 模拟熔断/报错状态码 | `simpleproxy add error.example.com 503 --type statusCode` |
| 切换某条规则开关 (启用/停用) | `simpleproxy toggle 1` / `simpleproxy toggle 1 --disable` |
| 删除指定规则 | `simpleproxy delete 1` |
| 导入/覆盖全部规则配置 | `simpleproxy sync --file ./my_rules.txt` |
| 切换外观模式 (浅色 / 深色 / 系统) | `simpleproxy theme light` / `dark` / `system` |

---

## 2. 本地 REST API 接口定义

服务端运行在 `127.0.0.1:9898`，支持以下 HTTP 接口：

- `GET /_simpleproxy/api/status` - 获取服务运行状态
- `GET /_simpleproxy/api/rules` - 获取所有规则列表
- `POST /_simpleproxy/api/rules/add` - 添加规则
- `POST /_simpleproxy/api/rules/toggle` - 切换规则开关
- `POST /_simpleproxy/api/rules/delete` - 删除指定规则
- `POST /_simpleproxy/api/config/sync` - 全量同步规则文本
- `POST /_simpleproxy/api/theme` - 切换应用外观主题
