# nixpkgs' jetbrains-mono builds the fonts from source via gftools/fontmake,
# which drags in a large from-scratch Python toolchain (afdko, fontmake,
# nanoemoji, ...) -- expensive, and made worse by the afdko doCheck override
# in flake.nix, which busts the binary cache for that whole chain. JetBrains
# publishes prebuilt fonts as a GitHub release asset, so just use those
# directly and skip the build entirely. No otf files are included in this
# release (only ttf/variable/webfonts), unlike nixpkgs' build.
{
  lib,
  fetchzip,
}:
fetchzip {
  pname = "jetbrains-mono";
  version = "2.304";
  url = "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip";
  hash = "sha256-44kfGgs1CqYUYVHRz3Ee62S/mL8Ahq2b3Ydtbf/1+Xg=";
  stripRoot = false;

  postFetch = ''
    mkdir -p $out/share/fonts
    mv $out/fonts/ttf $out/share/fonts/truetype
    mv $out/fonts/variable/*.ttf $out/share/fonts/truetype/
    mv $out/fonts/webfonts $out/share/fonts/WOFF2
    rm -rf $out/fonts
  '';

  meta = {
    description = "Typeface made for developers (prebuilt release, not built from source)";
    homepage = "https://jetbrains.com/mono/";
    changelog = "https://github.com/JetBrains/JetBrainsMono/blob/v2.304/Changelog.md";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
