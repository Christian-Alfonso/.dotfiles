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
sudo pacman -Syu --noconfirm || exit 1

#
# Configure Git
#

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
sudo pacman -S --noconfirm zsh || exit 1

# Install Oh My ZSH from their install script
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install additional ZSH plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Copy over ZSH configuration
cp -a .zsh/. ~

# Change default shell to ZSH
# Retry on authentication failure; exit on any other error
echo -n "Password: "
until chsh_error=$(chsh -s $(which zsh) 2>&1); do
    if echo "$chsh_error" | grep -qi "authentication\|pam\|sorry\|incorrect"; then
        echo -e "${YELLOW}Incorrect password, please try again${NC}"

        # Reshow prompt on password failure
        echo -n "Password: "
    else
        echo "Failed to change shell: $chsh_error" >&2
        exit 1
    fi
done

# Install Tmux
sudo pacman -S --noconfirm tmux || exit 1

# Copy over Tmux configuration
cp .tmux.conf ~/.tmux.conf

#
# Configure Neovim
#

# Install Neovim with dependencies
# Note: .nvim/install-with-dependencies.sh also needs to be updated in the
# .nvim submodule to replace apt package installs (fd-find, ripgrep,
# build-essential, clang) with their pacman equivalents (fd, ripgrep,
# base-devel, clang). The tarball, Rust, and CMake installs are unaffected.
sudo .nvim/install-with-dependencies.sh || exit 1

# Copy over Neovim configuration
mkdir ~/.config
mkdir ~/.config/nvim
cp -a .nvim/. ~/.config/nvim

# Install Oh-My-Posh from their example:
# https://ohmyposh.dev/docs/installation/linux#installation
sudo pacman -S --noconfirm unzip || exit 1
curl -s https://ohmyposh.dev/install.sh | bash -s

# Copy over Oh-My-Posh configuration
cp theme-v2.omp.json ~/theme-v2.omp.json
