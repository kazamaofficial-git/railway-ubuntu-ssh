# 🔑 Kazama · Get Your Tokens
### Step-by-step guide to wiring up GitHub (and optionally Railway)

[🇬🇧 English](TOKENS.md) · [🇮🇩 Bahasa Indonesia](TOKENS.id.md) · [← Back to README](../README.md)

> 💡 **Why tokens?**
> - **GitHub token** → your `/root/src` folder is backed up to a **private** repo and restored on every redeploy (your work survives container rebuilds).
> - **Railway token** → lets the `usage` command show your *real* remaining credit instead of an estimate.
>
> Both are **optional**. Neither is baked into the image — you set them as Railway **Variables**.

---

## 1️⃣ GitHub token — automatic `src` backup

The token lets the container create a private `kazama-src-<id>` repo and sync your files.

### 🚀 Direct link
➡️ [Create a GitHub Personal Access Token](https://github.com/settings/tokens/new?description=Kazama%20src-sync&scopes=repo)

### 🪜 Steps
1. Open the link above (or **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**).
2. Name it, e.g. `Kazama src-sync`.
3. Set an **Expiration** (e.g. *90 days*).
4. ✅ Tick the **`repo`** scope (full control of private repositories).
5. Click **Generate token**.
6. 📋 **Copy** the token (starts with `ghp_`). You will not see it again.

### 📥 Where to paste it
In Railway → your service → **Variables**:

```bash
GITHUB_TOKEN = ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

On the next deploy the container creates the private repo and starts syncing.

> 🔒 Inside the container the token is stored only in `/var/lib/kazama/github-token` (`chmod 600`). It is sent per command through an HTTP header and is never written to a remote URL or `.git/config`. You can revoke it anytime on GitHub.

---

## 2️⃣ Railway token — live credit in `usage` *(optional)*

### 🚀 Direct link
➡️ [Railway account tokens](https://railway.com/account/tokens)

### 🪜 Steps
1. Open the link above and click **Create Token**.
2. Choose **No workspace** (an **account** token), name it e.g. `Kazama usage`.
3. 📋 **Copy** the token.

### 📥 Where to paste it
```bash
RAILWAY_TOKEN = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Redeploy, SSH in and run `usage` — the *Mode* line switches from **ESTIMATE** to **LIVE**.

---

## 🧾 Quick reference

| Token | Variable | Type / scope | Direct link |
|-------|----------|--------------|-------------|
| 🟣 GitHub | `GITHUB_TOKEN` | classic PAT · `repo` | [github.com/settings/tokens/new](https://github.com/settings/tokens/new?description=Kazama%20src-sync&scopes=repo) |
| 🚂 Railway | `RAILWAY_TOKEN` | account token | [railway.com/account/tokens](https://railway.com/account/tokens) |

---

## 🩺 Troubleshooting

- **`GITHUB_TOKEN not set` when running `src-sync status`?**
  The token is saved at container **startup**. Redeploy once after setting the variable, then retry.
- **"Failed to create … (token needs the 'repo' scope)"?**
  Your token lacks the `repo` scope, or it is a *fine-grained* token without repository access. Re-create it as a classic token with `repo`.
- **`usage` still says ESTIMATE?**
  `RAILWAY_TOKEN` is empty/invalid, or it is not an *account* token. Re-create it and redeploy.

---

<p align="center">
  <b>© Kazama</b> · Developed by <a href="https://github.com/kazamaofficial-git"><b>@kazamaofficial-git</b></a>
</p>
