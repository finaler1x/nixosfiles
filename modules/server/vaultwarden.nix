{ config, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_PORT = 8222;
      ROCKET_ADDRESS = "127.0.0.1";
      DOMAIN = "https://vault.homelab.ts.net";

      # Nach erstem Account erstellen: Registrierung deaktivieren!
      # SIGNUPS_ALLOWED = false;
    };
  };
}
