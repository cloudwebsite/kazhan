# 同机多站点

一台服务器上想跑多个站时，先分清目标，再选方案。单站安装请先看 [部署指南](./deploy.md)。

| 你想要的 | 选哪个 |
|---|---|
| 多家互不相关的发卡站（账本、卡密、支付、管理员都分开） | **方案 A：多实例** |
| 同一主站下多个域名白标（共享进货与超管） | **方案 B：单实例分站** |
| 一库一 schema / 一租户一库 | **产品不做**（请用方案 A） |

---

## 方案 A：多实例（独立站点）

每个站点各自拥有：安装目录、端口、数据库（或独立库名）、密钥、systemd 服务名（或独立 Compose 项目）。  
前面用 Nginx / 宝塔按**域名**反代到不同端口。

### 一键脚本多站示例

默认只适合单站。多站必须改目录、端口、unit 文件，且以后 `update` 也要带同一组变量：

```bash
# 站点 A
sudo env \
  KAZHAN_INSTALL_DIR=/opt/kazhan-a \
  KAZHAN_PORT=8001 \
  KAZHAN_UNIT_FILE=/etc/systemd/system/kazhan-a.service \
  bash /tmp/kazhan-install.sh install --db sqlite

# 站点 B
sudo env \
  KAZHAN_INSTALL_DIR=/opt/kazhan-b \
  KAZHAN_PORT=8002 \
  KAZHAN_UNIT_FILE=/etc/systemd/system/kazhan-b.service \
  bash /tmp/kazhan-install.sh install --db sqlite
```

更新时同样带目录与 unit：

```bash
sudo env KAZHAN_INSTALL_DIR=/opt/kazhan-a \
  KAZHAN_UNIT_FILE=/etc/systemd/system/kazhan-a.service \
  bash /tmp/kazhan-install.sh update
```

### Docker 多站

每个站点单独目录（或不同 `COMPOSE_PROJECT_NAME`），**端口与数据卷不要冲突**，各自一份 `.env` 密钥。  
官方在线更新助手按「一套 Compose 项目」设计：多站就多套，分别在各自后台更新。

### 必须避免

1. 不要共用同一安装目录或同一份配置。  
2. 不要共用默认 `kazhan.service` 却不改 `KAZHAN_UNIT_FILE`。  
3. 不要多站共用同一套卡密 / 数据加密密钥。  
4. 反代必须把正确的 `Host` 传给后端。

### 怎么验收

- 两个域名打开后，数据互不可见  
- 停掉站点 A，站点 B 仍可用  
- 各站更新只影响本站  

---

## 方案 B：单实例 + 分站（白标）

只安装**一套**卡栈，用行级分站给不同域名换皮。适合加盟 / 分销；**不适合**两家完全独立的商户。

产品内租户模式只有行级（`tenancy.mode=row`），与用 SQLite 还是 MySQL 无关。  
分站卖主站货并可加价；开通、域名、加价等操作见 [分站（白标）](../features/subsite.md)。

| 适合 | 不适合 |
|---|---|
| 主站 + 多个换皮域名 | 要完全独立的两家店 |
| 统一进货、统一超管 | 要求密钥 / 支付商户号物理隔离 |
| 省内存与进程数 | 要单独拆走某一站单独升级 |

---

## 两方案对比

| | A 多实例 | B 单实例分站 |
|---|---|---|
| 进程 | 每站一个 | 一个 |
| 数据隔离 | 强（分目录 / 分库） | 同行级（同库） |
| 密钥 / 支付 | 可完全独立 | 共用进程密钥 |
| 升级 | 逐站 | 一次 |
| 默认安装脚本 | 要改 DIR/PORT/UNIT | 标准单站即可 |
