{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}: let
  serviceUser = "lexis-inference";
  serviceGroup = serviceUser;
  stateDirectory = "/var/lib/lexis-inference";
  virtualEnvironment = "${stateDirectory}/venv";
  modelRevision = "audio-cpp-mf-q8_0-sha256-062c5e040e0ec9a2d31dc1209d70233ed2bb132e9ead5cea84af420644079053";
  modelId = "dots-studio/dots.tts-mf";
  audioCppModelId = "dots-tts-mf";
  audioCppModelPath = "${stateDirectory}/models/dots-tts-mf-q8_0.gguf";
  audioCppModelUrl = "https://huggingface.co/audio-cpp/audio.cpp-gguf/resolve/4d501e4c45a311bb84b82389dc6e61f559e23570/DotTTS-MF-GGUF/dots-tts-mf-q8_0.gguf?download=true";
  audioCppModelSha256 = "062c5e040e0ec9a2d31dc1209d70233ed2bb132e9ead5cea84af420644079053";
  audioCpp =
    (flake-inputs.audio-cpp.packages.${pkgs.system}.cuda.override {
      models = ["dots_tts"];
    }).overrideAttrs (old: {
      cmakeFlags = old.cmakeFlags ++ ["-DCMAKE_CUDA_ARCHITECTURES=75-real"];
    });

  # Keep the gateway source in Lexis, but make the complete runtime project
  # (including this repository's lockfile) a single immutable Nix input.  The
  # setup unit installs that project into the mutable state directory; model
  # weights and the uv cache never enter /nix/store.
  runtimeProject = pkgs.runCommand "lexis-rig-inference-project" {} ''
    mkdir -p "$out/lexis-inference"
    cp -R ${flake-inputs.lexis}/inference/. "$out/lexis-inference/"
    if [ ! -f "$out/lexis-inference/src/lexis_inference/audio_cpp_backend.py" ]; then
      echo "The pinned Lexis input does not contain the Audio.cpp backend" >&2
      echo "Update the flake.lock Lexis revision before activating Rig" >&2
      exit 1
    fi
    cp ${./lexis-inference/pyproject.toml} "$out/pyproject.toml"
    cp ${./lexis-inference/uv.lock} "$out/uv.lock"
    cp ${./lexis-inference/benchmark_dots.py} "$out/benchmark_dots.py"
  '';

  installScript = pkgs.writeShellScript "lexis-inference-install" ''
    set -euo pipefail

    state=${lib.escapeShellArg stateDirectory}
    venv=${lib.escapeShellArg virtualEnvironment}
    export HOME="$state"
    export XDG_CACHE_HOME="$state/xdg-cache"
    export UV_CACHE_DIR="$state/uv-cache"
    export UV_PROJECT_ENVIRONMENT="$venv"

    install -d -m 0750 -o ${serviceUser} -g ${serviceGroup} "$state"
    install -d -m 0750 -o ${serviceUser} -g ${serviceGroup} "$state/models"

    model=${lib.escapeShellArg audioCppModelPath}
    model_url=${lib.escapeShellArg audioCppModelUrl}
    model_sha256=${lib.escapeShellArg audioCppModelSha256}
    if [ -f "$model" ] && ! printf '%s  %s\n' "$model_sha256" "$model" | ${pkgs.coreutils}/bin/sha256sum --check --status -; then
      echo "Removing a corrupt Audio.cpp model at $model" >&2
      rm -f "$model"
    fi
    if [ ! -f "$model" ]; then
      partial="$model.partial"
      rm -f "$partial"
      trap 'rm -f "$partial"' EXIT
      ${pkgs.curl}/bin/curl --fail --location --retry 5 --retry-all-errors \
        --output "$partial" "$model_url"
      printf '%s  %s\n' "$model_sha256" "$partial" | ${pkgs.coreutils}/bin/sha256sum --check --status -
      mv "$partial" "$model"
      chmod 0640 "$model"
      trap - EXIT
    fi
    if [ ! -x "$venv/bin/python" ]; then
      ${pkgs.uv}/bin/uv venv --python ${pkgs.python312}/bin/python3.12 "$venv"
    fi

    # --locked makes a changed dependency graph fail loudly instead of
    # silently solving a new gateway environment during service startup.
    ${pkgs.uv}/bin/uv sync \
      --project ${runtimeProject} \
      --locked \
      --no-dev \
      --link-mode copy \
      --python "$venv/bin/python"
  '';

  benchmarkScript = pkgs.writeShellScriptBin "lexis-inference-benchmark" ''
    exec ${virtualEnvironment}/bin/python ${runtimeProject}/benchmark_dots.py "$@"
  '';

  runtimePreflight = pkgs.writeShellScript "lexis-inference-runtime-preflight" ''
        set -euo pipefail
        exec ${virtualEnvironment}/bin/python -c '
    import sys
    print(f"python={sys.executable}", flush=True)
    import lexis_inference.audio_cpp_backend
    print("audio_cpp_backend=ok", flush=True)
    '
  '';

  audioCppPreflight = pkgs.writeShellScript "lexis-audio-cpp-preflight" ''
    set -euo pipefail
    exec ${audioCpp}/bin/audiocpp_server --list-devices
  '';

  commonEnvironment = {
    HOME = stateDirectory;
    PYTHONUNBUFFERED = "1";
    PYTHONHASHSEED = "0";
    TOKENIZERS_PARALLELISM = "false";
    HF_HOME = "${stateDirectory}/models";
    HF_HUB_CACHE = "${stateDirectory}/models/hub";
    HF_HUB_DISABLE_TELEMETRY = "1";
    # PyPI's CUDA wheels expect both the host NVIDIA driver and the C++ runtime
    # to be discoverable by the dynamic loader. NixOS exposes these through
    # generated paths rather than a global /usr/lib/ldconfig entry.
    LD_LIBRARY_PATH =
      (lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.zlib])
      + ":/run/opengl-driver/lib";
    LEXIS_INFERENCE_HOST = "0.0.0.0";
    LEXIS_INFERENCE_PORT = "8765";
    LEXIS_INFERENCE_MODEL = modelId;
    LEXIS_INFERENCE_MODEL_REVISION = modelRevision;
    LEXIS_INFERENCE_REFERENCE_DIR = "${stateDirectory}/references";
    LEXIS_INFERENCE_WORKER_FACTORY = "lexis_inference.audio_cpp_backend:factory";
    LEXIS_INFERENCE_WORKER_TIMEOUT_SECONDS = "180";
    LEXIS_INFERENCE_WORKER_STARTUP_TIMEOUT_SECONDS = "900";
    LEXIS_INFERENCE_MAX_REFERENCE_BYTES = "16777216";
    LEXIS_INFERENCE_MAX_AUDIO_BYTES = "16777216";
    LEXIS_AUDIO_CPP_URL = "http://127.0.0.1:18080";
    LEXIS_AUDIO_CPP_MODEL_ID = audioCppModelId;
    LEXIS_AUDIO_CPP_MODEL_PATH = audioCppModelPath;
    LEXIS_AUDIO_CPP_BINARY = "${audioCpp}/bin/audiocpp_server";
    LEXIS_AUDIO_CPP_HOST = "127.0.0.1";
    LEXIS_AUDIO_CPP_PORT = "18080";
    LEXIS_AUDIO_CPP_DEVICE = "0";
    LEXIS_AUDIO_CPP_THREADS = "1";
    LEXIS_AUDIO_CPP_SPAWN_SERVER = "true";
    LEXIS_AUDIO_CPP_REFERENCE_DURATION_SECONDS = "5";
    LEXIS_AUDIO_CPP_MAX_TOKENS = "500";
    LEXIS_AUDIO_CPP_FFMPEG = "${pkgs.ffmpeg}/bin/ffmpeg";
    LEXIS_AUDIO_CPP_OPUS_BITRATE = "64k";
  };
