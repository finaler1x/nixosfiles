{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./zsh.nix
    ./neovim.nix
    ./tmux.nix
    ./ghostty.nix
  ];

  home.username = "antonio";
  home.homeDirectory = "/home/antonio";

  home.packages = with pkgs; [
    ripgrep
    fd
    btop
    unzip
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.stateVersion = "24.11";
}
