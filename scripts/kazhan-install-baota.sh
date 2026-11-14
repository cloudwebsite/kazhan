#!/usr/bin/env bash
# 卡栈 · Debian + 宝塔面板 安装 / 管理
#
# 适用：已装宝塔的 Debian / Ubuntu；二进制已上传到服务器，或从 GitHub Release 下载。
# 默认不注册 systemd（避免与宝塔「进程守护」双开）；仅生成目录、配置，并打印面板填写项。
#
# 用法：
#   sudo bash kazhan-install-baota.sh install --bin /root/kazhan-linux-amd64
#   sudo bash kazhan-install-baota.sh install --package-dir /root/kazhan-release --db sqlite
#   sudo bash kazhan-install-baota.sh install --db mysql --db-host 127.0.0.1 ...
#   sudo bash kazhan-install-baota.sh update
#   sudo bash kazhan-install-baota.sh status|start|stop|restart|logs|uninstall|print-nginx|print-supervisor
#
# 环境变量：
#   KAZHAN_INSTALL_DIR  默认 /www/server/kazhan
#   KAZHAN_PORT         默认 8000（仅本机监听，交给宝塔 Nginx 反代）
#   KAZHAN_RUN_USER     默认 www（宝塔站点用户）；不存在则回退 root
#   KAZHAN_VERSION      无 --bin/--package-dir 时下载的 tag，默认 latest
#   KAZHAN_GH_REPO      默认 cloudwebsite/kazhan
#   KAZHAN_USE_SYSTEMD=1  额外写入 systemd（一般宝塔环境不要开）
set -Eeuo pipefail
umask 077

readonly GH_REPO="${KAZHAN_GH_REPO:-cloudwebsite/kazhan}"
readonly VERSION="${KAZHAN_VERSION:-latest}"
readonly PORT="${KAZHAN_PORT:-8000}"
readonly INSTALL_DIR="${KAZHAN_INSTALL_DIR:-/www/server/kazhan}"
readonly CONF_DIR="${INSTALL_DIR}/configs"
readonly DATA_DIR="${INSTALL_DIR}/data"
readonly BIN="${INSTALL_DIR}/kazhan"
readonly UNIT_FILE="${KAZHAN_UNIT_FILE:-/etc/systemd/system/kazhan.service}"
readonly SERVICE=kazhan
readonly USE_SYSTEMD="${KAZHAN_USE_SYSTEMD:-0}"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
have_systemd() { [ -d /run/systemd/system ] && command -v systemctl >/dev/null; }
require_command() { command -v "$1" >/dev/null || die "缺少 $1，请先安装"; }
svc() { systemctl "$@" "$SERVICE.service"; }

is_debian_like() {
  [ -f /etc/debian_version ] || grep -qiE 'debian|ubuntu' /etc/os-release 2>/dev/null
}

detect_run_user() {
  if [ -n "${KAZHAN_RUN_USER:-}" ]; then
    printf '%s\n' "$KAZHAN_RUN_USER"
    return
  fi
  if id www >/dev/null 2>&1; then
    printf 'www\n'
  elif id www-data >/dev/null 2>&1; then
    printf 'www-data\n'
  else
    printf 'root\n'
  fi
}

need_root() {
  [ "$(uname -s)" = Linux ] || die '此脚本仅支持 Linux'
  is_debian_like || warn '未检测到 Debian/Ubuntu；宝塔脚本仍可继续，请自行确认依赖'
  [ "$(id -u)" = 0 ] || die '请以 root / sudo 运行（宝塔终端或 SSH）'
  [[ "$INSTALL_DIR" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die '安装目录必须为无空格的普通绝对路径'
}

arch_name() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) die '仅支持 amd64 / arm64' ;;
  esac
}

# 校验本地文件（可选对照同目录 SHA256SUMS）
verify_local_bin() {
  local src="$1" sums_dir="$2" arch name
  arch="$(arch_name)"
  name="kazhan-linux-${arch}"
  [ -f "$src" ] || die "找不到二进制: $src"
  if [ -f "${sums_dir}/SHA256SUMS" ]; then
    python3 - "$src" "${sums_dir}/SHA256SUMS" "$name" <<'PYTHON'
import hashlib, pathlib, sys
src, sums, name = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
rows = [line.split() for line in sums.read_text().splitlines()]
expected = [r[0] for r in rows if len(r) == 2 and r[1].lstrip('*') in (name, pathlib.Path(src).name)]
digest = hashlib.sha256(src.read_bytes()).hexdigest()
if expected and digest not in expected:
    sys.exit('SHA256 校验失败，中止安装')
if expected:
    print('SHA256 校验通过')
PYTHON
  else
    warn '未找到 SHA256SUMS，跳过校验（仅信任本机已上传文件）'
  fi
}

