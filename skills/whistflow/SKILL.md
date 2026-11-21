---
name: whistflow
description: Manage and control WhistFlow, the lightweight native Swift macOS proxy tool. Operate via CLI (`whistflow`) or Local REST API on `127.0.0.1:9898/_whistflow/api/` — view proxy status, add/toggle/delete Whistle rules (Host redirect, Mock API resBody, Remote URL rewrite, Status code 503/404, Headers injection), bulk sync configurations, switch appearance themes (light/dark/system) and view modes (visual/config). Use when the user mentions WhistFlow, Whistle proxy, local API mocking, domain hosts mapping, web debugging, or asks to configure local macOS proxy rules.
license: MIT
compatibility: Requires macOS with WhistFlow.app installed and running, and `whistflow` CLI (Python 3.9+) in PATH.
metadata:
  repo: "https://github.com/guodonglu/WhistFlow"
---

# WhistFlow Skill：极简 Swift 原生 macOS 代理控制

WhistFlow 是基于 Swift 6.3 原生开发的 macOS 超轻量级代理工具，体积仅 **1.2 MB**，运行内存约 **10 MB**，冷启动 **2.9 ms**，采用 macOS 26/27 Liquid Glass（流体毛玻璃）与 HIG 设计规范，完全兼容 Whistle 规则语法。

WhistFlow 独立监听在 `127.0.0.1:9898`，**绝不侵入 macOS 全局网络设置**，与用户的 Clash / Surge / VPN 代理 100% 隔离安全运行。

本 Skill 支持通过命令行工具 `whistflow` 或直接调用本地 REST API 控制 WhistFlow。

---

## 0. 检查服务状态

```bash
whistflow status
```
- 若状态为 `RUNNING`，即可正常执行规则增删改查；
- 若连接失败，可通过 `open /Applications/WhistFlow.app` 或打开本地 WhistFlow.app 启动应用。

---

## 1. 常用 CLI 流程

| 场景 | 命令 |
|---|---|
| 查看代理运行状态及命中统计 | `whistflow status` |
| 列出当前全部代理规则（表格格式） | `whistflow list` 或 `whistflow ls` |
| 快速添加 Host 映射 | `whistflow add api.dev.com 127.0.0.1:3000` |
| 快速添加 Mock 接口数据 | `whistflow add api.dev.com/user "resBody://({'code':0,'msg':'ok'})"` |
| 快速添加远程重定向 | `whistflow add cdn.example.com/lib https://cdn.jsdelivr.net` |
| 模拟熔断/报错状态码 | `whistflow add error.example.com statusCode://503` |
| 切换某条规则开关 (启用/停用) | `whistflow toggle <pattern>` 或 `whistflow toggle <UUID>` |
| 删除指定规则 | `whistflow rm <pattern>` 或 `whistflow rm <UUID>` |
| 查看完整 Whistle 配置文本 | `whistflow raw` |
| 导入/覆盖全部 Whistle 配置 | `cat my_rules.txt \| whistflow raw` |
| 切换外观模式 (浅色 / 深色 / 系统) | `whistflow theme light` / `dark` / `system` |
| 切换界面模式 (可视化 / 配置模式) | `whistflow mode visual` / `config` |
| 清空所有规则 | `whistflow clear` |

---

## 2. Whistle 常用规则语法速查

WhistFlow 原生解析 Whistle 规范语法（格式为 `<匹配模式> <操作符>`）：

1. **Hosts 域名/端口转发**：
   ```whistle
   api.dev.com 127.0.0.1:3000
   staging.service.internal 10.0.4.12:8080
   ```
2. **Map Local / Mock 接口返回**：
   ```whistle
   mock.dev.com/api/user resBody://({"id":1001,"name":"Antigravity","role":"admin"})
   ```
3. **Map Remote 远程路径重定向**：
   ```whistle
   cdn.example.com/static https://unpkg.com
   ```
4. **状态码注入 (模拟故障)**：
   ```whistle
   error.example.com statusCode://503
   forbidden.example.com statusCode://403
   ```
5. **通配符与路径匹配**：
   - 泛域名匹配：`*.test.com 127.0.0.1:8000`
   - 精确路径匹配：`api.company.com/v2/pay 127.0.0.1:9090`
   - 正则表达式匹配：`/^https?:\/\/.*\.test\.com\// 127.0.0.1:8080`

---

## 3. 本地 REST API (供 Agent / MCP 直接调用)

WhistFlow 内置本地管理 API，基准地址为：`http://127.0.0.1:9898/_whistflow/api`

### 1) 查看运行状态
```bash
curl -s http://127.0.0.1:9898/_whistflow/api/status
```
返回：
```json
{
  "status": "running",
  "port": 9898,
  "rules_count": 4,
  "total_requests": 12,
  "matched_requests": 5,
  "version": "1.0.0"
}
```

### 2) 获取所有规则
```bash
curl -s http://127.0.0.1:9898/_whistflow/api/rules
```

### 3) 添加规则
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"rule": "api.test.com 127.0.0.1:8000"}' \
  http://127.0.0.1:9898/_whistflow/api/rules/add
```

### 4) 开关切换规则
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"pattern": "api.test.com"}' \
  http://127.0.0.1:9898/_whistflow/api/rules/toggle
```

### 5) 删除规则
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"pattern": "api.test.com"}' \
  http://127.0.0.1:9898/_whistflow/api/rules/delete
```

### 6) 切换浅色/深色主题
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"mode": "light"}' \
  http://127.0.0.1:9898/_whistflow/api/appearance
```

---

## 4. 隔离与 Clash 协同验证规范

1. **绝对不要改动 macOS 系统的“网络代理”或网络偏好设置**。
2. WhistFlow 作为定向代理服务，仅供指定请求转发使用。若需向 WhistFlow 发起调试验证请求，必须使用单次显式指定代理：
   ```bash
   curl -x http://127.0.0.1:9898 http://<pattern>/path
   ```
3. 这样可确保宿主机上的 Clash、微信、开发工具等网络完全不受任何干扰。
