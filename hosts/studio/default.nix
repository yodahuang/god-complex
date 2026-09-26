{...}: {
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
        # The QEMU 10.1.5 pin that worked around the SME2-over-HVF vCPU init
        # assert (HV_SYS_REG_SMCR_EL1, sysreg.c.inc) is gone: nixpkgs now
        # hardcodes `-machine virt-11.0` for the aarch64-darwin builder
        # (nixos/lib/qemu-common.nix), which 10.1.5 cannot accept, so the VM
        # failed to start (exit 1, crash loop, "Failed to find a machine for
        # remote build"). QEMU 11.1.1 (current unstable) boots under HVF on
        # macOS 26.5.x, so use the default package again.
      };
    };
  };
}
