.DEFAULT_GOAL := install

dotfiles = .ackrc \
				.asdfc \
				.fzf.zsh \
				.gitconfig \
				.gitignore_global \
				.hyper.js \
				.irbrc \
				.prompt.sh \
				.tmux \
				.tmux.conf \
				.vim \
				.vimrc \
				.zshrc

install: symlink submodules packages shell vim languages other

symlink:
	for file in $(dotfiles); do \
		rm -rf ~/$$file ;\
		ln -s $(shell pwd)/$$file ~/$$file ;\
	done

submodules:
	git submodule update --init ;\
  git submodule sync

packages:
	brew bundle

shell:
	chsh -s /bin/zsh

vim:
	mkdir -p ~/.config/nvim ;\
	rm -rf ~/.config/nvim/init.vim ;\
	ln -s $(shell pwd)/.init.vim ~/.config/nvim/init.vim ;\
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

languages:
	asdf install

other:
	defaults write com.apple.screencapture location ~/Downloads;killall SystemUIServer ;\
  defaults write com.apple.finder AppleShowAllFiles TRUE;killall Finder
