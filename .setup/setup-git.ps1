#!/bin/bash

# This is a dual PowerShell/bash script, since the same commands
# are used on both Windows and WSL. The configuration can be updated
# here and apply to both.
#
# This clever hack was discovered here:
# https://stackoverflow.com/questions/39421131/is-it-possible-to-write-one-script-that-runs-in-bash-shell-and-powershell

git config --global core.pager ''
git config --global core.editor 'nvim'
git config --global core.autocrlf 'false'