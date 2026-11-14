# 支付渠道配置手册

按后台「支付渠道 → 添加」各驱动的真实字段整理。通用步骤见 [支付总览](./)。

使用前请确认 [站点地址](../guide/settings.md) 为公网可访问地址。敏感字段已配置时留空表示不修改。

---

## 余额支付

- 驱动代码：`wallet`
- 说明：会员余额扣款；无需网关密钥。需启用渠道且会员有余额。

（无额外驱动字段，或仅启用即可）

---

## 虎皮椒支付

- 驱动代码：`xunhupay`
- 说明：虎皮椒微信 / 支付宝收款；不同 APPID 分别添加渠道，电脑扫码、手机跳转支付

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `appid` | APPID | text | 必填 | 虎皮椒后台的支付渠道 APPID。微信和支付宝请分别添加渠道并填写各自凭据。 |
| `appsecret` | APPSECRET | password | 必填·敏感 | 对应 APPID 的密钥，用于下单签名及回调验签 |
| `api_url` | 支付网关 | text | 选填 |  |

---

## 支付宝

- 驱动代码：`alipay`
- 说明：支付宝官方（RSA2）：一渠道勾选当面付/电脑网站/手机网站；收银台按端择优，默认当面付

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `app_id` | App ID | text | 必填 |  |
| `private_key` | 应用私钥 | textarea | 必填·敏感 | 粘贴密钥工具生成的应用私钥，支持裸 Base64 或完整 PEM（PKCS1/PKCS8）。已配置时留空保持不变。 |
| `alipay_public_key` | 支付宝公钥 | textarea | 必填·敏感 | 填写支付宝开放平台提供的支付宝公钥，支持裸 Base64 或完整 PEM；不要填写应用公钥或公钥证书。已配置时留空保持不变。 |
| `gateway` | 网关地址 | text | 选填 |  |
| `modes` | 支付模式 | select | 必填 | 须勾选当面付（门槛低，电脑手机均可扫码）。电脑网站/手机网站需支付宝侧单独签约；有对应模式时收银台按端自动择优，否则走当面付。 |

---

## 微信支付

- 驱动代码：`wechat`
- 说明：微信官方（APIv2）：一渠道勾选 Native 扫码/H5；移动端有 H5 时优先跳转

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `app_id` | AppID | text | 必填 |  |
| `mch_id` | 商户号 | text | 必填 |  |
| `api_key` | API 密钥 | password | 必填·敏感 | 商户平台设置的 APIv2 密钥 |
| `sign_type` | 签名方式 | select | 选填 |  |
| `modes` | 支付模式 | select | 必填 | 须勾选 Native 扫码。H5 需商户平台开通手机网站支付；有 H5 时移动端优先跳转，否则扫码。 |
| `h5_type` | H5 场景类型 | select | 选填 |  |
| `h5_wap_url` | H5 网站 URL | text | 选填 | 启用 H5 时必填；scene_info.wap_url |
| `h5_wap_name` | H5 网站名称 | text | 选填 |  |
| `h5_redirect_url` | H5 支付完成回跳 | text | 选填 | 拼到 mweb_url 的 redirect_url |

---

## 易支付

- 驱动代码：`epay`
- 说明：易支付聚合网关（需对接第三方平台）

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `pid` | 商户号 | text | 必填 |  |
| `key` | 商户密钥 | password | 必填·敏感 | 平台商户密钥，用于签名 |
| `api_url` | 下单网关 | text | 必填 |  |

---

## UPAY PRO

- 驱动代码：`upay`
- 说明：UPAY PRO 原生接口 · CNY 计价，支持 USDT、USDC 多链及 TRX

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `api_url` | 网关地址 | text | 必填 | UPAY PRO 服务根地址，不含 /api/create_order |
| `secret_key` | 通信密钥 | password | 必填·敏感 | UPAY PRO 后台设置中的 SecretKey；留空保留已保存的密钥 |
| `trade_types` | 收款币种与网络 | select | 必填 | 可多选；顾客选择币种与网络后进入对应收银台。请仅启用网关已配置钱包和汇率的选项。 |
| `timeout` | 本地支付期限（秒） | number | 选填 | 60–3600 秒；同时受商品订单及网关有效期限制。网关期限需在 UPAY PRO 后台另行设置。 |

---

## GM Pay

