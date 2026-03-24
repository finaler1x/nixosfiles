{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
      inherit pkgs;
      # Generate noctalia.json first (on the running VM):
      #   nix run nixpkgs#noctalia-shell ipc call state all > ./modules/features/noctalia.json
      settings = (builtins.fromJSON (builtins.readFile ./noctalia.json)).settings;
    };
  };

  flake.nixosModules.noctalia = { pkgs, ... }: {
    environment.systemPackages = [
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myNoctalia
    ];
  };
}
