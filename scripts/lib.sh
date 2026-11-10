# shellcheck shell=bash
# ============================================================
# Kazama SSH (GitHub Actions mode) — shared helpers
# Developer  : @kazamaofficial-git
# Repository : https://github.com/kazamaofficial-git/railway-ubuntu-ssh
# ============================================================
# Sourced by every script in this folder. Only defines functions/variables.

KZ_LANG="${KZ_LANG:-en}"
[[ $KZ_LANG == id ]] || KZ_LANG=en

# Usage: msg "english" "indonesia"
msg() { if [[ $KZ_LANG == id ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

kz_info() { printf '[kazama] %s\n' "$(msg "$1" "$2")"; }
kz_warn() { printf '::warning::[kazama] %s\n' "$(msg "$1" "$2")"; }
kz_die() {
  printf '::error::[kazama] %s\n' "$(msg "$1" "$2")"
  exit 1
}

# Prefer the Actions SECRET (NAME); fall back to the repository VARIABLE (NAME_VAR, not masked).
# Usage: value="$(kz_secret NAME)"   → prints nothing when neither is set
kz_secret() {
  local name=$1 var="${1}_VAR"
  if [[ -n ${!name:-} ]]; then
    printf '%s' "${!name}"
  elif [[ -n ${!var:-} ]]; then
    kz_warn \
      "$name was read from a repository VARIABLE (not masked). Move it to Secrets." \
      "$name dibaca dari VARIABLE repository (tidak disamarkan). Pindahkan ke Secrets." >&2
    printf '::add-mask::%s\n' "${!var}" >&2
    printf '%s' "${!var}"
  fi
}

kz_summary() { [[ -n ${GITHUB_STEP_SUMMARY:-} ]] && printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"; return 0; }
kz_output() { [[ -n ${GITHUB_OUTPUT:-} ]] && printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"; return 0; }

# Bytes → "12.3GiB"
kz_human() { numfmt --to=iec-i --suffix=B --format='%.1f' "$1" 2>/dev/null || printf '%sB' "$1"; }
