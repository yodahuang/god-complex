# figkit: nested-layout SVG diagrams for paper notes (used by the
# make-paper-notes skill). Ships a `figkit` command that is a Python with
# fonttools and figkit importable, plus rsvg-convert for previews:
#   figkit gen.py      # gen.py does `from figkit import *`
{
  python3,
  librsvg,
  runCommand,
  writeShellApplication,
}: let
  python = python3.withPackages (ps: [ps.fonttools]);
  lib-dir = runCommand "figkit-lib" {} ''
    mkdir -p $out
    cp ${./figkit.py} $out/figkit.py
  '';
in
  writeShellApplication {
    name = "figkit";
    runtimeInputs = [librsvg];
    text = ''
      export PYTHONPATH="${lib-dir}''${PYTHONPATH:+:$PYTHONPATH}"
      exec ${python}/bin/python "$@"
    '';
  }