in {
  users.groups.${serviceGroup} = {};
  users.users.${serviceUser} = {
    isSystemUser = true;
    group = serviceGroup;
    home = stateDirectory;
    createHome = true;
  };

  environment.systemPackages = [
    benchmarkScript
    audioCpp
    pkgs.ffmpeg
    pkgs.curl
    pkgs.uv
  ];

  networking.firewall.allowedTCPPorts = lib.mkAfter [8765];

  systemd.tmpfiles.rules = [
    "d ${stateDirectory} 0750 ${serviceUser} ${serviceGroup} -"
    "d ${stateDirectory}/models 0750 ${serviceUser} ${serviceGroup} -"
    "d ${stateDirectory}/references 0750 ${serviceUser} ${serviceGroup} -"
    "d ${stateDirectory}/uv-cache 0750 ${serviceUser} ${serviceGroup} -"
    "d ${stateDirectory}/xdg-cache 0750 ${serviceUser} ${serviceGroup} -"
  ];

  systemd.services.lexis-inference-install = {
    description = "Install the locked Lexis Rig inference environment";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = serviceUser;
      Group = serviceGroup;
      ExecStart = installScript;
      WorkingDirectory = stateDirectory;
      ReadWritePaths = [stateDirectory];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      TimeoutStartSec = "30min";
    };
  };

  systemd.services.lexis-inference = {
    description = "Lexis Dots MF CUDA inference gateway";
    wantedBy = ["multi-user.target"];
    requires = ["lexis-inference-install.service"];
    after = ["lexis-inference-install.service" "network-online.target"];
    wants = ["network-online.target"];
    environment = commonEnvironment;
    serviceConfig = {
      Type = "simple";
      User = serviceUser;
      Group = serviceGroup;
      ExecStart = "${virtualEnvironment}/bin/lexis-inference";
      ExecStartPre = [runtimePreflight audioCppPreflight];
      WorkingDirectory = stateDirectory;
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = "20min";
      TimeoutStopSec = 30;
      KillMode = "control-group";
      LimitNOFILE = 65536;
      UMask = "0077";
      ReadWritePaths = [stateDirectory];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
    };
    unitConfig = {
      StartLimitIntervalSec = "300s";
      StartLimitBurst = 3;
    };
  };
}
