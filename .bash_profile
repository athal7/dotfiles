# get machine specific bashrc
source ~/.bashrc

source ~/.prompt
source ~/.git_aliases
source ~/.aliases

export ARCHFLAGS='-arch x86_64'
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

export CC=gcc-4.2
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"
PATH=$PATH:$HOME/.rvm/bin

export RUBYOPT=-Itest
export JRUBY_OPTS=--1.9


# git completion
source ~/git-completion.bash
complete -o default -o nospace -F _git_checkout gco
source /usr/local/etc/bash_completion.d/git-completion.bash

CLICOLOR=1
LSCOLORS=gxfxcxdxbxegedabagacad
export TERM=xterm-color

alias openvpn="cd ~; osascript openvpn.applescript; cd -"
alias rearrange="cd ~; osascript WindowArrangement.scpt; cd -"

if [ -f `brew --prefix`/etc/autojump ]; then
. `brew --prefix`/etc/autojump
fi
