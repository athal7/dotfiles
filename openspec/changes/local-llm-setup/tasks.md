## 1. Provision the lms CLI via dotfiles

- [x] 1.1 Add `$HOME/.lmstudio/bin` to PATH in `dot_zshenv.tmpl`
- [x] 1.2 Add a `run_once` chezmoi script (e.g. `.chezmoiscripts/run_once_after_lms-bootstrap.sh.tmpl`) that runs `~/.lmstudio/bin/lms bootstrap` only when that binary exists, and exits 0 otherwise
- [x] 1.3 Run `chezmoi apply`, then verify in a new shell that `command -v lms` resolves

## 2. Download the primary MLX MoE model

- [x] 2.1 Resolve the exact LM Studio hub identifier for the MLX `Qwen3-30B-A3B` 4-bit build (`lms get --help`; hub search)
- [ ] 2.2 Download it via `lms get <resolved-id>` into `~/.lmstudio/models`
- [ ] 2.3 Confirm it appears in `lms ls`

## 3. Configure load settings

- [ ] 3.1 Load the model with the MLX runtime and full GPU offload (all layers)
- [ ] 3.2 Set the context window to 32K (fall back to 16K if memory headroom is tight)
- [ ] 3.3 Save the per-model load config so it persists across loads
- [ ] 3.4 Set the model as the LM Studio default

## 4. Verify on M4 Pro

- [ ] 4.1 Send a ~17K-token prompt and confirm no `n_ctx` overflow error
- [ ] 4.2 Run a generation and record decode tokens-per-second as the M4 Pro baseline
- [ ] 4.3 Confirm memory use stays within 48 GB with headroom under load

## 5. Cleanup (optional)

- [ ] 5.1 After verifying the MLX setup, remove `unsloth/Qwen3.5-27B-GGUF` (~15 GB)
- [ ] 5.2 Remove the redundant `Qwen3-8B-GGUF` (~4.7 GB), keeping `Qwen3-8B-MLX-4bit`
- [ ] 5.3 Record the model decision in the KB decisions log

## 6. Documentation

- [ ] 6.1 Update `README.md` if the new `run_once` script or a config section warrants it
