# Configuration Files or ".dotfiles"

This repository contains my own personal configuration files (or "dotfiles,"
because of the leading "." on the directories, which indicates a hidden filepath
in UNIX and open source applications) for various applications that I use.

## Table of Contents

- [.nvim](#nvim---neovim)
- [.vscode](#vscode---visual-studio-code)
- [.wt](#wt---windows-terminal)
- [.tmux.conf](#tmuxconf---tmux)

## `.nvim` - Neovim

| Path               | Location                                |
| ------------------ | --------------------------------------- |
| Folder/File        | [.nvim](.nvim/)                         |
| Location (Windows) | `"%LocalAppData%/nvim"`                 |
| Location (Linux)   | `"$HOME/.config/nvim"`                  |
| Documentation      | <https://neovim.io/doc/user/index.html> |

Configuration files for the Neovim editor - see README in that repository for
more information on setup and dependencies.

## `.vscode` - Visual Studio Code

| Path               | Location                                                 |
| ------------------ | -------------------------------------------------------- |
| Folder/File        | [.vscode](.vscode/)                                      |
| Location (Windows) | `"%AppData%\Code\User\settings.json"`                    |
| Location (Linux)   | `"$HOME/.config/Code/User/settings.json"`                |
| Documentation      | <https://code.visualstudio.com/docs/getstarted/settings> |

Configuration files for the Visual Studio Code editor. Settings are backed up to
the cloud, and should sync on sign-in.

Requires the DroidSansM Nerd Font from
[Nerd Fonts](https://www.nerdfonts.com/font-downloads) (which can be installed
through
[Oh My Posh's font installer](https://ohmyposh.dev/docs/installation/fonts)).

## `.wt` - Windows Terminal

| Path               | Location                                                                                     |
| ------------------ | -------------------------------------------------------------------------------------------- |
| Folder/File        | [.wt](.wt/)                                                                                  |
| Location (Windows) | `"%LocalAppData%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"` |
| Location (Linux)   | -                                                                                            |
| Documentation      | <https://learn.microsoft.com/en-us/windows/terminal/>                                        |

Configuration files for Windows Terminal.

## `.tmux.conf` - Tmux

| Path               | Location                            |
| ------------------ | ----------------------------------- |
| Folder/File        | [.tmux.conf](.tmux.conf)            |
| Location (Windows) | -                                   |
| Location (Linux)   | "$HOME/.tmux.conf"                  |
| Documentation      | <https://github.com/tmux/tmux/wiki> |

Configuration files for Tmux.

Tmux is not available for Windows, so use WSL with Windows Terminal
configuration to start normal PowerShell and other shells through Tmux in WSL.
Configuration assumes version greater than 3.2 for Tmux, and that the default
shell is Bash.
