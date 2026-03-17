{ config, pkgs, ... }:

{
  services.samba = {
    enable = true;
    settings = {
      global = {
        security = "user";
        "server string" = "homelab";
        "map to guest" = "Bad User";
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
        "use sendfile" = "yes";
      };
      data = {
        path = "/mnt/data";
        "read only" = "no";
        "valid users" = "antonio";
        "create mask" = "0644";
        "directory mask" = "0755";
        browseable = "yes";
      };
    };
  };

  # Samba-Passwort muss einmalig gesetzt werden:
  # sudo smbpasswd -a antonio

  # Samba Discovery im Netzwerk
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
