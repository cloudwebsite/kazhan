# 在线更新与回滚

卡栈支持在后台或命令行升级到新版本。升级前请先备份：**配置 / `.env`、数据库、上传目录、密钥**。

---

## 怎么更新（按你的安装方式）

| 安装方式 | 推荐操作 |
|---|---|
| 一键脚本 | `sudo bash /tmp/kazhan-install.sh update` |
| 手动 / 宝塔二进制 | 后台「系统设置 → 系统更新」，或 CLI（见下） |
| Docker 官方 Compose | 后台在线更新（需已接入升级助手） |

### 后台

1. 打开 **系统设置 → 系统更新**  
2. **检查更新** → 阅读说明 → **立即更新**  
3. 等待完成；用 `/health` 或后台版本号确认已是新版  

关闭浏览器**不会**取消已开始的更新任务。

### 命令行（单二进制）

```bash
cd /opt/kazhan   # 改成你的安装目录
./kazhan self-update --check -conf configs
./kazhan self-update -y -conf configs
# 指定源（一般不用）
./kazhan self-update -y -conf configs -source github
```

- **systemd**：CLI 更新后常会自动重启。  
- **宝塔 / supervisord**：CLI 更新后请在面板里重启进程。  
- 多进程拆分部署时，面板在线更新可能禁用，请用 CLI 滚动各进程。

### Docker

官方单实例 Compose（含升级助手）可在后台点更新。  
助手会验签、拉镜像、短暂停机备份后再切换。  

尚未接入助手的旧 Docker 部署，在原目录执行：

```bash
git pull --ff-only
KAZHAN_VERSION=最新版本号 bash deploy/docker-install.sh --online
```

以后日常仍走后台更新。不要用 `docker compose down -v` 清掉还要保留的数据卷。

---

## 备份工具（MySQL / PostgreSQL）

单二进制在线更新会先备份数据库。服务器上需要对应工具，否则更新会中止：

```bash
sudo apt install -y default-mysql-client   # MySQL
sudo apt install -y postgresql-client     # PostgreSQL
```

SQLite 由程序内置备份。Docker 官方助手按约定备份应用卷 / 内置 MySQL。

---

## 回滚

### 单二进制

```bash
cd /opt/kazhan
./kazhan self-update --rollback -conf configs
sudo systemctl restart kazhan   # 若未自动重启
```

若新程序本身无法启动，不能指望它执行 `--rollback`：停服务后，从 `backups/pre-*/kazhan.old` 或已校验的旧版发行文件恢复二进制再启动。

### Docker

后台「回退」仅在数据库结构兼容时可用，**不会**自动还原数据库或覆盖新订单。  
结构已变或不明确时：先在隔离环境用备份验证，再决定是否恢复。

---

## 注意

1. 只回滚程序 ≠ 恢复数据库；资金与订单有变化时，程序与库要成套恢复。  
2. 密钥不要重新随机生成「修数据」——丢密钥则旧卡密密文无法解密。  
3. 确认以 `/health` 或后台显示的版本为准，不要以下载完成为准。  
4. 更新源默认 `auto`；自建静态源见系统更新配置说明。
