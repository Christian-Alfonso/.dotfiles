#!/bin/bash

# Move to the path where the script is being run
cd $(wslpath -a "")

# Always update package lists first
sudo apt update

#
# Configure shell
#

# Install ZSH
sudo apt install zsh

# Install Oh My ZSH from their install script
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Copy over ZSH configuration
cp -a .zsh/. ~

# Change default shell to ZSH
chsh -s /bin/zsh

# Install Tmux
sudo apt install tmux

# Copy over Tmux configuration
cp .tmux.conf ~

#
# Configure Neovim
#

# Install Neovim from their example:
# https://github.com/neovim/neovim/blob/master/INSTALL.md#pre-built-archives-2
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

# Copy over Neovim configuration
mkdir ~/.config/nvim
cp -a .nvim/. ~/.config/nvim
