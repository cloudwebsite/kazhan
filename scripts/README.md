# scripts 说明

本目录在**私有开发仓**里既有安装脚本，也有测试 / 发版辅助脚本。  
同步到**公共发行仓**时，**只放与二进制安装、下载、校验相关的脚本**。

## 公共仓允许（二进制相关）

| 文件 | 用途 |
|---|---|
| `kazhan-install.sh` | Linux 一键安装 / 更新 / 启停（下载 Release 二进制 + SHA256） |
| `kazhan-install-baota.sh` | 宝塔环境安装助手（本地二进制或 Release 下载；默认不抢 systemd） |

客户安装文档里的下载地址形如：

```text
https://raw.githubusercontent.com/cloudwebsite/kazhan/main/scripts/kazhan-install.sh
```

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
3. 安装脚本变量前缀统一 `KAZHAN_*`，下载源默认 `cloudwebsite/kazhan`。
