#!/bin/bash
set -e

# Sill reads these at launch; changes in its UI remain until this script changes.
# Leave pairing, device history, permissions, and other preferences under Sill's control.
defaults write me.saffer.sill.mac remoteAccess -bool true
defaults write me.saffer.sill.mac directWireless -bool false
defaults write me.saffer.sill.mac showPairingWindowToScreenSharing -bool false
