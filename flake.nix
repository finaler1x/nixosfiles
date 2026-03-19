{
  description = "NixOS Multi-Host Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, sops-nix, ... }: {

    # ── Homelab NAS (24/7) ───────────────────────────────
    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/homelab/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.antonio = import ./home;
        }
      ];
    };

    # ── Service VM (Immich, Paperless) ────────────────────
    # Deploy: nixos-rebuild switch --flake .#service-vm --target-host antonio@service-vm.home.local
    nixosConfigurations.service-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/service-vm/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.antonio = import ./home;
        }
      ];
    };

    # ── Dev VM (Forgejo, Code Server, Portainer, Dozzle) ──
    # Deploy: nixos-rebuild switch --flake .#dev-vm --target-host antonio@dev-vm.home.local
    nixosConfigurations.dev-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sops-nix.nixosModules.sops
        ./hosts/dev-vm/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.antonio = import ./home;
        }
      ];
    };

    # ── WSL (Dev Environment) ─────────────────────────
    nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-wsl.nixosModules.wsl
        ./hosts/wsl/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.antonio = import ./home;
        }
      ];
    };
  };
}
