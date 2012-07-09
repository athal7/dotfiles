export ARCHFLAGS='-arch x86_64' 
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# RVM
export CC=gcc-4.2
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"

# JRuby
export JRUBY_OPTS=--1.9

# Git aliases
# Remotes
alias gcl='git clone'
alias gres='git remote -v show'
alias grea='git remote add'
alias grer='git remote rm'
# Pushing/Pulling
alias gf='git fetch'
alias gl='git pull'
alias glom='git pull origin master'
alias gp='git push'
alias gpom='git push origin master'
alias gt='git tag -a'
# Status
alias gst='git status'
alias gd='git diff'
alias gs='git stash'
alias gsa='git stash apply'
alias gh='git hist'
# Adding/Committing 
alias ga='git add'
alias gap='git add -p'
alias gaa='git add -A'
alias gc='git commit -v'
alias gcm='git commit -v -m'
alias gcam='git add -A && git commit -v -m'
alias gac='git add -A && git commit -v'
# Branches
alias gb='git branch'
alias gbn='git checkout -b'
alias gbd='git branch -D'
alias go='git checkout'
# Merge/Rebase
alias grb='git rebase'
alias grbi='git rebase -i'
alias gm='git merge'

# Bash Prompt Color / Layout
export RUBYOPT=-Itest

function rvm_version {
local gemset=$(echo $GEM_HOME | awk -F'@' '{print $2}')
[ "$gemset" != "" ] && echo "@$gemset"
}

RED="\[\033[0;31m\]"
YELLOW="\[\033[0;33m\]"
GREEN="\[\033[0;32m\]"
BLUE="\[\033[0;36m\]"
PINK="\[\033[0;35m\]"
WHITE="\[\033[1;37m\]"
BLACK="\[\033[0;30m\]"
OFF="\[\033[0m\]"
source /usr/local/etc/bash_completion.d/git-completion.bash
export PS1="ɾ $YELLOW\$(~/.rvm/bin/rvm-prompt v)\$(rvm_version) $BLUE\W $PINK\$(__git_ps1 "%s")$OFF\nɩ $GREEN=> $OFF"

# other aliases
alias be='bundle exec'
alias bp='vi  ~/.bash_profile'
# alias canes= 'cane --style-glob "app/**/*.rb" --abc-glob "app/**/*.rb" --no-doc'
alias rspec='rspec --color -f d'
alias reeks='reek app/**/*.rb | grep "TooManyStatements\|UncommunicativeVariableName\|LongMethod"'
alias reloadbash='source ~/.bash_profile'

#hitch
hitch() {
  command hitch "$@"
  if [[ -s "$HOME/.hitch_export_authors" ]] ; then source "$HOME/.hitch_export_authors" ; fi
}
alias unhitch='hitch -u'

# Get the aliases and functions
if [ -f /.bashrc ]; then
  . /.bashrc
fi

#Autojump
[[ -f ~/.autojump/etc/profile.d/autojump.bash ]] && source ~/.autojump/etc/profile.d/autojump.bash

#enables color in the terminal bash shell export
CLICOLOR=1
#sets up the color scheme for list export
LSCOLORS=gxfxcxdxbxegedabagacad
#sets up the prompt color (currently a green similar to linux terminal)
#enables color for iTerm
export TERM=xterm-color
