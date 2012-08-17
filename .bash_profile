# get machine specific bashrc
source ~/.bashrc

# ?
export ARCHFLAGS='-arch x86_64'
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# rvm
export CC=gcc-4.2
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"
PATH=$PATH:$HOME/.rvm/bin
function rvm_version {
local gemset=$(echo $GEM_HOME | awk -F'@' '{print $2}')
[ "$gemset" != "" ] && echo "@$gemset"
}

# test unit
export RUBYOPT=-Itest

# jruby
export JRUBY_OPTS=--1.9

# git aliases
  # remotes
  alias gcl='git clone'
  alias gres='git remote -v show'
  alias grea='git remote add'
  alias grer='git remote rm'
  # pushing/pulling
  alias gf='git fetch'
  alias gl='git pull'
  alias glom='git pull origin master'
  alias gp='git push'
  alias gpom='git push origin master'
  # status
  alias gst='git status'
  alias gd='git diff'
  alias gs='git stash'
  alias gsa='git stash apply'
  alias gh='git log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short'
  # adding/committing
  alias ga='git add'
  alias gap='git add -p'
  alias gcm='git commit -v -m'
  alias gcam='git add -A && git commit -v -m'
  # branches
  alias gb='git branch'
  alias gbn='git checkout -b'
  alias gbd='git branch -D'
  alias go='git checkout'
  # merge/rebase
  alias grb='git rebase'
  alias grbi='git rebase -i'
  alias gm='git merge'
  alias gcadd="git add \"$@\" && git commit --amend -C HEAD"

# bash prompt
RED="\[\033[0;31m\]"
YELLOW="\[\033[0;33m\]"
GREEN="\[\033[0;32m\]"
BLUE="\[\033[0;36m\]"
PINK="\[\033[0;35m\]"
WHITE="\[\033[1;37m\]"
BLACK="\[\033[0;30m\]"
OFF="\[\033[0m\]"
source /usr/local/etc/bash_completion.d/git-completion.bash
export PS1="$BLUE\W$YELLOW \$(__git_ps1 "%s")$PINK •\$(~/.rvm/bin/rvm-prompt v)\$(rvm_version) $GREEN \n§ $OFF"
CLICOLOR=1
LSCOLORS=gxfxcxdxbxegedabagacad
export TERM=xterm-color

# other aliases
alias be='bundle exec'
alias bp='vi  ~/.bash_profile'
# alias canes= 'cane --style-glob "app/**/*.rb" --abc-glob "app/**/*.rb" --no-doc'
alias rspec='rspec --color -f d'
alias reeks='reek app/**/*.rb | grep "TooManyStatements\|UncommunicativeVariableName\|LongMethod"'
alias start="source ~/Scripts/start_app.sh"
alias reload='source ~/.bash_profile'
alias ring='rvm use 1.9.3 && ringleader ~/Documents/Projects/ringleader.yml'

# hitch
hitch() {
  command hitch "$@"
  if [[ -s "$HOME/.hitch_export_authors" ]] ; then source "$HOME/.hitch_export_authors" ; fi
}
alias unhitch='hitch -u'

# autojump
[[ -f ~/.autojump/etc/profile.d/autojump.bash ]] && source ~/.autojump/etc/profile.d/autojump.bash

# show directory in iterm header
export PROMPT_COMMAND='echo -ne "\033]0;${PWD/#$HOME/~}\007"'
