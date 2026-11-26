#!/usr/bin/env bash
# 卡栈 Linux 安装器。交互方式对齐常见一键管理器：域名、Nginx、证书、systemd，中断后可续装。
# 数据库在安装时选择：SQLite 不装额外服务；MySQL / PostgreSQL 会在本机安装对应服务和 Redis，并创建库与账号。
# 宝塔请用面板插件「卡栈部署」，不要用本脚本和插件同时管同一实例。
#
#   sudo bash kazhan-install.sh
#   sudo bash kazhan-install.sh install --yes --domain shop.example.com --email ops@example.com --db mysql
#   sudo bash kazhan-install.sh install --yes --domain 10.0.0.8 --db sqlite
#   sudo kazhan-install status|logs|update|configure-domain|renew-cert|uninstall
#
# 同机多站不要用本脚本，请用宝塔插件「卡栈部署」按域名各部署一次。
# 下载先走 gh-proxy.com / ghfast.top / ghproxy.net，失败再直连。KAZHAN_GITHUB_DIRECT=0 可禁止直连。
set -Eeuo pipefail
umask 077

readonly MANAGER_VERSION="1.2.0"
readonly GH_REPO="${KAZHAN_GH_REPO:-cloudwebsite/kazhan}"
readonly VERSION="${KAZHAN_VERSION:-latest}"
readonly GITHUB_ACCEL_DEFAULTS="https://gh-proxy.com https://ghfast.top https://ghproxy.net"
readonly MANAGER_SOURCE_URL="https://raw.githubusercontent.com/cloudwebsite/kazhan/main/scripts/kazhan-install.sh"
readonly MIN_BINARY_BYTES=1048576
readonly MAX_BINARY_BYTES=314572800

INSTALL_DIR="${KAZHAN_INSTALL_DIR:-/opt/kazhan}"
SITE="$(basename "$INSTALL_DIR")"
SERVICE="$(basename "${KAZHAN_UNIT_FILE:-/etc/systemd/system/${SITE}.service}" .service)"
UNIT_FILE="${KAZHAN_UNIT_FILE:-/etc/systemd/system/${SERVICE}.service}"
ETC_DIR="/etc/${SITE}"
STATE_FILE="${ETC_DIR}/install-state.json"
CONF_DIR="${INSTALL_DIR}/configs"
DATA_DIR="${INSTALL_DIR}/data"
BIN="${INSTALL_DIR}/kazhan"
NGINX_AVAILABLE="/etc/nginx/sites-available/${SITE}.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/${SITE}.conf"
NGINX_TRANSITION_AVAILABLE="/etc/nginx/sites-available/${SITE}-acme.conf"
NGINX_TRANSITION_ENABLED="/etc/nginx/sites-enabled/${SITE}-acme.conf"
ACME_ROOT="/var/www/${SITE}-acme"
CERTBOT_DEPLOY_HOOK="/etc/letsencrypt/renewal-hooks/deploy/${SITE}-nginx"
BACKUP_DIR="/var/backups/${SITE}"
MANAGER_BIN="/usr/local/sbin/${SITE}-install"
LOCK_FILE="/run/${SITE}-install.lock"
SERVICE_USER="$SITE"
SERVICE_GROUP="$SITE"
APP_PORT="${KAZHAN_PORT:-8000}"
RUN_TMP=""
ASSUME_YES=0
LOCAL_BIN=""

DB_DIALECT=""
DB_HOST="127.0.0.1"
DB_PORT=""
DB_USER=""
DB_PASS=""
DB_NAME=""
REDIS_ADDR=""
REDIS_PASS=""
DOMAIN=""
ACME_EMAIL=""
TLS_MODE=""
CERT_NAME=""

log() { printf '[INFO] %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

on_error() {
  printf '[ERROR] 命令在第 %s 行失败（退出码 %s）。已写入的配置会保留，修好后重新运行 install 会从中断处继续。\n' "${1:-?}" "$?" >&2
  exit "$?"
}
cleanup() { [[ -n "$RUN_TMP" && -d "$RUN_TMP" ]] && rm -rf -- "$RUN_TMP"; }
init_runtime() {
  [[ -n "$RUN_TMP" ]] || RUN_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kazhan-install.XXXXXX")"
  trap cleanup EXIT
  trap 'on_error $LINENO' ERR
}
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "请使用 root 运行，例如：sudo bash $0"; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "缺少 $1"; }
acquire_lock() {
  require_command flock
  mkdir -p -- "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "另一个卡栈安装进程正在运行"
}
has_tty() { [[ -r /dev/tty && -w /dev/tty ]]; }
can_use_whiptail() { has_tty && command -v whiptail >/dev/null 2>&1 && [[ "${TERM:-dumb}" != "dumb" ]]; }
trim() { local v=$1; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }
lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

