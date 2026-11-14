# 部署指南

卡栈是一套**发卡商城**：一个 Linux 程序里已经包含商城前台和管理后台。  
一般**不需要**单独装 PHP、Node，也不用自己编译前端。

下载地址：[GitHub Releases](https://github.com/cloudwebsite/kazhan/releases)  
请下载带架构名的文件（如 `kazhan-linux-amd64`）和 `SHA256SUMS`，**不要**把 Source code 压缩包当安装包。

---

## 先选一种安装方式

| 你的情况 | 选这个 |
|---|---|
| 有一台 Linux 云服务器，想尽快跑起来 | **方式一：一键脚本**（推荐新手） |
| 已经会用 Docker / 想一键带 MySQL+Redis | **方式二：Docker Compose** |
| 已有宝塔 / 1Panel，习惯用面板守护进程 | **方式三：手动放二进制** |

装好后统一做两件事：

1. 浏览器打开 `http://服务器IP:8000/install`（端口若改过则用新端口）  
2. 按向导创建管理员、站点名称和网址  

生产环境建议再配域名 + Nginx/HTTPS（见下文）。

同一台机器要开**多家互不相关的店**，或主站下多个白标分站，见 [同机多站点](./multi-site.md)。

---

## 方式一：Linux 一键安装（推荐）

### 需要什么

- Linux（常见 Debian / Ubuntu）
- 能 SSH 登录，有 `sudo`
- 已安装：`curl`、`python3`、`ca-certificates`

```bash
sudo apt update
sudo apt install -y curl python3 ca-certificates
```

### 安装命令

```bash
curl -fsSL https://raw.githubusercontent.com/cloudwebsite/kazhan/main/scripts/kazhan-install.sh -o /tmp/kazhan-install.sh
sudo bash /tmp/kazhan-install.sh install
```

脚本会问用哪种数据库：

| 选择 | 适合 | 还要准备什么 |
|---|---|---|
| **SQLite**（默认） | 试用、轻量站 | 无；不强制 Redis |
| MySQL / PostgreSQL | 正式站、访问量大 | 事先装好数据库；还要 Redis |

脚本**不会**帮你安装 MySQL / PostgreSQL 服务器本身。

已下载二进制时可离线指定本地文件：

```bash
sudo bash /tmp/kazhan-install.sh install --bin ./kazhan-linux-amd64 --db sqlite
```

非交互示例（密码含特殊字符时用单引号）：

```bash
sudo bash /tmp/kazhan-install.sh install --db mysql \
  --db-host 127.0.0.1 --db-port 3306 --db-user kazhan \
  --db-pass '替换成数据库密码' --db-name kazhan \
  --redis 127.0.0.1:6379
```

### 装完怎么管

```bash
systemctl status kazhan
sudo systemctl restart kazhan
journalctl -u kazhan -n 100 --no-pager

# 升级到新版本（会先验签、备份再替换）
sudo bash /tmp/kazhan-install.sh update
```

默认安装目录：`/opt/kazhan`，默认端口：`8000`。  
改目录或端口时，安装和管理命令要用同一组环境变量：

```bash
sudo env KAZHAN_INSTALL_DIR=/srv/kazhan KAZHAN_PORT=8080 \
  bash /tmp/kazhan-install.sh install --db sqlite
```

| 变量 | 默认 | 用途 |
|---|---|---|
| `KAZHAN_VERSION` | `latest` | 首次下载的 Release 版本 |
| `KAZHAN_PORT` | `8000` | HTTP 端口 |
| `KAZHAN_INSTALL_DIR` | `/opt/kazhan` | 安装目录 |
| `KAZHAN_GH_REPO` | `cloudwebsite/kazhan` | 下载来源仓库 |

### 小提示

- 请先下载脚本再执行；不要 `curl | bash`，否则交互输入可能异常。  
- 已存在安装时，重复 `install` 会拒绝覆盖；升级请用 `update`。  
- 脚本不自动配 Nginx / HTTPS。

---

## 方式二：Docker Compose

### 需要什么

- Docker Engine + Compose v2.20+
- Git、Bash、OpenSSL、curl、Python 3
- 能访问 GitHub Release 与 `ghcr.io`

### 安装命令

```bash
git clone https://github.com/cloudwebsite/kazhan.git
cd kazhan
bash deploy/docker-install.sh
```

首次会生成 `deploy/.env`（含密钥和 MySQL 密码，权限 0600），并拉起卡栈 + 升级助手 + MySQL + Redis。

### 打开安装向导时怎么填

| 向导字段 | 填什么 |
|---|---|
| 数据库类型 | MySQL |
| 主机 / 端口 | `mysql` / `3306` |
| 用户 / 库名 | `kazhan` / `kazhan` |
| 数据库密码 | `deploy/.env` 里的 `MYSQL_PASSWORD` |
| Redis 地址 | `redis:6379` |
| Redis 密码 | 留空 |

注意：容器里的 `127.0.0.1` 是容器自己，**不能**当 Compose 里 MySQL/Redis 的地址。

### 日常命令

```bash
cd deploy
docker compose ps
docker compose logs --tail 100 updater kazhan
docker compose restart kazhan
curl -fsS http://127.0.0.1:8000/health
```

官方单实例 Compose 支持后台「系统设置 → 在线更新」。细节见 [在线更新与回滚](../operations/update.md)。

**千万不要**对还要保留的数据执行 `docker compose down -v`（`-v` 会删卷）。

---

## 方式三：手动 / 宝塔 / 1Panel

1. 从 [Releases](https://github.com/cloudwebsite/kazhan/releases) 下载对应架构二进制，核对 `SHA256SUMS`。  
2. 放到目录，例如 `/opt/kazhan`：

```bash
mkdir -p /opt/kazhan
cd /opt/kazhan
cp /path/to/kazhan-linux-amd64 ./kazhan
chmod +x ./kazhan
./kazhan serve -conf configs
```

3. 浏览器打开 `/install` 完成向导。  
4. 生产请用面板「进程守护」或 systemd，不要长期靠手动 `nohup`。

面板里建议：

- 启动命令：`/opt/kazhan/kazhan serve -conf /opt/kazhan/configs`
- 运行目录：`/opt/kazhan`
- 进程数：1  
- 运行用户要能读写配置、数据和二进制目录

不要同时用 systemd 和面板守护**同一套**实例。

也可用命令行安装：`./kazhan install -conf configs`（交互输入管理员与站点信息），装完仍需 `serve` 启动。

---

## 域名、Nginx 与 HTTPS

1. 域名 DNS 指到服务器。  
2. 用 Nginx / 宝塔 / 1Panel 做反向代理，目标例如 `http://127.0.0.1:8000`。  
3. **必须**用 `location ^~ /`，否则面板自带的 `js|css` 规则可能抢走静态资源，安装页全 404。

```nginx
server {
    listen 80;
    server_name shop.example.com;
    client_max_body_size 64m;
    location ^~ / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

若安装页静态资源全 404：先 `curl -sI http://127.0.0.1:8000/assets/...` 确认本机正常，再检查反代是否带了 `^~`。

HTTPS：用面板证书或 `certbot`，证书签好后再强制跳转 HTTPS。

管理后台默认路径：`/admin`。上传文件在工作目录下的 `data/uploads/`。

---

## 更新怎么做

| 部署方式 | 怎么更新 |
|---|---|
| 一键脚本 | `sudo bash /tmp/kazhan-install.sh update` |
| 手动二进制 | 后台「系统设置 → 在线更新」，或 CLI `self-update` |
| Docker 官方 Compose | 后台在线更新（需已接入升级助手） |

更新前建议备份：配置 / `.env`、数据库、上传目录。  
密钥丢失后旧卡密无法解密。完整说明见 [在线更新与回滚](../operations/update.md)。

MySQL / PostgreSQL 的二进制在线更新需要服务器上有 `mysqldump` / `pg_dump`：

```bash
sudo apt install -y default-mysql-client   # MySQL
sudo apt install -y postgresql-client     # PostgreSQL
```

---

## 装完建议马上做

1. 改掉弱密码；需要时开启 [两步验证](../operations/security-2fa.md)。  
2. 在系统设置里核对站点网址（须公网可访问，支付回调依赖它）。  
3. 配置至少一种支付渠道后再上架商品。  
4. 定期备份，不要只备份数据库而丢掉密钥文件。

接下来请看：

- [装完先配这些](./first-config.md)
- [系统设置全览](./settings.md)
- [支付总览](../payment/)
- [商品、分类与卡密](../features/commerce.md)
- [备份与密钥](../operations/backup.md)
- [同机多站点](./multi-site.md) · [更新日志](../changelog/)