download_bin() (
  local dest="$1" arch tmp tag asset base
  arch="$(arch_name)"; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  tag="$VERSION"
  if [ "$tag" = latest ]; then
    tag="$(curl -fsSL --retry 3 "https://api.github.com/repos/${GH_REPO}/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
  fi
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die '版本须为 vX.Y.Z'
  asset="kazhan-linux-${arch}"
  base="https://github.com/${GH_REPO}/releases/download/${tag}"
  log "下载 ${tag} (${arch})"
  curl -fSL --retry 3 --connect-timeout 15 -o "$tmp/$asset" "$base/$asset"
  curl -fsSL --retry 3 --connect-timeout 15 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
  verify_local_bin "$tmp/$asset" "$tmp"
  install -m 755 "$tmp/$asset" "$dest"
)

ask() {
  local ans=""
  if [ -t 0 ]; then read -r -p "$1 [$2]: " ans; fi
  printf '%s\n' "${ans:-$2}"
}
ask_secret() {
  local ans=""
  if [ -t 0 ]; then
    read -r -s -p "$1: " ans
    printf '\n' >&2
  fi
  printf '%s\n' "$ans"
}

resolve_db() {
  DB_DIALECT="${DB_DIALECT:-}"
  if [ -z "$DB_DIALECT" ]; then
    DB_DIALECT="$(ask '数据库 postgres / mysql / sqlite（宝塔可先用 sqlite，或选已装的 MySQL）' sqlite)"
  fi
  case "$DB_DIALECT" in sqlite|mysql|postgres) ;; *) die '数据库须为 sqlite / mysql / postgres';; esac
  DB_HOST="${DB_HOST:-}"; DB_NAME="${DB_NAME:-}"
  DB_USER="${DB_USER:-}"; DB_PASS="${DB_PASS:-}"; DB_PORT="${DB_PORT:-}"
  REDIS_ADDR="${REDIS_ADDR:-}"; REDIS_PASS="${REDIS_PASS:-}"
  if [ "$DB_DIALECT" = sqlite ]; then return; fi
  local def_port=5432 def_user=postgres
  if [ "$DB_DIALECT" = mysql ]; then def_port=3306; def_user=root; fi
  DB_HOST="${DB_HOST:-$(ask '数据库主机' '127.0.0.1')}"
  DB_PORT="${DB_PORT:-$(ask '数据库端口' "$def_port")}"
  DB_USER="${DB_USER:-$(ask '数据库用户' "$def_user")}"
  DB_PASS="${DB_PASS:-$(ask_secret '数据库密码')}"
  DB_NAME="${DB_NAME:-$(ask '数据库名（不存在将创建）' 'kazhan')}"
  REDIS_ADDR="${REDIS_ADDR:-$(ask 'Redis 地址（宝塔可装 Redis；sqlite 不需要）' '127.0.0.1:6379')}"
  REDIS_PASS="${REDIS_PASS:-$(ask_secret 'Redis 密码（可留空）')}"
  [ -n "$DB_PASS" ] || die '数据库密码不能为空'
}

