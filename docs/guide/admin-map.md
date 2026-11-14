# 后台菜单对照

按当前后台左侧菜单整理（权限不足时部分菜单/页签不可见）。

![系统设置页示意](/images/settings-overview.png)

---

## 一级菜单

| 菜单 | 路径 | 做什么 | 文档 |
|---|---|---|---|
| 运营概览 | `/home` | 今日/近7天/近30天支付额、订单、毛利、趋势与分站对比 | [运营概览](../features/dashboard.md) |
| 用户管理 | `/user` | 会员列表、启停、指定等级等 | [会员与钱包](../features/members.md) |
| 商品管理 | `/product` | 商品、SKU、发货来源、上架与评价 | [商品与库存](../features/commerce.md) |
| 商品分类 | `/category` | 分类树与前台展示顺序 | [商品与库存](../features/commerce.md) |
| 内容管理 | `/content` | 文章/公告、首页横幅 | [内容管理](../features/content.md) |
| 营销管理 | `/marketing` | 会员等级、优惠券、秒杀/促销、抽奖、免费领取 | [营销功能](../features/marketing.md) |
| 分站管理 | `/reseller` | 白标分站开通与管理 | [分站](../features/subsite.md) |
| 卡密库存 | `/inventory` | 本地卡密入库、锁定、清理 | [商品与库存](../features/commerce.md) |
| 订单管理 | `/order` | 查单、补发、待发货、实物发货 | [订单处理](../features/orders.md) |
| 工单管理 | `/ticket` | 售前/售后工单、SLA、会话回复 | [工单管理](../features/tickets.md) |
| 支付渠道 | `/payment-channel` | 添加/启用收款驱动、用途开关 | [支付总览](../payment/) |
| 员工管理 | `/staff` | 员工账号、角色、权限点、重置密码/TOTP | [员工与权限](../features/staff.md) |
| 钱包管理 | `/wallet` | 余额/积分流水、调账、提现审核、礼品卡 | [会员与钱包](../features/members.md) |
| 渠道管理 | `/channel` | 货源连接、健康评分、供货账号、采购单、对账 | [货源对接](../features/supply.md) |
| 系统设置 | `/settings` | 参数、货币、审计、数据清理、在线更新 | [系统设置全览](./settings.md) |

---

## 带页签的页面

| 页面 | 页签 |
|---|---|
| 内容管理 | 文章管理 · 首页横幅 |
| 营销管理 | 会员等级 · 优惠券 · 秒杀/促销 · 抽奖活动 · 免费领取 |
| 钱包管理 | 账单流水 · 提现审核 · 礼品卡 |
| 渠道管理 | 货源渠道 · 健康评分 · 供货账号 · 采购单 · 明细对账 |
| 系统设置（外层） | **参数设置** · **货币** · **审计日志** · **数据清理** · **系统更新** |
| 系统设置 → 参数设置（内层） | 站点基础 · 模板 · 推荐位 · 页脚配置 · 交易 · 工单/通知通道 · 安全 · 运维 · 充值 · 供货充值 · 积分 · 提现 · 分销设置 · 分站 · 货源 · 对象存储 · 前台工具 · 邮件短信 · 客户代码 · 语言货币 |

深链示例：系统设置货币页可用 `?tab=currency`；渠道对账可用 `?tab=reconcile`。

---

## 界面速览

下列截图来自当前后台实机界面（空数据站布局相同）。各功能页文档内另有一句操作说明。

**运营概览** — KPI、趋势、支付方式分布与待办。

![运营概览](/images/admin-home.png)

**商品管理** — 分类树 + 上架/库存筛选；卡密在「卡密库存」。

![商品管理](/images/admin-product.png)

**订单管理** — 状态筛选、补单与待发货。

![订单管理](/images/admin-order.png)

**营销管理** — 会员等级 / 优惠券 / 秒杀 / 抽奖 / 免费领取。

![营销管理](/images/admin-marketing.png)

**支付渠道** — 添加驱动、启停与用途。

![支付渠道](/images/admin-payment.png)

**钱包管理** — 流水、调账、提现审核、礼品卡。

![钱包管理](/images/admin-wallet.png)

**渠道管理** — 货源、健康评分、供货账号、采购与对账。

![渠道管理](/images/admin-channel.png)

**工单管理** — 售前/售后工作台与 SLA。

![工单管理](/images/admin-ticket.png)

**员工管理** — 账号、角色与行内权限。

![员工管理](/images/admin-staff.png)

**内容管理** — 文章公告与首页横幅。

![内容管理](/images/admin-content.png)

**系统设置** — 参数 / 货币 / 审计 / 数据清理 / 更新。

![系统设置](/images/settings-overview.png)

---

## 建议上手顺序

1. [部署](./deploy.md) → [装完先配这些](./first-config.md)  
2. 支付渠道 → 商品/卡密 → 小额测试单  
3. 再开货源、营销、分站、工单通知  

