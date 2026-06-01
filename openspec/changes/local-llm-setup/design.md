## Context

Hardware: MacBook Pro (Mac16,7), Apple M4 Pro, 48 GB unified memory. LM Studio is installed (cask declared in `.chezmoidata/packages.yaml`) with both llama.cpp (2.13/2.14) and MLX (`mlx-llm 1.6.0`) runtimes present. Current local models: `Qwen3-8B-MLX-4bit` (4.3 GB), `Qwen3-8B-GGUF` Q4_K_M (4.7 GB), and `unsloth/Qwen3.5-27B-GGUF` Q4_K_S (15 GB). The 27B is the intended "big" model, but its load config sets a 4 K context window, so real prompts fail with `n_keep: 17100 >= n_ctx: 4096`. The `lms` CLI binary exists at `~/.lmstudio/bin/lms` but is not on PATH.

The Ollama MLX blog's headline throughput (1810 tok/s prefill, 112 tok/s decode) is M5-only: it comes from the M5 GPU Neural Accelerators running an NVFP4 35B-A3B MoE. None of those conditions hold on an M4 Pro, so the goal is the best *reproducible* M4 Pro setup, not parity with the blog.

## Goals / Non-Goals

**Goals:**
- A primary local model that decodes fast on M4 Pro and fits comfortably in 48 GB with a large context window.
- Correct, reproducible LM Studio load config (runtime, GPU offload, context length).
- `lms` CLI provisioned through the dotfiles so model setup is scriptable and survives a fresh machine.

**Non-Goals:**
- Matching the blog's M5 throughput numbers.
- Reinstalling Ollama (removed; LM Studio is the chosen runtime).
- NVFP4 quantization (an NVIDIA-path format, not relevant on Apple Silicon).
- Fine-tuning or training.

## Decisions

### Decision: MLX format over GGUF
MLX is Apple's framework and the `mlx-llm` runtime is already installed. On Apple Silicon, MLX typically delivers higher tok/s and lower memory overhead than llama.cpp/Metal for the same quant. Alternative considered: stay on GGUF (simpler, models already present) — rejected because it leaves measurable Apple Silicon performance unused, which is the entire point of this change.

### Decision: Mixture-of-Experts as the primary model class
A MoE model activates only a fraction of its parameters per token. `Qwen3-30B-A3B` is ~30B total but ~3B active, so decode speed is close to a 3B dense model while quality is close to a much larger one. This mirrors the architecture the blog used (35B-A3B). Alternatives: dense 27B (current) — far more compute per token, slower; dense 14B — decent but a lower quality ceiling than a 30B-A3B at similar speed. Primary pick: `Qwen3-30B-A3B` MLX 4-bit (~17 GB). Benchmarks (below) confirm this: the MoE measured ~2.4x faster than a dense 8B on this machine, so smaller dense models are not useful fallbacks — they are slower AND lower quality.

### Decision: 16K–32K context window, full GPU offload
The 27B failed because context was 4 K. On 48 GB, a ~17 GB MoE leaves ample room for a 32K KV cache. Use full GPU offload (all layers) — unified memory makes CPU offload pointless here. Default the primary model to 32K context; the 8B can use 16K.

### Decision: provision `lms` via dotfiles, not a separate package
`lms` ships inside the LM Studio app bundle and is bootstrapped to `~/.lmstudio/bin/lms`. Rather than a Homebrew formula (none exists), add `~/.lmstudio/bin` to PATH in `dot_zshenv.tmpl` and add a `run_once` chezmoi script that runs `lms bootstrap` (idempotent) after the cask installs. This keeps the single-source package registry intact while making the CLI reproducible.

### Decision: retire all non-MoE local models
Benchmarks disproved the "keep an 8B fallback" idea — the dense 8B ran at 29.5 tok/s vs the 30B-A3B's 71.5 tok/s. So both the dense `Qwen3.5-27B-GGUF` (15.8 GB) and both `Qwen3-8B` variants (GGUF + MLX, ~4.7 GB) were removed, reclaiming ~24 GB and leaving `Qwen3-30B-A3B` as the sole local model.

## Risks / Trade-offs

- [MLX model identifier may differ in the LM Studio hub] → verify the exact tag with hub search before pinning it in tasks.
- [Memory pressure with 32K context + other apps] 17 GB weights + a large KV cache + OS could approach limits under heavy multitasking → start at 16K, raise to 32K after observing headroom; keep `unloadPreviousModelOnSelect` enabled.
- [`lms bootstrap` requires the app installed first] → the run_once script must no-op gracefully when `~/.lmstudio/bin/lms` is absent.
- [Quality regression vs dense models on some reasoning tasks] → keep the 8B MLX available and document how to switch.

## Migration Plan

1. Wire `lms` onto PATH and bootstrap (dotfiles change + `chezmoi apply`).
2. Download the MLX MoE model via `lms get`.
3. Create/verify the load config (MLX runtime, full GPU offload, context length).
4. Smoke-test: load the model, run a long-prompt generation, record tok/s.
5. Set it as the LM Studio default.
6. (Optional) remove the dense GGUF models.

Rollback: the existing GGUF models remain until step 6; reverting the dotfiles change restores the prior setup.

## Open Questions

- Exact hub identifier for the MLX MoE build (resolve during tasks).
- Whether to record the model decision in the KB decisions log (nice-to-have).

## Benchmark Results (M4 Pro / 48 GB, measured)

Measured via the LM Studio OpenAI-compatible server (port 1234), 500-token generations:

| Model | Decode tok/s | Active params | Resident |
|---|---|---|---|
| Qwen3-30B-A3B (MoE, MLX 4-bit) | **71.5** | ~3B | ~22 GiB |
| Qwen3-8B (dense, MLX) | 29.5 | 8B | ~5 GiB |

Findings:
- The MoE is ~2.4x faster than the dense 8B because it activates only ~3B params/token — it wins on both speed and quality, so there is no faster small fallback.
- A 30,023-token prompt was processed at 32K context with no `n_ctx` overflow (the failure that broke the old dense 27B at 4K).
- With only the 30B loaded, free memory measured 79%. Loading a second model caused swapping; hence one model + a 30-minute idle TTL (`--ttl 1800`) and `--parallel 1` for a single user.
