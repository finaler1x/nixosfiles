{ config, lib, pkgs, modulesPath, ... }:

{
  # ── PLACEHOLDER ───────────────────────────────────────
  # Replace this file with the output of:
  #   nixos-generate-config --show-hardware-config
  # Run that command on the actual VM after installing NixOS.

  imports = [
    (modulesPath + "/profiles/hyperv-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "hv_vmbus" "hv_storvsc" "hv_blkvsc" "hv_netvsc"
    "sd_mod" "sr_mod"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
