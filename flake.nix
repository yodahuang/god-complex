{
  description = "Yanda's one for all";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
    devenv.url = "github:cachix/devenv/latest";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
  };

  outputs =
    inputs@{ self, darwin, nixpkgs, home-manager, nix-doom-emacs, nur, ... }: {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#studio
      darwinConfigurations."Studio" = darwin.lib.darwinSystem {
        modules = [
          ./hosts/studio/default.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.overlays = [ nur.overlay ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.yanda = import ./home.nix;
            # Inspired by
            # https://discourse.nixos.org/t/adding-doom-emacs-using-home-manager/27742/2
            home-manager.extraSpecialArgs = {
              flake-inputs = inputs;
              # This is already in Darwin
              is_darwin = true;
              with_display = true;
            };
          }
        ];
        system = "aarch64-darwin";
        specialArgs.flake-inputs = inputs;
      };

      nixosConfigurations."Rig" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/rig/default.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ nur.overlay ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.yanda = import ./home.nix;
            home-manager.extraSpecialArgs = {
              flake-inputs = inputs;
              is_darwin = false;
              with_display = true;
            };
          }
        ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."Studio".pkgs;
    };
}
