{
  pkgs,
  lib,
  flake-inputs,
  ...
}: {
  imports = [../../darwin/core.nix];

  networking.hostName = "studio";

  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024;
          memorySize = 8 * 1024;
        };
        cores = 4;
        # QEMU 11.0's new SME2-over-HVF vCPU init asserts and aborts (SIGABRT
        # in hvf_arch_init_vcpu, HV_SYS_REG_SMCR_EL1 in sysreg.c.inc) on macOS
        # 26.5.x SME-capable Apple Silicon, so the builder VM never boots and
        # aarch64-linux builds fail with "Failed to find a machine for remote
        # build". It is unconditional (no -cpu flag avoids it; -cpu max,sme=off
        # is rejected under HVF as the property doesn't exist on the host CPU)
        # and there is no released QEMU fix. Pin the builder's QEMU to 25.11's
        # 10.1.5, which predates the SME2-HVF code, keeping HVF acceleration.
        # Verified to boot under HVF on macOS 26.5.1. Drop once nixpkgs' QEMU
        # ships a fix.
        qemu.package = flake-inputs.nixpkgs-qemu.legacyPackages.${pkgs.system}.qemu_kvm;
      };
    };
  };
}
