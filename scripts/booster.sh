#!/usr/bin/env bash
# ============================================================
# Kazama Storage Booster (Linux / GitHub Actions)
# Developer  : @kazamaofficial-git
# Repository : https://github.com/kazamaofficial-git/railway-ubuntu-ssh
# ============================================================
# Frees disk space on / and prints "free space before -> after".
#
#   safe  package/log/tmp caches, rotated logs, unused Docker images
#   deep  safe + apt lists, snap cache, journal wipe
#   max   deep + REMOVES the apps/SDKs listed in linux-catalog.conf (Android, .NET, Haskell,
#         R, Julia, Swift, Mono, PHP, databases, cloud CLIs, Edge, Firefox, CodeQL, LLVM ...)
#         Google Chrome is always kept; protect more with KZ_KEEP="chrome,dotnet".
#
# Usage: booster.sh [safe|deep|max]      (KZ_DRY_RUN=1 only prints what it would do)
# The Ubuntu release (22.04 / 24.04 / ...) is detected and printed; catalog entries only run
# when something they name is actually installed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

MODE="${1:-safe}"
case $MODE in safe | deep | max) ;; *) kz_die "Unknown mode '$MODE' (safe|deep|max)." "Mode '$MODE' tidak dikenal (safe|deep|max)." ;; esac
DRY="${KZ_DRY_RUN:-0}"
CATALOG="${KZ_CATALOG:-$HERE/linux-catalog.conf}"
export DEBIAN_FRONTEND=noninteractive

IFS=', ' read -r -a KEEP <<<"${KZ_KEEP:-chrome}"
# shellcheck disable=SC1091
UBUNTU="$(. /etc/os-release 2>/dev/null && printf 'ubuntu-%s' "${VERSION_ID:-unknown}")"

run() { # run a privileged command (or just print it in dry-run mode)
  if [[ $DRY == 1 ]]; then printf '   [dry-run] %s\n' "$*"; else sudo "$@" >/dev/null 2>&1 || true; fi
}
free_bytes() { df -B1 --output=avail / | tail -n 1 | tr -d ' '; }
is_kept() { local id=$1 k; for k in "${KEEP[@]}"; do [[ ${k,,} == "${id,,}" ]] && return 0; done; return 1; }

declare -a STEP_NAMES=() STEP_FREED=()
step() { # step "en" "id" command...
  local en=$1 id=$2 before after freed
  shift 2
  before="$(free_bytes)"
  printf '  * %s ...' "$(msg "$en" "$id")"
  "$@"
  after="$(free_bytes)"
  freed=$((after - before)); ((freed < 0)) && freed=0
  printf ' +%s\n' "$(kz_human "$freed")"
  STEP_NAMES+=("$(msg "$en" "$id")")
  STEP_FREED+=("$freed")
}

# ---------------------------------------------------------------- safe
do_apt_cache() { run apt-get clean; run apt-get -y autoremove --purge; }
do_logs() {
  run journalctl --vacuum-size=50M
  run find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -delete
  run find /var/crash -mindepth 1 -delete
}
do_tmp() { run find /var/tmp -mindepth 1 -delete; run find /tmp -mindepth 1 -maxdepth 1 ! -name kazama -delete; }
do_docker() { command -v docker >/dev/null 2>&1 && run docker system prune --all --force; return 0; }

# ---------------------------------------------------------------- deep
do_apt_lists() { run find /var/lib/apt/lists -mindepth 1 -delete; run find /var/lib/snapd/cache -mindepth 1 -delete; }
do_journal() { run journalctl --rotate; run journalctl --vacuum-time=1s; }

# ---------------------------------------------------------------- max
expand_installed() { # expand apt globs to the packages that are really installed
  local pattern
  for pattern in "$@"; do
    dpkg-query -W -f='${Package}\n' "$pattern" 2>/dev/null | sort -u
  done
}

entry_present() { # entry_present "folders" "packages"
  local f p
  IFS=';' read -r -a folders <<<"$1"
  for f in "${folders[@]}"; do
    f="${f// /}"; [[ -z $f ]] && continue
    # shellcheck disable=SC2086
    compgen -G "$f" >/dev/null 2>&1 && return 0
  done
  if [[ -n ${2// /} ]]; then
    # shellcheck disable=SC2086
    [[ -n $(expand_installed $2) ]] && return 0
  fi
  return 1
}

remove_entry() { # remove_entry "folders" "packages" "services"
  local folders_raw=$1 pkgs_raw=$2 services_raw=$3 f s
  local -a folders pkgs services
  IFS=';' read -r -a folders <<<"$folders_raw"
  read -r -a services <<<"$services_raw"
  for s in "${services[@]}"; do run systemctl stop "$s"; run systemctl disable "$s"; done
  # shellcheck disable=SC2086
  mapfile -t pkgs < <(expand_installed $pkgs_raw)
  ((${#pkgs[@]})) && run apt-get -y purge "${pkgs[@]}"
  for f in "${folders[@]}"; do
    f="${f// /}"; [[ -z $f ]] && continue
    # shellcheck disable=SC2086
    for path in $f; do [[ -e $path ]] && run rm -rf "$path"; done
  done
}

do_catalog() {
  [[ -r $CATALOG ]] || { kz_warn "Catalog not found: $CATALOG" "Katalog tidak ditemukan: $CATALOG"; return 0; }
  local line id name folders pkgs services
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*# || -z ${line// /} ]] && continue
    IFS='|' read -r id name folders pkgs services <<<"$line"
    id="${id// /}"; name="$(sed -E 's/^ +| +$//g' <<<"$name")"; services="$(sed -E 's/^ +| +$//g' <<<"$services")"
    is_kept "$id" && continue
    entry_present "$folders" "$pkgs" || continue
    step "Remove $name" "Hapus $name" remove_entry "$folders" "$pkgs" "$services"
  done <"$CATALOG"
}

# ---------------------------------------------------------------- go
start_free="$(free_bytes)"
printf '\n  KAZAMA Storage Booster\n  Mode: %s   %s: %s\n  Ubuntu: %s   Keep: %s\n\n' \
  "$MODE" "$(msg 'Free now' 'Kosong sekarang')" "$(kz_human "$start_free")" "$UBUNTU" "${KEEP[*]}"

step "Package caches" "Cache paket" do_apt_cache
step "Rotated logs and crash reports" "Log lama dan crash report" do_logs
step "Temporary files" "File sementara" do_tmp
step "Unused Docker images" "Image Docker tidak terpakai" do_docker
if [[ $MODE == deep || $MODE == max ]]; then
  step "APT lists and snap cache" "Daftar APT dan cache snap" do_apt_lists
  step "Journal" "Journal" do_journal
fi
[[ $MODE == max ]] && do_catalog

end_free="$(free_bytes)"
gained=$((end_free - start_free)); ((gained < 0)) && gained=0
line="$(msg 'Free space' 'Ruang kosong'): $(kz_human "$start_free") -> $(kz_human "$end_free") (+$(kz_human "$gained"))"
printf '\n  %s\n\n' "$line"

rows=''
for i in "${!STEP_NAMES[@]}"; do
  ((${STEP_FREED[$i]} > 0)) && rows+="| ${STEP_NAMES[$i]} | $(kz_human "${STEP_FREED[$i]}") |"$'\n'
done
kz_summary "
### Kazama Storage Booster (${MODE} · ${UBUNTU})

**${line}**

| Step | Freed |
|---|---|
${rows}"
