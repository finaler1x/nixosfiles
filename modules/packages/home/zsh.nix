{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      export EDITOR="nvim"
    '';

    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)";
      ll = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      gs = "git status";
      gp = "git push";
      gc = "git commit";
      rebuild = "sudo nixos-rebuild switch --flake .#homelab";
    };
  };
}
