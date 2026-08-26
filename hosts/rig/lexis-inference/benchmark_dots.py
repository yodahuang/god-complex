#!/usr/bin/env python3
"""Run a reproducible direct Dots MF benchmark on Rig."""

from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path
import random
import resource
import subprocess
import time
from typing import Any


MODEL_REVISION = "c28105adc8228143392b4e346994ff613ee48a06"
SAMPLE_RATE = 48_000


def _peak_rss_bytes() -> int:
    # Linux reports ru_maxrss in KiB.
    return int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss) * 1024


def _load_sentences(path: Path, limit: int | None) -> list[dict[str, str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("corpus JSON must be an object")
    raw_examples = payload.get("examples")
    if not isinstance(raw_examples, list) or not raw_examples:
        raise ValueError("corpus JSON must contain a non-empty examples list")
    examples: list[dict[str, str]] = []
    for index, raw in enumerate(raw_examples):
        if not isinstance(raw, dict):
            raise ValueError(f"corpus example {index} is not an object")
        sentence = str(raw.get("sentence", "")).strip()
        if not sentence:
            raise ValueError(f"corpus example {index} has no sentence")
        example_id = str(raw.get("example_id", f"example-{index + 1:04d}"))
        examples.append({"example_id": example_id, "sentence": sentence})
    selected = examples if limit is None else examples[:limit]
    if not selected:
        raise ValueError("--limit selected zero sentences")
    return selected


def _read_transcript(args: argparse.Namespace) -> str:
    if bool(args.reference_text) == bool(args.reference_text_file):
        raise ValueError("provide exactly one of --reference-text or --reference-text-file")
    if args.reference_text_file:
        transcript = args.reference_text_file.read_text(encoding="utf-8")
    else:
        transcript = args.reference_text
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("reference transcript must not be blank")
    return transcript


def _set_seed(seed: int) -> None:
    import numpy as np
    import torch

    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def _encode_opus(
    audio: Any,
    sample_rate: int,
    *,
    ffmpeg: str,
    bitrate: str,
) -> bytes:
    import soundfile as sf

    wav = io.BytesIO()
    sf.write(wav, audio, sample_rate, format="WAV", subtype="PCM_16")
    completed = subprocess.run(
        [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-f",
            "wav",
            "-i",
            "pipe:0",
            "-ar",
            str(sample_rate),
            "-ac",
            "1",
            "-c:a",
            "libopus",
            "-b:a",
            bitrate,
            "-f",
            "ogg",
            "pipe:1",
        ],
        input=wav.getvalue(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=30,
    )
    if completed.returncode != 0:
        detail = " ".join(completed.stderr.decode("utf-8", "replace").split())
        raise RuntimeError(f"ffmpeg failed: {detail[:300]}")
    if not completed.stdout.startswith(b"OggS"):
        raise RuntimeError("ffmpeg returned a non-Ogg output")
    return completed.stdout


def _cuda_memory() -> dict[str, int | float]:
    import torch

    return {
        "allocated_bytes": int(torch.cuda.max_memory_allocated()),
        "reserved_bytes": int(torch.cuda.max_memory_reserved()),
        "allocated_gib": int(torch.cuda.max_memory_allocated()) / (1024**3),
        "reserved_gib": int(torch.cuda.max_memory_reserved()) / (1024**3),
    }


def _synchronize_cuda() -> None:
    import torch

    torch.cuda.synchronize()


def _snapshot_gpu() -> dict[str, str] | None:
    try:
        completed = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=name,driver_version,memory.total,memory.used,utilization.gpu,temperature.gpu",
                "--format=csv,noheader,nounits",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            text=True,
            timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if completed.returncode != 0:
        return None
    fields = [field.strip() for field in completed.stdout.strip().split(",")]
    if len(fields) != 6:
        return None
    return dict(
        zip(
            ("name", "driver_version", "memory_total_mib", "memory_used_mib", "utilization_percent", "temperature_c"),
            fields,
            strict=True,
        )
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus-json", type=Path, required=True)
    parser.add_argument("--reference-audio", type=Path, required=True)
    transcript = parser.add_mutually_exclusive_group(required=True)
    transcript.add_argument("--reference-text")
    transcript.add_argument("--reference-text-file", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--model", default="dots-studio/dots.tts-mf")
    parser.add_argument("--revision", default=MODEL_REVISION)
    parser.add_argument("--cache-dir", type=Path, default=Path("/var/lib/lexis-inference/models"))
    parser.add_argument("--precision", default="float16")
    parser.add_argument("--optimize", action="store_true")
    parser.add_argument("--no-optimize-warmup", action="store_true")
    parser.add_argument("--max-new-tokens", type=int, default=96)
    parser.add_argument("--max-sequence-length", type=int, default=2_048)
    parser.add_argument("--vocoder-merge-steps", type=int, default=4)
    parser.add_argument("--num-steps", type=int, default=4)
    parser.add_argument("--guidance-scale", type=float, default=1.2)
    parser.add_argument("--speaker-scale", type=float, default=1.5)
    parser.add_argument("--language", default="EN")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--opus-bitrate", default="64k")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--no-audio", action="store_true", help="validate waveforms without writing Opus files")
    return parser


def main() -> int:
    args = _parser().parse_args()
    if args.max_new_tokens < 1 or args.num_steps < 1:
        raise ValueError("--max-new-tokens and --num-steps must be positive")
    if not args.reference_audio.is_file():
        raise ValueError(f"reference audio does not exist: {args.reference_audio}")
    transcript = _read_transcript(args)
    examples = _load_sentences(args.corpus_json, args.limit)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if any(args.output_dir.iterdir()):
        raise ValueError(f"output directory is not empty: {args.output_dir}")

    import numpy as np
    import torch
    from dots_tts.runtime import DotsTtsRuntime

    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable; this benchmark must run on the Rig GPU")
    _set_seed(args.seed)
    torch.cuda.reset_peak_memory_stats()
    gpu_before = _snapshot_gpu()
    _synchronize_cuda()
    load_started = time.perf_counter()
    runtime = DotsTtsRuntime.from_pretrained(
        args.model,
        revision=args.revision,
        cache_dir=str(args.cache_dir),
        precision=args.precision,
        optimize=args.optimize,
        max_generate_length=args.max_new_tokens,
        max_sequence_length=args.max_sequence_length,
        vocoder_merge_steps=args.vocoder_merge_steps,
        warmup_on_optimize=not args.no_optimize_warmup,
    )
    model_load_seconds = time.perf_counter() - load_started
    results: list[dict[str, Any]] = []
    failures: list[dict[str, str]] = []
    generation_started = time.perf_counter()
    for index, example in enumerate(examples):
        seed = args.seed + index
        _set_seed(seed)
        _synchronize_cuda()
        started = time.perf_counter()
        try:
            with torch.inference_mode():
                result = runtime.generate(
                    text=example["sentence"],
                    prompt_audio_path=str(args.reference_audio),
                    prompt_text=transcript,
                    language=args.language,
                    speaker_scale=args.speaker_scale,
                    ode_method="euler",
                    num_steps=args.num_steps,
                    guidance_scale=args.guidance_scale,
                    normalize_text=False,
                )
            _synchronize_cuda()
            if not isinstance(result, dict) or "audio" not in result:
                raise RuntimeError("runtime returned no audio")
            sample_rate = int(result.get("sample_rate", 0))
            audio = result["audio"].detach().float().cpu().squeeze().numpy()
            if sample_rate != SAMPLE_RATE:
                raise RuntimeError(f"runtime returned {sample_rate} Hz, expected {SAMPLE_RATE} Hz")
            if audio.ndim != 1 or audio.size == 0 or not bool(np.isfinite(audio).all()):
                raise RuntimeError("runtime returned an empty, non-mono, or non-finite waveform")
            peak = float(np.max(np.abs(audio)))
            if not np.isfinite(peak) or peak > 1.5:
                raise RuntimeError(f"runtime returned an out-of-range waveform (peak={peak:.3f})")
            opus_bytes = b""
            output_path: str | None = None
            if not args.no_audio:
                opus_bytes = _encode_opus(
                    np.clip(audio, -1.0, 1.0),
                    sample_rate,
                    ffmpeg=args.ffmpeg,
                    bitrate=args.opus_bitrate,
                )
                output = args.output_dir / f"{index + 1:04d}-{example['example_id']}.ogg"
                temporary = output.with_suffix(".tmp")
                temporary.write_bytes(opus_bytes)
                temporary.replace(output)
                output_path = str(output)
            elapsed = time.perf_counter() - started
            duration_seconds = float(audio.size / sample_rate)
            results.append(
                {
                    "index": index,
                    "example_id": example["example_id"],
                    "sentence": example["sentence"],
                    "seed": seed,
                    "elapsed_seconds": elapsed,
                    "audio_duration_seconds": duration_seconds,
                    "real_time_factor": elapsed / duration_seconds if duration_seconds else None,
                    "sample_rate": sample_rate,
                    "peak": peak,
                    "opus_bytes": len(opus_bytes),
                    "output_path": output_path,
                }
            )
            print(
                f"{index + 1}/{len(examples)} {elapsed:.2f}s "
                f"audio={duration_seconds:.2f}s rtf={elapsed / duration_seconds:.2f}",
                flush=True,
            )
        except Exception as exc:  # noqa: BLE001 - benchmark must report item failures
            failures.append(
                {
                    "index": str(index),
                    "example_id": example["example_id"],
                    "sentence": example["sentence"],
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )
            print(f"{index + 1}/{len(examples)} FAILED: {failures[-1]['error']}", flush=True)
    elapsed = time.perf_counter() - generation_started
    durations = [float(item["elapsed_seconds"]) for item in results]
    rtf_values = [float(item["real_time_factor"]) for item in results]
    report: dict[str, Any] = {
        "schema_version": "dots_cuda_benchmark.v1",
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "host": os.uname().nodename,
        "model": args.model,
        "revision": args.revision,
        "precision": args.precision,
        "optimize": bool(args.optimize),
        "num_steps": args.num_steps,
        "max_new_tokens": args.max_new_tokens,
        "max_sequence_length": args.max_sequence_length,
        "vocoder_merge_steps": args.vocoder_merge_steps,
        "corpus_json": str(args.corpus_json),
        "reference_audio": str(args.reference_audio),
        "reference_audio_bytes": args.reference_audio.stat().st_size,
        "reference_transcript_chars": len(transcript),
        "sample_rate": SAMPLE_RATE,
        "examples_requested": len(examples),
        "assets": len(results),
        "failures": failures,
        "model_load_seconds": model_load_seconds,
        "generation_elapsed_seconds": elapsed,
        "examples_per_second": len(results) / elapsed if elapsed else 0.0,
        "audio_duration_seconds": sum(item["audio_duration_seconds"] for item in results),
        "rtf_mean": sum(rtf_values) / len(rtf_values) if rtf_values else None,
        "rtf_p50": sorted(rtf_values)[len(rtf_values) // 2] if rtf_values else None,
        "peak_rss_bytes": _peak_rss_bytes(),
        "peak_rss_gib": _peak_rss_bytes() / (1024**3),
        "cuda_memory": _cuda_memory(),
        "gpu_before": gpu_before,
        "gpu_after": _snapshot_gpu(),
        "results": results,
    }
    report_path = args.output_json or args.output_dir / "benchmark.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
    return 0 if not failures else 2


if __name__ == "__main__":
    raise SystemExit(main())
