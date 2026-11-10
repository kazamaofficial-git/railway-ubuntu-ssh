# shellcheck shell=bash
# ============================================================
# Kazama — shared shell library
# Developer  : @kazamaofficial-git
# Repository : https://github.com/kazamaofficial-git/railway-ubuntu-ssh
# ============================================================
# Sourced by: kazama-entrypoint · src-sync · usage · kazama-welcome.sh
# Provides  : persisted config, i18n (en/id), logging, colours,
#             container resource helpers.
#
# This file only defines variables and functions — it never runs
# anything on its own, so it is safe to source from any script.

# ---------------------------------------------------------------
# Constants (overridable through the environment for testing)
# ---------------------------------------------------------------
KZ_NAME="Kazama"
KZ_AUTHOR="@kazamaofficial-git"
KZ_REPO_URL="https://github.com/kazamaofficial-git/railway-ubuntu-ssh"

KZ_CONF_FILE="${KZ_CONF_FILE:-/etc/kazama/kazama.conf}"
KZ_STATE_DIR="${KZ_STATE_DIR:-/var/lib/kazama}"
KZ_SRC_DIR="${KZ_SRC_DIR:-/root/src}"

# Variables persisted by kazama-entrypoint for interactive SSH sessions.
# sshd login shells do NOT inherit the container environment, so without
# this file `src-sync` / `usage` would not see APP_LANG, SRC_REPO, etc.
KZ_PERSISTED_VARS=(APP_LANG SYNC_INTERVAL SRC_REPO RAILWAY_PROJECT_ID KZ_PLATFORM)

# ---------------------------------------------------------------
# Config
# ---------------------------------------------------------------

# Load persisted KEY=VALUE pairs. Real environment variables always win.
kz_load_config() {
  [[ -r $KZ_CONF_FILE ]] || return 0
  local key value
  while IFS='=' read -r key value; do
    [[ " ${KZ_PERSISTED_VARS[*]} " == *" $key "* ]] || continue
    [[ -n ${!key:-} ]] || export "$key=$value"
  done <"$KZ_CONF_FILE"
}

# Read a secret from the environment, falling back to its state file.
# Usage: kz_secret ENV_NAME file-name
kz_secret() {
  local env_name=$1 file="$KZ_STATE_DIR/$2"
  if [[ -n ${!env_name:-} ]]; then
    printf '%s' "${!env_name}"
  elif [[ -r $file ]]; then
    printf '%s' "$(<"$file")"
  fi
}

# ---------------------------------------------------------------
# i18n — English (default) and Indonesian
# ---------------------------------------------------------------

kz_lang() {
  case "${APP_LANG:-en}" in
    id | ID | id_ID* | indonesian | Indonesian) printf 'id' ;;
    *) printf 'en' ;;
  esac
}

kz_load_config
KZ_LANG="$(kz_lang)"

# Print the message matching the active language.
# Usage: msg "english text" "teks indonesia"
msg() {
  if [[ $KZ_LANG == id ]]; then
    printf '%s' "$2"
  else
    printf '%s' "$1"
  fi
}

# ---------------------------------------------------------------
# Logging — always to stderr so stdout stays clean for data
# ---------------------------------------------------------------

kz_info() { printf '[kazama] %s\n' "$(msg "$1" "$2")" >&2; }
kz_warn() { printf '[kazama] ⚠ %s\n' "$(msg "$1" "$2")" >&2; }
kz_err() { printf '[kazama] ✖ %s\n' "$(msg "$1" "$2")" >&2; }
kz_die() {
  kz_err "$1" "$2"
  exit 1
}

# ---------------------------------------------------------------
# Colours — call kz_init_colors from scripts that print to a terminal
# ---------------------------------------------------------------

kz_init_colors() {
  if [[ -z ${NO_COLOR:-} && ( -t 1 || -n ${FORCE_COLOR:-} ) ]]; then
    C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
    C_CYAN=$'\e[38;5;51m' C_SKY=$'\e[38;5;45m' C_BLUE=$'\e[38;5;33m'
    C_INDIGO=$'\e[38;5;63m' C_PURPLE=$'\e[38;5;135m' C_PINK=$'\e[38;5;171m'
    C_GREEN=$'\e[38;5;46m' C_YELLOW=$'\e[38;5;220m' C_RED=$'\e[38;5;196m'
    C_GREY=$'\e[38;5;245m' C_WHITE=$'\e[38;5;231m'
  else
    C_RESET='' C_BOLD='' C_DIM='' C_CYAN='' C_SKY='' C_BLUE='' C_INDIGO=''
    C_PURPLE='' C_PINK='' C_GREEN='' C_YELLOW='' C_RED='' C_GREY='' C_WHITE=''
  fi
}

