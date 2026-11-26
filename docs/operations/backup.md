# 备份与密钥

更新、迁机、翻车恢复都依赖备份。  
**只备份数据库不够**——没有密钥，旧卡密密文解不开。

---

## 必须一起备份的东西

| 内容 | 常见位置 |
|---|---|
| 配置与密钥 | `/opt/kazhan/configs/`、`kazhan.env`；宝塔站点目录下的 `configs/` |
| 数据库 | SQLite 文件或 MySQL/PG dump |
| 上传文件 | `data/uploads/` |
| 主题包 | `data/themes/` |

四把关键密钥（JWT 管理端/用户端、卡密、数据加密）丢失后，历史卡密与部分凭据 **无法解密**。不要为了「修复」去重新随机生成覆盖。

---

## 备份节奏建议

| 场景 | 建议 |
|---|---|
| 日常 | 每日自动备份库 + 每周完整（含 uploads/主题/密钥） |
| 升级前 | 手动再做一份完整备份，保留到确认新版稳定 |
| 改支付/货源密钥前 | 至少备份配置与库 |

备份目录权限建议仅管理员可读（如 `0700`）。

---

## 一键脚本 / 二进制

```bash
# 示例：停服后拷贝（按你的实际目录调整）
sudo systemctl stop kazhan
sudo tar czf /root/kazhan-backup-$(date +%F).tgz \
  -C /opt/kazhan configs data kazhan.env
# 另存数据库 dump（MySQL/PG）后再启动
sudo systemctl start kazhan
```

SQLite 可直接拷贝 `data` 下的库文件（务必停服或确保文件一致）。  
MySQL：

```bash
mysqldump -u用户 -p 库名 > kazhan-$(date +%F).sql
```

PostgreSQL：

```bash
pg_dump -U用户 库名 > kazhan-$(date +%F).sql
```

在线更新也会尝试自动备份；缺 `mysqldump`/`pg_dump` 时更新会中止。见 [在线更新](./update.md)。

---

## 恢复原则

1. 先在隔离环境试恢复，再切生产。  
2. 程序版本、数据库结构、密钥必须配套。  
3. 恢复点之后若已有真实收款，要人工对账，避免漏单或重复发货。  
4. 不要用「清空库重装」代替找回密钥。

---

## 相关

- [部署指南](../guide/deploy.md)  
- [在线更新与回滚](./update.md)  
- [两步验证与账号恢复](./security-2fa.md)  
