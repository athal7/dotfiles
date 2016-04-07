# Mac OS X’s Terminal.app, runs a login shell by default for each new terminal window,
# calling .bash_profile instead of .bashrc
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi
