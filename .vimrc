" bring in the bundles for mac and windows
set rtp+=~/.vim/vundle/
call vundle#rc()

runtime! common_config/*.vim
runtime! custom_config/*.vim
