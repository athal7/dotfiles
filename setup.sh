#!/usr/bin/env bash

## Setup hook for use with Github Codespaces 
## https://docs.github.com/en/codespaces/setting-up-your-codespace/personalizing-codespaces-for-your-account

ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/codespace/.profile
source ~/.profile
make symlink
make packages
make languages