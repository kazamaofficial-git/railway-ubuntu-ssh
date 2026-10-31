# shellcheck shell=bash
# ============================================================
# Kazama — SSH login banner
# Developer  : @kazamaofficial-git
# Repository : https://github.com/kazamaofficial-git/railway-ubuntu-ssh
# ============================================================
# Sourced by /etc/profile on login. It only runs for interactive
# bash terminals, and renders inside a subshell so no variable or
# function ever leaks into the user's session.
# Set KAZAMA_NO_BANNER=1 (e.g. in ~/.profile) to silence it.

[ -n "${BASH_VERSION:-}" ] && [ -t 1 ] && [ -z "${KAZAMA_NO_BANNER:-}" ] || return 0

(
  # shellcheck source=/dev/null
  . /usr/local/lib/kazama/common.sh 2>/dev/null || exit 0
  kz_init_colors

  # ---- system info ------------------------------------------------------
  os_name="$( . /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-Linux}")"
  kernel="$(uname -r)"
  cpu_model="$(awk -F': ' '/^model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null | sed -E 's/ +/ /g')"
  vcpus="$(printf '%.0f' "$(kz_cpu_count)")"
  mem_text="$(kz_human_bytes "$(kz_mem_used_bytes)") / $(kz_human_bytes "$(kz_mem_total_bytes)")"
  disk_text="$(df -h / 2>/dev/null | awk 'NR == 2 { print $3 " / " $2 " (" $5 ")" }')"
  ip_addr="$(hostname -I 2>/dev/null | awk '{ print $1 }')"
  uptime_text="$(kz_fmt_duration "$(kz_container_age)")"

  # ---- src sync status (local marker only — no network call) ------------
  if [ -n "$(kz_secret GITHUB_TOKEN github-token)" ] && [ -s "$KZ_STATE_DIR/src-repo" ]; then
    sync_text="${C_GREEN}● $(msg 'synced →' 'tersinkron →')${C_RESET} ${C_WHITE}$(<"$KZ_STATE_DIR/src-repo")${C_RESET}"
  else
    sync_text="${C_GREY}● $(msg 'off — set GITHUB_TOKEN to enable backup' 'mati — isi GITHUB_TOKEN untuk mengaktifkan backup')${C_RESET}"
  fi

  row() { printf '  %s%-8s%s %s│%s %s\n' "$C_CYAN" "$1" "$C_RESET" "$C_GREY" "$C_RESET" "$2"; }
  hint() { printf '  %s➜%s %s%s%-17s%s %s%s%s\n' "$C_GREEN" "$C_RESET" "$C_YELLOW" "$C_BOLD" "$1" "$C_RESET" "$C_DIM" "$2" "$C_RESET"; }

  # ---- logo -------------------------------------------------------------
  printf '\n'
  printf '%s\n' "${C_CYAN}${C_BOLD}  ██╗  ██╗ █████╗ ███████╗ █████╗ ███╗   ███╗ █████╗ ${C_RESET}"
  printf '%s\n' "${C_SKY}${C_BOLD}  ██║ ██╔╝██╔══██╗╚══███╔╝██╔══██╗████╗ ████║██╔══██╗${C_RESET}"
  printf '%s\n' "${C_BLUE}${C_BOLD}  █████╔╝ ███████║  ███╔╝ ███████║██╔████╔██║███████║${C_RESET}"
  printf '%s\n' "${C_INDIGO}${C_BOLD}  ██╔═██╗ ██╔══██║ ███╔╝  ██╔══██║██║╚██╔╝██║██╔══██║${C_RESET}"
  printf '%s\n' "${C_PURPLE}${C_BOLD}  ██║  ██╗██║  ██║███████╗██║  ██║██║ ╚═╝ ██║██║  ██║${C_RESET}"
  printf '%s\n' "${C_PINK}${C_BOLD}  ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝${C_RESET}"
  printf '\n'
  printf '%s\n' "${C_WHITE}${C_BOLD}      ☁  Cloud Shell · Railway · ${os_name}  🚂${C_RESET}"
  printf '%s\n' "${C_YELLOW}${C_BOLD}               Developer · ${KZ_AUTHOR}${C_RESET}"
  printf '\n'

  # ---- details ----------------------------------------------------------
  rule="${C_GREY}  ────────────────────────────────────────────────────${C_RESET}"
  printf '%s\n' "$rule"
  row "User" "${C_WHITE}$(whoami)${C_RESET}${C_GREY} @ ${C_WHITE}$(hostname)${C_RESET}"
  row "OS" "${C_WHITE}${os_name}${C_RESET}"
  row "Kernel" "${C_WHITE}${kernel}${C_RESET}"
  row "Uptime" "${C_WHITE}${uptime_text}${C_RESET}"
  row "CPU" "${C_WHITE}${cpu_model:-CPU} ${C_GREY}(${vcpus} vCPU)${C_RESET}"
  row "Memory" "${C_WHITE}${mem_text}${C_RESET}"
  row "Disk" "${C_WHITE}${disk_text}${C_RESET}"
  row "IP" "${C_WHITE}${ip_addr:-n/a}${C_RESET}"
  row "Sync" "$sync_text"
  printf '%s\n' "$rule"

  # ---- hints ------------------------------------------------------------
  hint "usage" "$(msg 'check Railway trial credit & uptime left' 'cek sisa kredit trial & uptime Railway')"
  hint "src-sync status" "$(msg 'see your private backup repository' 'lihat repository backup privat Anda')"
  printf '\n'
)
