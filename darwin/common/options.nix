{lib, ...}: {
  options.homebrewProfile = lib.mkOption {
    type = lib.types.str;
    default = "lite";
    description = "Which Homebrew profile to use (lite or full)";
  };
}
