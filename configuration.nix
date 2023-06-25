{ pkgs, lib, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs;
        [
          vim
          cachix
        ];

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # services.emacs.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      programs.fish.enable = true;
      environment.shells = with pkgs; [
      	bashInteractive
        zsh
        fish
      ];

      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
             "obsidian"
           ];

      users.users.yanda = {
        name = "yanda";
        home = "/Users/yanda";
        shell = pkgs.fish;
      };


      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 4;
    }
