## Why

Local LLM inference on this MacBook Pro (Apple M4 Pro, 48 GB unified memory) underperforms and is misconfigured. The current setup runs a dense 27B model in GGUF with a 4 K context window, which errors on real prompts (`n_keep: 17100 >= n_ctx: 4096`) and decodes slowly. The Ollama MLX blog numbers are unreachable on this hardware — they require M5-class GPU Neural Accelerators plus an NVFP4 Mixture-of-Experts model — so we need a setup tuned to what an M4 Pro actually runs well: MLX-format MoE models with a correctly sized context window.

## What Changes

- Adopt **MLX-format Mixture-of-Experts (MoE)** as the primary local model class — a small active-parameter count yields fast decode on M4 Pro — replacing the dense GGUF 27B as the daily driver.
- Standardize LM Studio load configuration: MLX runtime, full GPU offload, and a 16K–32K context window (fixes the `n_ctx: 4096` error that broke the 27B).
- Provision the LM Studio `lms` CLI reproducibly via the dotfiles so model downloads and load config are scriptable.
- Optionally reclaim disk by retiring the slow, misconfigured dense GGUF models.

## Capabilities

### New Capabilities
- `local-llm`: Local LLM runtime selection, model choice, load configuration, and CLI provisioning tuned for Apple Silicon (M4 Pro / 48 GB).

### Modified Capabilities

(none — no existing spec capabilities change)

## Impact

- **Dotfiles / packages**: `dot_zshenv.tmpl` gains `~/.lmstudio/bin` on PATH; a new `run_once` chezmoi script runs `lms bootstrap`. The LM Studio cask is already declared in `.chezmoidata/packages.yaml`.
- **LM Studio config**: models downloaded under `~/.lmstudio/models`; a default model plus per-model load config (context length, GPU offload, MLX runtime).
- **No application code** in other repositories is affected.
