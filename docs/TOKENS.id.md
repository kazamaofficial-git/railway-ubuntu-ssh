# 🔑 Kazama · Dapatkan Token Anda
### Panduan langkah demi langkah menghubungkan GitHub (dan Railway serta Tailscale, opsional)

[🇬🇧 English](TOKENS.md) · [🇮🇩 Bahasa Indonesia](TOKENS.id.md) · [← Kembali ke README](../README.id.md)

> 💡 **Kenapa butuh token?**
> - **Token GitHub** → folder `/root/src` Anda dibackup ke repo **privat** dan dipulihkan setiap redeploy (pekerjaan aman meski container di-rebuild).
> - **Token Railway** → membuat perintah `usage` menampilkan sisa kredit *sebenarnya*, bukan estimasi.
>
> Keduanya **opsional**. Tidak ada yang dimasukkan ke dalam image — Anda mengaturnya lewat **Variables** Railway.

---

## 1️⃣ Token GitHub — backup otomatis `src`

Token ini memungkinkan container membuat repo privat `kazama-src-<id>` dan menyinkronkan file Anda.

### 🚀 Link langsung
➡️ [Buat GitHub Personal Access Token](https://github.com/settings/tokens/new?description=Kazama%20src-sync&scopes=repo)

### 🪜 Langkah
1. Buka link di atas (atau **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**).
2. Beri nama, mis. `Kazama src-sync`.
3. Atur **Expiration** (mis. *90 days*).
4. ✅ Centang scope **`repo`** (kontrol penuh repository privat).
5. Klik **Generate token**.
6. 📋 **Salin** token (diawali `ghp_`). Token tidak akan ditampilkan lagi.

### 📥 Tempel di mana
Di Railway → service Anda → **Variables**:

```bash
GITHUB_TOKEN = ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Pada deploy berikutnya container akan membuat repo privat dan mulai sinkronisasi.

> 🔒 Di dalam container token hanya disimpan di `/var/lib/kazama/github-token` (`chmod 600`). Token dikirim per perintah lewat HTTP header dan tidak pernah ditulis ke URL remote atau `.git/config`. Anda bisa mencabutnya kapan saja di GitHub.

---

## 2️⃣ Token Railway — kredit live di `usage` *(opsional)*

### 🚀 Link langsung
➡️ [Account tokens Railway](https://railway.com/account/tokens)

### 🪜 Langkah
1. Buka link di atas dan klik **Create Token**.
2. Pilih **No workspace** (token **akun**), beri nama mis. `Kazama usage`.
3. 📋 **Salin** token.

### 📥 Tempel di mana
```bash
RAILWAY_TOKEN = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Redeploy, masuk via SSH, lalu jalankan `usage` — baris *Mode* berubah dari **ESTIMATE** menjadi **LIVE**.

---

## 3️⃣ Auth key Tailscale — SSH privat *(opsional)*

### 🚀 Link langsung
➡️ [Auth key Tailscale](https://login.tailscale.com/admin/settings/keys)

### 🪜 Langkah
1. Buka link dan klik **Generate auth key…**.
2. Centang **Reusable** dan **Ephemeral** (mesin hilang saat container berhenti).
3. Atur masa berlaku, klik **Generate key**, lalu 📋 **salin** (diawali `tskey-auth-`).

### 📥 Tempel di mana
```bash
TAILSCALE_AUTHKEY = tskey-auth-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Redeploy, pastikan Tailscale aktif di perangkat Anda, lalu `ssh root@kazama-ssh` (atau IP `100.x.y.z`).

> **Mode GitHub Actions:** tambahkan key yang sama sebagai **Secret** bernama `TAILSCALE_AUTHKEY` di *Settings → Secrets and variables → Actions* (plus secret `ROOT_PASSWORD`). *Variable* dengan nama itu juga bisa dipakai sebagai cadangan, tetapi variable tidak disamarkan.

---

## 🧾 Referensi cepat

| Token | Variabel | Tipe / scope | Link langsung |
|-------|----------|--------------|---------------|
| 🟣 GitHub | `GITHUB_TOKEN` | classic PAT · `repo` | [github.com/settings/tokens/new](https://github.com/settings/tokens/new?description=Kazama%20src-sync&scopes=repo) |
| 🚂 Railway | `RAILWAY_TOKEN` | account token | [railway.com/account/tokens](https://railway.com/account/tokens) |
| 🔒 Tailscale | `TAILSCALE_AUTHKEY` | auth key (reusable, ephemeral) | [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) |

---

## 🩺 Pemecahan masalah

- **`GITHUB_TOKEN belum diatur` saat menjalankan `src-sync status`?**
  Token disimpan saat container **start**. Redeploy sekali setelah mengisi variabel, lalu coba lagi.
- **"Gagal membuat … (token harus memiliki scope 'repo')"?**
  Token Anda tidak punya scope `repo`, atau berupa token *fine-grained* tanpa akses repository. Buat ulang sebagai token classic dengan scope `repo`.
- **`usage` masih menampilkan ESTIMATE?**
  `RAILWAY_TOKEN` kosong/tidak valid, atau bukan token *akun*. Buat ulang lalu redeploy.

---

<p align="center">
  <b>© Kazama</b> · Dikembangkan oleh <a href="https://github.com/kazamaofficial-git"><b>@kazamaofficial-git</b></a>
</p>
