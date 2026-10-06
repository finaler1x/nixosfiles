# nix-infra

NixOS homelab — NAS managed from one repo.

## Hosts

| Host | Machine | Rebuild |
|------|---------|---------|
| `homelab` | NAS (24/7) | `sudo nixos-rebuild switch --flake .#homelab` |

## Services

Web UI routes are defined in `modules/docker/homelab/Caddyfile` at `*.homelab`.
They require AdGuard DNS rewrites pointing to the NAS Tailscale IP.
TLS via Caddy's internal CA (`local_certs`). Import the root cert once per device:
```bash
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt
```

### homelab (Compose and native NixOS services)

| Domain | Service |
|--------|---------|
| `adguard.homelab` | AdGuard Home — DNS + ad blocker |
| `sync.homelab` | Syncthing — device sync |
| `dash.homelab` | Homarr — dashboard |
| `vault.homelab` | Vaultwarden — password manager |
| `status.homelab` | Uptime Kuma — monitoring |
| `ntfy.homelab` | Ntfy — push notifications |
| `photos.homelab` | Immich — photo/video management |
| `cloud.homelab` | Nextcloud — Compose family files and Team folders |
| `docs.homelab` | Paperless-ngx — Compose document management |
| `portainer.homelab` | Portainer — Docker management |
| `logs.homelab` | Dozzle — container logs |

Cockpit is available at `https://cockpit.homelab` through the same proxy.

Nextcloud and Paperless setup, four-person permissions, Tailscale/CA requirements,
verification and backup limitations: [Family applications](docs/family-apps.md).
They use `/storage/apps/nextcloud` and `/storage/apps/paperless`, not the legacy
`/mnt/storage` layout below. Each has its own PostgreSQL/Redis containers; Immich
continues to use the native host services. Versions are pinned and excluded from
Watchtower. NixOS supplies storage guards and coordinated local backups.

Immich remains native by default. The [prepared Docker cutover](modules/docker/immich/README.md)
uses a fresh final copy and an explicit native/Docker selector; it does not
activate the production container or reuse the isolated trial automatically.

## Legacy storage layout (inactive mergerfs configuration)

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
