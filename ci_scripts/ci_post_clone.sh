#!/bin/sh

# Set the -e flag to stop running the script in case a command returns
# a non-zero exit code.
set -e

# Allow usage of macros
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Work around Xcode Cloud "Unable to resolve module dependency" errors for
# SwiftSyntax-based macro plugins (swift-perception, swift-dependencies,
# swift-composable-architecture, swift-case-paths, app-remote-config) by
# disabling explicit module builds for this build session.
defaults write com.apple.dt.Xcode IDEBuildingExplicitModules -bool NO
