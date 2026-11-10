#!/usr/bin/env bash
# Render the chezmoi templates named on the command line (pre-commit passes the
# staged .tmpl files) and lint the ones that render to shell code.
#
# Two wrinkles this handles:
# - `.chezmoidata/local.yaml` is gitignored, so worktrees never have it and
#   templates that read private data (`.runlayer`, `.orgs`, …) would fail. The
#   public `local.yaml.example` is layered on via `--override-data-file`, which
#   needs a real `.yaml` extension to autodetect format — hence the temp copy.
# - Go-template control-flow syntax inside a shell script is not valid bash
#   before rendering, so pre-commit's shellcheck hook excludes `.tmpl` files and
#   the rendered output is linted here instead.
#
# The temp copy is PID-scoped with `cp` rather than `mktemp`: pre-commit runs
# this hook as several parallel processes for --all-files, and uutils coreutils'
# `mktemp` seeds its random suffix by wall-clock second, so concurrent
# invocations collide on the same "random" name and fail with EEXIST.

set -euo pipefail

src="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
overlay="${TMPDIR:-/tmp}/chezmoi-templates-local-example-$$.yaml"
trap 'rm -f "$overlay"' EXIT INT TERM
cp "$src/local.yaml.example" "$overlay"

status=0
for template in "$@"; do
  if ! rendered="$(chezmoi execute-template -S "$src" --override-data-file "$overlay" <"$template")"; then
    status=1
    continue
  fi
  if head -1 <<<"$rendered" | grep -qE '^#!.*\b(ba|z)?sh\b'; then
    shellcheck --shell=bash --severity=error <(printf '%s\n' "$rendered") || status=1
  fi
done

exit "$status"
