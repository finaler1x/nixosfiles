{ config, pkgs, ... }:

{
  imports = [
    ../../nixos/common.nix
    ../../nixos/tailscale.nix
  ];

  # ── WSL ───────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = "antonio";
    startMenuLaunchers = true;

    # Windows Laufwerke unter /mnt/c etc.
    wslConf.automount.root = "/mnt";

    # Interop: Windows Programme aus WSL starten
    interop.includePath = true;
  };

  # ── Netzwerk ──────────────────────────────────────────
  networking.hostName = "wsl";

  # ── Dev Pakete ────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    neovim
    vscode
    python3
    poetry
    go
    nodejs
    docker-compose
    lazygit
    jq
    yq
    httpie
    gh
  ];

  # ── Docker ────────────────────────────────────────────
  virtualisation.docker.enable = true;
  users.users.antonio.extraGroups = [ "docker" ];

  # ── Nix LD (für externe Binaries) ────────────────────
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}
