#!/bin/sh
set -eu

# The OMP native loader falls back to ~/.omp/natives unless this XDG root exists.
mkdir -p "$HOME/.local/share/omp"
