## 1. Provision the lms CLI via dotfiles

- [x] 1.1 Add `$HOME/.lmstudio/bin` to PATH in `dot_zshenv.tmpl`
- [x] 1.2 Add a `run_once` chezmoi script (e.g. `.chezmoiscripts/run_once_after_lms-bootstrap.sh.tmpl`) that runs `~/.lmstudio/bin/lms bootstrap` only when that binary exists, and exits 0 otherwise
- [x] 1.3 Run `chezmoi apply`, then verify in a new shell that `command -v lms` resolves

## 2. Download the primary MLX MoE model

- [x] 2.1 Resolve the exact LM Studio hub identifier for the MLX `Qwen3-30B-A3B` 4-bit build (`lms get --help`; hub search)
- [x] 2.2 Download it via `lms get <resolved-id>` into `~/.lmstudio/models`
- [x] 2.3 Confirm it appears in `lms ls`

## 3. Configure load settings

- [x] 3.1 Load the model with the MLX runtime and full GPU offload (all layers)
- [x] 3.2 Set context to 40960 (model max) and Max Concurrent Predictions to 2 (supports parallel coding sessions; pool is shared dynamically)
- [ ] 3.3 Save the per-model load config so it persists across loads
- [x] 3.4 Set the model as the LM Studio default

## 4. Verify on M4 Pro

- [x] 4.1 Send a ~17K-token prompt and confirm no `n_ctx` overflow error
- [x] 4.2 Run a generation and record decode tokens-per-second as the M4 Pro baseline
- [x] 4.3 Confirm memory use stays within 48 GB with headroom under load

## 5. Cleanup (optional)

- [x] 5.1 After verifying the MLX setup, remove `unsloth/Qwen3.5-27B-GGUF` (~15 GB)
- [x] 5.2 Remove the redundant `Qwen3-8B-GGUF` (~4.7 GB), keeping `Qwen3-8B-MLX-4bit`
- [x] 5.3 Record the model decision in the KB decisions log

## 6. Documentation

- [x] 6.1 Update `README.md` if the new `run_once` script or a config section warrants it

> Note: 3.3 (persist load config across loads) is the one remaining item — it's a one-click GUI action (load model → set load config → "Set as default for this model"). The CLI `lms load` flags used here (`--gpu max -c 40960 --parallel 2 --ttl 1800`) are not auto-persisted. 6.1 evaluated: README is a high-level feature list and does not enumerate scripts, so no change needed.