ui_message() {
  local title=$1 message
  message=$(printf '%b' "$2")
  if can_use_whiptail; then whiptail --title "$title" --msgbox "$message" 18 78
  elif has_tty; then printf '\n== %s ==\n%s\n' "$title" "$message" >/dev/tty
  else printf '\n== %s ==\n%s\n' "$title" "$message"
  fi
}
ui_yesno() {
  local title=$1 message
  message=$(printf '%b' "$2")
  if [[ "$ASSUME_YES" == 1 ]]; then log "$title：$message"; return 0; fi
  if can_use_whiptail; then whiptail --title "$title" --yesno "$message" 18 78; return $?; fi
  local answer
  while true; do
    printf '\n== %s ==\n%s [y/N]: ' "$title" "$message" >/dev/tty
    IFS= read -r answer </dev/tty || return 1
    case "$(lowercase "$answer")" in
      y|yes) return 0 ;;
      ''|n|no) return 1 ;;
    esac
  done
}
ui_input() {
  local title=$1 prompt=$2 default_value=${3:-} value
  if can_use_whiptail; then
    value=$(whiptail --title "$title" --inputbox "$prompt" 12 78 "$default_value" 3>&1 1>&2 2>&3) || return 130
  else
    printf '\n== %s ==\n%s' "$title" "$prompt" >/dev/tty
    [[ -n "$default_value" ]] && printf ' [%s]' "$default_value" >/dev/tty
    printf ': ' >/dev/tty
    IFS= read -r value </dev/tty || return 130
    [[ -n "$value" ]] || value=$default_value
  fi
  printf '%s' "$value"
}
ui_menu() {
  local title=$1 prompt=$2 choice
  shift 2
  if can_use_whiptail; then
    choice=$(whiptail --title "$title" --menu "$prompt" 20 78 10 "$@" 3>&1 1>&2 2>&3) || return 130
    printf '%s' "$choice"
    return 0
  fi
  local -a tags=() labels=()
  while (($# >= 2)); do tags+=("$1"); labels+=("$2"); shift 2; done
  printf '\n== %s ==\n%s\n' "$title" "$prompt" >/dev/tty
  local i
  for ((i = 0; i < ${#tags[@]}; i++)); do printf '  %d) %s\n' "$((i + 1))" "${labels[$i]}" >/dev/tty; done
  while true; do
    printf '请选择 [1-%d]: ' "${#tags[@]}" >/dev/tty
    IFS= read -r choice </dev/tty || return 130
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#tags[@]})); then
      printf '%s' "${tags[$((choice - 1))]}"; return 0
    fi
  done
}
prompt_validated() {
  local validator=$1 title=$2 prompt=$3 default_value=${4:-} value
  while true; do
    value=$(ui_input "$title" "$prompt" "$default_value") || exit 130
    value=$(trim "$value")
    if "$validator" "$value"; then printf '%s' "$value"; return 0; fi
    ui_message "输入无效" "请检查后重新输入。"
  done
}

is_ipv4_host() {
  local host=$1
  [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local IFS=. octet
  local -a octets
  read -r -a octets <<< "$host"
  for octet in "${octets[@]}"; do ((10#$octet >= 0 && 10#$octet <= 255)) || return 1; done
}
validate_domain() {
  local domain
  domain=$(lowercase "$1")
  [[ ${#domain} -le 253 && "$domain" != *://* && "$domain" != */* && "$domain" != \** ]] || return 1
  is_ipv4_host "$domain" && return 1
  [[ "$domain" == *.* && "$domain" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]
}
validate_install_host() { is_ipv4_host "$1" || validate_domain "$1"; }
validate_email() { [[ ${#1} -le 254 && "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; }
validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1024 && 10#$1 <= 65535)); }
validate_ident() { [[ "$1" =~ ^[a-z][a-z0-9_]{0,30}$ ]]; }
resolve_tls_mode() {
  if [[ "${KAZHAN_LOCAL_HTTP:-0}" == 1 ]] || is_ipv4_host "$1"; then printf 'http'; else printf 'letsencrypt'; fi
}
site_scheme() { [[ "${TLS_MODE:-letsencrypt}" == http ]] && printf 'http' || printf 'https'; }
site_base_url() { printf '%s://%s' "$(site_scheme)" "${1:-$DOMAIN}"; }
certificate_name_for_domain() { printf '%s-%s' "$SITE" "$(printf '%s' "$1" | sha256sum | awk '{print substr($1,1,16)}')"; }

assert_paths() {
  [[ "$INSTALL_DIR" =~ ^/(opt|srv)/[A-Za-z0-9][A-Za-z0-9._-]{0,40}$ ]] || die "安装目录只允许 /opt 或 /srv 下的普通名称：${INSTALL_DIR}"
  [[ "$SITE" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,40}$ ]] || die "站点名无效"
  [[ "$SERVICE_USER" =~ ^[a-z][a-z0-9-]{0,31}$ ]] || die "运行用户名无效：${SERVICE_USER}（目录名请用小写字母、数字和连字符）"
  [[ "$INSTALL_DIR" != / && "$ETC_DIR" != /etc ]] || die "拒绝危险路径"
}
check_os() {
  [[ -r /etc/os-release ]] || die "无法读取 /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  case "${ID:-}" in
    ubuntu) dpkg --compare-versions "${VERSION_ID}" ge 22.04 || die "需要 Ubuntu 22.04 或更新版本" ;;
    debian) dpkg --compare-versions "${VERSION_ID}" ge 12 || die "需要 Debian 12 或更新版本" ;;
    *) die "当前系统 ${ID:-unknown} 不受支持；安装器支持 Ubuntu 22.04+ 与 Debian 12+" ;;
  esac
  [[ "$(ps -p 1 -o comm= | tr -d '[:space:]')" == systemd ]] || die "需要 systemd"
  case "$(uname -m)" in x86_64|amd64|aarch64|arm64) ;; *) die "仅支持 amd64 / arm64" ;; esac
}
check_resources() {
  local free_mb mem_kb
  free_mb=$(df -Pm "$(dirname "$INSTALL_DIR")" 2>/dev/null | awk 'NR==2 {print $4}')
  if [[ -n "$free_mb" ]] && ((free_mb < 2048)); then die "磁盘可用空间不足 2GB"; fi
  mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  if ((mem_kb > 0 && mem_kb < 524288)); then die "内存低于 512MB"; fi
  if ((mem_kb > 0 && mem_kb < 1048576)); then warn "内存低于推荐的 1GB"; fi
}
port_in_use() { ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq ":${1}$"; }
port_bound_only_to_loopback() {
  local addresses address
  addresses=$(ss -ltnH 2>/dev/null | awk -v suffix=":${1}" '$4 ~ suffix "$" {print $4}')
  [[ -n "$addresses" ]] || return 1
  while IFS= read -r address; do
    [[ "$address" == "127.0.0.1:${1}" || "$address" == "[::1]:${1}" || "$address" == "::1:${1}" ]] || return 1
  done <<< "$addresses"
}
nginx_has_domain_conflict() {
  command -v nginx >/dev/null 2>&1 || return 1
  nginx -T 2>/dev/null | awk -v domain="$1" '
    $1 == "server_name" { for (i = 2; i <= NF; i++) { value=$i; gsub(/;/, "", value); if (value == domain) found=1 } }
    END { exit(found ? 0 : 1) }'
}
check_web_ports() {
  local port listeners
  for port in 80 443; do
    port_in_use "$port" || continue
    listeners=$(ss -ltnp 2>/dev/null | awk -v suffix=":${port}" '$4 ~ suffix "$"')
    [[ "$listeners" == *nginx* ]] || die "TCP ${port} 已被非 Nginx 进程占用，安装器不会停掉它"
  done
}
check_unmanaged() {
  state_exists && return 0
  local path
  for path in "$INSTALL_DIR" "$ETC_DIR" "$UNIT_FILE" "$NGINX_AVAILABLE" "$NGINX_ENABLED" "$ACME_ROOT" "$CERTBOT_DEPLOY_HOOK"; do
    [[ ! -e "$path" ]] || die "路径已存在且不是本安装器创建的：${path}"
  done
  if getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
    die "系统用户 ${SERVICE_USER} 已存在，但没有安装状态，已停止以免接管旧账号"
  fi
}

state_exists() { [[ -f "$STATE_FILE" ]]; }
state_get() {
  python3 - "$STATE_FILE" "$1" <<'PY'
import json, sys
path, field = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
value = data.get(field, "")
sys.stdout.write("" if value is None else str(value))
PY
}
state_set() {
  python3 - "$STATE_FILE" "$1" "$2" <<'PY'
import json, os, sys
path, field, value = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
data[field] = value
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.chmod(tmp, 0o600)
os.replace(tmp, path)
PY
}
state_init() {
  mkdir -p -- "$ETC_DIR"
  python3 - "$STATE_FILE" <<PY
import json, os
data = {
  "installer_version": "${MANAGER_VERSION}",
  "phase": "prerequisites",
  "domain": """${DOMAIN}""",
  "acme_email": """${ACME_EMAIL}""",
  "tls_mode": """${TLS_MODE}""",
  "cert_name": """${CERT_NAME}""",
  "app_port": """${APP_PORT}""",
  "db_dialect": """${DB_DIALECT}""",
  "db_host": """${DB_HOST}""",
  "db_port": """${DB_PORT}""",
  "db_user": """${DB_USER}""",
  "db_pass": """${DB_PASS}""",
  "db_name": """${DB_NAME}""",
  "redis_addr": """${REDIS_ADDR}""",
  "redis_pass": """${REDIS_PASS}""",
  "release_version": ""
}
tmp = "${STATE_FILE}.tmp"
os.makedirs(os.path.dirname(tmp), exist_ok=True)
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
os.chmod(tmp, 0o600)
os.replace(tmp, "${STATE_FILE}")
PY
  chmod 0700 "$ETC_DIR"
}
load_state() {
  DOMAIN=$(state_get domain)
  ACME_EMAIL=$(state_get acme_email)
  TLS_MODE=$(state_get tls_mode)
  CERT_NAME=$(state_get cert_name)
  APP_PORT=$(state_get app_port)
  DB_DIALECT=$(state_get db_dialect)
  DB_HOST=$(state_get db_host)
  DB_PORT=$(state_get db_port)
  DB_USER=$(state_get db_user)
  DB_PASS=$(state_get db_pass)
  DB_NAME=$(state_get db_name)
  REDIS_ADDR=$(state_get redis_addr)
  REDIS_PASS=$(state_get redis_pass)
}
phase_rank() {
  case "$1" in prerequisites) echo 1 ;; datastore) echo 2 ;; acme_ready) echo 3 ;; cert_issued) echo 4 ;; services_ready) echo 5 ;; installed) echo 6 ;; *) echo 0 ;; esac
}
phase_at_least() { (($(phase_rank "$1") >= $(phase_rank "$2"))); }

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y "$@"
}
install_base_packages() {
  log "安装 Nginx、Certbot 和基础工具"
  apt_install ca-certificates certbot curl iproute2 nginx openssl python3 whiptail
}
enable_service() {
  local unit=$1
  systemctl enable --now "$unit"
  local i
  for ((i = 0; i < 30; i++)); do systemctl is-active --quiet "$unit" && return 0; sleep 1; done
  die "服务 ${unit} 未能启动"
}

install_redis() {
  log "安装 Redis"
  apt_install redis-server
  local unit=redis-server
  systemctl list-unit-files redis.service >/dev/null 2>&1 && systemctl cat redis.service >/dev/null 2>&1 && unit=redis
  enable_service "$unit"
  local conf=""
  for conf in /etc/redis/redis.conf /etc/redis.conf; do [[ -f "$conf" ]] && break; done
  [[ -f "$conf" ]] || die "找不到 Redis 配置文件"
  REDIS_ADDR="127.0.0.1:6379"
  local generated existing
  generated=$(openssl rand -hex 24)
  existing=$(python3 - "$conf" "$generated" <<'PY'
import pathlib, re, sys
path, generated = sys.argv[1:]
text = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
found = re.search(r"(?m)^requirepass\s+(\S+)\s*$", text)
if found and found.group(1) not in {"\"\"", "''", "foobared"}:
    print(found.group(1))
    raise SystemExit
if re.search(r"(?m)^#\s*requirepass\s+", text):
    text = re.sub(r"(?m)^#\s*requirepass\s+.*$", "requirepass " + generated, text, count=1)
else:
    text += "\nrequirepass " + generated + "\n"
pathlib.Path(path).write_text(text, encoding="utf-8")
print(generated)
print("changed", file=sys.stderr)
PY
)
  REDIS_PASS=$existing
  if python3 - "$conf" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
raise SystemExit(0 if re.search(r"(?m)^requirepass\s+\S+", text) else 1)
PY
  then
    systemctl restart "$unit"
    enable_service "$unit"
  fi
  redis-cli -a "$REDIS_PASS" --no-auth-warning ping | grep -qx PONG || die "Redis 未通过本机认证"
  state_set redis_addr "$REDIS_ADDR" || true
  state_set redis_pass "$REDIS_PASS" || true
}

install_mysql() {
  log "安装 MySQL / MariaDB"
  apt_install default-mysql-server
  if systemctl cat mysql.service >/dev/null 2>&1; then enable_service mysql
  elif systemctl cat mariadb.service >/dev/null 2>&1; then enable_service mariadb
  else die "安装后找不到 mysql 或 mariadb 服务"
  fi
  local i
  for ((i = 0; i < 30; i++)); do mysql --protocol=socket -uroot -e "SELECT 1" >/dev/null 2>&1 && return 0; sleep 1; done
  die "本机 root 无法通过 socket 登录数据库。若 root 已改成密码登录，请先恢复 socket 认证后再运行安装器"
}
create_mysql() {
  validate_ident "$DB_USER" && validate_ident "$DB_NAME" || die "数据库名无效"
  local pass=${DB_PASS//\'/\'\'}
  mysql --protocol=socket -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${pass}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${pass}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
GRANT CREATE ON *.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
}
install_postgres() {
  log "安装 PostgreSQL"
  apt_install postgresql
  enable_service postgresql
}
create_postgres() {
  validate_ident "$DB_USER" && validate_ident "$DB_NAME" || die "数据库名无效"
  local pass=${DB_PASS//\'/\'\'}
  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${pass}' CREATEDB;
  ELSE
    ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${pass}' CREATEDB;
  END IF;
END
\$\$;
SQL
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
  fi
}
provision_datastores() {
  case "$DB_DIALECT" in
    sqlite) REDIS_ADDR=""; REDIS_PASS=""; return 0 ;;
    mysql) install_mysql; create_mysql; install_redis ;;
    postgres) install_postgres; create_postgres; install_redis ;;
    *) die "数据库须为 sqlite、mysql 或 postgres" ;;
  esac
}

