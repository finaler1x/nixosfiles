{ ... }:

{
  services.paperless = {
    enable = true;
    dataDir = "/storage/apps/paperless";
    database.createLocally = true;
    address = "127.0.0.1";
    port = 28981;
    domain = "docs.homelab";
    configureNginx = false; # family-apps.nix supplies the private socket vhost
    consumptionDirIsPublic = false;
    passwordFile = null; # interactive paperless-manage createsuperuser
    settings = {
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_THREADS_PER_WORKER = 2;
      PAPERLESS_PROXY_SSL_HEADER = [ "HTTP_X_FORWARDED_PROTO" "https" ];
      PAPERLESS_TRUSTED_PROXIES = "127.0.0.1";
    };
    exporter = {
      enable = true;
      onCalendar = "*-*-* 02:30:00";
    };
  };

  # No shared scanner inbox before ownership workflows have been configured.
  # Authenticated uploads are the initial family intake path.
  systemd.tmpfiles.settings."10-paperless" = {
    "/storage/apps/paperless".d.mode = "0700";
    "/storage/apps/paperless/media".d.mode = "0700";
    "/storage/apps/paperless/consume".d.mode = "0700";
  };
}
