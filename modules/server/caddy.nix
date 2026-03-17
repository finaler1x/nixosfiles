{ config, pkgs, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts."nextcloud.homelab.ts.net" = {
      extraConfig = ''
        reverse_proxy localhost:8080
      '';
    };

    virtualHosts."photos.homelab.ts.net" = {
      extraConfig = ''
        reverse_proxy localhost:2283
      '';
    };

    virtualHosts."adguard.homelab.ts.net" = {
      extraConfig = ''
        reverse_proxy localhost:3000
      '';
    };

    virtualHosts."vault.homelab.ts.net" = {
      extraConfig = ''
        reverse_proxy localhost:8222
      '';
    };

    virtualHosts."status.homelab.ts.net" = {
      extraConfig = ''
        reverse_proxy localhost:3001
      '';
    };
  };
}
