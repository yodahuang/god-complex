{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}: let
  rigplaneSource = flake-inputs.rig-control-plane;
  rigplanePackage = pkgs.callPackage (rigplaneSource + "/deploy/nix/rigplane-package.nix") {};
  llamaCpp = pkgs.llama-cpp.override {cudaSupport = true;};
  audioCpp =
    (flake-inputs.audio-cpp.packages.${pkgs.system}.cuda.override {
      models = ["dots_tts"];
    }).overrideAttrs (old: {
      cmakeFlags = old.cmakeFlags ++ ["-DCMAKE_CUDA_ARCHITECTURES=75-real"];
    });

  stateDirectory = "/var/lib/rigplane";
  configDirectory = "/etc/rigplane";

  # PaddleOCR-VL 1.6 for crop OCR on vLLM, fetched by digest from Hugging
  # Face. The file list and digests are the same checkpoint the Studio serves.
  paddleOcrRevision = "c5630abae1d940eafe0697512a0325494b02ab42";
  paddleOcrFiles = (lib.importJSON ../../rigplane/studio-model-digests.json)."paddleocr-vl-1.6".files;
  paddleOcrModel = pkgs.linkFarm "paddleocr-vl-1.6" (map (file: {
      name = file.path;
      path = pkgs.fetchurl {
        url = "https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6/resolve/${paddleOcrRevision}/${file.path}";
        sha256 = lib.removePrefix "sha256:" file.digest;
      };
    })
    paddleOcrFiles);
  ocrModelDirectory = "${stateDirectory}/models/ocr/paddleocr-vl-1.6";

  # vLLM is not packaged with CUDA in nixpkgs, so its Python environment is a
  # locked uv project synced into the state directory (rigplane-vllm-env). The
  # wrapper supplies what its manylinux wheels and Triton JIT need on NixOS.
  vllmProject = ./vllm;
  vllmState = "${stateDirectory}/vllm";
  vllmPython = pkgs.python312;
  vllmWrapper = pkgs.writeShellScript "rigplane-vllm" ''
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.zlib]}:/run/opengl-driver/lib
    export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
    export TRITON_PTXAS_PATH=${pkgs.cudaPackages.cuda_nvcc}/bin/ptxas
    export CC=${pkgs.gcc}/bin/gcc
    export PATH=${lib.makeBinPath [pkgs.gcc pkgs.coreutils]}:''${PATH:-}
    export HOME=${vllmState}/home
    export XDG_CACHE_HOME=${vllmState}/cache
    export VLLM_CACHE_ROOT=${vllmState}/cache/vllm
    export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
    export VLLM_NO_USAGE_STATS=1 DO_NOT_TRACK=1
    exec ${vllmState}/venv/bin/vllm "$@"
  '';
  vllmEnvScript = pkgs.writeShellScript "rigplane-vllm-env" ''
    set -euo pipefail
    export UV_PROJECT_ENVIRONMENT=${vllmState}/venv
    export UV_CACHE_DIR=${vllmState}/uv-cache
    export UV_PYTHON=${vllmPython}/bin/python3.12
    export UV_PYTHON_DOWNLOADS=never
    export UV_NO_CONFIG=1
    export HOME=${vllmState}/home
    ${pkgs.coreutils}/bin/mkdir -p ${vllmState}/home ${vllmState}/cache
    exec ${pkgs.uv}/bin/uv sync --frozen --no-install-project --project ${vllmProject}
  '';
  configFile = "${configDirectory}/config.toml";
  importDirectory = "${stateDirectory}/model-import";
  textSource = "${importDirectory}/text/Hy-MT2-7B-Q4_K_M.gguf";
  audioSource = "${importDirectory}/audio/dots-tts-mf-q8_0.gguf";
  textModel = "${stateDirectory}/models/text/Hy-MT2-7B-Q4_K_M.gguf";
  audioModel = "${stateDirectory}/models/audio/dots-tts-mf-q8_0.gguf";
  template = rigplaneSource + "/deploy/rigplane/config.toml.example";
  agentTokenPath = config.age.secrets."rigplane-agent-token".path;
  clientTokenPath = config.age.secrets."rigplane-client-token".path;
  audioLdLibraryPath = "${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.zlib]}:/run/opengl-driver/lib";
  legacyUnits = [
    "pixiv-translate-text.service"
    "pixiv-translate-text-install.service"
    "rig-inference-manager.service"
    "lexis-inference.service"
    "lexis-inference-install.service"
  ];

  configureScript = pkgs.writeShellScript "rigplane-configure" ''
    set -euo pipefail

    coreutils=${lib.escapeShellArg "${pkgs.coreutils}/bin"}
    sed=${lib.escapeShellArg "${pkgs.gnused}/bin/sed"}
    awk=${lib.escapeShellArg "${pkgs.gawk}/bin/awk"}
    df=${lib.escapeShellArg "${pkgs.coreutils}/bin/df"}
    nvidia_smi=/run/current-system/sw/bin/nvidia-smi
    config_dir=${lib.escapeShellArg configDirectory}
    config_file=${lib.escapeShellArg configFile}
    state=${lib.escapeShellArg stateDirectory}
    template=${lib.escapeShellArg (toString template)}
    text_source=${lib.escapeShellArg textSource}
    audio_source=${lib.escapeShellArg audioSource}
    text_model=${lib.escapeShellArg textModel}
    audio_model=${lib.escapeShellArg audioModel}
    agent_token_path=${lib.escapeShellArg agentTokenPath}
    client_token_path=${lib.escapeShellArg clientTokenPath}
    llama_binary=${lib.escapeShellArg "${llamaCpp}/bin/llama-server"}
    audio_bridge=${lib.escapeShellArg "${rigplanePackage}/bin/rigplane-audio-worker"}
    audio_binary=${lib.escapeShellArg "${audioCpp}/bin/audiocpp_server"}
    ffmpeg_binary=${lib.escapeShellArg "${pkgs.ffmpeg}/bin/ffmpeg"}
    audio_ld_library_path=${lib.escapeShellArg audioLdLibraryPath}
    vllm_wrapper=${lib.escapeShellArg "${vllmWrapper}"}
    ocr_source=${lib.escapeShellArg "${paddleOcrModel}"}
    ocr_model=${lib.escapeShellArg ocrModelDirectory}

    sha256_file() {
      "$coreutils/sha256sum" "$1" | "$coreutils/cut" -d' ' -f1
    }

    token_digest() {
      token=$("$coreutils/cat" "$1")
      if [ -z "$token" ] || [ "$(printf '%s' "$token" | "$coreutils/wc" -l)" -ne 0 ]; then
        echo "token must contain one non-empty line: $1" >&2
        exit 1
      fi
      printf '%s' "$token" | "$coreutils/sha256sum" | "$coreutils/cut" -d' ' -f1
    }

    link_or_copy_model() {
      source=$1
      target=$2
      if [ ! -f "$source" ]; then
        echo "model source is missing: $source" >&2
        exit 1
      fi
      if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$(sha256_file "$source")" != "$(sha256_file "$target")" ]; then
          echo "model target has a different digest: $target" >&2
          exit 1
        fi
        return
      fi
      if ! "$coreutils/ln" "$source" "$target" 2>/dev/null; then
        "$coreutils/cp" --reflink=auto --preserve=mode,timestamps "$source" "$target"
      fi
    }

    [ -x "$nvidia_smi" ] || {
      echo "nvidia-smi is unavailable: $nvidia_smi" >&2
      exit 1
    }
    [ -s "$agent_token_path" ] || {
      echo "agent secret is unavailable: $agent_token_path" >&2
      exit 1
    }
    [ -s "$client_token_path" ] || {
      echo "client secret is unavailable: $client_token_path" >&2
      exit 1
    }

    "$coreutils/install" -d -m 0750 -o rigplane -g rigplane \
      "$config_dir" "$state" "$state/models" "$state/models/text" "$state/models/audio" "$state/references"
    link_or_copy_model "$text_source" "$text_model"
    link_or_copy_model "$audio_source" "$audio_model"
    "$coreutils/chown" rigplane:rigplane "$text_model" "$audio_model"
    "$coreutils/chmod" 0640 "$text_model" "$audio_model"

    # Copy (never hard-link) the OCR checkpoint out of the store, so the
    # ownership change below cannot reach a store path.
    "$coreutils/install" -d -m 0750 -o rigplane -g rigplane "$state/models/ocr" "$ocr_model"
    for source in "$ocr_source"/*; do
      name=$("$coreutils/basename" "$source")
      target="$ocr_model/$name"
      if [ ! -f "$target" ] || [ "$(sha256_file "$source")" != "$(sha256_file "$target")" ]; then
        "$coreutils/cp" -L --reflink=auto "$source" "$target.tmp"
        "$coreutils/mv" -f "$target.tmp" "$target"
      fi
      "$coreutils/chown" rigplane:rigplane "$target"
      "$coreutils/chmod" 0640 "$target"
    done

    text_digest=$(sha256_file "$text_source")
    text_size=$("$coreutils/stat" -c '%s' "$text_source")
    audio_digest=$(sha256_file "$audio_source")
    audio_size=$("$coreutils/stat" -c '%s' "$audio_source")
    client_digest=$(token_digest "$client_token_path")
    agent_digest=$(token_digest "$agent_token_path")
    gpu_uuid=$($nvidia_smi --query-gpu=uuid --format=csv,noheader | "$sed" -n '1p' | "$coreutils/tr" -d '[:space:]')
    gpu_memory_mb=$($nvidia_smi --query-gpu=memory.total --format=csv,noheader,nounits | "$sed" -n '1p' | "$coreutils/tr" -d '[:space:]')
    [ "$gpu_uuid" != "" ] || { echo "NVIDIA GPU UUID is unavailable" >&2; exit 1; }
    case "x$gpu_memory_mb" in
      x|x*[!0-9]*) echo "NVIDIA GPU memory is invalid: $gpu_memory_mb" >&2; exit 1 ;;
    esac
    vram_bytes=$((gpu_memory_mb * 1024 * 1024))
    ram_bytes=$("$awk" '/^MemTotal:/ { print $2 * 1024; exit }' /proc/meminfo)
    disk_total_bytes=$("$df" -P -B1 "$state" | "$awk" 'NR == 2 { print $2; exit }')
    case "x$disk_total_bytes" in
      x|x*[!0-9]*) echo "cache filesystem size is invalid: $disk_total_bytes" >&2; exit 1 ;;
    esac
    cpu_millis=$(($(${pkgs.coreutils}/bin/nproc) * 1000))
    nixos_version=$(/run/current-system/sw/bin/nixos-version --raw)
    measured_at=$(/run/current-system/sw/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')
    # Hy's measured footprint with an 8192-token unified q8_0 KV cache and four
    # slots; the deployment's 5% margin is added on top by the estimator.
    text_peak_bytes=$((5248 * 1024 * 1024))
    audio_peak_bytes=$((vram_bytes / 2))
    text_revision="rig-text-$(printf '%s' "$text_digest" | "$coreutils/cut" -c1-16)"
    audio_revision="rig-audio-$(printf '%s' "$audio_digest" | "$coreutils/cut" -c1-16)"

    temporary_config=$("$coreutils/mktemp" "$config_dir/config.toml.XXXXXX")
    trap '"$coreutils/rm" -f "$temporary_config"' EXIT
    "$coreutils/cp" "$template" "$temporary_config"
    "$sed" -i \
      -e "s|/run/current-system/sw/bin/llama-server|$llama_binary|g" \
      -e "s|/run/current-system/sw/bin/rigplane-audio-worker|$audio_bridge|g" \
      -e "s|/run/current-system/sw/bin/rigplane-vllm|$vllm_wrapper|g" \
      -e "s|/run/current-system/sw/bin/audiocpp_server|$audio_binary|g" \
      -e "s|/run/current-system/sw/bin/ffmpeg|$ffmpeg_binary|g" \
      -e "s|/run/opengl-driver/lib|$audio_ld_library_path|g" \
      -e "s|/etc/rigplane/agent-token|$agent_token_path|g" \
      -e "s|sha256:d5296f001b037ed2b0e5e4c77dbdfbd6bcd309957100fbf6a7d2cf77daf832cd|sha256:$client_digest|" \
      -e "s|sha256:2a8b159ac3d0016a010795058f4e0febaeac99ee821d0a9182d696b377261cfd|sha256:$agent_digest|" \
      -e "s|revision = \"REPLACE\"|revision = \"$text_revision\"|" \
      -e "s|model_revision = \"REPLACE\"|model_revision = \"$text_revision\"|" \
      -e "s|revision = \"REPLACE_AUDIO\"|revision = \"$audio_revision\"|" \
      -e "s|model_revision = \"REPLACE_AUDIO\"|model_revision = \"$audio_revision\"|" \
      -e 's|source_license = "REPLACE"|source_license = "local"|g' \
      -e "s|os_version = \"REPLACE\"|os_version = \"$nixos_version\"|" \
      -e '0,/product = "REPLACE"/s//product = "NVIDIA CUDA GPU"/' \
      -e 's|vendor = "REPLACE"|vendor = "x86_64"|' \
      -e 's|product = "REPLACE"|product = "host-cpu"|' \
      -e "s|hardware_fingerprint = \"uuid:REPLACE\"|hardware_fingerprint = \"uuid:$gpu_uuid\"|" \
      -e "s|attributes = { uuid = \"REPLACE\" }|attributes = { uuid = \"$gpu_uuid\" }|" \
      -e 's|hardware_fingerprint = "cpu:REPLACE"|hardware_fingerprint = "cpu:x86_64"|' \
      -e 's|path = "REPLACE.gguf"|path = "text/Hy-MT2-7B-Q4_K_M.gguf"|' \
      -e "s|weights_bytes = 123456789|weights_bytes = $text_size|" \
      -e "s|size_bytes = 123456789|size_bytes = $text_size|" \
      -e "s|weights_bytes = 222222222|weights_bytes = $audio_size|" \
      -e "s|size_bytes = 222222222|size_bytes = $audio_size|" \
      -e "0,/manifest_digest = \"sha256:0000000000000000000000000000000000000000000000000000000000000000\"/s//manifest_digest = \"sha256:$text_digest\"/" \
      -e "s|sha256:1111111111111111111111111111111111111111111111111111111111111111|sha256:$text_digest|" \
      -e "s|sha256:2222222222222222222222222222222222222222222222222222222222222222|sha256:$audio_digest|" \
      -e "s|sha256:3333333333333333333333333333333333333333333333333333333333333333|sha256:$audio_digest|" \
      -e "s|measured_load_peak_bytes = 234567890|measured_load_peak_bytes = $text_peak_bytes|" \
      -e "s|base_accelerator_bytes = 123456789|base_accelerator_bytes = $text_peak_bytes|" \
      -e "s|measured_load_peak_bytes = 4294967296|measured_load_peak_bytes = $audio_peak_bytes|" \
      -e "s|base_accelerator_bytes = 4294967296|base_accelerator_bytes = $audio_peak_bytes|" \
      -e "s|8589934592|$vram_bytes|g" \
      -e "s|16681070592|$ram_bytes|g" \
      -e "s|1099511627776|$disk_total_bytes|g" \
      -e "s|16000|$cpu_millis|g" \
      -e "s|measured_at = 2026-09-19T00:00:00Z|measured_at = $measured_at|g" \
      "$temporary_config"
    "$coreutils/install" -o rigplane -g rigplane -m 0640 "$temporary_config" "$config_file"
    "$coreutils/install" -o rigplane -g rigplane -m 0400 \
      <(printf '%s\n' node_01a04987-5100-7001-8000-000000000001) \
      "$state/node-id"
  '';

  retireLegacyScript = pkgs.writeShellScript "rigplane-retire-legacy" ''
    set -u
    for unit in ${lib.concatStringsSep " " (map lib.escapeShellArg legacyUnits)}; do
      if ${pkgs.systemd}/bin/systemctl cat "$unit" >/dev/null 2>&1; then
        ${pkgs.systemd}/bin/systemctl disable --now "$unit" || true
        ${pkgs.systemd}/bin/systemctl mask "$unit" || true
      fi
    done
    ${pkgs.systemd}/bin/systemctl daemon-reload || true
  '';
in {
  # Rig only needs the RTX 2070 Super's SM75 code path. Keeping this host
  # capability-specific prevents llama.cpp from compiling every CUDA
  # architecture supported by the pinned toolkit.
  nixpkgs.config.cudaCapabilities = ["7.5"];

  age.secrets."rigplane-agent-token" = {
    file = ../../secrets/rigplane-agent-token.age;
    owner = "rigplane";
    group = "rigplane";
    mode = "0400";
  };
  age.secrets."rigplane-client-token" = {
    file = ../../secrets/rigplane-client-token.age;
    owner = "yanda";
    group = "users";
    mode = "0400";
  };

  # These paths must exist before systemd creates the hardened mount namespace
  # for the first-run configuration service.
  systemd.tmpfiles.rules = [
    "d ${configDirectory} 0750 rigplane rigplane -"
    "d ${stateDirectory} 0750 rigplane rigplane -"
    "d ${importDirectory} 0755 root root -"
    "d ${importDirectory}/text 0755 root root -"
    "d ${importDirectory}/audio 0755 root root -"
    "d ${stateDirectory}/models 0750 rigplane rigplane -"
    "d ${stateDirectory}/models/text 0750 rigplane rigplane -"
    "d ${stateDirectory}/models/audio 0750 rigplane rigplane -"
    "d ${stateDirectory}/references 0750 rigplane rigplane -"
    "d ${vllmState} 0750 rigplane rigplane -"
  ];

  # Sync the locked vLLM environment before the agent can start the OCR
  # worker. `uv sync --frozen` is a no-op when the venv already matches.
  systemd.services.rigplane-vllm-env = {
    description = "Sync the Rigplane vLLM Python environment";
    wantedBy = ["multi-user.target"];
    before = ["rigplane-agent.service"];
    wants = ["network-online.target"];
    after = ["network-online.target" "systemd-tmpfiles-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = vllmEnvScript;
      User = "rigplane";
      Group = "rigplane";
      RemainAfterExit = true;
      TimeoutStartSec = "30min";
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      ReadWritePaths = [vllmState];
    };
  };

  environment.systemPackages = [llamaCpp audioCpp pkgs.ffmpeg];

  systemd.services.rigplane-configure = {
    description = "Prepare Rigplane model cache and host configuration";
    wantedBy = ["multi-user.target"];
    before = ["rigplane-coordinator.service" "rigplane-agent.service"];
    after = ["agenix.service" "local-fs.target" "systemd-tmpfiles-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = configureScript;
      User = "root";
      Group = "root";
      RemainAfterExit = true;
      TimeoutStartSec = "15min";
      ProtectHome = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      PrivateDevices = false;
      ReadWritePaths = [configDirectory stateDirectory];
    };
  };

  systemd.services.rigplane-retire-legacy = {
    description = "Retire the legacy Rig inference services";
    wantedBy = ["multi-user.target"];
    before = legacyUnits ++ ["rigplane-configure.service"];
    unitConfig.Conflicts = legacyUnits;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = retireLegacyScript;
      RemainAfterExit = true;
    };
  };

  system.activationScripts.rigplaneRetireLegacy = lib.stringAfter ["users"] ''
    ${retireLegacyScript}
  '';

  # The coordinator is intentionally reachable only on Rig's private LAN
  # address. Backend worker ports remain loopback-only.
  networking.firewall.allowedTCPPorts = lib.mkAfter [7443];

  services.rigplane = {
    enable = true;
    package = rigplanePackage;
    configFile = configFile;
    # Studio (Mac) node: MLX-VLM OCR (PaddleOCR-VL) and Qwen-VL deployments,
    # its agent principal, and model manifests. Regenerate with
    # rigplane/gen_studio_config.py when the Mac's models change.
    configFragments = [../../rigplane/studio-coordinator-fragment.toml];
    coordinator.enable = true;
    agent.enable = true;
    extraGroups = ["video" "render"];
    stateDirectory = stateDirectory;
  };

  systemd.services.rigplane-coordinator.requires = ["rigplane-configure.service"];
  systemd.services.rigplane-coordinator.after = ["rigplane-configure.service"];
  systemd.services.rigplane-agent.requires = [
    "rigplane-configure.service"
    "rigplane-coordinator.service"
  ];
  systemd.services.rigplane-agent.after = [
    "rigplane-configure.service"
    "rigplane-coordinator.service"
    "rigplane-vllm-env.service"
  ];
  # Wanted, not required: without the vLLM environment only the OCR worker
  # fails to start; translation and speech keep working.
  systemd.services.rigplane-agent.wants = ["rigplane-vllm-env.service"];
}
