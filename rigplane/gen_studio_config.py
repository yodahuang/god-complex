"""Generate the Studio (Mac) rigplane agent config and coordinator fragment.

Inputs: model_digests.json (sha256 of every model file) and the agent token
digest. Outputs two TOML files. IDs are fixed so regeneration is stable.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

digests = json.loads(Path(sys.argv[1]).read_text())
out_dir = Path(sys.argv[2])
token_digest = sys.argv[3]
home = Path.home()
cache_dir = home / ".local/share/rigplane/models"
state_dir = home / ".local/state/rigplane"
repo = home / "Projects/rig-control-plane"
coordinator_url = sys.argv[4] if len(sys.argv) > 4 else "http://192.168.1.124:7443"

NODE = "node_01a04987-5100-7010-8000-000000000010"
AGENT = "agent_01a04987-5100-7010-8000-000000000010"
DEV_GPU = "device_01a04987-5100-7011-8000-000000000011"
DEV_CPU = "device_01a04987-5100-7012-8000-000000000012"
DEV_DISK = "device_01a04987-5100-7013-8000-000000000013"
POOL_MEM = "pool_01a04987-5100-701a-8000-00000000001a"
POOL_CPU = "pool_01a04987-5100-701b-8000-00000000001b"
POOL_DISK = "pool_01a04987-5100-701c-8000-00000000001c"
MLX_VLM_VERSION = "mlx-vlm-0.7.4"

memsize = int(subprocess.check_output(["/usr/sbin/sysctl", "-n", "hw.memsize"]).strip())
ncpu = int(subprocess.check_output(["/usr/sbin/sysctl", "-n", "hw.ncpu"]).strip())
import shutil
disk_total = shutil.disk_usage(str(Path.home())).total
chip = subprocess.check_output(["/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"]).decode().strip()

MODELS = {
    "paddleocr-vl-1.6": {
        "model_id": "model_01a04987-5100-7016-8000-000000000016",
        "deployment_id": "deploy_01a04987-5100-7017-8000-000000000017",
        "alias": "PaddleOCR-VL-1.6",
        "display_name": "PaddleOCR-VL 1.6 (0.9B) crop OCR",
        "license": "apache-2.0",
        "variant": "mlx-bf16",
        "quantization": "bf16",
        "base_bytes": 3 << 30,
        "parameters": {"maxOutputTokens": 512, "temperature": 0.0},
        "warm_policy": "keep_warm",
        "idle_unload_ms": 0,
        # Shares its alias with the Rig's vLLM copy; the coordinator compares
        # predicted finish times, starting from this per-crop guess.
        "expected_run_ms": 300,
    },
    "qwen3.6-35b-a3b-mlx-4bit": {
        "model_id": "model_01a04987-5100-7018-8000-000000000018",
        "deployment_id": "deploy_01a04987-5100-7019-8000-000000000019",
        "alias": "Qwen3.6-35B-A3B",
        "display_name": "Qwen3.6 35B-A3B VL (MLX 4-bit)",
        "license": "apache-2.0",
        "variant": "mlx-4bit",
        "quantization": "4bit",
        "base_bytes": 22 << 30,
        "parameters": {"maxOutputTokens": 1024, "temperature": 0.0},
        "warm_policy": "on_demand",
        "idle_unload_ms": 600000,
    },
}


def toml_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{json.dumps(k)} = {toml_value(v)}" for k, v in value.items()) + " }"
    raise TypeError(type(value))


def table(name, values, array=False):
    header = f"[[{name}]]" if array else f"[{name}]"
    return header + "\n" + "".join(f"{key} = {toml_value(value)}\n" for key, value in values.items()) + "\n"


def revision(files):
    return "studio-" + hashlib.sha256("".join(f["digest"] for f in files).encode()).hexdigest()[:16]


# ---------------------------------------------------------------- coordinator
fragment = ["# Studio (Mac) node: MLX-VLM OCR and Qwen-VL, served through Rigplane.\n\n"]
fragment.append(table("auth.principals", {
    "id": "agent-studio", "kind": "agent", "token_digest": token_digest,
    "scopes": ["agent"], "node_id": NODE,
}, array=True))
fragment.append(table("nodes", {
    "id": NODE, "alias": "Studio",
    "labels": {"site": "studio", "accelerator.family": "apple-silicon"},
    "agent_token_file": str(home / ".config/rigplane/agent-token"),
}, array=True))
for key, spec in MODELS.items():
    files = digests[key]["files"]
    rev = revision(files)
    weights = sum(f["size_bytes"] for f in files)
    manifest = "sha256:" + hashlib.sha256(json.dumps(
        [[f"{key}/{f['path']}", f["size_bytes"], f["digest"]] for f in files]).encode()).hexdigest()
    fragment.append(table("models", {
        "model_id": spec["model_id"], "revision": rev, "alias": spec["alias"],
        "display_name": spec["display_name"], "source_license": spec["license"],
        "operations": ["text.generate", "vision.generate"],
        "manifest_digest": manifest, "trust_remote_code": False,
    }, array=True))
    fragment.append(table("models.variants", {
        "variant": spec["variant"], "format": "mlx", "platforms": ["darwin-arm64"],
        "quantization": spec["quantization"], "weights_bytes": weights,
        "measured_load_peak_bytes": spec["base_bytes"], "metadata": {},
    }, array=True))
    for f in files:
        fragment.append(table("models.variants.files", {
            "path": f"{key}/{f['path']}", "size_bytes": f["size_bytes"], "digest": f["digest"],
        }, array=True))
    fragment.append(table("deployments", {
        "deployment_id": spec["deployment_id"], "generation": 1, "alias": spec["alias"],
        "operations": ["text.generate", "vision.generate"], "model_id": spec["model_id"],
        "model_revision": rev, "variant_preference": [spec["variant"]],
        "parameters": spec["parameters"], "placement_selector": {"site": "studio"},
        "warm_policy": spec["warm_policy"], "idle_unload_ms": spec["idle_unload_ms"],
        "queue_id": "queue_default", "enabled": True,
        **({"expected_run_ms": spec["expected_run_ms"]} if "expected_run_ms" in spec else {}),
    }, array=True))
    fragment.append(table("deployments.backend_constraints", {
        "adapter": "mlx-vlm", "version_spec": "*", "os": ["darwin"],
        "architectures": ["arm64"], "accelerator_apis": ["metal"],
    }, array=True))
    fragment.append(table("deployments.resource_policy", {
        "accelerator_required": True, "accelerator_apis": ["metal"], "min_cpu_millis": 1000,
        "min_ram_bytes": 0, "base_accelerator_bytes": spec["base_bytes"],
        "per_input_byte_multiplier": 0.0, "context_formula": "none",
        "safety_margin_bytes": 536870912, "exclusive_keys": [], "max_concurrency_per_worker": 1,
    }))

# ---------------------------------------------------------------- agent
agent = ["# Studio (Mac) Rigplane node agent. Generated; do not edit by hand.\n\n"]
agent.append(table("agent", {
    "node_id_file": str(state_dir / "node-id"),
    "coordinator_url": coordinator_url,
    "token_file": str(home / ".config/rigplane/agent-token"),
    "state_dir": str(state_dir / "agent"),
    "model_cache_dir": str(cache_dir),
    "link_local_model_files": True,
}))
agent.append(table("agent.registration", {
    "protocol_version": "1", "node_id": NODE, "agent_id": AGENT, "alias": "Studio",
    "agent_version": "rigplane-agent/0.1.0", "boot_id": "configured-at-start",
    "os": "darwin", "os_version": "configured-at-start", "architecture": "arm64",
    "labels": {"site": "studio", "accelerator.family": "apple-silicon"},
    "config_digest": "sha256:" + "0" * 64,
}))
for device in (
    {"device_id": DEV_GPU, "kind": "gpu", "vendor": "apple", "product": chip,
     "hardware_fingerprint": "apple:metal:0"},
    {"device_id": DEV_CPU, "kind": "cpu", "vendor": "apple", "product": chip,
     "hardware_fingerprint": "cpu:apple"},
    {"device_id": DEV_DISK, "kind": "disk", "vendor": "system",
     "product": "Rigplane model cache filesystem", "hardware_fingerprint": "disk:rigplane-cache",
     "attributes": {"path": str(cache_dir)}},
):
    agent.append(table("agent.registration.devices", device, array=True))
now = "2026-09-29T00:00:00Z"
for pool in (
    {"pool_id": POOL_MEM, "node_id": NODE, "kind": "unified_memory", "device_ids": [DEV_GPU],
     "capacity_bytes": memsize, "allocatable_bytes": memsize - (6 << 30),
     "available_bytes": memsize - (6 << 30), "max_leases": 1, "active_leases": 0,
     "exclusivity_keys": [], "measured_at": now},
    {"pool_id": POOL_CPU, "node_id": NODE, "kind": "cpu", "device_ids": [DEV_CPU],
     "capacity_cpu_millis": ncpu * 1000, "available_cpu_millis": ncpu * 1000,
     "max_leases": 1, "active_leases": 0, "measured_at": now},
    {"pool_id": POOL_DISK, "node_id": NODE, "kind": "disk_cache", "device_ids": [DEV_DISK],
     "capacity_bytes": disk_total, "allocatable_bytes": disk_total, "available_bytes": disk_total,
     "max_leases": 1, "active_leases": 0, "measured_at": now},
):
    body = "".join(
        f"{key} = {value}\n" if key == "measured_at" else f"{key} = {toml_value(value)}\n"
        for key, value in pool.items()
    )
    agent.append("[[agent.registration.resource_pools]]\n" + body + "\n")
agent.append(table("agent.registration.capabilities", {
    "adapter": "mlx-vlm", "adapter_version": MLX_VLM_VERSION,
    "operations": ["text.generate", "vision.generate"],
    "input_media_types": ["application/json"],
    "output_media_types": ["application/json", "text/event-stream"],
    "streaming_modes": ["none", "tokens"], "cancellation": "cooperative",
    "max_context_tokens": 32768, "max_input_bytes": 1048576,
    "supported_model_formats": ["mlx"], "accelerator_apis": ["metal"],
}, array=True))
socket = str(state_dir / "mlx-vlm.sock")
agent.append(table("adapters", {
    "key": "mlx-vlm", "enabled": True, "supervisor": "direct", "endpoint": f"unix://{socket}",
    "command": [str(repo / ".venv/bin/rigplane-mlx-vlm-worker"), "--socket", socket,
                "--backend-version", MLX_VLM_VERSION],
}, array=True))

out_dir.mkdir(parents=True, exist_ok=True)
(out_dir / "studio-coordinator-fragment.toml").write_text("".join(fragment))
(out_dir / "studio-agent.toml").write_text("".join(agent))
links = [(f["source"], str(cache_dir / key / f["path"])) for key in MODELS for f in digests[key]["files"]]
(out_dir / "studio-model-links.json").write_text(json.dumps(links, indent=1))
print("wrote", out_dir, "socket path length", len(socket))
