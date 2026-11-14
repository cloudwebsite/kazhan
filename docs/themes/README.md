# 主题概览

卡栈商城主题负责前台样子；下单、支付、发货、登录仍走系统接口。  
管理后台是另一套界面，不随商城主题切换。

---

## 站长：怎么换主题

1. 后台打开 **系统设置 → 模板 → 商城主题**（或「管理主题」）。  
2. 若有 ZIP 主题包：选主题 → **安装主题**。  
3. 在列表里选中目标主题，点 **切换为默认**。  
4. **新打开或刷新**的商城页才会用新主题；已开着的旧标签页可能仍是旧资源。

内置 **Classic** 始终可用，不能被 ZIP 覆盖。  
外观细调（背景、导航、每行数量等）见 [主题设置](./settings.md)；改完要 **发布生效**。

官方可安装主题包示例名称：综合商城、蓝曜商城、轻透卡片、暖橙轻享、极速发卡、风尚卡片、二次元馆等（以你安装包内实际列表为准）。

---

## 开发者：打 ZIP 主题包

主题包是独立前端资源，不要塞 `.vue` / `.ts` / `node_modules`。

在开发环境项目根目录（私有源码仓）示例：

```sh
pnpm --dir storefront install --frozen-lockfile
pnpm --dir storefront build:theme
python3 scripts/package-theme.py \
  --dist storefront/dist-theme \
  --key my-store \
  --name '我的商城主题' \
  --version 1.0.0 \
  --author 'Your Team' \
  --output /tmp/my-store-1.0.0.zip
```

### ZIP 结构

```text
my-store/
  theme.json
  index.html
  preview.webp        # 可选
  assets/
    index-xxxx.js
    index-xxxx.css
```

`theme.json` 至少包含 `schema_version`、`key`、`name`、`version`。  
`key`：1–64 位小写字母、数字、下划线或连字符；`classic` 为保留名。

### 资源与路由

服务端会注入 `<base href="/templates/.../">`，因此：

1. 构建请用相对资源路径（如 Vite `base: './'`），不要手写冲突的绝对 `/assets/...`。  
2. 前端路由 base 用站点根 `/`（与资源 base 不是一回事）。  
3. 业务链接用 `/product/123` 这类站点根路径；API 用 `/api/v1/storefront/...`。  
4. `/api`、`/uploads`、`/payments`、`/health`、`/install`、后台路径、`/templates` 由系统接管。

主题文件落在工作目录 `data/themes/`；备份与 Docker 卷请带上该目录。

### 发布前验收

至少测：首页、分类/详情、登录与游客下单、支付往返、订单与卡密、购物车、个人中心，以及手机与桌面宽度。  
只安装可信来源的主题包。

设置字段与 CSS 变量约定见 [主题设置](./settings.md)。
