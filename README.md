# 卡栈

数字商品销售 · 自动发卡 · 双向上下游供货。

Go 单二进制交付，内含商城与管理后台。支持 SQLite、MySQL、PostgreSQL。

## 下载与安装

1. 打开 [Releases](https://github.com/cloudwebsite/kazhan/releases)，下载对应架构的具名文件：
   - `kazhan-linux-amd64` / `kazhan-linux-arm64`
   - 校验：`SHA256SUMS`
2. **不要**下载 Release 页上的 Source code (zip/tar.gz) 当作安装包。
3. 一键安装脚本（仅下载与校验二进制）：

```bash
curl -fsSL https://raw.githubusercontent.com/cloudwebsite/kazhan/main/scripts/kazhan-install.sh -o /tmp/kazhan-install.sh
sudo bash /tmp/kazhan-install.sh install
```

4. 完整步骤见文档站 [部署指南](https://cloudwebsite.github.io/kazhan/guide/deploy.html)，或仓库内 [`doc/部署指南.md`](./doc/部署指南.md)。
5. 装完配置清单：[装完先配这些](https://cloudwebsite.github.io/kazhan/guide/first-config.html)。

在线更新默认探测本仓库 Release（签名清单 `update.json`）。

## 文档

- 文档站：https://cloudwebsite.github.io/kazhan/
- 本仓库只含对外文档、精选说明与安装脚本；产品源码与 CI 构建在私有开发仓。

## License

见 [`LICENSE`](./LICENSE) / [`LICENSE.zh-CN.txt`](./LICENSE.zh-CN.txt)。