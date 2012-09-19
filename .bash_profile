# get machine specific bashrc
source ~/.bashrc

# get elements of bash profile
source ~/.prompt
source ~/.git_aliases
source ~/.aliases

# ?
export ARCHFLAGS='-arch x86_64'
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# rvm
export CC=gcc-4.2
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"
PATH=$PATH:$HOME/.rvm/bin

# test unit
export RUBYOPT=-Itest

# jruby
export JRUBY_OPTS=--1.9


# git completion
source ~/git-completion.bash
complete -o default -o nospace -F _git_checkout gco
source /usr/local/etc/bash_completion.d/git-completion.bash
CLICOLOR=1
LSCOLORS=gxfxcxdxbxegedabagacad
export TERM=xterm-color


# hitch
hitch() {
  command hitch "$@"
  if [[ -s "$HOME/.hitch_export_authors" ]] ; then source "$HOME/.hitch_export_authors" ; fi
}
alias unhitch='hitch -u'

# open vpn from command line, written by webandy
alias openvpn="cd ~; /usr/local/bin/pgrep racoon | xargs sudo kill -9; osascript openvpn.applescript; cd -"

# autojump (must be at the bottom)
if [ -f `brew --prefix`/etc/autojump ]; then
. `brew --prefix`/etc/autojump
fi
