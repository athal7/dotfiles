export DOTFILE_DIR=$(dirname $(readlink $BASH_SOURCE))
source ~/.bashrc # machine specific

source $DOTFILE_DIR/bash_profile_helpers/.colors

source $DOTFILE_DIR/bash_profile_helpers/.aliases
source $DOTFILE_DIR/bash_profile_helpers/.autojump
source $DOTFILE_DIR/bash_profile_helpers/.git_completion
source $DOTFILE_DIR/bash_profile_helpers/.js
source $DOTFILE_DIR/bash_profile_helpers/.prompt
source $DOTFILE_DIR/bash_profile_helpers/.ruby
