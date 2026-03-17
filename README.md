# nix-infra

NixOS multi-host configuration — VM, Homelab, WSL from one repo.

## Hosts

| Host | Description | Rebuild |
|------|-------------|---------|
| `vm` | VirtualBox VM (Playground) | `sudo nixos-rebuild switch --flake .#vm` |
| `homelab` | Server (Nextcloud, Immich, Samba, ...) | `sudo nixos-rebuild switch --flake .#homelab` |
| `wsl` | Windows WSL (Dev Environment) | `sudo nixos-rebuild switch --flake .#wsl` |

## WSL Installation

```powershell
# 1. NixOS-WSL runterladen von https://github.com/nix-community/NixOS-WSL/releases
# 2. Doppelklick auf nixos.wsl (oder:)
wsl --install --from-file nixos.wsl

# 3. NixOS starten
wsl -d NixOS

# 4. Repo clonen
nix-shell -p git
git clone git@github.com:YOUR_USER/nix-infra.git ~/nix-infra
sudo ln -sf ~/nix-infra /etc/nixos

# 5. Rebuild
sudo nixos-rebuild switch --flake /etc/nixos#wsl
```

## Homelab Services

| Service | URL | Port |
|---------|-----|------|
| Nextcloud | nextcloud.homelab.ts.net | 8080 |
| Immich | photos.homelab.ts.net | 2283 |
| AdGuard Home | adguard.homelab.ts.net | 3000 |
| Vaultwarden | vault.homelab.ts.net | 8222 |
| Uptime Kuma | status.homelab.ts.net | 3001 |
| Samba | \\\\homelab-ip\data | 445 |

## Structure

```
├── flake.nix              # Entry point, all hosts
├── hosts/
│   ├── vm/                # VM config
│   ├── homelab/           # Server config
│   └── wsl/               # WSL dev environment
├── modules/
│   ├── common.nix         # Shared across all hosts
│   └── server/            # Server-only modules
└── home/                  # Home Manager (shared dotfiles)
```

## Quick Start

```bash
# Rebuild
sudo nixos-rebuild switch --flake /etc/nixos#HOSTNAME

# Update all inputs
nix flake update --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#HOSTNAME

# Rollback
sudo nixos-rebuild switch --rollback

# Remote rebuild homelab
nixos-rebuild switch --flake .#homelab \
  --target-host antonio@homelab \
  --use-remote-sudo
```

## TODO

- [ ] sops-nix for secrets
- [ ] Auto-updates for homelab
