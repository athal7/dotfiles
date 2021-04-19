.DEFAULT_GOAL := install

dotfiles = .ackrc \
				.asdfrc \
        .default-npm-packages \
				.gitconfig \
				.gitignore_global \
				.prettierrc \
				.tool-versions \
				.zshrc \
				docker-compose.yml

install: symlink packages shell languages other

echo.%:
	@echo "\n`tput smso`Building $*`tput rmso`"

symlink: echo.symlink
	@for file in $(dotfiles); do \
		rm -rf ~/$$file ;\
		ln -s $(shell pwd)/$$file ~/$$file ;\
	done

packages: echo.packages
	brew bundle

shell: echo.shell
	chsh -s /bin/zsh
	
sudoauth: echo.sudoauth
	(echo "auth sufficient pam_tid.so"; sudo cat /etc/pam.d/sudo) >tmpfile ;\
  sudo cp tmpfile /etc/pam.d/sudo ;\
  rm tmpfile

languages: echo.languages
	asdf install

other: echo.other
	defaults write com.apple.screencapture location ~/Downloads;killall SystemUIServer ;\
  defaults write com.apple.finder AppleShowAllFiles TRUE;killall Finder