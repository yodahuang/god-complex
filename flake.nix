{
  description = "Yanda's one for all";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
    nur.url = "github:nix-community/NUR";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    darwin,
    nixpkgs,
    home-manager,
    nix-doom-emacs,
    nur,
    nixos-hardware,
    nix-vscode-extensions,
    agenix,
    ...
  }: let
    # A helper function to build the home-manager configuration.
    make_home_manager_config = {
      with_display,
      usually_headless,
      ...
    }: {
      nixpkgs.overlays = [nur.overlays.default];
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.yanda = import ./home.nix;
      # Inspired by
      # https://discourse.nixos.org/t/adding-doom-emacs-using-home-manager/27742/2
      home-manager.extraSpecialArgs = {
        flake-inputs = inputs;
        inherit with_display usually_headless;
      };
    };
  in {
    darwinConfigurations."Studio" = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./hosts/studio/default.nix
        ./common.nix
        home-manager.darwinModules.home-manager
        (make_home_manager_config {
          with_display = true;
          usually_headless = false;
        })
      ];
      specialArgs.flake-inputs = inputs;
    };

    darwinConfigurations."Geisha" = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./hosts/geisha/default.nix
        ./common.nix
        home-manager.darwinModules.home-manager
        (make_home_manager_config {
          with_display = true;
          usually_headless = false;
        })
      ];
      specialArgs.flake-inputs = inputs;
    };

    nixosConfigurations."Rig" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/rig/default.nix
        ./common.nix
        ./nixos/default.nix
        ./nixos/nvidia.nix
        home-manager.nixosModules.home-manager
        (make_home_manager_config {
          with_display = true;
          usually_headless = false;
        })
      ];
    };

    nixosConfigurations."EarlGrey" = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        {
          nixpkgs.overlays = [
            (self: super: {homer = super.callPackage ./pkgs/homer.nix {};})
          ];
        }
        ./hosts/earl_grey/default.nix
        ./common.nix
        home-manager.nixosModules.home-manager
        (make_home_manager_config {
          with_display = false;
          usually_headless = true;
        })
        agenix.nixosModules.default
      ];
    };

    nixosConfigurations."Surface" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/surface/default.nix
        ./common.nix
        ./nixos/default.nix
        nixos-hardware.nixosModules.microsoft-surface-common
        home-manager.nixosModules.home-manager
        (make_home_manager_config {
          with_display = true;
          usually_headless = false;
        })
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Studio".pkgs;
  };
}
