#!/bin/bash

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

# Install Neovim from their example:
# https://github.com/neovim/neovim/blob/master/INSTALL.md#pre-built-archives-2
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
sudo rm nvim-linux-x86_64.tar.gz

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