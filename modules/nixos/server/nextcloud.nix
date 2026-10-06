{ pkgs, ... }:

{
  services.nextcloud = {
    enable = true;
    # Explicit major: never change system.stateVersion to select Nextcloud.
    package = pkgs.nextcloud33;
    hostName = "cloud.homelab";
    home = "/storage/apps/nextcloud";
    https = true;
    database.createLocally = true;
    configureRedis = true;
    config = {
      dbtype = "pgsql";
      # Supported from Nextcloud 32: install without a default credential.
      # Bootstrap interactively with nextcloud-occ after successful setup.
      adminuser = null;
      adminpassFile = null;
    };
    extraApps = {
      inherit (pkgs.nextcloud33Packages.apps) groupfolders;
    };
    appstoreEnable = false;
    autoUpdateApps.enable = false;
    settings = {
      overwriteprotocol = "https";
      "overwrite.cli.url" = "https://cloud.homelab";
      default_phone_region = "DE";
      # nginx already restores REMOTE_ADDR from the private UNIX socket.
      trusted_proxies = [ ];
    };
    poolSettings = {
      "pm" = "dynamic";
      "pm.max_children" = "8";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
      "pm.max_requests" = "500";
    };
  };
}
