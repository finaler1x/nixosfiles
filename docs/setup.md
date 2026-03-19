# Setup Guide

Complete setup from scratch in order. Each phase can be tested before moving to the next.

---

## Phase 1 — NixOS on the NAS

### 1.1 Install NixOS

Install NixOS on the boot SSD as usual. After the first boot:

```bash
# Clone this repo
nix-shell -p git
git clone git@github.com:YOUR_USER/nix-infra.git ~/nix-infra
sudo ln -sf ~/nix-infra /etc/nixos
```

### 1.2 Find disk UUIDs

```bash
sudo blkid
```

Fill in `modules/server/storage.nix`:
- `UUID-DISK-1` … `UUID-DISK-4` → your 4 data HDDs
- `UUID-PARITY-1` → your parity HDD

Fill in `modules/server/backup.nix`:
- `BACKUP-UUID` → your external backup drive (leave disconnected for now if not ready)

### 1.3 Add your SSH public key

In `modules/common.nix`, uncomment and fill in:
```nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA..."
];
```

### 1.4 Set up sops-nix

```bash
# Get the NAS host age key (run this ON the NAS after first boot)
nix-shell -p ssh-to-age --run \
  "ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub"
# → age1abc123...  ← paste into .sops.yaml as &homelab

# Generate your personal age key (run on your dev machine, not NAS)
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"
# Print the public key:
age-keygen -y ~/.config/sops/age/keys.txt
# → age1xyz456...  ← paste into .sops.yaml as &antonio
```

Edit `.sops.yaml` and replace both `age1REPLACE_WITH_...` placeholders.

Create the secrets file (refer to `secrets/nas.yaml.example` for structure):
```bash
sops secrets/nas.yaml
```

Fill in:
| Key | Value |
|-----|-------|
| `samba/antonio_password` | your Samba password |
| `vaultwarden/admin_token` | `openssl rand -hex 32` |
| `ntfy/admin_password` | a password for the Ntfy admin UI |
| `tailscale/auth_key` | from tailscale.com → Settings → Auth Keys |
| `restic/password` | a strong password for the backup repo |
| `gaming_rig_mac` | Ethernet MAC of your gaming rig (`ipconfig /all` on Windows) |

### 1.5 First NixOS build

```bash
sudo nixos-rebuild switch --flake /etc/nixos#homelab
```

If it fails: check disk UUIDs and that `secrets/nas.yaml` exists and is encrypted.

### 1.6 One-time manual steps

```bash
# Samba password
sudo smbpasswd -a antonio

# Tailscale — register and advertise your LAN
sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --ssh
# Then approve the route at tailscale.com/admin/machines
```

---

## Phase 2 — Docker Services on the NAS

### 2.1 Prepare env file

```bash
cd /etc/nixos/docker/nas
cp .env.example .env
# Fill in TZ, PUID, PGID
# Leave SERVICE_VM_IP and DEV_VM_IP blank for now
```

### 2.2 Start services

```bash
docker compose up -d
```

### 2.3 AdGuard — initial setup

AdGuard runs a setup wizard on first start.

1. Open `http://NAS_IP:3000` in your browser
2. Complete the wizard (listen on all interfaces, port 53)
3. In AdGuard settings:
   - **DNS → Upstream**: `1.1.1.1` and `9.9.9.9`
   - **Filters → DNS rewrites**: add `*.home.local` → `NAS_IP`

After this step, all `*.home.local` domains resolve to the NAS.

> Set your router's DNS server to `NAS_IP` so all devices use AdGuard automatically.

### 2.4 Trust Caddy's root certificate

Caddy issues self-signed certs for `.home.local` domains. You need to trust its CA once per device.

```bash
# Export the root cert
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt > caddy-root.crt
```

**macOS**: Double-click `caddy-root.crt` → Keychain Access → System → right-click → "Trust always"

**Windows**: Double-click → Install Certificate → Local Machine → "Trusted Root Certification Authorities"

