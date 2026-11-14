# 文档开发

本目录为 VuePress 2 文档站（对外权威在公共仓 `cloudwebsite/kazhan`）。

```bash
cd docs
yarn install
yarn docs:dev    # 本地预览（可切换白天/黑夜看代码块对比度）
yarn docs:build  # 输出到 .vuepress/dist
```

Windows 也可双击 `bin/run.cmd` / `bin/package.cmd`。

## 约定

| 项 | 说明 |
|---|---|
| 导航 | `.vuepress/config.ts` |
| 首页 | 根目录 `README.md` |
| 白天模式代码块 | `.vuepress/styles/index.scss`（浅底深字）；Shiki 浅色主题 `min-light` |
| 读者 | 站长 / 运维小白能看懂；少写实现自嗨 |
| 产品名 | 卡栈 / kazhan；勿写旧产品出处品牌 |
| 对接品牌 | 支付 / 货源等第三方名称可保留 |
| 发行说明 | changelog 只挂当前 v1.0 线 |

## 文档结构（对外）

| 目录 | 内容 |
|---|---|
| `guide/` | 部署、首次配置、系统设置全览、多站点 |
| `features/` | 商品订单、会员、货源、营销、分站等 |
| `payment/` | 支付总览 + 渠道专题 |
| `themes/` | 主题 |
| `operations/` | 更新、备份、2FA、低库存 |
| `changelog/` + `releases/` | 更新日志 |

推送到公共仓见私有仓 `dev-docs/git推送/公共仓文档推送.md`。
