#!/usr/bin/env bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — private access via Tailscale
# Developer  : @kazamaofficial-git
# ============================================================
# Reads  : TAILSCALE_AUTHKEY (secret) / TAILSCALE_AUTHKEY_VAR (variable), KZ_TS_HOSTNAME
# Output : host, name  ($GITHUB_OUTPUT)
# Use an EPHEMERAL, reusable auth key so the machine disappears when the run ends.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

key="$(kz_secret TAILSCALE_AUTHKEY)"
[[ -n $key ]] || kz_die \
  "TAILSCALE_AUTHKEY is missing (create one at https://login.tailscale.com/admin/settings/keys)." \
  "TAILSCALE_AUTHKEY belum diisi (buat di https://login.tailscale.com/admin/settings/keys)."
echo "::add-mask::$key"

kz_info "Installing Tailscale ..." "Memasang Tailscale ..."
curl -fsSL https://tailscale.com/install.sh | sudo sh >/dev/null

name="${KZ_TS_HOSTNAME:-}"
[[ -n $name ]] || name="kazama-ssh-${GITHUB_RUN_ID:-local}"

if ! sudo tailscale up --authkey="$key" --hostname="$name" --accept-dns=false --reset; then
  kz_die "tailscale up failed — check the auth key." "tailscale up gagal — periksa auth key."
fi

ip=''
for _ in $(seq 1 15); do
  ip="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
  [[ -n $ip ]] && break
  sleep 2
done
[[ -n $ip ]] || kz_die "Could not get a Tailscale IP." "Gagal mendapatkan IP Tailscale."

kz_output host "$ip"
kz_output name "$name"
kz_info "Tailscale ready: $ip ($name)" "Tailscale siap: $ip ($name)"