arch_name() { case "$(uname -m)" in x86_64|amd64) echo amd64 ;; aarch64|arm64) echo arm64 ;; *) die "仅支持 amd64 / arm64" ;; esac; }
github_accel_list() {
  local raw=${KAZHAN_GITHUB_ACCELS:-$GITHUB_ACCEL_DEFAULTS} item
  for item in $raw; do
    [[ "$item" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(\.[A-Za-z]{2,})+$ ]] || continue
    printf '%s\n' "${item%/}"
  done
}
validate_effective_download_url() {
  local url=$1 accel inner
  [[ "$url" =~ ^https://(github\.com|api\.github\.com|raw\.githubusercontent\.com|release-assets\.githubusercontent\.com|objects\.githubusercontent\.com|github-releases\.githubusercontent\.com)(/|$) ]] && return 0
  while IFS= read -r accel; do
    [[ -n "$accel" && "$url" == "${accel}/"* ]] || continue
    inner=${url#"${accel}/"}
    [[ "$inner" =~ ^https://(github\.com|api\.github\.com|raw\.githubusercontent\.com|release-assets\.githubusercontent\.com|objects\.githubusercontent\.com|github-releases\.githubusercontent\.com)(/|$) ]] && return 0
  done < <(github_accel_list)
  return 1
}
curl_github_candidates() {
  local canonical_url=$1 destination=$2 max_time=$3
  local -a candidates=()
  local accel candidate response status next_url hop url
  while IFS= read -r accel; do [[ -n "$accel" ]] && candidates+=("${accel%/}/${canonical_url}"); done < <(github_accel_list)
  [[ "${KAZHAN_GITHUB_DIRECT:-1}" == 1 ]] && candidates+=("$canonical_url")
  ((${#candidates[@]} > 0)) || return 1
  for candidate in "${candidates[@]}"; do
    url=$candidate
    rm -f -- "$destination"
    for ((hop = 0; hop < 10; hop++)); do
      validate_effective_download_url "$url" || break
      response=$(curl --fail --silent --show-error --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time "$max_time" \
        --write-out $'%{http_code}\n%{redirect_url}' "$url" -o "$destination") || break
      status=${response%%$'\n'*}
      next_url=${response#*$'\n'}
      case "$status" in
        200) [[ -s "$destination" ]] && return 0; break ;;
        301|302|303|307|308) [[ -n "$next_url" ]] || break; url=$next_url ;;
        *) break ;;
      esac
    done
    rm -f -- "$destination"
  done
  return 1
}
download_url() {
  local url=$1 dest=$2 max_time=$3 rest
  case "$url" in
    "https://api.github.com/repos/${GH_REPO}/releases/latest"|$MANAGER_SOURCE_URL) ;;
    "https://github.com/${GH_REPO}/releases/download/"*)
      rest=${url#https://github.com/${GH_REPO}/releases/download/}
      [[ "$rest" =~ ^v[0-9]+\.[0-9]+\.[0-9]+/(kazhan-linux-(amd64|arm64)|SHA256SUMS)$ ]] || die "拒绝下载地址"
      ;;
    *) die "拒绝下载地址" ;;
  esac
  curl_github_candidates "$url" "$dest" "$max_time"
}
verify_sha256() {
  python3 - "$1" "$2" "$3" <<'PY'
import hashlib, pathlib, sys
src, sums, name = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
rows = [line.split() for line in sums.read_text().splitlines() if line.strip()]
expected = [row[0].lower() for row in rows if len(row) >= 2 and row[1].lstrip("*") in (name, src.name)]
digest = hashlib.sha256(src.read_bytes()).hexdigest()
if len(expected) != 1 or digest not in expected:
    raise SystemExit("SHA256 校验失败，中止安装")
PY
}
download_bin() {
  local dest=$1 tmp tag asset base size
  tmp=$(mktemp -d)
  tag=$VERSION
  if [[ "$tag" == latest ]]; then
    download_url "https://api.github.com/repos/${GH_REPO}/releases/latest" "$tmp/release.json" 60 || { rm -rf "$tmp"; die "无法读取 Release"; }
    tag=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["tag_name"])' "$tmp/release.json")
  fi
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { rm -rf "$tmp"; die "版本须为 vX.Y.Z"; }
  asset="kazhan-linux-$(arch_name)"
  base="https://github.com/${GH_REPO}/releases/download/${tag}"
  log "下载 ${tag} (${asset})"
  download_url "$base/$asset" "$tmp/$asset" 300 || { rm -rf "$tmp"; die "二进制下载失败"; }
  download_url "$base/SHA256SUMS" "$tmp/SHA256SUMS" 60 || { rm -rf "$tmp"; die "SHA256SUMS 下载失败"; }
  verify_sha256 "$tmp/$asset" "$tmp/SHA256SUMS" "$asset"
  size=$(python3 -c 'import os,sys; print(os.path.getsize(sys.argv[1]))' "$tmp/$asset")
  if ((size < MIN_BINARY_BYTES || size > MAX_BINARY_BYTES)); then rm -rf "$tmp"; die "二进制大小异常"; fi
  install -m 0755 "$tmp/$asset" "$dest"
  rm -rf "$tmp"
  state_exists && state_set release_version "$tag" || true
}

create_service_user() {
  if ! getent group "$SERVICE_GROUP" >/dev/null; then groupadd --system "$SERVICE_GROUP"; fi
  if ! getent passwd "$SERVICE_USER" >/dev/null; then
    useradd --system --gid "$SERVICE_GROUP" --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}
write_config() {
  mkdir -p -- "$CONF_DIR" "$DATA_DIR"
  python3 - "$CONF_DIR/config.yaml" "$DATA_DIR" "$APP_PORT" "$DB_DIALECT" "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASS" "$DB_NAME" "$REDIS_ADDR" "$REDIS_PASS" <<'PY'
import json, os, secrets, sys
from urllib.parse import quote
path, data, port, driver, host, dbport, user, password, name, redis_addr, redis_pass = sys.argv[1:]
source = "file:" + data + "/kazhan.db"
if driver == "mysql":
    source = "{}:{}@tcp({}:{})/{}?parseTime=True&loc=UTC&charset=utf8mb4".format(user, password, host, dbport, name)
elif driver == "postgres":
    if ":" in host and not host.startswith("["):
        host = "[" + host + "]"
    source = "postgres://{}:{}@{}:{}/{}?sslmode=disable".format(quote(user, safe=""), quote(password, safe=""), host, dbport, quote(name, safe=""))
security = {}
for key in ("jwt_admin_key", "jwt_user_key", "card_key", "data_key"):
    security[key] = secrets.token_hex(32)
cfg = {
    "server": {"http": {"addr": "127.0.0.1:" + port, "timeout": "30s"}, "grpc": {"addr": ""}, "migrate_on_start": True},
    "data": {"database": {"driver": driver, "source": source, "max_open_conns": 20, "max_idle_conns": 5},
             "redis": {"addr": redis_addr, "password": redis_pass, "read_timeout": "0.2s", "write_timeout": "0.2s"}},
    "security": security, "tenancy": {"mode": "row"}, "log": {"level": "info", "format": "text"},
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o640)
with os.fdopen(fd, "w", encoding="utf-8") as handle:
    json.dump(cfg, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
}
fix_ownership() {
  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$INSTALL_DIR"
  chmod 0750 "$INSTALL_DIR" "$CONF_DIR" "$DATA_DIR"
  chmod 0640 "$CONF_DIR/config.yaml"
  chmod 0755 "$BIN"
}
write_unit() {
  cat > "$UNIT_FILE" <<EOF
[Unit]
Description=卡栈 (${SITE})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN} serve -conf ${CONF_DIR}
Environment=KAZHAN_SUPERVISOR=systemd
Restart=always
RestartSec=3
LimitNOFILE=65535
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  chmod 0644 "$UNIT_FILE"
  systemctl daemon-reload
}
install_manager_copy() {
  local source=${BASH_SOURCE[0]:-}
  mkdir -p -- "$(dirname "$MANAGER_BIN")"
  if [[ -n "$source" && -r "$source" ]]; then install -m 0755 "$source" "$MANAGER_BIN"
  else
    download_url "$MANAGER_SOURCE_URL" "${RUN_TMP}/manager" 60 || die "管理脚本下载失败"
    install -m 0755 "${RUN_TMP}/manager" "$MANAGER_BIN"
  fi
}
prepare_app() {
  create_service_user
  mkdir -p -- "$INSTALL_DIR"
  if [[ ! -x "$BIN" ]]; then
    if [[ -n "$LOCAL_BIN" ]]; then
      [[ -f "$LOCAL_BIN" ]] || die "找不到二进制: $LOCAL_BIN"
      install -m 0755 "$LOCAL_BIN" "$BIN"
    else
      download_bin "$BIN"
    fi
  fi
  "$BIN" version >/dev/null || die "二进制不可执行"
  if [[ ! -f "$CONF_DIR/config.yaml" ]]; then
    if [[ "$DB_DIALECT" != sqlite ]]; then
      "$BIN" dbtest -dialect "$DB_DIALECT" -host "$DB_HOST" -port "$DB_PORT" \
        -user "$DB_USER" -password "$DB_PASS" -name "$DB_NAME" \
        -redis "$REDIS_ADDR" -redis-password "$REDIS_PASS" || die "数据库或 Redis 校验失败"
    fi
    write_config
  fi
  fix_ownership
  write_unit
  install_manager_copy
}

atomic_install_text() {
  local destination=$1 mode=$2 temporary
  temporary="${RUN_TMP}/$(basename "$destination").tmp"
  cat > "$temporary"
  mkdir -p -- "$(dirname "$destination")"
  install -m "$mode" "$temporary" "$destination"
}
render_acme_site() {
  cat <<EOF
# 由卡栈安装器维护。
server {
    listen 80;
    listen [::]:80;
    server_name ${1};
    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_ROOT};
        default_type text/plain;
        try_files \$uri =404;
    }
    location / { return 404; }
}
EOF
}
write_acme_site() {
  render_acme_site "$1" | atomic_install_text "$NGINX_AVAILABLE" 0644
  ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
}
write_transition_acme_site() {
  render_acme_site "$1" | atomic_install_text "$NGINX_TRANSITION_AVAILABLE" 0644
  ln -sfn "$NGINX_TRANSITION_AVAILABLE" "$NGINX_TRANSITION_ENABLED"
  nginx -t
  systemctl reload nginx
}
remove_transition_site() {
  rm -f -- "$NGINX_TRANSITION_ENABLED" "$NGINX_TRANSITION_AVAILABLE"
  nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
}
render_proxy() {
  local domain=$1 port=$2
  cat <<EOF
    client_max_body_size 101m;
    location ^~ / {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600s;
        client_body_timeout 600s;
    }
EOF
}
write_http_site() {
  { echo "# 由卡栈安装器维护（HTTP）。"
    echo "server {"
    echo "    listen 80;"
    echo "    listen [::]:80;"
    echo "    server_name ${1};"
    render_proxy "$1" "$2"
    echo "}"
  } | atomic_install_text "$NGINX_AVAILABLE" 0644
  ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
}
write_https_site() {
  local domain=$1 port=$2 cert=$3 live
  live="/etc/letsencrypt/live/${cert}"
  [[ -s "$live/fullchain.pem" && -s "$live/privkey.pem" ]] || die "证书不存在：$live"
  { echo "# 由卡栈安装器维护。"
    echo "server {"
    echo "    listen 80;"
    echo "    listen [::]:80;"
    echo "    server_name ${domain};"
    echo "    location ^~ /.well-known/acme-challenge/ { root ${ACME_ROOT}; default_type text/plain; try_files \$uri =404; }"
    echo "    location / { return 301 https://\$host\$request_uri; }"
    echo "}"
    echo "server {"
    echo "    listen 443 ssl http2;"
    echo "    listen [::]:443 ssl http2;"
    echo "    server_name ${domain};"
    echo "    ssl_certificate ${live}/fullchain.pem;"
    echo "    ssl_certificate_key ${live}/privkey.pem;"
    echo "    ssl_protocols TLSv1.2 TLSv1.3;"
    render_proxy "$domain" "$port"
    echo "}"
  } | atomic_install_text "$NGINX_AVAILABLE" 0644
  ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
  nginx -t
  systemctl reload nginx
}
write_certbot_hook() {
  cat <<'EOF' | atomic_install_text "$CERTBOT_DEPLOY_HOOK" 0755
#!/usr/bin/env bash
set -euo pipefail
nginx -t
systemctl reload nginx
EOF
}
verify_acme() {
  local domain=$1 token dir response
  token=$(openssl rand -hex 16)
  dir="${ACME_ROOT}/.well-known/acme-challenge"
  mkdir -p -- "$dir"
  printf '%s' "$token" > "${dir}/${token}"
  response=$(curl --fail --silent --show-error --connect-timeout 8 --max-time 20 "http://${domain}/.well-known/acme-challenge/${token}" || true)
  rm -f -- "${dir}/${token}"
  [[ "$response" == "$token" ]]
}
issue_certificate() {
  local domain=$1 email=$2 cert=$3 live="/etc/letsencrypt/live/${cert}"
  [[ -s "$live/fullchain.pem" && -s "$live/privkey.pem" ]] && return 0
  local -a args=(certonly --webroot -w "$ACME_ROOT" -d "$domain" --cert-name "$cert" --email "$email" --agree-tos --no-eff-email --non-interactive)
  [[ "${KAZHAN_ACME_STAGING:-0}" == 1 ]] && args+=(--staging)
  certbot "${args[@]}"
  [[ -s "$live/fullchain.pem" && -s "$live/privkey.pem" ]]
}
maybe_open_ufw() {
  command -v ufw >/dev/null 2>&1 || return 0
  ufw status 2>/dev/null | grep -q '^Status: active' || return 0
  if ui_yesno "防火墙" "UFW 已启用。证书和访问需要 80/443。是否执行 ufw allow 'Nginx Full'？"; then
    ufw allow 'Nginx Full'
  else
    warn "未修改 UFW。请自行放行 TCP 80/443"
  fi
}
health_ok() {
  local response
  response=$(curl --fail --silent --show-error --max-time 5 "$1") || return 1
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); raise SystemExit(not (d.get("status",{}).get("database") and d["status"].get("server")))' "$response"
}
wait_health() {
  local i
  for ((i = 0; i < 40; i++)); do health_ok "http://127.0.0.1:${APP_PORT}/health" && return 0; sleep 2; done
  journalctl -u "$SERVICE" -n 40 --no-pager >&2 || true
  return 1
}
extract_asset() {
  python3 - "$1" "$2" <<'PY'
import sys, urllib.parse
from html.parser import HTMLParser
class Finder(HTMLParser):
    def __init__(self):
        super().__init__(); self.asset = ""
    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if name in ("src", "href") and value and ("/assets/" in value or value.startswith("assets/") or value.startswith("./assets/")):
                self.asset = urllib.parse.urljoin(sys.argv[2], value); return
finder = Finder()
finder.feed(open(sys.argv[1], encoding="utf-8", errors="replace").read())
print(finder.asset)
PY
}
verify_public() {
  local domain=$1 scheme html asset status
  scheme=$(site_scheme)
  health_ok "${scheme}://${domain}/health" || return 1
  curl --fail --silent --show-error --max-time 30 "${scheme}://${domain}/" >/dev/null || return 1
  html="${RUN_TMP}/admin.html"
  curl --fail --silent --show-error --max-time 30 "${scheme}://${domain}/admin/" -o "$html" || return 1
  asset=$(extract_asset "$html" "${scheme}://${domain}/admin/") || return 1
  [[ -n "$asset" ]] || return 1
  curl --fail --silent --show-error --max-time 30 "$asset" >/dev/null || return 1
  if [[ "$scheme" == https ]]; then
    status=$(curl --silent --output /dev/null --max-time 20 --write-out '%{http_code}' "http://${domain}/") || return 1
    [[ "$status" == 301 || "$status" == 302 || "$status" == 307 || "$status" == 308 ]]
  fi
}

