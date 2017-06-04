# zsh
  export ZSH=$HOME/.oh-my-zsh
  HYPHEN_INSENSITIVE=true
  COMPLETION_WAITING_DOTS=true
  DISABLE_UPDATE_PROMPT=true

# zsh plugins
  plugins=(autojump docker jsontools osx tmux vi-mode zsh-completions)
  source $ZSH/oh-my-zsh.sh
  ZSH_TMUX_AUTOSTART=true

  fancy-ctrl-z () {
    if [[ $#BUFFER -eq 0 ]]; then
      BUFFER="fg"
      zle accept-line
    else
      zle push-input
      zle clear-screen
    fi
  }
  zle -N fancy-ctrl-z
  bindkey '^Z' fancy-ctrl-z

# prompt
  source ~/.shell/.shell_prompt.sh

# terminal color settings
  CLICOLOR=1
  export TERM=xterm-256color
  export EDITOR="vim"

  BLACK="\[\033[0;30m\]"
  RED="\[\033[0;31m\]"
  GREEN="\[\033[0;32m\]"
  YELLOW="\[\033[0;33m\]"
  DARKBLUE="\[\033[0;34m\]"
  PINK="\[\033[0;35m\]"
  BLUE="\[\033[0;36m\]"
  WHITE="\[\033[1;37m\]"
  OFF="\[\033[0m\]"

# color for man pages
  export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
  export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
  export LESS_TERMCAP_me=$'\E[0m'           # end mode
  export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
  export LESS_TERMCAP_so=$'\E[1;31m'        # begin standout-mode - info box
  export LESS_TERMCAP_ue=$'\E[0m'           # end underline
  export LESS_TERMCAP_us=$'\E[04;33;5;146m' # begin underline

# shell aliases
  alias ll="ls -la"
  alias e='vim'
  alias less="less -R"
  alias lf="less +F"
  alias g='hub'
  alias mkcd='mkdir $1 && cd $1'
  function mkcd {
     mkdir -p "$1" && cd "$1"
  }
  alias watch='watch '

# homebrew
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

# ruby
  export ARCHFLAGS='-arch x86_64'
  export CC=gcc
  export RUBYOPT=-Itest
  export JRUBY_OPTS=--1.9
  export RUBY_HEAP_FREE_MIN=1024
  export RUBY_GC_HEAP_INT_SLOTS=4000000
  export RUBY_HEAP_SLOTS_INCREMENT=250000
  export RUBY_GC_MALLOC_LIMIT=500000000
  export RUBY_HEAP_SLOTS_GROWTH_FACTOR=1

  source /usr/local/share/chruby/chruby.sh
  source /usr/local/share/chruby/auto.sh
  export RB_VERSION=2.3.3
  chruby $RB_VERSION

  alias be='bundle exec'
  alias brspec='bundle exec rspec'
  alias bspec='bundle exec rspec'
  alias rs='rails server'
  alias rc='rails console'
  alias bi='bundle install'
  alias bl="bundle --local"
  alias bbs="bundle install --binstubs .bundle/bin"

# python
  export PYTHONDONTWRITEBYTECODE=1
  export PIP_DOWNLOAD_CACHE=$HOME/.pip/cache
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"

# node
  export NVM_DIR=~/.nvm
  . $(brew --prefix nvm)/nvm.sh --no-use

# docker
  alias d="docker"
  alias dc="docker-compose"
  alias dcr="docker-compose run --rm"
  function docker_cleanup {
    docker rm -f $(docker ps -a -q)
    docker images --all --format "{{.ID}}" | xargs docker rmi
    docker images --quiet --filter=dangling=true | xargs docker rmi
  }
  alias k="kubectl"
  function kpod {
    kubectl get pod --no-headers $@ | cut -d ' ' -f 1
  }

  function klog {
    for pod in $(kpod "${@:1:2}"); do
      kubectl logs -f $pod "${@:3}"
    done
  }

  function ksh {
    kubectl exec -it $(kpod "${@:1:2}") "${@:3}" bash
  }

  function ksc {
    local context=${1}
    if [[ -z "$context" ]]; then
      kubectl config get-contexts
    else
      kubectl config use-context ${context}
    fi
  }

  function kns {
    local namespace=${1}
    if [[ -z "$namespace" ]]; then
      kubectl get ns
    else
      local context=$(kubectl config current-context)
      kubectl config set-context ${context} --namespace ${namespace}
    fi
  }

  function kcapacity {
    for node in $(kubectl get no --no-headers | awk '$0 !~ /Disabled/ {print $1}'); do
      echo -n "Node ${node} - "
      kubectl describe no $node | grep -A4 'Allocated resources' | tail -n1 | awk '{print "CPU Requests " $1 " " $2 " Memory Requests: " $5 " " $6}'
    done
  }

# AWS
  export AWS_ACCOUNT_ID=$(aws ec2 describe-security-groups \
    --group-names 'Default' \
    --query 'SecurityGroups[0].OwnerId' \
    --output text)

# secrets file
  source ~/.secrets
