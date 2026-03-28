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
      ll = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      gs = "git status";
      gp = "git push";
      gc = "git commit";
      rebuild = "sudo nixos-rebuild switch --flake .#homelab";
      dchl = "docker compose -f ~/Projects/nixosfiles/modules/docker/homelab/docker-compose.yml";
    };
  };
}