db_ident() { printf '%s' "$SITE" | tr 'A-Z-' 'a-z_' | sed 's/[^a-z0-9_]/_/g' | cut -c1-31; }
collect_input() {
  if [[ -z "$DOMAIN" ]]; then
    has_tty || die "非交互安装请提供 --domain 和 --db"
    DOMAIN=$(prompt_validated validate_install_host "站点地址" "公网域名将申请 HTTPS；内网 IP 只用 HTTP" "")
  fi
  DOMAIN=$(lowercase "$DOMAIN")
  validate_install_host "$DOMAIN" || die "域名或 IP 无效"
  TLS_MODE=$(resolve_tls_mode "$DOMAIN")
  if [[ "$TLS_MODE" == http ]]; then
    ACME_EMAIL=""
    ui_message "HTTP 模式" "主机 ${DOMAIN} 不申请证书。上线请改用已解析到本机的域名。"
  elif [[ -z "$ACME_EMAIL" ]]; then
    has_tty || die "公网域名请提供 --email"
    ACME_EMAIL=$(prompt_validated validate_email "证书邮箱" "用于 Let's Encrypt 到期通知" "")
  fi
  validate_email "$ACME_EMAIL" || [[ "$TLS_MODE" == http ]] || die "邮箱无效"
  if [[ -z "$DB_DIALECT" ]]; then
    has_tty || die "请提供 --db sqlite|mysql|postgres"
    DB_DIALECT=$(ui_menu "数据库" "选择后由安装器在本机安装并建库。SQLite 不安装数据库服务。" \
      sqlite "SQLite，适合试用和小站" \
      mysql "安装 MySQL/MariaDB 和 Redis，并创建库与账号" \
      postgres "安装 PostgreSQL 和 Redis，并创建库与账号") || exit 130
  fi
  case "$DB_DIALECT" in sqlite|mysql|postgres) ;; *) die "数据库须为 sqlite、mysql 或 postgres" ;; esac
  if [[ -z "$APP_PORT" ]]; then APP_PORT=8000; fi
  validate_port "$APP_PORT" || die "端口无效"
  if port_in_use "$APP_PORT"; then
    has_tty || die "端口 ${APP_PORT} 已被占用"
    APP_PORT=$(prompt_validated validate_port "应用端口" "端口已被占用，请换一个只在本机监听的端口" "$((APP_PORT + 1))")
  fi
  DB_HOST=127.0.0.1
  if [[ "$DB_DIALECT" == sqlite ]]; then
    DB_PORT=""; DB_USER=""; DB_PASS=""; DB_NAME=""; REDIS_ADDR=""; REDIS_PASS=""
  else
    [[ "$DB_DIALECT" == mysql ]] && DB_PORT=3306 || DB_PORT=5432
    DB_NAME=$(db_ident)
    DB_USER=$DB_NAME
    validate_ident "$DB_NAME" || die "无法从目录名生成数据库名，请改用小写目录名"
    DB_PASS=$(openssl rand -hex 24)
  fi
  CERT_NAME=$(certificate_name_for_domain "$DOMAIN")
}
show_summary() {
  local db_text="SQLite（不安装 MySQL / PostgreSQL / Redis）"
  [[ "$DB_DIALECT" == mysql ]] && db_text="本机安装 MySQL/MariaDB + Redis，创建库 ${DB_NAME}"
  [[ "$DB_DIALECT" == postgres ]] && db_text="本机安装 PostgreSQL + Redis，创建库 ${DB_NAME}"
  local tls_text="申请 Let's Encrypt 并写入 Nginx HTTPS"
  [[ "$TLS_MODE" == http ]] && tls_text="仅 HTTP 反代，跳过证书"
  ui_yesno "确认安装" "地址：$(site_base_url "$DOMAIN")\n安装向导：$(site_base_url "$DOMAIN")/install\n应用：127.0.0.1:${APP_PORT}\n数据库：${db_text}\n${tls_text}\n\n将通过 apt 安装缺少的软件包。管理员账号在网页向导里创建。"
}
check_domain_preconditions() {
  local domain=$1 mode
  mode=$(resolve_tls_mode "$domain")
  if [[ "$mode" != http ]]; then
    getent ahosts "$domain" >/dev/null 2>&1 || die "域名 ${domain} 无法解析，请先配置 DNS"
  fi
  if nginx_has_domain_conflict "$domain" && [[ ! -e "$NGINX_AVAILABLE" && ! -e "$NGINX_TRANSITION_AVAILABLE" ]]; then
    die "Nginx 已有其他站点使用 ${domain}"
  fi
}

