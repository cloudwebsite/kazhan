# 卡栈产品命名

| 项 | 约定 |
|---|---|
| 产品显示名 | 卡栈 |
| 英文 / 仓库 / 二进制 | kazhan（`cloudwebsite/kazhan`） |
| License 版权行 | Copyright (c) 2026 卡栈（kazhan） |
| Go module | `github.com/cloudwebsite/kazhan/server` |
| 默认更新源仓库 | `cloudwebsite/kazhan` |
| 环境变量前缀 | `KAZHAN_*` |
| 默认安装目录 | `/opt/kazhan` |
| TOTP Issuer | 卡栈 |
| 本站货源协议 | `kazhan` |
| 对接他站 Supply 线 | 协议码 `zcard`（对接品牌，非本产品名） |

清理总账：仓库父级 [`docs/ZCARD残留排查与替换清单.md`](../../../docs/ZCARD残留排查与替换清单.md)。

## 已完成

- 用户可见默认文案、SEO 回落、主题 Author、邮件/通知主题、CLI 帮助
- 环境变量、安装脚本、Docker Compose 服务名与路径统一为 `KAZHAN_*` / `kazhan`
- 前端 / 主题技术前缀 `kazhan-*`；删除 `zcard-install.sh`
- Go module / 更新源 / 产品命名表

## 保留

对接协议码与后台「ZCard 协议（对接）」类选项文案（对接品牌，见总账 §5）。

历史 `docs/releases/*` 为档案，不随产品改写。
