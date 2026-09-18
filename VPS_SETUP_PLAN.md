# VPS Setup Plan for Pistisai (Coolify-based)

## Overview
Deploy Pistisai Flutter web app to VPS (68.168.30.4) using Coolify for container management and GitHub Actions for CI/CD.

**VPS:** 68.168.30.4 (Ubuntu 24.04 LTS)
**Tailscale IP:** 100.101.206.45
**Coolify URL:** http://100.101.206.45:8000

---

## Phase 0: Prerequisites (Local)

1. **SSH keys ready:** Your ed25519 pubkey (`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPu4TAbuWRj4eSM8+dzwsS3t6NROuvFV4Ml4IwV3jFUg`)
2. **Local `zoidbot` user** with passwordless sudo created
3. **GitHub repo access** for pistisAI/pistisai-app

---

## Phase 1: VPS System Update & Reboot

```bash
ssh root@68.168.30.4
apt-get update && apt-get upgrade -y && reboot
```

---

## Phase 2: Create System Users

```bash
# Create users with NO password (key-only auth)
adduser --disabled-password --gecos "" rightguy
adduser --disabled-password --gecos "" zoidbot

# Add to sudo and docker groups
usermod -aG sudo,docker rightguy
usermod -aG sudo,docker zoidbot

# NOPASSWD sudo
echo 'rightguy ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/rightguy
echo 'zoidbot ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/zoidbot
chmod 440 /etc/sudoers.d/rightguy /etc/sudoers.d/zoidbot
```

---

## Phase 3: SSH Keys

```bash
# For rightguy: use your existing ed25519 pubkey
mkdir -p /home/rightguy/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPu4TAbuWRj4eSM8+dzwsS3t6NROuvFV4Ml4IwV3jFUg' > /home/rightguy/.ssh/authorized_keys
chown -R rightguy:rightguy /home/rightguy/.ssh
chmod 700 /home/rightguy/.ssh
chmod 600 /home/rightguy/.ssh/authorized_keys

# For zoidbot: generate new keypair
sudo -u zoidbot ssh-keygen -t ed25519 -f /home/zoidbot/.ssh/id_ed25519 -N ""
# Save private key locally to ~/.hermes/vault/zoidbot_ssh_key
```

---

## Phase 4: Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey=[REDACTED - stored in GitHub Secrets]
# VPS assigned 100.101.206.45
```

---

## Phase 5: Docker

```bash
curl -fsSL https://get.docker.com | sh
# Users already in docker group from Phase 2
```

---

## Phase 6: SSH Hardening (CORRECT ORDER - after users + keys + Tailscale + Docker)

```bash
# Create hardening config
cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
# Security hardening
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey

# Listen ONLY on Tailscale IP and localhost
ListenAddress 100.101.206.45
ListenAddress 127.0.0.1

# Allowed users
AllowUsers rightguy zoidbot root

# Additional hardening
MaxAuthTries 3
LoginGraceTime 30
PermitEmptyPasswords no
X11Forwarding no
EOF

# Fix systemd socket activation conflict
systemctl stop ssh ssh.socket
systemctl daemon-reload
systemctl start ssh.socket ssh

# Verify
ss -tlnp | grep :22
# Should show ONLY 100.101.206.45:22 and 127.0.0.1:22
```

---

## Phase 7: Coolify Configuration (via browser)

1. **Create admin account:** `christopher.maltais@gmail.com`
2. **Enable API access** in Settings → API
3. **Create API token** (Root permissions, never expires)
4. **Save token** to `~/.hermes/vault/coolify_api_token` (chmod 600)
5. **Add server:** Use Tailscale IP `100.101.206.45`, key-based auth
6. **Create Pistisai team** and add both users

---

## Phase 8: DNS (Cloudflare)

Using Global API Key: `[REDACTED - stored in GitHub Secrets]`

| Domain | Type | Target | Proxy |
|--------|------|--------|-------|
| cloudtolocalllm.online | A | 68.168.30.4 | DNS only |
| direct.cloudtolocalllm.online | A | 68.168.30.4 | DNS only |
| vps.cloudtolocalllm.online | A | 68.168.30.4 | DNS only |
| direct.pistisai.app | A | 68.168.30.4 | DNS only |
| vps.pistisai.app | A | 68.168.30.4 | DNS only |

`pistisai.app` apex + subdomains remain on Cloudflare Tunnels (proxied).

---

## Phase 9: Deploy pistisai-app

1. Fix Flutter web build (dependency_overrides in pubspec.yaml):
   ```yaml
   dependency_overrides:
     material_ui: 1.1.0
     cupertino_ui: 1.0.1
   ```
2. Update `.github/workflows/deploy-web.yml`:
   - Build → push to GHCR
   - Trigger Coolify via webhook (not SSH)
3. Pin Flutter base image: `ghcr.io/cirruslabs/flutter:3.44.6` (not `stable`)

---

## Key Files / Secrets

| Item | Location |
|------|----------|
| Your SSH pubkey | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPu4TAbuWRj4eSM8+dzwsS3t6NROuvFV4Ml4IwV3jFUg` |
| Zoidbot SSH key | `~/.hermes/vault/zoidbot_ssh_key` |
| Coolify API token | `[REDACTED - stored in GitHub Secrets]` |
| Cloudflare Global API Key | `[REDACTED - stored in GitHub Secrets]` |
| Tailscale auth key | `[REDACTED - stored in GitHub Secrets]` |
| Root password (for initial login) | `[REDACTED - stored in GitHub Secrets]` |

## Local Machine Setup (This PC)

| Item | Status |
|------|--------|
| Local `zoidbot` user | ✅ Created with `wheel` group |
| Local passwordless sudo | ✅ `/etc/sudoers.d/zoidbot` — `zoidbot ALL=(ALL) NOPASSWD: ALL` |

---

## Deployment Order Checklist

- [ ] Phase 0: Prerequisites
- [ ] Phase 1: VPS update/reboot
- [ ] Phase 2: Create users
- [ ] Phase 3: SSH keys
- [ ] Phase 4: Tailscale
- [ ] Phase 5: Docker
- [ ] Phase 6: SSH hardening
- [ ] Phase 7: Coolify config
- [ ] Phase 8: DNS
- [ ] Phase 9: Deploy app

---

## Notes

- **SSH lockdown must be in correct order:** Users → Keys → NOPASSWD sudo → Tailscale → Docker → SSH hardening
- **Never lock down SSH before users have keys and NOPASSWD sudo configured**
- **Coolify uses Tailscale IP for server communication**
- **Root SSH uses key auth only (PermitRootLogin prohibit-password)**
- **Public IP SSH completely blocked**
- **Coolify marketplace apps recommended:** Open WebUI, n8n (workflow automation), PostgreSQL, Redis (managed by Coolify)