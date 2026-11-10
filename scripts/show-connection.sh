#!/usr/bin/env bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — print connection details (log + job summary)
# Developer  : @kazamaofficial-git
# ============================================================
# Reads: KZ_HOST, KZ_NAME, KZ_UBUNTU, KZ_DURATION, SSH_USERNAME (optional)
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

host="$KZ_HOST"
name="${KZ_NAME:-}"
extra_user=''
[[ -n ${SSH_USERNAME:-} && -n $(kz_secret SSH_PASSWORD 2>/dev/null) ]] && extra_user="$SSH_USERNAME"

title="$(msg 'Kazama SSH is ready' 'Kazama SSH siap')"
how="$(msg \
  "1. Make sure **Tailscale** is running on your device and signed in to the same tailnet.
2. Connect:" \
  "1. Pastikan **Tailscale** aktif di perangkat Anda dan masuk ke tailnet yang sama.
2. Hubungkan:")"
pw="$(msg 'password = your `ROOT_PASSWORD` secret (or your SSH key)' 'password = secret `ROOT_PASSWORD` Anda (atau SSH key Anda)')"
ending="$(msg \
  "This session lasts at most **${KZ_DURATION} minutes**. Cancel the workflow run to stop it earlier. Everything on this machine is erased when it ends." \
  "Sesi ini berlangsung maksimal **${KZ_DURATION} menit**. Batalkan workflow run untuk menghentikan lebih awal. Semua data di mesin ini terhapus saat sesi berakhir.")"

user_line=''
[[ -n $extra_user ]] && user_line="ssh ${extra_user}@${host}"

kz_summary "## 🖥️ ${title}

| | |
|---|---|
| **Runner** | \`${KZ_UBUNTU}\` |
| **Address (Tailscale)** | \`${host}\`${name:+ (\`${name}\`)} |

${how}

\`\`\`bash
ssh root@${host}
${user_line}
\`\`\`

${pw}

${ending}

— *Kazama · @kazamaofficial-git*"

echo
echo "=============================================="
echo " ${title}"
echo "   ssh root@${host}"
[[ -n $extra_user ]] && echo "   ssh ${extra_user}@${host}"
echo "   $(msg 'Password: ROOT_PASSWORD' 'Password: ROOT_PASSWORD')"
echo "=============================================="
