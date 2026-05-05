#!/bin/bash

#
# setup-wsl-arch.sh
#
# Script for automatically setting up a new WSL installation (Arch Linux) to
# install and copy over the necessary configuration files for each program.
#

# Move to the path where the script is being run
cd $(wslpath -a "")

# Always sync package databases and upgrade first
pacman -Syu --noconfirm || exit 1

#
# Configure Git
#

# Git does not come with Arch by default, so it needs to be installed first thing
pacman -S --noconfirm git || exit 1

# Even though this is a PowerShell script, it does NOT
# require PowerShell to be installed; see the file itself
# for the workaround being used here
.setup/setup-git.ps1

#
# Configure shell
#

YELLOW='\033[0;33m'
NC='\033[0m' # No Color
echo -e "${YELLOW}TYPE EXIT AT ZSH PROMPT TO CONTINUE SETUP${NC}"

# Install ZSH
pacman -S --noconfirm zsh || exit 1

# Install Oh My ZSH from their install script
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install additional ZSH plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Copy over ZSH configuration
cp -a .zsh/. ~

# Change default shell to ZSH
chsh -s "$(command -v zsh)" || exit 1

# Install Tmux
pacman -S --noconfirm tmux || exit 1

# Copy over Tmux configuration
cp .tmux.conf ~/.tmux.conf

#
# Configure Neovim
#

# Install Neovim with dependencies
.nvim/install-with-dependencies-arch.sh || exit 1

# Copy over Neovim configuration
mkdir ~/.config
mkdir ~/.config/nvim
cp -a .nvim/. ~/.config/nvim

# Install Oh-My-Posh from their example:
# https://ohmyposh.dev/docs/installation/linux#installation
pacman -S --noconfirm unzip || exit 1
curl -s https://ohmyposh.dev/install.sh | bash -s

# Copy over Oh-My-Posh configuration
cp theme-v2.omp.json ~/theme-v2.omp.json

echo "Arch Linux WSL setup complete!"