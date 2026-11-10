#!/usr/bin/env bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — keep the session alive
# Developer  : @kazamaofficial-git
# ============================================================
# Reads: KZ_DURATION (minutes, 5-345), KZ_IDLE (minutes, 0 = never stop on idle)
# Ends when: the time limit is reached, nobody has been connected over SSH for KZ_IDLE
#            minutes, or the file /tmp/kazama/STOP exists. Cancelling the run also works.
# (KZ_DURATION_SECONDS / KZ_TICK exist only for automated tests.)
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

clamp() { # clamp VALUE DEFAULT MIN MAX
  local v=$1
  [[ $v =~ ^[0-9]+$ ]] || v=$2
  ((v < $3)) && v=$3
  ((v > $4)) && v=$4
  printf '%s' "$v"
}

duration_min="$(clamp "${KZ_DURATION:-330}" 330 5 345)"
idle_min="$(clamp "${KZ_IDLE:-30}" 30 0 345)"
duration_s=$((duration_min * 60))
[[ -n ${KZ_DURATION_SECONDS:-} ]] && duration_s=$KZ_DURATION_SECONDS
tick="${KZ_TICK:-20}"
stop_file=/tmp/kazama/STOP
mkdir -p "$(dirname "$stop_file")"
rm -f "$stop_file"

start=$SECONDS
last_active=$SECONDS
last_log=$((SECONDS - 600))

kz_info "Session running for up to ${duration_min} min (idle stop: ${idle_min} min)" \
        "Sesi berjalan hingga ${duration_min} menit (stop saat idle: ${idle_min} menit)"

while true; do
  # Never let a failing `ss` abort the session: count 0 instead.
  active="$(ss -H -tn state established '( sport = :22 )' 2>/dev/null | wc -l || true)"
  [[ $active =~ ^[0-9]+$ ]] || active=0
  ((active > 0)) && last_active=$SECONDS

  if [[ -e $stop_file ]]; then kz_info "Stop file found - ending session" "File STOP ditemukan - mengakhiri sesi"; break; fi
  if ((SECONDS - start >= duration_s)); then kz_info "Time limit reached - ending session" "Batas waktu tercapai - mengakhiri sesi"; break; fi
  if ((idle_min > 0 && SECONDS - last_active >= idle_min * 60)); then
    kz_info "No SSH session for ${idle_min} min - ending session" "Tidak ada sesi SSH selama ${idle_min} menit - mengakhiri sesi"
    break
  fi
  if ((SECONDS - last_log >= 300)); then
    left=$(((duration_s - (SECONDS - start)) / 60))
    kz_info "Alive - ${left} min left, SSH sessions: ${active}" "Aktif - sisa ${left} menit, sesi SSH: ${active}"
    last_log=$SECONDS
  fi
  sleep "$tick"
done
