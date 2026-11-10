#!/usr/bin/env bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — optional apt packages
# Developer  : @kazamaofficial-git
# ============================================================
# Reads: KZ_PACKAGES (comma/space separated, e.g. "htop,ncdu")
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

mapfile -t wanted < <(tr ',[:space:]' '\n\n' <<<"${KZ_PACKAGES:-}" | grep -v '^$' || true)
if ((${#wanted[@]} == 0)); then
  kz_info "No extra packages requested" "Tidak ada paket tambahan"
  exit 0
fi

valid=()
for pkg in "${wanted[@]}"; do
  if [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]*$ ]]; then
    valid+=("$pkg")
  else
    kz_warn "Skipping invalid package name '$pkg'" "Melewati nama paket tidak valid '$pkg'"
  fi
done
((${#valid[@]})) || exit 0

kz_info "Installing: ${valid[*]}" "Memasang: ${valid[*]}"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${valid[@]}" || \
  kz_warn "Some packages could not be installed" "Beberapa paket gagal dipasang"
