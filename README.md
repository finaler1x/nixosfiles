# nix-infra

NixOS homelab — NAS + two VMs managed from one repo.

## Hosts

| Host | Machine | RAM | Rebuild |
|------|---------|-----|---------|
| `homelab` | NAS (24/7) | 8GB | `sudo nixos-rebuild switch --flake .#homelab` |
| `service-vm` | Gaming Rig (Hyper-V) | 8GB | `nixos-rebuild switch --flake .#service-vm --target-host antonio@service-vm.home.local --use-remote-sudo` |
| `dev-vm` | Dev VM (VirtualBox) | 4GB | `sudo nixos-rebuild switch --flake .#dev-vm` |
| `wsl` | Dev Machine | — | `sudo nixos-rebuild switch --flake .#wsl` |

## Services

All web UIs are at `*.home.local` — requires AdGuard DNS rewrites pointing to the NAS IP.
TLS via Caddy's internal CA (`local_certs`). Import the root cert once per device:
```bash
docker exec caddy cat /data/caddy/pki/authorities/local/root.crt
```

### NAS (docker/nas/)

| Domain | Service |
|--------|---------|
| `adguard.home.local` | AdGuard Home — DNS + ad blocker |
| `files.home.local` | Filebrowser — web file manager |
| `sync.home.local` | Syncthing — device sync |
| `dash.home.local` | Homarr — dashboard |
| `vault.home.local` | Vaultwarden — password manager |
| `status.home.local` | Uptime Kuma — monitoring |
| `ntfy.home.local` | Ntfy — push notifications |

### service-vm (docker/service-vm/)

| Domain | Service |
|--------|---------|
| `photos.home.local` | Immich — photo/video management |
| `docs.home.local` | Paperless-ngx — document management |

### dev-vm (docker/dev-vm/)

| Domain | Service |
|--------|---------|
| `git.home.local` | Forgejo — Git server |
| `code.home.local` | Code Server — VS Code in browser |
| `portainer.home.local` | Portainer — Docker management |
| `logs.home.local` | Dozzle — container logs |

## Storage (NAS)

```
/mnt/storage/          ← mergerfs pool (4x 4TB, epmfs)
  media/               ← photos, videos, music
  documents/           ← paperless, scans
  backups/             ← restic targets, manual backups
  shares/              ← general file sharing (Samba)
  syncthing/           ← Syncthing data
  docker/
    nas/               ← NAS container data
    service-vm/        ← service-vm container data (NFS-mounted in VM)
    dev-vm/            ← dev-vm container data (NFS-mounted in VM)
/mnt/parity1/          ← SnapRAID parity (1x 4TB)
```

## Structure

```
flake.nix
.sops.yaml                     # sops-nix key configuration
secrets/
  nas.yaml                     # encrypted secrets (safe to commit)
  nas.yaml.example             # plain-text structure reference
hosts/
  homelab/                     # NAS
  service-vm/                  # Immich + Paperless VM
  dev-vm/                      # Dev tools VM
  wsl/                         # WSL dev environment
modules/
  common.nix                   # shared: locale, user, base packages
  tailscale.nix                # Tailscale + subnet router
  secrets.nix                  # sops-nix secret declarations
  server/
    storage.nix                # mergerfs mounts + directory structure
    snapraid.nix               # SnapRAID + systemd timers
    samba.nix                  # Samba shares
    nfs.nix                    # NFS exports to VMs
    docker.nix                 # Docker daemon
    firewall.nix               # firewall rules
    monitoring.nix             # smartd SMART monitoring
    backup.nix                 # restic backups
    wol.nix                    # Wake-on-LAN (wake-gaming / sleep-gaming)
docker/
  nas/
    docker-compose.yml
    Caddyfile
    .env.example               → cp to .env and fill in
  service-vm/
    docker-compose.yml
    .env.example
  dev-vm/
    docker-compose.yml
    .env.example
home/                          # Home Manager dotfiles (shared)
```

## Docs

- **[docs/setup.md](docs/setup.md)** — full setup guide, phase by phase
- **[docs/todo.md](docs/todo.md)** — what still needs to be done

## Common Commands

```bash
# Rebuild local host
sudo nixos-rebuild switch --flake /etc/nixos#HOSTNAME

# Update all flake inputs
nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#HOSTNAME

# Rollback
sudo nixos-rebuild switch --rollback

# Edit secrets
sops secrets/nas.yaml

# Wake gaming rig / shut it down
wake-gaming
sleep-gaming
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
