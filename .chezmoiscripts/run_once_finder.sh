#!/bin/bash
defaults write com.apple.screencapture location ~/Downloads
killall SystemUIServer
defaults write com.apple.finder AppleShowAllFiles -boolean true
killall Finder
