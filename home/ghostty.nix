{ config, pkgs, ... }:

{
  # Falls programs.ghostty nicht verfügbar ist,
  # ersetze diesen Block mit:
  # home.packages = with pkgs; [ ghostty ];

  programs.ghostty = {
    enable = true;
    settings = {
      font-size = 12;
      background-opacity = 0.95;
      confirm-close-surface = false;
    };
  };
}
