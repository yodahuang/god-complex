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
    nix-doom-emacs.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    vscode-server.flake = false;
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.darwin.follows = "darwin";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    # chocolate-bar supports the ARM systems used here. Restrict bun2nix's
    # flake-parts system matrix so checks do not evaluate unsupported
    # x86_64-darwin outputs from nixpkgs 26.11.
    chocolate-bar-systems = {
      url = "path:./systems/chocolate-bar";
      flake = false;
    };
    chocolate-bar.url = "github:yodahuang/chocolate-bar";
    chocolate-bar.inputs.nixpkgs.follows = "nixpkgs";
    chocolate-bar.inputs.bun2nix.inputs.systems.follows = "chocolate-bar-systems";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    claude-code-nix.inputs.nixpkgs.follows = "nixpkgs";
    # The Rig service installs the gateway from this pinned source tree into
    # its locked uv environment. Keep this input non-flake so the inference
    # package is copied without evaluating Lexis' desktop/trainer outputs.
    lexis = {
      url = "github:yodahuang/Lexis";
      flake = false;
    };
    # The Pixiv semantic service and the Rig manager are developed together
    # while this deployment is being brought up. Keep the source as a non-flake
    # input so the NixOS module and Python manager are copied into the remote
    # build closure without adding another application flake.
    pixiv-viewer = {
      url = "path:/Users/yanda/Projects/pixiv-viewer";
      flake = false;
    };
    # The Rig operations UI is a standalone application with its own release
    # lifecycle. Keep it separate from the Pixiv reader source tree.
    rig-control-plane = {
      url = "path:/Users/yanda/Projects/rig-control-plane";
      flake = false;
    };
    # Local development input for the filesystem-backed static-sites service.
    # Replace this with the published repository URL before sharing the flake.
    static-sites = {
      url = "path:/Users/yanda/Documents/ChatGPT/static-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned native CUDA runtime used by the Rig's Dots MeanFlow worker. The
    # host module restricts the build to the dots_tts model and SM75 so the
    # resulting binary matches the RTX 2070 Super instead of shipping a full
    # framework build.
    audio-cpp = {
      url = "github:0xShug0/audio.cpp?rev=db21cbdd60f3d2ff62114bc863781ff8073ac39b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    deploy-rs,
    ...
  }: let
    homelabInventory = import ./homelab/inventory.nix;
    homelabLib = import ./homelab/lib.nix {lib = nixpkgs.lib;};
    homelabManifest = homelabLib.manifest (homelabLib.validate homelabInventory);
    homelabTests = import ./homelab/tests.nix {lib = nixpkgs.lib;};

    # A helper function to build the home-manager configuration.
    make_home_manager_config = {
      with_display,
      usually_headless,
      enable_hermes ? false,
      ...
    }: {
      nixpkgs.overlays = [
        nur.overlays.default
        inputs.claude-code-nix.overlays.default
      ];
      home-manager.backupFileExtension = "bak";
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.yanda = import ./home.nix;
      # Inspired by
      # https://discourse.nixos.org/t/adding-doom-emacs-using-home-manager/27742/2
      home-manager.extraSpecialArgs = {
        flake-inputs = inputs;
        inherit with_display usually_headless enable_hermes;
      };
    };
    studioDarwin = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./hosts/studio/default.nix
        ./common.nix
        home-manager.darwinModules.home-manager
        (make_home_manager_config {
          with_display = true;
          usually_headless = false;
          enable_hermes = true;
        })
      ];
      specialArgs.flake-inputs = inputs;
    };
    geishaDarwin = darwin.lib.darwinSystem {
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
  in {
    # Secret-free, normalized intent consumed by the OpenTofu plan. Observed
    # addresses are deliberately not part of this output.
    inherit homelabManifest;

    # Reusable Home Manager module for declarative macOS default-app
    # associations. Consume with:
    #   imports = [ inputs.<this>.homeManagerModules.default ];
    homeManagerModules = {
      macos-default-apps = import ./modules/macos-default-apps.nix;
      default = self.homeManagerModules.macos-default-apps;
    };

    darwinConfigurations = {
      studio = studioDarwin;
      Studio = studioDarwin;
      geisha = geishaDarwin;
      Geisha = geishaDarwin;
    };

    nixosConfigurations."Rig" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs.flake-inputs = inputs;
      modules = [
        ./hosts/rig/default.nix
        ./common.nix
        ./nixos/default.nix
        ./nixos/nvidia.nix
        ./nixos/tailscale.nix
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        (make_home_manager_config {
          with_display = true;
          usually_headless = false;
        })
      ];
    };

    nixosConfigurations."EarlGrey" = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs.flake-inputs = inputs;
      modules = [
        {
          nixpkgs.overlays = [
            (self: super: {homer = super.callPackage ./pkgs/homer.nix {};})
          ];
        }
        ./hosts/earl_grey/default.nix
        ./common.nix
        ./nixos/tailscale.nix
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

    deploy.nodes.EarlGrey = {
      hostname = "EarlGrey";
      sshUser = "yanda";
      user = "root";
      # SSH auth is key-based (1Password agent); yanda has passwordless sudo on
      # the Pi (security.sudo.wheelNeedsPassword = false in hosts/earl_grey),
      # so no interactive sudo password is needed.
      profiles.system.path =
        deploy-rs.lib.aarch64-linux.activate.nixos
        self.nixosConfigurations.EarlGrey;
    };

    deploy.nodes.Rig = {
      hostname = "rig";
      sshUser = "yanda";
      user = "root";
      # Build the x86_64-linux system on Rig instead of on the deployment host.
      remoteBuild = true;
      # Rig's sudo policy grants yanda a narrow NOPASSWD rule for activation.
      interactiveSudo = false;
      # Authentication is intentionally inherited from the user's OpenSSH
      # configuration and agent (including 1Password on the deployment host).
      profiles.system.path =
        deploy-rs.lib.x86_64-linux.activate.nixos
        self.nixosConfigurations.Rig;
    };

    checks.aarch64-linux =
      (deploy-rs.lib.aarch64-linux.deployChecks self.deploy)
      // {
        homelab-inventory = assert homelabTests.all;
          nixpkgs.legacyPackages.aarch64-linux.runCommand "homelab-inventory-check" {} ''
            touch $out
          '';
      };

    packages.aarch64-darwin.homelab-manifest =
      nixpkgs.legacyPackages.aarch64-darwin.writeText
      "homelab-inventory.json"
      (builtins.toJSON homelabManifest);

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.studio.pkgs;
  };
}
