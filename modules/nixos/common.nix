{ config, pkgs, ... }:

{
  # ── System ────────────────────────────────────────────
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
  };

  # ── Nix ───────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ── User ──────────────────────────────────────────────
  users.users.root.initialPassword = "root";

  users.users.antonio = {
    isNormalUser = true;
    description = "Antonio";
    initialPassword = "";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # SSH Public Key
      # "ssh-ed25519 AAAA..."
    ];
  };

  # ── Basis-Pakete ──────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    htop
    btop
    fastfetch
    ripgrep
    fd
    unzip
    neovim
    tmux
  ];

  # ── Shell ─────────────────────────────────────────────
  programs.zsh.enable = true;
  users.users.antonio.shell = pkgs.zsh;

  # ── SSH ───────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.AcceptEnv = [ "TERM" ];
  };

  # ── Firewall ──────────────────────────────────────────
  networking.firewall.enable = true;
}
