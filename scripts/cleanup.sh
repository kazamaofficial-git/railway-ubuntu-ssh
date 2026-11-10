#!/usr/bin/env bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — leave the tailnet and collect optional files
# Developer  : @kazamaofficial-git
# ============================================================
# Reads: KZ_SAVE_FILES ('true' copies /root/src and the sudo user's home for upload), SSH_USERNAME
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

command -v tailscale >/dev/null 2>&1 && sudo tailscale logout >/dev/null 2>&1

if [[ ${KZ_SAVE_FILES:-} == true ]]; then
  dest="${RUNNER_TEMP:-/tmp}/kazama-files"
  mkdir -p "$dest"
  [[ -d /root/src ]] && sudo cp -a /root/src "$dest/root-src"
  if [[ -n ${SSH_USERNAME:-} && -d /home/${SSH_USERNAME} ]]; then
    sudo rsync -a --exclude='.*' "/home/${SSH_USERNAME}/" "$dest/home-${SSH_USERNAME}/" 2>/dev/null \
      || sudo cp -a "/home/${SSH_USERNAME}" "$dest/home-${SSH_USERNAME}"
  fi
  sudo chown -R "$(id -u):$(id -g)" "$dest"
  kz_info "Files collected for upload" "File dikumpulkan untuk diunggah"
fi
kz_info "Cleanup done - session ended" "Pembersihan selesai - sesi berakhir"
exit 0
