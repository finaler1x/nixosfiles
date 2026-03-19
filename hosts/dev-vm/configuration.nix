{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker.nix
  ];

  # ── Boot ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Netzwerk ──────────────────────────────────────────
  networking.hostName = "dev-vm";
  networking.networkmanager.enable = true;

  # ── SSH ───────────────────────────────────────────────
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };

  # ── NFS Mounts from NAS ──────────────────────────────
  # Replace NAS_IP with the actual IP of your homelab NAS.
  fileSystems."/mnt/nas/storage" = {
    device = "NAS_IP:/mnt/storage";
    fsType = "nfs";
    options = [
      "soft" "timeo=150" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10"
    ];
  };

  fileSystems."/mnt/nas/docker" = {
    device = "NAS_IP:/mnt/storage/docker/dev-vm";
    fsType = "nfs";
    options = [
      "soft" "timeo=150" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10"
    ];
  };

  # ── Firewall ──────────────────────────────────────────
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22   # SSH
      2222 # Forgejo SSH (git push/pull)
      # Web services (3000, 8080, 9000, 8081) only reachable via Caddy on NAS
    ];
  };

  # ── Garbage Collection ───────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "24.11";
}
