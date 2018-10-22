# zsh
  export ZSH=$HOME/.oh-my-zsh
  HYPHEN_INSENSITIVE=true
  COMPLETION_WAITING_DOTS=true

# plugins
  plugins=(autojump docker jsontools osx tmux zsh-completions)
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
  export EDITOR="nvim"

  BLACK="\033[0;30m"
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  DARKBLUE="\033[0;34m"
  PINK="\033[0;35m"
  BLUE="\033[0;36m"
  WHITE="\033[1;37m"
  OFF="\033[0m"

# color for man pages
  export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
  export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
  export LESS_TERMCAP_me=$'\E[0m'           # end mode
  export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
  export LESS_TERMCAP_so=$'\E[1;31m'        # begin standout-mode - info box
  export LESS_TERMCAP_ue=$'\E[0m'           # end underline
  export LESS_TERMCAP_us=$'\E[04;33;5;146m' # begin underline

# shell aliases
  alias cat='bat'
  alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"
  alias e=$EDITOR
  alias help='tldr'
  alias less="less -R"
  alias lf="less +F"
  alias lg='lazygit'
  alias ll="ls -la"
  alias g='hub'
  alias mkcd='mkdir $1 && cd $1'
  function mkcd {
     mkdir -p "$1" && cd "$1"
  }
  alias watch='watch '

# homebrew
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

# version management
  source /usr/local/opt/asdf/asdf.sh
  source /usr/local/etc/bash_completion.d


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

# go
  export GOPATH="$HOME/go"
  export PATH="$HOME/go/bin:$PATH"

# elixir
  export PATH="$HOME/.mix/escripts:$PATH"

# docker
  alias d="docker"
  alias dc="docker-compose"
  alias dcr="docker-compose run --rm"
  alias docker_cleanup="docker system prune"
  alias k="kubectl"
  alias klog="kubetail"
  function kpod {
    kubectl get pod --no-headers $@ | cut -d ' ' -f 1
  }

  function ksh {
    local pod=$(kpod "${@:1:2}")
    shift
    shift
    if [ $# -lt 1 ]; then
      kubectl exec -it $pod bash
    else
      kubectl exec -it $pod -- $*
    fi
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

# secrets file
  source ~/.secrets