run_install() {
  assert_paths
  check_unmanaged
  local fresh=0
  if ! state_exists; then
    fresh=1
    check_os
    check_resources
    ui_yesno "安装准备" "将安装 Nginx、Certbot。若选择 MySQL 或 PostgreSQL，还会安装对应数据库和 Redis，并创建库与账号。是否继续？" || die "已取消"
    install_base_packages
    check_web_ports
    collect_input
    check_domain_preconditions "$DOMAIN"
    show_summary || die "已取消"
    state_init
  else
    check_os
    load_state
    if [[ "$(state_get phase)" == installed ]]; then
      ui_message "已经安装" "商城：$(site_base_url)\n安装向导：$(site_base_url)/install\n管理命令：sudo ${MANAGER_BIN}"
      return 0
    fi
    install_base_packages
    check_web_ports
    log "从阶段 $(state_get phase) 继续"
  fi
  maybe_open_ufw
  check_domain_preconditions "$DOMAIN"

  local phase
  phase=$(state_get phase)
  if ! phase_at_least "$phase" datastore; then
    provision_datastores
    state_set phase datastore
    phase=datastore
  fi
  prepare_app
  if [[ "$TLS_MODE" == http ]]; then
    state_set phase cert_issued
    phase=cert_issued
  else
    if ! phase_at_least "$phase" acme_ready; then
      mkdir -p -- "${ACME_ROOT}/.well-known/acme-challenge"
      chmod -R 0755 "$ACME_ROOT"
      write_acme_site "$DOMAIN"
      write_certbot_hook
      state_set phase acme_ready
      phase=acme_ready
    fi
    if ! phase_at_least "$phase" cert_issued; then
      verify_acme "$DOMAIN" || die "http://${DOMAIN} 的证书挑战无法从公网回读。请检查 DNS、80 端口和 CDN 后再运行 install"
      issue_certificate "$DOMAIN" "$ACME_EMAIL" "$CERT_NAME" || die "证书申请失败。修复后重新运行 install"
      state_set phase cert_issued
      phase=cert_issued
    fi
  fi
  if ! phase_at_least "$phase" services_ready; then
    systemctl enable --now "$SERVICE"
    wait_health || die "本机健康检查失败"
    port_bound_only_to_loopback "$APP_PORT" || die "应用端口未只监听 127.0.0.1"
    state_set phase services_ready
    phase=services_ready
  fi
  if [[ "$TLS_MODE" == http ]]; then
    write_http_site "$DOMAIN" "$APP_PORT"
  else
    write_https_site "$DOMAIN" "$APP_PORT" "$CERT_NAME"
  fi
  verify_public "$DOMAIN" || die "站点验证失败。Nginx 和证书已保留，修好后重新运行 install"
  state_set phase installed
  ui_message "安装成功" "商城：$(site_base_url)\n请打开 $(site_base_url)/install 创建管理员。\n管理命令：sudo ${MANAGER_BIN}"
}