**Linux**:
```bash
sudo cp caddy-root.crt /usr/local/share/ca-certificates/caddy-root.crt
sudo update-ca-certificates
```

**iPhone/Android**: Email the cert to yourself, open it, follow the prompts.

### 2.5 Vaultwarden — create first account

1. Temporarily set `SIGNUPS_ALLOWED=true` in `docker/nas/docker-compose.yml`
2. `docker compose up -d vaultwarden`
3. Go to `https://vault.home.local`, create your account
4. Set `SIGNUPS_ALLOWED=false`, `docker compose up -d vaultwarden`
5. Access the admin panel at `https://vault.home.local/admin` using the `vaultwarden/admin_token` from sops

### 2.6 Uptime Kuma — configure monitors

Go to `https://status.home.local` and add monitors:

| Name | Type | URL / Host | Interval |
|------|------|-----------|----------|
| AdGuard | HTTP | `https://adguard.home.local` | 60s |
| Filebrowser | HTTP | `https://files.home.local` | 60s |
| Syncthing | HTTP | `https://sync.home.local` | 60s |
| Homarr | HTTP | `https://dash.home.local` | 60s |
| Vaultwarden | HTTP | `https://vault.home.local` | 60s |
| Ntfy | HTTP | `https://ntfy.home.local` | 60s |
| Immich | HTTP | `https://photos.home.local` | 120s |
| Paperless | HTTP | `https://docs.home.local` | 120s |
| Forgejo | HTTP | `https://git.home.local` | 120s |
| Code Server | HTTP | `https://code.home.local` | 120s |

For VM services (Immich, Paperless, Forgejo, Code Server): set up a **Maintenance Window** for overnight hours or whenever the gaming rig is typically off.

**Connect Ntfy notifications:**
1. Uptime Kuma → Settings → Notifications → Add → Ntfy
2. Server URL: `https://ntfy.home.local`
3. Topic: `homelab-alerts`
4. Password: your `ntfy/admin_password` from sops

### 2.7 Subscribe to Ntfy alerts

Install the Ntfy app on your phone.
Add server: `https://ntfy.home.local`
Subscribe to topic: `homelab-alerts`

You'll now receive alerts from:
- Uptime Kuma (service down)
- smartd (SMART disk warnings)
- Watchtower (container updates, if configured)

---

## Phase 3 — Gaming Rig Setup

### 3.1 Enable Wake-on-LAN

On the gaming rig (Windows):
1. BIOS/UEFI: find and enable "Wake on LAN" / "Power on by PCI-E"
2. Windows: Device Manager → Network Adapters → your Ethernet NIC
   → Properties → Power Management → check "Wake on Magic Packet"
3. Windows: Settings → Optional Features → add "OpenSSH Server", start and enable it

Enable key-based SSH auth on Windows:
```powershell
# On Windows, add your SSH public key to the admin authorized_keys
$key = "ssh-ed25519 AAAA..."
Add-Content "C:\ProgramData\ssh\administrators_authorized_keys" $key
# Set correct permissions (required by Windows SSH)
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
```

Test WoL from the NAS:
```bash
wake-gaming   # sends magic packet
# Wait ~30s, then verify:
ssh antonio@gaming-rig.home.local "echo online"
```

### 3.2 Hyper-V setup

Enable Hyper-V:
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
```

Create an **External Virtual Switch** in Hyper-V Manager:
- Name: `LAN`
- Type: External
- Bind to your Ethernet adapter (not Wi-Fi)

This gives VMs bridge networking — they get their own IP on your LAN.

---

## Phase 4 — service-vm

### 4.1 Create the VM in Hyper-V

- RAM: 8192 MB (static, not dynamic — Immich ML needs stable memory)
- CPU: 2–4 cores, weight: Low
- Disk: 20 GB (Generation 2)
- Network: LAN (the external switch)
- Automatic Start Action: Always start, delay 30s

### 4.2 Install NixOS

Boot the NixOS ISO in the VM and install as usual.
After installation, replace the placeholder hardware config:

```bash
# On the VM after first boot
nixos-generate-config --show-hardware-config
```

Copy the output into `hosts/service-vm/hardware-configuration.nix`.

Also replace `NAS_IP` in `hosts/service-vm/configuration.nix` with the actual NAS IP.

### 4.3 Deploy NixOS config

From your dev machine (or from inside the VM with `sudo nixos-rebuild switch --flake .#service-vm`):

