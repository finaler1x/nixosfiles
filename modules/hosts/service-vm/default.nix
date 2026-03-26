{ inputs, ... }:
{
  flake.nixosConfigurations.service-vm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.sops-nix.nixosModules.sops
      ../../hosts/service-vm/configuration.nix
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.antonio = import ../../packages/home;
      }
    ];
  };
}