show_status() {
  state_exists || die "未找到本安装器的状态：${STATE_FILE}"
  load_state
  local app=未知 nginx=未知 health=失败 cert=未知
  systemctl is-active --quiet "$SERVICE" && app=运行中 || app=未运行
  systemctl is-active --quiet nginx && nginx=运行中 || nginx=未运行
  health_ok "http://127.0.0.1:${APP_PORT}/health" && health=正常 || true
  if [[ "$TLS_MODE" == http ]]; then cert="HTTP，无证书"
  elif [[ -s "/etc/letsencrypt/live/${CERT_NAME}/cert.pem" ]]; then
    cert=$(openssl x509 -in "/etc/letsencrypt/live/${CERT_NAME}/cert.pem" -noout -enddate | cut -d= -f2-)
  fi
  ui_message "状态" "阶段：$(state_get phase)\n应用：${app}\nNginx：${nginx}\n健康：${health}\n数据库：${DB_DIALECT}\n地址：$(site_base_url)\n证书：${cert}"
}
show_logs() {
  state_exists || die "尚未安装"
  case "${1:-app}" in
    app) journalctl -u "$SERVICE" -n 100 --no-pager ;;
    nginx) journalctl -u nginx -n 100 --no-pager ;;
    *) die "日志类型：app 或 nginx" ;;
  esac
}
service_action() {
  state_exists || die "尚未安装"
  systemctl "$1" "$SERVICE"
  [[ "$1" == stop ]] || wait_health || warn "服务已执行 ${1}，健康检查尚未通过"
}
configure_domain() {
  state_exists || die "尚未安装"
  load_state
  local old_domain=$DOMAIN old_cert=$CERT_NAME old_mode=$TLS_MODE
  local new_domain new_mode new_cert new_email
  new_domain=$(prompt_validated validate_install_host "修改域名或 IP" "公网域名申请 HTTPS；IP 保持 HTTP" "$DOMAIN")
  new_domain=$(lowercase "$new_domain")
  [[ "$new_domain" != "$old_domain" ]] || return 0
  new_mode=$(resolve_tls_mode "$new_domain")
  new_cert=$(certificate_name_for_domain "$new_domain")
  nginx_has_domain_conflict "$new_domain" && die "Nginx 已有站点使用 ${new_domain}"
  if [[ "$new_mode" == http ]]; then
    TLS_MODE=http; DOMAIN=$new_domain
    write_http_site "$new_domain" "$APP_PORT"
    verify_public "$new_domain" || die "HTTP 验证失败"
    state_set domain "$new_domain"; state_set tls_mode http; state_set cert_name "$new_cert"; state_set acme_email ""
    [[ "$old_mode" == letsencrypt ]] && certbot delete --cert-name "$old_cert" --non-interactive >/dev/null 2>&1 || true
    ui_message "已切换" "现在访问 $(site_base_url)/install"
    return 0
  fi
  new_email=$(prompt_validated validate_email "证书邮箱" "用于新证书通知" "${ACME_EMAIL:-}")
  getent ahosts "$new_domain" >/dev/null 2>&1 || die "新域名无法解析"
  [[ ! -e "/etc/letsencrypt/live/${new_cert}" ]] || die "证书名已存在，拒绝接管"
  mkdir -p -- "${ACME_ROOT}/.well-known/acme-challenge"
  write_certbot_hook
  write_transition_acme_site "$new_domain"
  if ! verify_acme "$new_domain" || ! issue_certificate "$new_domain" "$new_email" "$new_cert"; then
    remove_transition_site
    die "新域名证书失败，原站点未切换"
  fi
  local backup="${RUN_TMP}/nginx-before.conf"
  cp -p -- "$NGINX_AVAILABLE" "$backup"
  remove_transition_site
  TLS_MODE=letsencrypt; DOMAIN=$new_domain
  if ! write_https_site "$new_domain" "$APP_PORT" "$new_cert" || ! verify_public "$new_domain"; then
    TLS_MODE=$old_mode; DOMAIN=$old_domain
    install -m 0644 "$backup" "$NGINX_AVAILABLE"
    ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    nginx -t && systemctl reload nginx
    certbot delete --cert-name "$new_cert" --non-interactive >/dev/null 2>&1 || true
    die "新域名验证失败，已恢复原站点"
  fi
  state_set domain "$new_domain"; state_set acme_email "$new_email"; state_set cert_name "$new_cert"; state_set tls_mode letsencrypt
  [[ "$old_mode" == letsencrypt ]] && certbot delete --cert-name "$old_cert" --non-interactive >/dev/null 2>&1 || true
  ui_message "域名已切换" "请打开 $(site_base_url)/install"
}
renew_certificate() {
  state_exists || die "尚未安装"
  load_state
  [[ "$TLS_MODE" == letsencrypt ]] || die "当前是 HTTP 模式，没有证书可续签"
  certbot renew --cert-name "$CERT_NAME" --deploy-hook "$CERTBOT_DEPLOY_HOOK"
  ui_message "证书" "Certbot 已检查。未到期的证书不会更换。"
}
do_update() {
  [[ -x "$BIN" ]] || die "尚未安装"
  local arg
  for arg in "$@"; do
    case "$arg" in --bin|--bin=*|-conf|--conf|-conf=*|--conf=*|--rollback*|-rollback*) die "请使用部署指南中的更新流程" ;; esac
  done
  (cd "$INSTALL_DIR" && "$BIN" self-update -y -conf "$CONF_DIR" "$@")
  if [[ -f "$UNIT_FILE" ]]; then
    systemctl restart "$SERVICE"
    wait_health || die "更新后健康检查失败"
  fi
}
uninstall_managed() {
  state_exists || die "尚未安装"
  load_state
  ui_yesno "卸载" "将停止卡栈、删除本站 Nginx、证书、程序和配置。MySQL / PostgreSQL / Redis 软件本身保留。是否继续？" || return 0
  systemctl stop "$SERVICE" || true
  systemctl disable "$SERVICE" || true
  rm -f -- "$UNIT_FILE"
  systemctl daemon-reload || true
  local backup="${BACKUP_DIR}/uninstall-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
  mkdir -p -- "$BACKUP_DIR"
  tar -czf "$backup" -C / "$CONF_DIR" "$DATA_DIR" "$STATE_FILE" 2>/dev/null || true
  chmod 0600 "$backup" || true
  rm -f -- "$NGINX_ENABLED" "$NGINX_AVAILABLE" "$NGINX_TRANSITION_ENABLED" "$NGINX_TRANSITION_AVAILABLE" "$CERTBOT_DEPLOY_HOOK"
  nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
  [[ "$TLS_MODE" == letsencrypt ]] && certbot delete --cert-name "$CERT_NAME" --non-interactive >/dev/null 2>&1 || true
  if [[ "$DB_DIALECT" == mysql ]] && ui_yesno "删除数据库" "是否删除本站 MySQL 库 ${DB_NAME}？数据库软件仍保留。"; then
    mysql --protocol=socket -uroot -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';" || warn "删除 MySQL 库失败，请手工处理"
  fi
  if [[ "$DB_DIALECT" == postgres ]] && ui_yesno "删除数据库" "是否删除本站 PostgreSQL 库 ${DB_NAME}？数据库软件仍保留。"; then
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" || warn "删除 PostgreSQL 库失败"
    sudo -u postgres psql -c "DROP ROLE IF EXISTS ${DB_USER};" || true
  fi
  rm -rf -- "$INSTALL_DIR" "$ETC_DIR" "$ACME_ROOT"
  userdel "$SERVICE_USER" >/dev/null 2>&1 || true
  rm -f -- "$MANAGER_BIN"
  ui_message "已卸载" "备份（若成功）：${backup}"
}

