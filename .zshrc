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
  
# version management
  source /usr/local/opt/asdf/asdf.sh
  export PATH="$HOME/.asdf/shims:$PATH"

# ruby
  export ARCHFLAGS='-arch x86_64'
  export CC=gcc

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

# mac only aliases
  alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"
  alias tf='terraform'
  alias watch='watch '

# aliases for compat with codespaces
  source ~/.bash_aliases

# secrets file
  source ~/.secrets
