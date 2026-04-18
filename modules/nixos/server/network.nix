{ config, pkgs, ... }:

{
  # Switch away from NetworkManager to networkd + wpa_supplicant
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;

  # DHCP on any wireless interface (wlan0, wlp*, etc.)
  systemd.network = {
    enable = true;
    networks."10-wired" = {
      matchConfig.Type = "ether";
      networkConfig.DHCP = "yes";
      dhcpV4Config.RouteMetric = 100; # prefer wired
    };
    networks."20-wireless" = {
      matchConfig.Type = "wlan";
      networkConfig.DHCP = "yes";
      dhcpV4Config.RouteMetric = 600; # fallback
    };
  };

  # wpa_supplicant — networks configured imperatively via wpa_cli / wpa_passphrase
  networking.wireless = {
    enable = true;
    # Allow wpa_cli to be run as root for manual network management
    userControlled.enable = false;
  };

  environment.systemPackages = [ pkgs.wpa_supplicant ];
}