# 宝塔反代场景：默认只监听 127.0.0.1，避免端口直接暴露公网。
write_config() {
  mkdir -p "$CONF_DIR" "$DATA_DIR"
  export DB_DIALECT DB_HOST DB_PORT DB_USER DB_PASS DB_NAME REDIS_ADDR REDIS_PASS
  python3 - "$CONF_DIR/config.yaml" "$DATA_DIR" "$PORT" <<'PYTHON'
import json, os, secrets, sys
from urllib.parse import quote
path, data, port = sys.argv[1:]
e = os.environ
driver = e['DB_DIALECT']
source = 'file:' + data + '/kazhan.db'
if driver == 'mysql':
    source = '{}:{}@tcp({}:{})/{}?parseTime=True&loc=UTC&charset=utf8mb4'.format(
        e['DB_USER'], e['DB_PASS'], e['DB_HOST'], e['DB_PORT'], e['DB_NAME'])
elif driver == 'postgres':
    host = e['DB_HOST']
    if ':' in host and not host.startswith('['):
        host = '[' + host + ']'
    source = 'postgres://{}:{}@{}:{}/{}?sslmode=disable'.format(
        quote(e['DB_USER'], safe=''), quote(e['DB_PASS'], safe=''), host, e['DB_PORT'], quote(e['DB_NAME'], safe=''))
security = {}
for key in ('jwt_admin_key', 'jwt_user_key', 'card_key', 'data_key'):
    value = e.get('KAZHAN_' + key.upper()) or secrets.token_hex(32)
    if key in ('card_key', 'data_key'):
        try:
            valid = len(value) == 64 and len(bytes.fromhex(value)) == 32
        except ValueError:
            valid = False
    else:
        valid = len(value.encode()) >= 32
    if not valid:
        sys.exit('密钥格式错误: ' + key)
    security[key] = value
cfg = {
    'server': {
        'http': {'addr': '127.0.0.1:' + port, 'timeout': '30s'},
        'grpc': {'addr': ''},
        'migrate_on_start': True,
    },
    'data': {
        'database': {
            'driver': driver,
            'source': source,
            'max_open_conns': 20,
            'max_idle_conns': 5,
        },
        'redis': {
            'addr': e.get('REDIS_ADDR') or '',
            'password': e.get('REDIS_PASS') or '',
            'read_timeout': '0.2s',
            'write_timeout': '0.2s',
        },
    },
    'security': security,
    'tenancy': {'mode': 'row'},
    'log': {'level': 'info', 'format': 'text'},
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write('\n')
PYTHON
  unset DB_PASS REDIS_PASS
  log '已生成配置和四把持久密钥（0600）；请备份 configs 与 data'
}

fix_run_user() {
  RUN_USER="$(detect_run_user)"
  RUN_GROUP="$(id -gn "$RUN_USER" 2>/dev/null || echo "$RUN_USER")"
  chown -R "${RUN_USER}:${RUN_GROUP}" "$INSTALL_DIR"
  # 配置含密钥，目录可访问即可；config 保持 0600
  chmod 700 "$INSTALL_DIR" "$CONF_DIR" "$DATA_DIR" 2>/dev/null || true
  chmod 600 "$CONF_DIR/config.yaml" 2>/dev/null || true
  chmod 755 "$BIN"
  log "目录属主已设为 ${RUN_USER}:${RUN_GROUP}"
}

write_unit() {
  cat > "$UNIT_FILE" <<EOF
[Unit]
Description=卡栈
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_GROUP}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN} serve -conf ${CONF_DIR}
Environment=KAZHAN_SUPERVISOR=systemd
EnvironmentFile=-${INSTALL_DIR}/kazhan.env
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  chmod 644 "$UNIT_FILE"
  systemctl daemon-reload
}

print_supervisor_hint() {
  cat <<EOF

======== 宝塔 · 进程守护（必填）========
面板路径：软件商店 → 进程守护管理器 → 添加守护进程

  名称：          kazhan
  启动用户：      ${RUN_USER:-www}
  运行目录：      ${INSTALL_DIR}
  启动命令：      ${BIN} serve -conf ${CONF_DIR}
  进程数量：      1

添加后点「启动」。不要同时再用 systemd 管同一实例。
查看本提示： sudo bash $0 print-supervisor
EOF
}

