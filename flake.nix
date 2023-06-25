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
  };

  outputs = inputs@{ self, darwin, nixpkgs, home-manager, nix-doom-emacs, ... }:
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#studio
    darwinConfigurations."Studio" = darwin.lib.darwinSystem {
      modules = [ 
        ./configuration.nix
        ./hosts/studio/default.nix
        home-manager.darwinModules.home-manager
	  {
	    home-manager.useGlobalPkgs = true;
	    home-manager.useUserPackages = true;
	    home-manager.users.yanda = import ./home.nix;
	    # Inspired by 
            # https://discourse.nixos.org/t/adding-doom-emacs-using-home-manager/27742/2
	    home-manager.extraSpecialArgs.flake-inputs = inputs;
	  }
      ];
      system = "aarch64-darwin";
      specialArgs.flake-inputs = inputs;
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Studio".pkgs;
  };
}
