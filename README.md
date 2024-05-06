# Configuration Files or ".dotfiles"
This repository contains my own personal configuration files (or "dotfiles," because of the leading "." on the directories, which indicates a hidden filepath in UNIX and open source applications) for various applications that I use.

## .nvim - Neovim

Configuration files for the Neovim editor - see README in that repository for more information on setup and dependencies.

Documentation can be found at https://neovim.io/doc/user/index.html.

Location:
<details>
<summary>Windows</summary>
"%LocalAppData%\nvim"
</details>
<details>
<summary>Linux</summary>
"$HOME/.config/nvim"
</details>

## .vscode - Visual Studio Code

Configuration files for the Visual Studio Code editor. Settings are backed up to the cloud, and should sync on sign-in.

Requires the [Apc Customize UI++](https://marketplace.visualstudio.com/items?itemName=drcika.apc-extension) extension to
be able to additional UI customization, and DroidSansM Nerd Font from [Nerd Fonts](https://www.nerdfonts.com/font-downloads)
(which can be installed through [Oh My Posh's font installer](https://ohmyposh.dev/docs/installation/fonts)).

Documentation can be found at https://code.visualstudio.com/docs/getstarted/settings.

Location:
<details>
<summary>Windows</summary>
"%AppData%\Code\User\settings.json"
</details>
<details>
<summary>Linux</summary>
"$HOME/.config/Code/User/settings.json"
</details>

## .wt - Windows Terminal

Configuration files for Windows Terminal.

Documentation can be found at https://code.visualstudio.com/docs/getstarted/settings.

Location:
<details>
<summary>Windows</summary>
"%LocalAppData%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
</details>

## .tmux.conf - Tmux

Configuration files for Tmux.

Tmux documentation is limited, but is available at its repository on GitHub at https://github.com/tmux/tmux/wiki.

Tmux is not available for Windows, so use WSL with Windows Terminal configuration to start normal PowerShell
through Tmux in WSL. Configuration assumes version greater than 3.2 for Tmux, and that the default shell is
Bash.

Location:
<details>
<summary>Linux</summary>
"$HOME/.tmux.conf"
</details>
