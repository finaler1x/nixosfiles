{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = {
        spawn-at-startup = [{ command = [ "noctalia" ]; }];
        binds."Mod+Return".spawn = [ (pkgs.lib.getExe pkgs.kitty) ];
      };
    };
  };

  flake.nixosModules.niri = { pkgs, ... }: {
    programs.niri = {
      enable = true;
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };
    environment.systemPackages = [ pkgs.kitty ];
  };
}
