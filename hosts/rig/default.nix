# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  flake-inputs,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (flake-inputs.rig-control-plane + "/deploy/nix/rigplane.nix")
    ./rigplane.nix
  ];

  networking.hostName = "Rig"; # Define your hostname.

  # Enable the Budgie Desktop environment.
  services.xserver.displayManager.lightdm.enable = true;
  services.desktopManager.budgie.enable = true;

  # Add myself to it as this is the build machine.
  nix.settings.trusted-users = ["root" "yanda"];

  # deploy-rs only needs root for its immutable system activation and its
  # temporary rollback canary cleanup. Keep passwordless sudo limited to those
  # two commands instead of disabling the password for every wheel command.
  security.sudo.extraRules = [
    {
      users = ["yanda"];
      runAs = "root";
      commands = [
        {
          command = "/nix/store/*-activatable-nixos-system-*/activate-rs";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/rm /tmp/deploy-rs-canary-*";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.systemPackages = with pkgs; [protontricks];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [fcitx5-rime fcitx5-gtk];
  };
}
