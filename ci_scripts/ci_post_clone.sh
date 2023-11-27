#!/bin/sh

# Set the -e flag to stop running the script in case a command returns
# a non-zero exit code.
set -e

# Allow usage of macros
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
