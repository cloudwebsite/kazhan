# scripts 说明

本目录在**私有开发仓**里既有安装脚本，也有测试 / 发版辅助脚本。  
同步到**公共发行仓**时，**只放与二进制安装、下载、校验相关的脚本**。

## 公共仓允许（二进制相关）

| 文件 | 用途 |
|---|---|
| `kazhan-install.sh` | Linux 单站安装器。交互选择域名和数据库；公网域名会装 Nginx 并申请证书。选 MySQL 或 PostgreSQL 时，本机安装对应数据库和 Redis，并建库建账号。SQLite 不装这些服务。同机多站不走本脚本 |

客户安装：

```bash
curl -fsSL https://raw.githubusercontent.com/cloudwebsite/kazhan/main/scripts/kazhan-install.sh -o /tmp/kazhan-install.sh
sudo bash /tmp/kazhan-install.sh install
```

非交互示例：

```bash
sudo bash /tmp/kazhan-install.sh install --yes --domain shop.example.com --email ops@example.com --db mysql
```

宝塔单站或同机多站都用面板插件「卡栈部署」，按域名各部署一次。不要和本脚本同时管同一实例。

## 仅私有仓（不要进公共仓）

| 类型 | 例子 |
|---|---|
| 浏览器 / API 回归 | `test_*.cjs` / `test_*.ts` / `test_*.mjs` / `test_*.py` |
| Docker 联调 | `test_docker*.py` |
| 发版辅助 | `gen-release-notes.py`、`publish_docker_release.py` |
| 主题构建 | `build-storefront-themes.py`、`package-theme.py` |

## Agent / 运维约定

1. 往公共仓推文档时，若顺带同步 `scripts/`，**只 add 上表「公共仓允许」文件**。  
2. 新增「客户可 curl 的安装脚本」才可进公共白名单；内部测试脚本一律留私有仓。  
3. 安装脚本变量前缀统一 `KAZHAN_*`，下载源默认 `cloudwebsite/kazhan`。加速列表用 `KAZHAN_GITHUB_ACCELS`。
