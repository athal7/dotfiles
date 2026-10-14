# athal7's dotfiles

A macOS development environment managed with [chezmoi](https://chezmoi.io).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` and fill in machine-specific values.

This chezmoi source sets `umask = 0o077`, making managed files `0600` and directories `0700`. Before applying on an existing installation, set the same value in its active TOML config without regenerating other settings:

```bash
config="$(chezmoi data | jq -r '.chezmoi.configFile')"
yq -i -p=toml -o=toml '.umask = 63' "$config"
```

This also restricts externally managed app bundles. Run `chezmoi apply` after changing source files.

## Keyboard settings

OpenFlow and Create Companion are managed from pinned, checksum-verified public releases in the package registry. Chezmoi downloads the OpenFlow Apple-Silicon disk image to `~/Applications/OpenFlow-0.7.0.dmg` and installs `Create Companion.app`. Open the disk image and copy `OpenFlow.app` into `~/Applications`. macOS requires Input Monitoring and Accessibility permissions for Create Companion; its repository-owned config currently leaves start-at-login disabled.

The repository owns the OpenFlow keymap profile at `dot_config/openflow/profiles/naya-default-macos.json` and Create Companion's host config at `Library/Application Support/CreateCompanion/config.toml`. The Companion config intentionally has no per-app profiles yet; only its general `System` bindings are configured.

The OpenFlow profile's 211 keyboard-key bindings match the preserved Naya database snapshot. Its QWERTY layer uses the original `Naya Touch MacOS` config on both Touch sides; no custom Create Companion Touch gesture mapping is included. The original database snapshot at `dot_config/openflow/import/naya-create-profile.db` remains preserved for recovery and contains Naya-only records not represented in the OpenFlow profile.

The preserved Naya database snapshot stores four Tune settings as numeric sliders. The pinned OpenFlow 0.7.0 converter maps them by slot order, but its `MS-14 → pointer_accel_on` and `MS-17 → toggle_ticks` mappings conflict with the source rows: both are `numboxSlider` values, while OpenFlow defines those destination fields as toggles ([converter](https://github.com/create-collective/openflow/blob/8fc8a95011702b7d39038a7bd26051367f0e5479/backend/openflow_backend/db/nayaflow_convert.py), [field schema](https://github.com/create-collective/openflow/blob/8fc8a95011702b7d39038a7bd26051367f0e5479/backend/openflow_backend/db/userdata.py)). The profile therefore preserves `MS-14=20` and `MS-17=50` under their raw IDs, including their numeric-slider types; it does not guess replacement meanings or coerce either value to `false`. Those two settings remain unverified for firmware use.

Read-only comparison against `dot_config/openflow/import/naya-create-profile.db` confirms all 211 keyboard bindings and 10 layer/module assignments match after resolving OpenFlow-regenerated IDs. Every snapshot-defined Naya Touch/Tune gesture remains present; OpenFlow-side profiles may include additional gestures. The settings below are the only identified mapping correction:

| Naya row | Value | Source type | Repository profile field |
| --- | ---: | --- | --- |
| `MS-12` | 25 | `numboxSlider` | `pointer_speed` (converter mapping) |
| `MS-14` | 20 | `numboxSlider` | `MS-14` (raw; no verified semantic field) |
| `MS-16` | 72 | `numboxSlider` | `tick_strength` (converter mapping) |
| `MS-17` | 50 | `numboxSlider` | `MS-17` (raw; no verified semantic field) |

After deployment, two `WatchPaths` agents capture live edits in the repository: `companion-config-sync` watches `~/Library/Application Support/CreateCompanion/config.toml`, and `openflow-profile-sync` watches OpenFlow's `user-data.db` and WAL file. Each validates its input, updates only its matching repository file, and makes a local Git commit containing only that path; neither agent pushes. The OpenFlow watcher only considers the profile whose name exactly matches the repository profile; a differently named review candidate is ignored.

After every `chezmoi apply`, `.chezmoiscripts/run_after_openflow-profile-sync.sh.tmpl` loads the repository profile into OpenFlow's local profile store only if OpenFlow is already running. The hook never starts the app; it skips cleanly if the app is not installed or its loopback API is unreachable. Open OpenFlow manually, then run `chezmoi apply` again to sync.

The first sync imports the profile under its repository name. Later applies update that profile only when its prior state is managed and there are no unresolved GUI/repository edits. Each replacement saves the previous profile export locally before swapping in and verifying the new profile. An unexpected same-name profile, duplicate name, or concurrent edit stops the sync rather than overwriting an unmanaged profile. Resolve the reported conflict in OpenFlow or the repository, then apply again.

The helper uses OpenFlow profile RPCs only; it has no device or firmware route. **No keyboard is flashed by `chezmoi apply`.** Review the profile in OpenFlow before using an OpenFlow device-write control.

To inspect the loaded profile and compare it with the source:

```bash
openflow-profile-sync --source-dir "$PWD" list
openflow-profile-sync --source-dir "$PWD" status \
  --profile-file dot_config/openflow/profiles/naya-default-macos.json
```

`MATCH` means the settings agree. `DIFFERENT` exits 1 and lists semantic differences. The `companion-config-sync` watcher captures GUI edits to Create Companion's TOML back into the repository; `openflow-profile-sync` captures OpenFlow profile edits. Each watcher validates its input and makes a local Git commit containing only its matching repository file; neither pushes. Repository profile changes flow into OpenFlow on the next `chezmoi apply` while OpenFlow is running. If both copies changed since the last sync, the sync stops and preserves the existing profile export for recovery.

OpenFlow sync state is stored at `~/Library/Application Support/OpenFlowSettingsSync/repository-profiles.json`; backups are under `~/Library/Application Support/OpenFlowSettingsSync/backups/`. Never commit profile IDs or local sync state; review watcher-created commits before a later deploy.


The NayaFlow package and automatic database-sync LaunchAgent are no longer managed. Removing them does not uninstall an existing NayaFlow app or erase its live database; the original database snapshot remains a recovery source. This migration manages OpenFlow keymaps, module settings, and host-side gesture dispatch, not firmware updates or recovery writes. Keep NayaFlow installed until OpenFlow's firmware/recovery path is verified for this exact hardware. QMK/VIA are not substitutes; repository searches found no supported Naya Create target.

## What's included

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: [OMP configuration](dot_config/omp/agent/), [MCP servers](.chezmoidata/mcp.yaml), and [shared skills and index](dot_agents/skills/) installed at `~/.agents/skills/`. AoE (Agent of Empires) manages OMP sessions.
- Local AI: [OpenJev](https://github.com/razorback16/openjev) runs an MLX System One server on loopback for OMP's native [judge role](dot_config/omp/agent/config.yml.tmpl); its pinned Python environment is installed from the [package registry](.chezmoidata/packages.yaml) before the [LaunchAgent](dot_config/launchd-yaml/agents.yaml.tmpl) starts.
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) run the weekday [daily maintenance](dot_agents/prompts/daily-maintenance.md) session for independent production-error triage and KB enrichment, a separate daily Homebrew update and upgrade at 04:00, and weekly cleanup of old Chrome signing clones, idle worktrees, build artifacts, and disconnected development databases. The repo also configures an [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](https://github.com/athal7/cal), and [Homebridge](dot_config/homebridge/).
- Packages: [one registry](.chezmoidata/packages.yaml) for Homebrew, mise, the pinned OpenJev Python service, and GitHub releases, with [external downloads](.chezmoiexternal.toml.tmpl). The `cal-automation` package is installed from `athal7/tap` via Homebrew; its [private configuration](dot_config/cal/config.json.tmpl) renders from `.chezmoidata/local.yaml` to `~/.config/cal/config.json`. The pinned `codebase-memory-mcp` npm tool is also installed via mise with its native-binary postinstall script explicitly allowed, avoiding an `npx` wrapper per OMP session.
- Containers: Docker CLI and Compose use [Colima](https://github.com/abiosoft/colima). The complete default profile is managed in [dot_colima/default/colima.yaml](dot_colima/default/colima.yaml); edit it in the repository to change Colima settings. It configures a 64 GiB VM disk, 4 GiB memory, and Docker BuildKit garbage collection with a 4 GB cache target. Colima can grow a VM disk but cannot shrink one; before applying to a VM already larger than 64 GiB, set the profile disk value to at least its existing size. A disk increase takes effect only after a planned Colima restart; review `colima status` and host free space first. BuildKit GC reclaims eligible build cache, not images, containers, or volumes; active build references are retained, so cache-heavy builds may need to rebuild layers. The target is a GC policy, not reserved free space or a hard cap on total Docker storage. Check usage with `docker system df -v` and `colima ssh -- df -h /var/lib/docker`. Retained images and container data can still exhaust VM disk or host capacity. Shells point `DOCKER_HOST` at `$HOME/.colima/default/docker.sock`; set `DOCKER_HOST` after shell startup to use another daemon. Compose is exposed through `~/.docker/cli-plugins/docker-compose` without replacing `~/.docker/config.json`. A container with `/var/run/docker.sock` mounted can control sibling containers; treat the mount as privileged. Apple Container remains installed independently, and Colima does not migrate or delete its data.
- Knowledge-base collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`.

OMP’s vault feature (`vault://`) is the agent-facing interface for collected facts and evidence. OMP Mnemopi stores curated agent-learned insights only, with automatic retention disabled and project-tagged memories enabled for cross-project recall.

## Secrets and per-repository environment

Apple Passwords and 1Password remain the primary stores. Shell startup does not read Keychain or export a GitHub token. The managed `~/.envrc` defines `keychain_env VAR ACCOUNT` but loads no credentials until called. `ACCOUNT` names a macOS generic-password item under service `chezmoi`; use a separate Keychain item only when noninteractive access is needed. Never put secret values in tracked files or `.chezmoidata/local.yaml`.

For a trusted repository, keep its `.envrc` untracked and review it before allowing direnv:

```sh
source "$HOME/.envrc"
keychain_env MYAPP_API_KEY myapp_api_key
```

Run `direnv allow` in that repository. Global `.env` auto-loading and the all-path direnv whitelist are disabled. Work credentials that stay in 1Password can instead use the ignored, command-scoped Fnox config described below.

## OMP and AoE

`omp` uses `~/.config/omp/` as its global root and `~/.config/omp/agent/` for agent data; AoE launches sessions with those paths and receives the same `PI_CODING_AGENT_DIR` in its profile environment so its managed `hooks/pre/aoe-status.ts` lands in OMP's discovered hook directory. Keep that status module AoE-owned; chezmoi manages the separate `eval-timeout.ts` hook. OMP's session directory remains on its existing managed/XDG default. AoE requests only OMP's named Keychain credentials and a GitHub token. The interactive `omp` function supplies a GitHub token only to the launched process. Direct non-shell invocations must supply their own environment, including `GITHUB_TOKEN` for the GitHub MCP. AoE Serve binds to loopback behind private Tailscale Serve and uses a Keychain passphrase for its dashboard, not a URL token.

All new non-bare AoE worktrees use `~/code/.worktrees/<repo>/<branch>`, and multi-repo workspaces use `~/code/.worktrees/workspaces/<branch>-workspace-<session-id>`, regardless of where the source repositories live. Existing worktrees are not moved; bare repositories retain their in-repo worktree layout.

Fnox is pinned via mise for command-scoped repository credentials. Keep provider references in an ignored `fnox.local.toml` at the repository root; run `fnox exec -- <command>` so only that command receives them. For trusted AoE worktrees, a symlink at `~/code/.worktrees/<repo>/fnox.local.toml` pointing to `../../<repo>/fnox.local.toml` makes the same provider references discoverable by existing and future branches without copying secret material. Older `<repo>-worktrees/` roots need a link to `../<repo>/fnox.local.toml` while they remain. Do not commit these local configs or export their values in the shell.

The local `judge` role uses OpenJev's native `POST /v1/systemone` API, not chat prompting. The package install script creates a pinned Python 3.12 environment at `~/.local/share/openjev/venv` before `com.$USER.openjev` starts on `127.0.0.1:8091`. Its first start downloads the MLX weights. The LaunchAgent limits MLX's buffer cache to 4 GiB; OpenJev reports a 23.5-GiB working set with that limit on a 48-GiB M4 Pro. Check `GET http://127.0.0.1:8091/health` and `~/Library/Logs/openjev.error.log` after deployment; the judge is not available until model loading completes.

OMP uses native write approval with explicit bash, eval, hub, task, and write allows. OMP's native GitHub integration is disabled. The Bash policy prompts for direct `gh` commands; allowed Eval subprocesses do not inherit that Bash rule. The GitHub MCP tool catalog in `.chezmoidata/mcp.yaml` expands mutation globs into exact OMP approval keys; keep it aligned with the connected server. OMP 18.8.5 has no working `includeTools` filter, so the catalog is not an access-control boundary. GitHub writes still require approval for the exact target and payload. Git push and chezmoi-deploy (which applies and pushes main) also prompt when invoked through Bash; system instructions forbid bypassing these gates through Eval. OMP's approval key is managed separately in [`keybindings.yml`](dot_config/omp/agent/keybindings.yml) and uses `Alt+Enter`: AoE web encodes `Ctrl+Enter` as `ESC+CR`, which OMP parses as `Alt+Enter`. AoE's `C-q` live-send exit chord is handled by the TUI, not the web terminal; the web terminal sends `Ctrl+Q` to the pane. The custom OMP status line shows the model but omits Git branch/status; AoE remains the source for worktree context.

Codex Code Mode normally wraps file edits in `eval`. The OMP config exposes native `edit` and `write` as direct tools instead, so hashline edits remain surgical and prewalk can observe edit/write results. This setting is Codex-specific; other providers use their normal tool-call integration.

GitHub uses the official remote MCP at https://api.githubcopilot.com/mcp/. Its selected toolsets expose PR, issue, repository, user, and Actions operations; the locally enumerated read and write tools are intended usage and approval inputs, not an exhaustive filter on exposed tools. The currently listed writes (comments, review operations, branch and file changes, PR creation/merging, and workflow dispatch) prompt through generated exact-name policies. The remote uses the GitHub identity authorized through OMP; ensure it can access both organization scopes. For an uncovered endpoint, use `gh` via Bash; every command prompts. Do not use OMP's native GitHub tool.

OMP and scheduled KB enrichment enable every configured MCP server with the same server definitions and headers. Connectors that require credentials or environment URLs still need those values configured. The optional Runlayer MCP entries for GitHub are not used; the remaining Runlayer connectors stay independently configured.

OMP disables its native browser and Browser Relay, using Mozilla’s `firefox-devtools` MCP server as the only browser path. The package registry installs Firefox and pins the server with mise; OMP runs its installed binary in headless mode with a separate Firefox profile. The `slim` preset exposes page navigation, snapshots, input, and screenshots, but not console inspection, page-script evaluation, or extension installation. Browser access still requires affirmative consent each OMP session. Start a new OMP session after deployment to pick up the native browser setting; `/mcp reload` only refreshes MCP servers in an existing session.

AoE stores configuration, plugins, profiles, and runtime state under `~/.config/agent-of-empires/`. On an existing machine, copy the complete `~/.agent-of-empires/` tree there **before** applying chezmoi: AoE switches to XDG as soon as the new directory exists. Check the migration with `aoe settings explain session.default_tool` and `aoe list` before removing the legacy tree. The tmux status line is minimal; use `C-b s` or `C-b w` to select a session or window.

AoE's [`config.toml`](dot_config/agent-of-empires/config.toml.tmpl) is a full-file TOML template; its settings are declared directly, with home paths and private Runlayer URLs rendered only where needed. AoE keeps UI/runtime state in `state.toml`, not `config.toml`; the [web UI state template](dot_config/agent-of-empires/modify_state.toml) pins the mobile terminal key row while preserving AoE's other state. AoE plugins are declared in `.chezmoidata/packages.yaml` and installed/updated by the chezmoi plugin script; enabled plugins and capability grants are managed in `config.toml.tmpl`. The template enables AoE's startup plugin auto-updater; it updates clean plugins and preserves AoE's trust and approval checks. The chezmoi script also updates managed plugins with `--yes`, re-approving changed capability sets; its template declares the granted capability set and manifest hash. The Attention plugin displays prioritized items in each session pane.

The Attention dashboard's session action reuses a unique live OMP session for the same scratch title or repository worktree branch and sends the current request to it (reviving a stopped agent). Archived/trashed sessions are not resumed; ambiguous matches fail without creating another session. New items still create sessions through the scheduled-session dispatcher.

Homebridge stores its data at `~/.config/homebridge`. On a machine still using `~/.homebridge`, stop Homebridge before migrating the entire directory, preserve any existing destination as a backup, and check that the moved `config.json` parses before restarting it.

## Optional MCP setup

For higher Context7 quotas, create a free key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 remains available anonymously. Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The official GitHub MCP is enabled by default and uses OMP remote authentication with the GitHub identity you authorize. Its toolset and approval catalog live in .chezmoidata/mcp.yaml; listed write operations prompt through exact-name approval policies. Confirm that the identity can access both organization scopes before using it.

The `codebase-memory` MCP server keeps a local index under `~/.cache/codebase-memory-mcp`. New-project auto-indexing is off by default: run its `index_repository` tool once per project. Separate worktrees have separate indexes.
