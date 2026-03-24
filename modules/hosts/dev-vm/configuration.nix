{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/common.nix
    ../../nixos/server/docker.nix
  ];

  # ── Boot ──────────────────────────────────────────────
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # ── Netzwerk ──────────────────────────────────────────
  networking.hostName = "dev-vm";
  networking.networkmanager.enable = true;


  # ── Dev Tools ─────────────────────────────────────────
  programs.git.enable = true;
  programs.direnv.enable = true;
  programs.nix-ld.enable = true;
  programs.vscode.enable = true;

  environment.systemPackages = with pkgs; [
    gh
    lazygit
    nixfmt-rfc-style
];

  # ── SSH ───────────────────────────────────────────────
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };

  # ── Docker ────────────────────────────────────────────
  virtualisation.docker.enable = true;
  users.users.antonio.extraGroups = [ "docker" ];

  # ── Firewall ──────────────────────────────────────────
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
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
