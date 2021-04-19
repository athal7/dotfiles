# basic
  export EDITOR="code"

# zsh
  export ZPLUG_HOME=/usr/local/opt/zplug
  source $ZPLUG_HOME/init.zsh
  HYPHEN_INSENSITIVE=true
  COMPLETION_WAITING_DOTS=true

# plugins
  fpath=(/usr/local/share/zsh/site-functions $fpath)
  zplug "plugins/autojump", from:oh-my-zsh
  zplug "plugins/docker", from:oh-my-zsh
  zplug "plugins/jsontools", from:oh-my-zsh
  zplug "plugins/osx", from:oh-my-zsh
  zplug "jhawthorn/fzy", \
    as:command, \
    rename-to:fzy, \
    hook-build:"make && sudo make install"
  zplug "dracula/zsh", as:theme

  if ! zplug check; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
  fi
  zplug load

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

# interactive cheatsheet
  source <(navi widget zsh)

# shell aliases
  alias cat='bat'
  alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"
  alias e=$EDITOR
  alias help='navi'
  alias less="less -R"
  alias lf="less +F"
  alias ll="ls -la"
  alias g='git'
  alias mkcd='mkdir $1 && cd $1'
  function mkcd {
     mkdir -p "$1" && cd "$1"
  }
  function move-last-download {
    local download_dir="${HOME}/Downloads/"
    local last_download="$(ls -t ${download_dir} | head -1)"
    local destination_file="${PWD}/${1:-${last_download}}"

    echo "MV: ${download_dir}${last_download}"
    echo "TO: ${destination_file}"

    mv "${download_dir}${last_download}" "${destination_file}"
  }
  alias tf='terraform'
  alias watch='watch '

# version management
  source /usr/local/opt/asdf/asdf.sh
  export PATH="$HOME/.asdf/shims:$PATH"

# ruby
  export ARCHFLAGS='-arch x86_64'
  export CC=gcc
  alias be='bundle exec'

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

  docker-compose -f ~/docker-compose.yml up -d

# aws
export PATH="/usr/local/opt/awscli@1/bin:$PATH"

# secrets file
  source ~/.secrets
