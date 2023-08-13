{ pkgs, lib, ... }: {

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [ git vim ];

  # Necessary for using flakes on this system.
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      substituters =
        [ "https://nix-community.cachix.org" "https://cache.nixos.org/" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  programs.fish.enable = true;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "obsidian"
      "1password-cli"
      "vscode"
      "vscode-extension-github-copilot"
    ];

  users.users.yanda = {
    # NixOS would add some more ones.
    name = "yanda";
    shell = pkgs.fish;
  };
  
  # For remote build.
  # Remember to copy the identify file there.
  programs.ssh.extraConfig = ''
    Host rig
      IdentityFile /root/.ssh/id_ed25519
      User yanda
      HostName 192.168.4.72
  '';

	nix.buildMachines = [ {
	 hostName = "rig";
	 system = "x86_64-linux";
   protocol = "ssh-ng";
	 # if the builder supports building for multiple architectures, 
	 # replace the previous line by, e.g.,
	 # systems = ["x86_64-linux" "aarch64-linux"];
	 maxJobs = 1;
	 speedFactor = 2;
	 supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ];
	 mandatoryFeatures = [ ];
	}] ;
	nix.distributedBuilds = true;
	# optional, useful when the builder has a faster internet connection than yours
	nix.extraOptions = ''
		builders-use-substitutes = true
	'';

}
