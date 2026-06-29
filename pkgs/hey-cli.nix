# HEY CLI — https://github.com/basecamp/hey-cli
# Upstream ships no Nix package, so we build the Go binary ourselves.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "hey-cli";
  # No upstream tags yet; pin to a commit and use a date-based version.
  version = "0-unstable-2026-06-24";
  rev = "a3cf885fc80b906e887af3eb753b13f8ffcdae24";

  src = fetchFromGitHub {
    owner = "basecamp";
    repo = "hey-cli";
    inherit rev;
    hash = "sha256-cK0nZSXzeAS/INeXh4dUUmb9TBsSln6zBemsRcUPjVw=";
  };

  vendorHash = "sha256-6D2ETVXeVI0ad+g8x9qVTBEwEwXFbw7pTszje0p+qWw=";

  subPackages = ["cmd/hey"];

  # Mirror the Makefile's ldflags so `hey --version` reports something useful.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/basecamp/hey-cli/internal/version.Version=${version}"
    "-X github.com/basecamp/hey-cli/internal/version.Commit=${builtins.substring 0 7 rev}"
  ];

  meta = with lib; {
    description = "HEY email from the command line";
    homepage = "https://github.com/basecamp/hey-cli";
    license = licenses.mit;
    mainProgram = "hey";
    platforms = platforms.unix;
  };
}
