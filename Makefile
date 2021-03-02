.DEFAULT_GOAL := install

dotfiles = .ackrc \
				.asdfrc \
        .default-npm-packages \
        .default-python-packages \
				.finicky.js \
				.fzf.zsh \
				.gitconfig \
				.gitignore_global \
				.hyper.js \
				.prettierrc \
				.prompt.sh \
				.tmux \
				.tmux.conf \
				.tool-versions \
				.vim \
				.vimrc \
				.zshrc \
				docker-compose.yml

install: symlink submodules packages shell sudoauth vim languages other

cyan = "\\033[1\;96m"
off  = "\\033[0m"
echo.%:
	@echo "\n$(cyan)Building $*$(off)"

symlink: echo.symlink
	@for file in $(dotfiles); do \
		rm -rf ~/$$file ;\
		ln -s $(shell pwd)/$$file ~/$$file ;\
	done

submodules: echo.submodules
	git submodule update --init ;\
  git submodule sync

packages: echo.packages
	brew bundle

shell: echo.shell
	chsh -s /bin/zsh
	
sudoauth: echo.sudoauth
	(echo "auth sufficient pam_tid.so"; sudo cat /etc/pam.d/sudo) >tmpfile ;\
  sudo cp tmpfile /etc/pam.d/sudo ;\
  rm tmpfile

vim: echo.vim
	mkdir -p ~/.config/nvim ;\
	rm -rf ~/.config/nvim/init.vim ;\
	ln -s $(shell pwd)/.init.vim ~/.config/nvim/init.vim ;\
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

languages: echo.languages
	asdf install

other: echo.other
	defaults write com.apple.screencapture location ~/Downloads;killall SystemUIServer ;\
  defaults write com.apple.finder AppleShowAllFiles TRUE;killall Finder