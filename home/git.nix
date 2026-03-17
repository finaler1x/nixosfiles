{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Antonio";
    userEmail = "deine@email.com";
  };
}