```bash
nixos-rebuild switch --flake .#service-vm \
  --target-host antonio@service-vm.home.local \
  --use-remote-sudo
```

### 4.4 Create required NFS directories on the NAS

```bash
# On the NAS:
mkdir -p /mnt/storage/media/photos
mkdir -p /mnt/storage/media/immich-upload
mkdir -p /mnt/storage/documents/paperless
mkdir -p /mnt/storage/documents/paperless-consume
```

### 4.5 Start services

```bash
# On the service-vm:
cd /mnt/nas/docker   # NFS-mounted from NAS
cp /etc/nixos/docker/service-vm/.env.example .env
# Edit .env — fill in DB_PASSWORD, PAPERLESS_SECRET_KEY, etc.
docker compose -f /etc/nixos/docker/service-vm/docker-compose.yml up -d
```

### 4.6 Update Caddy .env on NAS

```bash
# On the NAS, edit docker/nas/.env:
SERVICE_VM_IP=192.168.1.XXX   # service-vm's actual IP
docker compose up -d caddy    # reload Caddy
```

---

## Phase 5 — dev-vm

### 5.1 Create the VM in Hyper-V

- RAM: 4096 MB (dynamic, min 2048)
- CPU: 2–4 cores, weight: Low
- Disk: 30 GB (Generation 2)
- Network: LAN
- Automatic Start Action: Always start, delay 60s (after service-vm)

### 5.2 Install NixOS + deploy config

Same process as service-vm:
1. Install NixOS, replace `hardware-configuration.nix` with `nixos-generate-config` output
2. Replace `NAS_IP` in `hosts/dev-vm/configuration.nix`
3. `nixos-rebuild switch --flake .#dev-vm --target-host ...`

### 5.3 Start services

```bash
# On the dev-vm:
cp /etc/nixos/docker/dev-vm/.env.example /mnt/nas/docker/.env
# Edit .env — fill in CODE_SERVER_PASSWORD
docker compose -f /etc/nixos/docker/dev-vm/docker-compose.yml up -d
```

### 5.4 Forgejo — finish setup

1. Go to `https://git.home.local`
2. Complete the install wizard (SQLite, set domain to `git.home.local`, SSH port to `2222`)
3. Create the admin account

### 5.5 Update Caddy .env on NAS

```bash
DEV_VM_IP=192.168.1.XXX   # dev-vm's actual IP
docker compose up -d caddy
```

---

## Phase 6 — Final Checks

```bash
# All NAS containers running?
docker compose ps

# Disk health
sudo smartctl -a /dev/sda   # repeat for sdb, sdc, sdd, sde

# SnapRAID — initial sync
sudo snapraid sync

# Restic — test backup
sudo systemctl start restic-backups-homelab.service
sudo systemctl status restic-backups-homelab.service

# WoL round-trip
wake-gaming && sleep 30 && ssh antonio@gaming-rig.home.local "echo ok"
sleep-gaming
```

Check `https://status.home.local` — everything should be green.

---

## Ongoing Maintenance

```bash
# Update flake inputs + rebuild
nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#homelab

# Update Docker containers (Watchtower does this automatically at 04:00,
# but to do it manually:)
docker compose pull && docker compose up -d

# Edit secrets
sops secrets/nas.yaml

# Check SnapRAID status
sudo snapraid status
sudo snapraid diff   # see what changed since last sync

# Check disk health
sudo smartctl -H /dev/sda
```
