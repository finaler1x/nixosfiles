{ config, pkgs, ... }:

{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud29;
    hostName = "nextcloud.homelab.ts.net";

    config = {
      adminpassFile = "/run/secrets/nextcloud-admin-pass";
      dbtype = "pgsql";
    };

    database.createLocally = true;

    # Performance
    configureRedis = true;
    caching.redis = true;

    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      default_phone_region = "DE";
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
  };
}
