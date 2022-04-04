#!/usr/bin/env bash

## Setup hook for use with Github Codespaces 
## https://docs.github.com/en/codespaces/setting-up-your-codespace/personalizing-codespaces-for-your-account

sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply $GITHUB_USERNAME