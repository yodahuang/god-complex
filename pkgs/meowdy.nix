{ fetchFromGitHub, buildGoModule, srcOnly, stdenv, pkgs, lib }:
let
  caddySrc = srcOnly (fetchFromGitHub {
    owner = "caddyserver";
    repo = "caddy";
    rev = "v2.7.4";
    hash = "sha256-oZSAY7vS8ersnj3vUtxj/qKlLvNvNL2RQHrNr4Cc60k=";
  });

  pluginSrc = srcOnly (fetchFromGitHub {
    owner = "caddy-dns";
    repo = "cloudflare";
    rev = "bfe272c8525b6dd8248fcdddb460fd6accfc4e84";
    hash = "sha256-s4BmQgAa1N4y6MZDZk5x63n3XdKdmzY8Qla1LCiwQ84=";
  });

  combinedSrc = stdenv.mkDerivation {
    name = "caddy-src";

    nativeBuildInputs = [ pkgs.go ];

    buildCommand = ''
      export GOCACHE="$TMPDIR/go-cache"
      export GOPATH="$TMPDIR/go"

      mkdir -p "$out/ourcaddy"

      cp -r ${caddySrc} "$out/caddy"
      cp -r ${pluginSrc} "$out/plugin"

      cd "$out/ourcaddy"

      go mod init caddy
      echo "package main" >> main.go
      echo 'import caddycmd "github.com/caddyserver/caddy/v2/cmd"' >> main.go
      echo 'import _ "github.com/porech/caddy-maxmind-geolocation"' >> main.go
      echo "func main(){ caddycmd.Main() }" >> main.go
      go mod edit -require=github.com/caddyserver/caddy/v2@v2.0.0
      go mod edit -replace github.com/caddyserver/caddy/v2=../caddy
      go mod edit -require=github.com/porech/caddy-maxmind-geolocation@v0.0.0
      go mod edit -replace github.com/porech/caddy-maxmind-geolocation=../plugin
    '';
  };
in buildGoModule {
  name = "meowdy";

  src = combinedSrc;

  vendorHash = "sha256-ekdvC+EJ5XMVps9XJJev1UWw5HfNc0OB8ZtNQ437Z+Y=";

  overrideModAttrs = _: {
    postPatch = "cd ourcaddy";

    postConfigure = ''
      go mod tidy
    '';

    postInstall = ''
      mkdir -p "$out/.magic"
      cp go.mod go.sum "$out/.magic"
    '';
  };

  postPatch = "cd ourcaddy";

  postConfigure = ''
    cp vendor/.magic/go.* .
  '';
}
