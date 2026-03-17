{ config, pkgs, ... }:

{
  services.adguardhome = {
    enable = true;
    settings = {
      http.address = "0.0.0.0:3000";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  # Nach Einrichtung: im Router den DNS auf die
  # Homelab-IP setzen → ganzes Netzwerk gefiltert
}
