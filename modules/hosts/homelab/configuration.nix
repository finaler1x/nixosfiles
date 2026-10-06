{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/common.nix
    ../../nixos/tailscale.nix
#    ../../nixos/secrets.nix
    # ── Storage ──────────────────────────────────────────
#    ../../nixos/server/storage.nix
    ../../nixos/server/storage-health.nix
    ../../nixos/server/immich.nix
    ../../nixos/server/family-apps.nix
#    ../../nixos/server/snapraid.nix
    # ── Network shares ───────────────────────────────────
    ../../nixos/server/samba.nix
#    ../../nixos/server/nfs.nix
    # ── Docker ───────────────────────────────────────────
    ../../nixos/server/docker.nix
    # ── Network ──────────────────────────────────────────
    ../../nixos/server/firewall.nix
    ../../nixos/server/network.nix
    # ── Maintenance ──────────────────────────────────────
#    ../../nixos/server/monitoring.nix
#    ../../nixos/server/backup.nix
#    ../../nixos/server/wol.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/disk/by-id";
  boot.zfs.extraPools = [ "storage" ];
  boot.zfs.forceImportRoot = false;

  networking.hostName = "homelab";
  networking.hostId = "1f7c5688";
  networking.hosts."100.99.212.33" = [ "adguard.homelab" ];

  services.zfs.autoScrub.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # ── Cockpit ──────────────────────────────────────────
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = false;
    settings = {
      WebService = {
        AllowUnencrypted = lib.mkForce true;
        Origins = lib.mkForce "https://cockpit.homelab";
        ListenAddress = "172.18.0.1";
      };
    };
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "24.11";
}