# ---------------------------------------------------------------
# Container resources (cgroup v2 → v1 → host fallback)
# ---------------------------------------------------------------

# Allocated vCPUs, e.g. "2.000".
kz_cpu_count() {
  local quota period
  if [[ -r /sys/fs/cgroup/cpu.max ]]; then
    read -r quota period </sys/fs/cgroup/cpu.max
    if [[ $quota != max && -n ${period:-} ]]; then
      awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.3f", q / p }'
      return
    fi
  elif [[ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]]; then
    quota="$(</sys/fs/cgroup/cpu/cpu.cfs_quota_us)"
    period="$(</sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null || echo 100000)"
    if ((quota > 0)); then
      awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.3f", q / p }'
      return
    fi
  fi
  nproc
}

# Memory limit in bytes (0 when unlimited / unknown).
kz_mem_limit_bytes() {
  local value=''
  if [[ -r /sys/fs/cgroup/memory.max ]]; then
    value="$(</sys/fs/cgroup/memory.max)"
  elif [[ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
    value="$(</sys/fs/cgroup/memory/memory.limit_in_bytes)"
  fi
  # "max" or an absurdly large number means "no limit".
  if [[ $value =~ ^[0-9]+$ ]] && ((value < 1 << 50)); then
    printf '%s' "$value"
  else
    printf '0'
  fi
}

# Memory in use by the container, in bytes.
kz_mem_used_bytes() {
  if [[ -r /sys/fs/cgroup/memory.current ]]; then
    printf '%s' "$(</sys/fs/cgroup/memory.current)"
  elif [[ -r /sys/fs/cgroup/memory/memory.usage_in_bytes ]]; then
    printf '%s' "$(</sys/fs/cgroup/memory/memory.usage_in_bytes)"
  else
    awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END { printf "%d", (t - a) * 1024 }' /proc/meminfo
  fi
}

# Total memory visible to the container, in bytes.
kz_mem_total_bytes() {
  local limit
  limit="$(kz_mem_limit_bytes)"
  if ((limit > 0)); then
    printf '%s' "$limit"
  else
    awk '/^MemTotal:/ { printf "%d", $2 * 1024 }' /proc/meminfo
  fi
}

# Memory total in GB (float) — used by the usage monitor.
kz_mem_gb() {
  awk -v b="$(kz_mem_total_bytes)" 'BEGIN { printf "%.3f", b / 1073741824 }'
}

# Outbound traffic since boot in GB (all interfaces except lo).
kz_egress_gb() {
  awk 'NR > 2 && $1 != "lo:" { tx += $10 } END { printf "%.4f", tx / 1073741824 }' /proc/net/dev 2>/dev/null \
    || printf '0'
}

# Bytes → human readable (KiB/MiB/GiB).
kz_human_bytes() {
  awk -v b="$1" 'BEGIN {
    split("B KiB MiB GiB TiB", u, " ")
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i]
  }'
}

# ---------------------------------------------------------------
# Time
# ---------------------------------------------------------------

# Age of PID 1 (this container) in seconds.
kz_container_age() {
  local clk_tck start_ticks uptime_s
  clk_tck="$(getconf CLK_TCK 2>/dev/null || echo 100)"
  # Strip "pid (comm) " first: the comm field may contain spaces.
  start_ticks="$(sed -E 's/^.*\) //' /proc/1/stat 2>/dev/null | awk '{ print $20 }')"
  uptime_s="$(awk '{ print int($1) }' /proc/uptime 2>/dev/null)"
  awk -v u="${uptime_s:-0}" -v s="${start_ticks:-0}" -v c="$clk_tck" \
    'BEGIN { a = u - s / c; printf "%d", (a < 0 ? 0 : a) }'
}

# Seconds since first deploy (stable across restarts), else container age.
kz_deploy_age() {
  local marker="$KZ_STATE_DIR/deploy-start" started
  if [[ -r $marker ]]; then
    started="$(<"$marker")"
    if [[ $started =~ ^[0-9]+$ ]]; then
      printf '%s' "$(($(date +%s) - started))"
      return
    fi
  fi
  kz_container_age
}

# Seconds → "Xd Yh Zm".
kz_fmt_duration() {
  local s=${1%.*}
  printf '%dd %dh %dm' "$((s / 86400))" "$((s % 86400 / 3600))" "$((s % 3600 / 60))"
}