usage() {
  cat <<EOF
卡栈安装器 ${MANAGER_VERSION}

不带参数时打开菜单。公网域名会安装 Nginx 并申请证书；内网 IP 只做 HTTP。
选择 MySQL 或 PostgreSQL 时，会在本机安装该数据库和 Redis，并创建库与账号。
SQLite 不安装这些服务。宝塔请用面板插件，不要和本脚本同时管理同一实例。

  install [--yes] [--domain 主机] [--email 邮箱] [--db sqlite|mysql|postgres] [--bin 文件]
  status | logs [app|nginx] | start | stop | restart | update
  configure-domain | renew-cert | uninstall
EOF
}
main_menu() {
  while true; do
    local choice
    if ! state_exists; then
      choice=$(ui_menu "卡栈" "未安装" install "安装" exit "退出") || return 0
    else
      choice=$(ui_menu "卡栈" "请选择" \
        status "查看状态" logs "查看日志" restart "重启" update "在线更新" \
        domain "修改域名和证书" renew "检查证书" uninstall "卸载" exit "退出") || return 0
    fi
    case "$choice" in
      install) run_install ;;
      status) show_status ;;
      logs) show_logs app ;;
      restart) service_action restart ;;
      update) do_update ;;
      domain) configure_domain ;;
      renew) renew_certificate ;;
      uninstall) uninstall_managed; return 0 ;;
      exit) return 0 ;;
    esac
  done
}
parse_install_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes) ASSUME_YES=1; shift ;;
      --local-http) export KAZHAN_LOCAL_HTTP=1; shift ;;
      --domain) [[ $# -ge 2 ]] || die "缺少 --domain"; DOMAIN=$2; shift 2 ;;
      --email) [[ $# -ge 2 ]] || die "缺少 --email"; ACME_EMAIL=$2; shift 2 ;;
      --db) [[ $# -ge 2 ]] || die "缺少 --db"; DB_DIALECT=$2; shift 2 ;;
      --bin) [[ $# -ge 2 ]] || die "缺少 --bin"; LOCAL_BIN=$2; shift 2 ;;
      *) die "未知参数: $1" ;;
    esac
  done
}
main() {
  require_root
  init_runtime
  acquire_lock
  assert_paths
  local command=${1:-}
  if [[ -z "$command" ]]; then
    if has_tty; then command=menu; else command=help; fi
  fi
  case "$command" in
    -h|--help|help) usage; return ;;
    --version) printf 'kazhan-install %s\n' "$MANAGER_VERSION"; return ;;
  esac
  case "$command" in
    menu) main_menu ;;
    install) shift; parse_install_args "$@"; run_install ;;
    status) show_status ;;
    logs) show_logs "${2:-app}" ;;
    start|stop|restart) service_action "$command" ;;
    update) shift; do_update "$@" ;;
    configure-domain) configure_domain ;;
    renew-cert) renew_certificate ;;
    uninstall) uninstall_managed ;;
    *) usage; die "未知命令: $command" ;;
  esac
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
