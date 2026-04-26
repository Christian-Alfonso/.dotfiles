#!/bin/bash

#
# setup-wsl.sh
#
# Script for automatically setting up a new WSL installation (assumes Ubuntu) to
# install and copy over the necessary configuration files for each program.
#

# Move to the path where the script is being run
cd $(wslpath -a "")

# Always update package lists first
sudo apt update

#
# Configure Git
#

# Even though this is a PowerShell script, it does NOT
# require PowerShell to be installed; see the file itself
# for the workaround being used here
sh .setup/setup-git.ps1

#
# Configure shell
#

YELLOW='\033[0;33m'
NC='\033[0m' # No Color
echo -e "${YELLOW}TYPE EXIT AT ZSH PROMPT TO CONTINUE SETUP${NC}"

# Install ZSH
sudo apt install zsh

# Install Oh My ZSH from their install script
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install additional ZSH plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Copy over ZSH configuration
cp -a .zsh/. ~

# Change default shell to ZSH
chsh -s /bin/zsh

# Install Tmux
sudo apt install tmux

# Copy over Tmux configuration
cp .tmux.conf ~/.tmux.conf

#
# Configure Neovim
#

# Install Neovim with dependencies
sudo sh .nvim/install-with-dependencies.sh

# Copy over Neovim configuration
mkdir ~/.config
mkdir ~/.config/nvim
cp -a .nvim/. ~/.config/nvim

# Install Oh-My-Posh from their example:
# https://ohmyposh.dev/docs/installation/linux#installation
sudo apt install unzip
curl -s https://ohmyposh.dev/install.sh | bash -s

# Copy over Oh-My-Posh configuration
cp theme-v2.omp.json ~/theme-v2.omp.json