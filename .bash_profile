export DOTFILE_DIR=$(dirname $(readlink $BASH_SOURCE))
source ~/.bashrc # machine specific
source $DOTFILE_DIR/bash_profile_helpers/.ruby_settings
source $DOTFILE_DIR/bash_profile_helpers/.terminal_color_settings
source $DOTFILE_DIR/bash_profile_helpers/.bash_prompt
source $DOTFILE_DIR/bash_profile_helpers/.git_completion
source $DOTFILE_DIR/bash_profile_helpers/.aliases
source $DOTFILE_DIR/bash_profile_helpers/.man_color
source $DOTFILE_DIR/bash_profile_helpers/.git_object_size
source $DOTFILE_DIR/bash_profile_helpers/.node_settings
source $DOTFILE_DIR/bash_profile_helpers/.autojump
