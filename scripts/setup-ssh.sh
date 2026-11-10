#!/usr/bin/env bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — OpenSSH, root password, optional user & keys
# Developer  : @kazamaofficial-git
# ============================================================
# Reads: ROOT_PASSWORD (secret) | SSH_USERNAME (input) + SSH_PASSWORD (secret, optional)
#        AUTHORIZED_KEYS (secret, optional) | KZ_LANG
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

export DEBIAN_FRONTEND=noninteractive

root_pw="$(kz_secret ROOT_PASSWORD)"
[[ -n $root_pw ]] || kz_die \
  "ROOT_PASSWORD is missing. Add it in Settings > Secrets and variables > Actions." \
  "ROOT_PASSWORD belum diisi. Tambahkan di Settings > Secrets and variables > Actions."
((${#root_pw} >= 8)) || kz_die "ROOT_PASSWORD must be at least 8 characters." "ROOT_PASSWORD minimal 8 karakter."
echo "::add-mask::$root_pw"

kz_info "Installing OpenSSH server ..." "Memasang server OpenSSH ..."
sudo apt-get update -qq
sudo apt-get install -y -qq openssh-server

# root password + the same sshd settings as the Railway image
printf 'root:%s\n' "$root_pw" | sudo chpasswd
sudo install -d -m 0755 /etc/ssh/sshd_config.d /run/sshd
sudo install -m 0644 "$REPO/rootfs/etc/ssh/sshd_config.d/10-kazama.conf" /etc/ssh/sshd_config.d/10-kazama.conf

if [[ -n ${AUTHORIZED_KEYS:-} ]]; then
  sudo install -d -m 0700 /root/.ssh
  printf '%s\n' "$AUTHORIZED_KEYS" | sudo tee /root/.ssh/authorized_keys >/dev/null
  sudo chmod 0600 /root/.ssh/authorized_keys
  kz_info "Authorized keys set for root" "Authorized keys untuk root diatur"
fi

# optional sudo user
user="${SSH_USERNAME:-}"
user_pw="$(kz_secret SSH_PASSWORD)"
if [[ -n $user && -n $user_pw ]]; then
  if [[ ! $user =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    kz_warn "Invalid username '$user' — skipping the extra user" "Username '$user' tidak valid — user tambahan dilewati"
  else
    echo "::add-mask::$user_pw"
    id "$user" &>/dev/null || sudo useradd --create-home --shell /bin/bash "$user"
    sudo usermod -aG sudo "$user"
    printf '%s:%s\n' "$user" "$user_pw" | sudo chpasswd
    kz_info "User $user ready (sudo)" "User $user siap (sudo)"
  fi
fi

# Kazama login banner (same files as the Railway image)
sudo install -d -m 0755 /usr/local/lib/kazama /etc/kazama /var/lib/kazama
sudo install -m 0644 "$REPO/rootfs/usr/local/lib/kazama/common.sh" /usr/local/lib/kazama/common.sh
sudo install -m 0644 "$REPO/rootfs/etc/profile.d/kazama-welcome.sh" /etc/profile.d/kazama-welcome.sh
printf 'APP_LANG=%s\nKZ_PLATFORM=GitHub Actions\n' "$KZ_LANG" | sudo tee /etc/kazama/kazama.conf >/dev/null

sudo systemctl enable --now ssh >/dev/null 2>&1 || sudo service ssh start
sudo systemctl restart ssh 2>/dev/null || sudo service ssh restart

for _ in $(seq 1 15); do
  if ss -ltn | grep -qE ':22\s'; then
    kz_info "sshd is listening on port 22" "sshd mendengarkan di port 22"
    exit 0
  fi
  sleep 2
done
kz_die "sshd is not listening on port 22." "sshd tidak mendengarkan di port 22."