print_nginx_hint() {
  cat <<EOF

======== 宝塔 · 网站反代（推荐）========
1. 网站 → 添加站点（仅域名，可先不创建数据库）
2. 设置 → 反向代理 → 添加：
     代理名称： kazhan
     目标 URL： http://127.0.0.1:${PORT}
     发送域名： \$host
3. 打开站点「配置文件」，务必用 ^~ 反代整站（不要用普通 location /）：
   宝塔默认常有 location ~ .*\\.(js|css) 在「网站根目录」找静态文件；
   若不加 ^~，/assets/*.js 会被该正则抢走 → 安装向导静态资源全 404。

# 删除或注释站点里类似下面的静态正则（若仍保留，必须保证下面的 ^~ 优先生效）：
# location ~ .*\\.(js|css)?\$ { expires 12h; ... }

location ^~ / {
    proxy_pass http://127.0.0.1:${PORT};
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 600s;
    client_max_body_size 101m;
    client_body_timeout 600s;
}

4. 保存后重载 Nginx。自检（应都是 200，且 JS 内容类型不是 text/html）：
     curl -sI http://127.0.0.1:${PORT}/assets/ | head
     curl -sI https://你的域名/assets/Install-占位.js   # 或浏览器 Network 里真实文件名
     curl -fsS http://127.0.0.1:${PORT}/health
5. SSL：站点 → SSL → 申请 Let's Encrypt 并开启强制 HTTPS
6. 浏览器打开：https://你的域名/install 完成安装向导

查看本提示： sudo bash $0 print-nginx
EOF
}

wait_healthy_http() {
  local attempt response
  for ((attempt=0; attempt<60; attempt++)); do
    if response="$(curl -fsS --max-time 2 "http://127.0.0.1:${PORT}/health" 2>/dev/null)" &&
      python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(not (d.get("status",{}).get("database") and d["status"].get("server")))' <<< "$response"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

ensure_backup_tools() {
  local tool package
  case "$DB_DIALECT" in
    postgres) tool=pg_dump; package=postgresql-client ;;
    mysql) tool=mysqldump; package=default-mysql-client ;;
    *) return 0 ;;
  esac
  if ! command -v "$tool" >/dev/null; then
    if command -v apt-get >/dev/null; then
      if ! apt-get update -qq || ! apt-get install -y "$package"; then
        warn "请自行安装 ${tool}（宝塔软件商店也可装数据库客户端）"
      fi
    else
      warn "请自行安装 ${tool}"
    fi
  fi
}

resolve_bin_source() {
  # 输出：把选中的本地二进制路径写到 BIN_SRC；空表示走下载
  BIN_SRC=""
  PACKAGE_DIR=""
  USE_SYSTEMD_FLAG=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --systemd)
        USE_SYSTEMD_FLAG=1
        shift
        continue
        ;;
      --bin|--package-dir|--db|--db-host|--db-port|--db-user|--db-pass|--db-name|--redis|--redis-pass)
        [ "$#" -ge 2 ] || die "缺少参数值: $1"
        ;;
      *) die "未知参数: $1（宝塔版请用 --bin 或 --package-dir 指向已上传包）" ;;
    esac
    case "$1" in
      --bin) BIN_SRC="$2" ;;
      --package-dir) PACKAGE_DIR="$2" ;;
      --db) DB_DIALECT="$2" ;;
      --db-host) DB_HOST="$2" ;; --db-port) DB_PORT="$2" ;;
      --db-user) DB_USER="$2" ;; --db-pass) DB_PASS="$2" ;; --db-name) DB_NAME="$2" ;;
      --redis) REDIS_ADDR="$2" ;; --redis-pass) REDIS_PASS="$2" ;;
    esac
    shift 2
  done
  if [ -n "$PACKAGE_DIR" ]; then
    local arch asset
    arch="$(arch_name)"
    asset="${PACKAGE_DIR%/}/kazhan-linux-${arch}"
    [ -f "$asset" ] || die "package-dir 内缺少 kazhan-linux-${arch}"
    verify_local_bin "$asset" "${PACKAGE_DIR%/}"
    BIN_SRC="$asset"
  fi
}

do_install() {
  need_root
  require_command curl
  require_command python3
  if ! [[ "$PORT" =~ ^[1-9][0-9]{0,4}$ ]] || ((PORT > 65535)); then
    die 'KAZHAN_PORT 必须为 1~65535'
  fi
  [ ! -e "$BIN" ] && [ ! -e "$CONF_DIR/config.yaml" ] || \
    die '已有部署：不会覆盖二进制或密钥；升级请用 update'
  if [ "${USE_SYSTEMD}" = 1 ] || [ "${USE_SYSTEMD_FLAG:-0}" = 1 ]; then
    have_systemd || die '请求了 systemd 但当前系统不可用'
    [ ! -e "$UNIT_FILE" ] || die 'kazhan.service 已存在'
  fi

  resolve_bin_source "$@"
  resolve_db
  mkdir -p "$INSTALL_DIR"

  if [ -n "$BIN_SRC" ]; then
    log "使用本机二进制: $BIN_SRC"
    verify_local_bin "$BIN_SRC" "$(dirname "$BIN_SRC")"
    install -m 755 "$BIN_SRC" "$BIN.new"
  else
    warn '未指定 --bin / --package-dir，将从 GitHub Release 下载'
    download_bin "$BIN.new"
  fi

  "$BIN.new" version >/dev/null || { rm -f "$BIN.new"; die '二进制不可执行（架构是否匹配？）'; }

  if [ "$DB_DIALECT" != sqlite ]; then
    if ! "$BIN.new" dbtest -dialect "$DB_DIALECT" -host "$DB_HOST" -port "$DB_PORT" \
      -user "$DB_USER" -password "$DB_PASS" -name "$DB_NAME" \
      -redis "$REDIS_ADDR" -redis-password "$REDIS_PASS"; then
      rm -f "$BIN.new"
      die '数据库或 Redis 校验失败'
    fi
  fi

  write_config
  mv "$BIN.new" "$BIN"
  ensure_backup_tools
  fix_run_user

  if [ "${USE_SYSTEMD}" = 1 ] || [ "${USE_SYSTEMD_FLAG:-0}" = 1 ]; then
    write_unit
    svc enable
    svc restart
    wait_healthy_http || die 'systemd 服务未通过健康检查'
    log '已用 systemd 拉起服务'
  else
    print_supervisor_hint
    warn "文件已就绪；请到宝塔「进程守护」按上面提示添加并启动"
    warn "启动后执行: curl -fsS http://127.0.0.1:${PORT}/health"
  fi
  print_nginx_hint
  log "安装目录 ${INSTALL_DIR}；完成面板守护与反代后访问 /install"
}

do_update() {
  need_root
  require_command curl
  require_command python3
  [ -x "$BIN" ] || die '尚未安装'
  local arg
  for arg in "$@"; do
    case "$arg" in
      --bin|--bin=*|-conf|--conf|-conf=*|--conf=*|--rollback|-rollback|--rollback=*|-rollback=*)
        die '此参数请使用部署指南中的独立运维流程';;
    esac
  done
  cd "$INSTALL_DIR"
  local state_before=""
  if [ -f update.state ]; then state_before="$(cat update.state)"; fi
  # 宝塔守护下进程可能仍占用旧二进制；self-update 会原子替换，之后必须在面板点重启
  "$BIN" self-update -y -conf "$CONF_DIR" "$@"
  if [ "${USE_SYSTEMD}" = 1 ] && have_systemd && systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then
    wait_healthy_http || die '更新后服务不健康'
  else
    warn '二进制已更新；请到宝塔「进程守护」重启 kazhan，再检查 /health'
  fi
  if [ -f update.state ] && [ "$(cat update.state)" != "$state_before" ]; then
    python3 - <<'PYTHON'
import json, time, sys
for _ in range(60):
    with open('update.state') as f:
        state = json.load(f)
    if state.get('rolled_back'):
        sys.exit('更新失败，程序已回滚；请检查日志')
    if state.get('status') == 'ok':
        break
    time.sleep(1)
else:
    sys.exit('更新尚未通过启动确认；请在宝塔重启进程后检查 update.state')
PYTHON
  fi
}

do_uninstall() {
  need_root
  if have_systemd && [ -e "$UNIT_FILE" ]; then
    svc stop 2>/dev/null || true
    svc disable 2>/dev/null || true
    rm -f "$UNIT_FILE"
    systemctl daemon-reload
  fi
  log "已尝试移除 systemd 单元（若有）。请到宝塔「进程守护」手动删除 kazhan。"
  log "配置、二进制与数据仍保留在 ${INSTALL_DIR}"
}

cmd_process() {
  # 无 systemd 时提示去面板操作
  if [ "${USE_SYSTEMD}" = 1 ] && have_systemd; then
    need_root
    svc "$1"
    return
  fi
  case "$1" in
    start|stop|restart)
      die "宝塔环境请在「进程守护」里对 kazhan 执行${1}；或设置 KAZHAN_USE_SYSTEMD=1 后使用 systemd" ;;
    status)
      if have_systemd && systemctl cat "$SERVICE" >/dev/null 2>&1; then
        svc status --no-pager
      else
        curl -fsS "http://127.0.0.1:${PORT}/health" && echo || die "进程未响应 ${PORT}；请到宝塔进程守护查看"
      fi
      ;;
    logs)
      die '宝塔环境请在「进程守护 → 日志」查看；若用了 systemd：journalctl -u kazhan -n 100 -f'
      ;;
  esac
}

main() {
  RUN_USER="$(detect_run_user)"
  RUN_GROUP="$(id -gn "$RUN_USER" 2>/dev/null || echo "$RUN_USER")"
  case "${1:-help}" in
    install) shift; do_install "$@" ;;
    update) shift; do_update "$@" ;;
    uninstall) do_uninstall ;;
    status) cmd_process status ;;
    logs) cmd_process logs ;;
    start|stop|restart) cmd_process "$1" ;;
    print-nginx) print_nginx_hint ;;
    print-supervisor) print_supervisor_hint ;;
    -h|--help|help)
      sed -n '2,22p' "$0"
      ;;
    *) die "未知命令: $1（help 查看用法）" ;;
  esac
}
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then main "$@"; fi
