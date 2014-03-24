## athal7's dotfiles

### Includes:
  - Vim configs adapted from [Neo's Vim Configs](https://github.com/neo/vim-config) (view their readme for installation/basic key mappings)
  - VPN opening AppleScript adapted from [webandy](https://github.com/webandy/applescripts)
  - Tmux configs adapted from [tmux: Productive Mouse-Free Development](http://pragprog.com/book/bhtmux/tmux)
  - Custom git aliases
  - [Git completion](https://github.com/git/git/blob/master/contrib/completion/git-completion.bash)
  - copy and paste to/from OSX clipboard in terminal vim (requires mvim as default terminal editor and `reattach-to-user-namespace` homebrew formula if using tmux)
  - Custom bash prompt
  - [autojump](https://github.com/joelthelion/autojump/wiki)
  - ctags setup using http://tbaggery.com/2011/08/08/effortless-ctags-with-git.html
  - Sourcing of machine-specific .bashrc
  - Ruby / Rails server and console helpers
  - Window arrangement script
  - Other bash aliases

Feel free to use these dotfiles as you wish, and also feel free to submit pull requests for anything you'd like to improve.
Keep in mind these configs update frequently.

### To install
* clone the repo
* copy the files to your home directory
* `source ~/.bash_profile`
* `brew install autojump macvim git bash-completion reattach-to-user-namespace tmux`
* `gem install tmuxinator`
* `cd vim-config && rake`
* `vi .` then `:BundleInstall`, then `:q` to exit
