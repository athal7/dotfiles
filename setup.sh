#!/usr/bin/env bash

## Setup hook for use with Github Codespaces 
## https://docs.github.com/en/codespaces/setting-up-your-codespace/personalizing-codespaces-for-your-account
make symlink
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/codespace/.profile
source ~/.profile
brew install bat git-delta eslint navi prettier
source ~/.bashrc
