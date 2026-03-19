# TODO

## NAS — Placeholders to fill in

- [ ] `modules/server/storage.nix` — replace `UUID-DISK-1` … `UUID-DISK-4` and `UUID-PARITY-1`
      → `sudo blkid | grep -E 'sda|sdb|sdc|sdd|sde'`
- [ ] `modules/server/backup.nix` — replace `BACKUP-UUID` (external backup drive)
      → `sudo blkid | grep sdf` (or whatever the backup drive is)
- [ ] `modules/common.nix` — add your SSH public key (currently commented out)
- [ ] `modules/server/nfs.nix` — verify subnet `192.168.1.0/24` matches your LAN
- [ ] `modules/tailscale.nix` — update the subnet comment with your actual LAN

## NAS — sops-nix Setup

- [ ] Generate homelab host age key and paste into `.sops.yaml`
- [ ] Generate personal age key and paste into `.sops.yaml`
- [ ] `sops secrets/nas.yaml` — create with all values from `secrets/nas.yaml.example`
  - [ ] `samba/antonio_password`
  - [ ] `vaultwarden/admin_token` (generate: `openssl rand -hex 32`)
  - [ ] `ntfy/admin_password`
  - [ ] `tailscale/auth_key` (from tailscale.com/admin/settings/keys)
  - [ ] `restic/password`
  - [ ] `gaming_rig_mac` (gaming rig's Ethernet NIC MAC)

## NAS — Docker Setup

- [ ] `docker/nas/.env` — copy from `.env.example`, fill `SERVICE_VM_IP` and `DEV_VM_IP` once VMs exist
- [ ] `docker/nas/docker-compose.yml` — Vaultwarden: set `SIGNUPS_ALLOWED=true` for first account creation, then revert

## NAS — One-Time Manual Steps (after first nixos-rebuild)

- [ ] `sudo smbpasswd -a antonio` — set Samba password
- [ ] `sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --ssh`
- [ ] Approve subnet route in Tailscale admin console
- [ ] AdGuard setup wizard: `http://NAS_IP:3000` (first run only)
  - [ ] Set upstream DNS: `1.1.1.1` and `9.9.9.9`
  - [ ] Add DNS rewrites: `*.home.local` → NAS IP
- [ ] Trust Caddy root cert on all devices (see SETUP.md)
- [ ] Create Vaultwarden admin account, then set `SIGNUPS_ALLOWED=false`
- [ ] Subscribe to Ntfy topic `homelab-alerts` in Ntfy app

## NAS — Monitoring Setup

- [ ] Uptime Kuma: add monitors for all services (see SETUP.md for list)
- [ ] Uptime Kuma: connect Ntfy as notification provider
- [ ] Uptime Kuma: add maintenance windows for VM services (when gaming rig is off)
- [ ] Watchtower: optionally configure `WATCHTOWER_NOTIFICATION_URL` for update alerts via Ntfy

## Gaming Rig — Hardware Prep

- [ ] BIOS/UEFI: enable Wake-on-LAN
- [ ] Windows: Device Manager → NIC → Power Management → enable "Wake on Magic Packet"
- [ ] Windows: enable OpenSSH Server (Settings → Optional Features → OpenSSH Server)
- [ ] Windows: set up SSH key auth for antonio (so `sleep-gaming` works without a password)
- [ ] Hyper-V: enable in Windows Features

## Gaming Rig — Hyper-V VMs

- [ ] Create `service-vm` (8GB RAM, 20GB disk, bridge network)
- [ ] Create `dev-vm` (4GB RAM, 30GB disk, bridge network)
- [ ] Both VMs: Automatic Start Action → "Always start"
- [ ] Both VMs: CPU weight → Low (gaming has priority)
- [ ] Install NixOS on both VMs
- [ ] Both VMs: replace `hardware-configuration.nix` stub with real one
      → `nixos-generate-config --show-hardware-config`
- [ ] Both VMs: replace `NAS_IP` in `configuration.nix` with actual NAS IP
- [ ] Deploy configs: `nixos-rebuild switch --flake .#service-vm --target-host ...`

## service-vm — Docker Setup

- [ ] `docker/service-vm/.env` — copy from `.env.example`, fill all values
- [ ] `docker compose up -d` — first start
- [ ] Create NFS subdirs on NAS before starting: `media/photos`, `media/immich-upload`,
      `documents/paperless`, `documents/paperless-consume`

## dev-vm — Docker Setup

- [ ] `docker/dev-vm/.env` — copy from `.env.example`, fill `CODE_SERVER_PASSWORD`
- [ ] `docker compose up -d` — first start
- [ ] Forgejo: finish setup wizard at `http://dev-vm-ip:3000`, create admin account

## Someday / Nice to Have

- [ ] Portainer Agent on service-vm → manage both VMs from one Portainer instance
- [ ] Enable auto-updates in `hosts/homelab/configuration.nix` (commented out block)
- [ ] Remote restic target (Backblaze B2, Hetzner Storage Box, etc.) as second backup destination
- [ ] Forgejo Actions runner for CI/CD
- [ ] Immich → configure external library pointing at `/mnt/nas/media/photos`
