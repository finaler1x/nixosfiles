{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Add antonio to the docker group
  users.users.antonio.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
