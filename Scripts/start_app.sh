#!/bin/sh

unset GIT_DIR

cd ~/Documents/Projects/$1
if [ "$2" == "noupdate" ] 
then
  echo "no update!"
  else
  git pull
  bundle --local
fi
uppertitle="$(tr [a-z] [A-Z] <<< "$1")"
echo -n -e "\033]0;$uppertitle\007"
foreman start
