{ config, pkgs, ... }:

{
  services.immich = {
    enable = true;
    port = 2283;
    machine-learning.enable = true;
    mediaLocation = "/mnt/data/immich";
  };
}