- 驱动代码：`epusdt`
- 说明：GM Pay 多链多币种收款，使用 GMPay v2 HMAC-SHA256 接口

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `api_url` | 网关地址 | text | 必填 | 填写支付网关基础地址，包含 https://。不要填写商城域名、管理后台路径或完整下单接口，系统会自动补全。本渠道使用 GMPay v2 HMAC-SHA256 协议。 |
| `pid` | 商户 ID | text | 必填 |  |
| `secret_key` | API 密钥 | password | 必填·敏感 | 网关后台的密钥（HMAC 签名） |
| `currency` | 法币计价 | select | 选填 |  |
| `token` | 支付代币 | select | 选填 | 收款代币（需 GM Pay 服务端已启用）。多选时顾客在收银台自选；仅选一个则锁定该币种 |
| `network` | 网络 | select | 选填 | 收款链需在 GM Pay 后台启用并配置钱包。Polygon 是链名；可用代币以网关返回为准。多选时顾客在 GM Pay 收银台自选 |

---

## BEpusdt

- 驱动代码：`bepusdt`
- 说明：BEpusdt 原生接口 · CNY 计价，支持固定链与多链多币种收银台

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `api_url` | 网关地址 | text | 必填 | BEpusdt 服务根地址，不含 /api/v1/order/create-transaction |
| `api_token` | API Token | password | 必填·敏感 | BEpusdt 后台 API 认证令牌 |
| `checkout_mode` | 收款模式 | select | 必填 |  |
| `trade_type` | 收款网络 | select | 必填 | 固定模式使用；网关需已配置该币种、网络的钱包和汇率。 |
| `currencies` | 收银台币种 | select | 选填 |  |
| `timeout` | 支付期限（秒） | number | 选填 | 180–3600 秒；同时受商品订单剩余期限限制。重试不会延长期限 |

---

## OkPay

- 驱动代码：`okpay`
- 说明：OkPay 加密收款（USDT/TRX）

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `merchant_id` | 商户 ID | text | 必填 |  |
| `merchant_token` | 商户 Token | password | 必填·敏感 | 用于 HMAC-SHA256 签名 |
| `gateway_url` | 网关地址 | text | 选填 |  |
| `coin` | 默认币种 | text | 选填 | 收银台未选方式时使用；方式 params.coin 优先 |
| `exchange_rate` | 兑基础货币汇率 | text | 选填 | 1 基础货币 = rate 加密币；下单金额按此换算 |
| `display_name` | 商品显示名 | text | 选填 |  |

---

## TokenPay

- 驱动代码：`tokenpay`
- 说明：TokenPay 加密币收款

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `gateway_url` | 网关地址 | text | 必填 |  |
| `notify_secret` | 通知密钥 | password | 必填·敏感 | 回调 MD5 签名密钥 |
| `currency` | 收款币种 | text | 必填 | 链上币种代码，非订单法币 |
| `exchange_rate` | 兑基础货币汇率 | text | 选填 | 1 基础货币 = rate 加密币 |

---

## HashPay

- 驱动代码：`hashpay`
- 说明：HashPay 加密货币收款：RSA 签名下单，收银台跳转，加密信封回调

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `api_base_url` | HashPay 站点地址 | text | 必填 | HashPay Worker 根地址，不含接口路径 |
| `merchant_id` | 商户 ID | text | 必填 |  |
| `private_key` | 商户 RSA 私钥 | textarea | 必填·敏感 | HashPay 创建/轮换商户时下发的私钥，用于请求签名与回调解密。支持 PEM 或裸 Base64（PKCS1/PKCS8）。已配置时留空保持不变。 |
| `currency` | 下单法币 | select | 必填 |  |

---

## Stripe（Visa/万事达）

- 驱动代码：`stripe`
- 说明：国际信用卡收单，Checkout 收银台

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `secret_key` | Secret Key | password | 必填·敏感 | Stripe 后台 API 密钥 |
| `webhook_secret` | Webhook Secret | password | 必填·敏感 | Webhook 签名密钥——回调地址填到 Stripe 后台后生成 |
| `target_currency` | 收款币种 | text | 选填 | 跨币收款目标（留空=CNY 直收）。需在汇率表中配置该币种 |

---

## PayPal

- 驱动代码：`paypal`
- 说明：PayPal 国际收款（Orders v2）

| 字段 | 名称 | 类型 | 要求 | 说明 |
|---|---|---|---|---|
| `client_id` | Client ID | text | 必填 |  |
| `client_secret` | Client Secret | password | 必填·敏感 | REST API 密钥 |
| `mode` | 运行环境 | select | 选填 |  |
| `webhook_id` | Webhook ID | password | 选填·敏感 | PayPal 后台 Webhook 签名校验 ID——回调地址填到后台后获取 |
| `brand_name` | 收银台品牌 | text | 选填 | PayPal 授权页展示的品牌名 |
| `target_currency` | 收款币种 | text | 选填 | 跨币收款目标（留空=CNY 直收）。需在汇率表中配置该币种 |
