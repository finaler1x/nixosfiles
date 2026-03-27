# nix-infra

NixOS homelab — NAS managed from one repo.

## Hosts

| Host | Machine | Rebuild |
|------|---------|---------|
| `homelab` | NAS (24/7) | `sudo nixos-rebuild switch --flake .#homelab` |

## Services

All web UIs are at `*.home.local` — requires AdGuard DNS rewrites pointing to the NAS IP.
TLS via Caddy's internal CA (`local_certs`). Import the root cert once per device:
```bash
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt
```

### homelab (modules/docker/homelab/)

| Domain | Service |
|--------|---------|
| `adguard.home.local` | AdGuard Home — DNS + ad blocker |
| `files.home.local` | Filebrowser — web file manager |
| `sync.home.local` | Syncthing — device sync |
| `dash.home.local` | Homarr — dashboard |
| `vault.home.local` | Vaultwarden — password manager |
| `status.home.local` | Uptime Kuma — monitoring |
| `ntfy.home.local` | Ntfy — push notifications |
| `photos.home.local` | Immich — photo/video management |
| `docs.home.local` | Paperless-ngx — document management |
| `portainer.home.local` | Portainer — Docker management |
| `logs.home.local` | Dozzle — container logs |

Cockpit is available at `http://homelab:9090`.

## Storage (NAS)

```
/mnt/storage/          ← mergerfs pool (4x 4TB, epmfs)
  media/               ← photos, videos, music
  documents/           ← paperless, scans
  backups/             ← restic targets, manual backups
  shares/              ← general file sharing (Samba)
  syncthing/           ← Syncthing data
  docker/
    homelab/           ← container data (caddy, adguard, vaultwarden, etc.)
/mnt/parity1/          ← SnapRAID parity (1x 4TB)
```

## Structure

```
flake.nix
.sops.yaml                          # sops-nix key configuration
secrets/
  nas.yaml                          # encrypted secrets (safe to commit)
  nas.yaml.example                  # plain-text structure reference
modules/
  hosts/
    homelab/                        # NAS host config
      configuration.nix
      hardware-configuration.nix
  nixos/
    common.nix                      # shared: locale, user, base packages
    tailscale.nix                   # Tailscale + subnet router
    secrets.nix                     # sops-nix secret declarations
    server/
      storage.nix                   # mergerfs mounts + directory structure
      snapraid.nix                  # SnapRAID + systemd timers
      samba.nix                     # Samba shares
      nfs.nix                       # NFS exports
      docker.nix                    # Docker daemon
      firewall.nix                  # firewall rules
      monitoring.nix                # smartd SMART monitoring
      backup.nix                    # restic backups
      wol.nix                       # Wake-on-LAN
  docker/
    homelab/
      docker-compose.yml
      Caddyfile
      .env.example                  → cp to .env and fill in
  packages/
    home/                           # Home Manager dotfiles (zsh, git, neovim, tmux)
```

## Common Commands

```bash
# Rebuild local host
sudo nixos-rebuild switch --flake /etc/nixos#homelab

# Update all flake inputs
nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#homelab

# Rollback
sudo nixos-rebuild switch --rollback

# Edit secrets
sops secrets/nas.yaml
```

## sops-nix Setup (run once per machine)

```bash
# 1. Get the host's age public key
nix-shell -p ssh-to-age --run \
  "ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub"

# 2. Generate your personal age key (for editing secrets locally)
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"
age-keygen -y ~/.config/sops/age/keys.txt   # print public key

# 3. Put both public keys in .sops.yaml

# 4. Create secrets (uses structure from secrets/nas.yaml.example)
sops secrets/nas.yaml
```
