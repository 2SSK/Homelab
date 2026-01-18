---
created: 2026-01-18
tags: [homelab, dotfiles, bash, vim, stow]
aliases: ["dotfiles configuration", "bash setup", "vim config"]
---

# Homelab - Dotfiles Configuration

## Overview

Dotfiles managed via GNU Stow from `/opt/Homelab/dotfiles`.

Provides:

- **Bash** configuration with XDG compliance
- **Vim** configuration optimized for servers
- **FZF** integration with fuzzy search functions
- **Vi-mode** for command line editing

## Structure

```text
dotfiles/
├── bash/
│   ├── .bashrc                    → ~/.bashrc
│   └── .config/bash/              → ~/.config/bash/
│       ├── bashrc                 # Main configuration
│       ├── aliases.bash           # Command aliases
│       ├── prompt.bash            # Git-aware prompt
│       ├── keybinds.bash          # Vi-mode keybindings
│       ├── fzf.bash               # FZF configuration
│       └── functions/
│           ├── system.bash        # System utilities
│           └── utils.bash         # General utilities
└── vim/
    ├── .vimrc                     → ~/.vimrc
    └── .vim/                      → ~/.vim/
```

## Bash Features

### Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `cd ..` | Go up one directory |
| `...` | `cd ../..` | Go up two directories |
| `ll` | `ls -alF` or `eza -la` | Detailed listing |
| `la` | `ls -A` or `eza -a` | Show hidden files |
| `gs` | `git status -sb` | Short git status |
| `gp` | `git push` | Push to remote |
| `dps` | `docker ps` | List containers |
| `dc` | `docker compose` | Docker Compose |
| `reload` | `source ~/.bashrc` | Reload configuration |

### Functions

| Function | Description |
|----------|-------------|
| `mkcd <dir>` | Create directory and cd into it |
| `extract <file>` | Extract any archive format |
| `sysinfo` | Display system information |
| `psg <name>` | Process grep with header |
| `topmem [n]` | Top n memory consumers |
| `topcpu [n]` | Top n CPU consumers |
| `listening` | Show listening ports |
| `portcheck <port>` | Check if port is in use |
| `srestart <svc>` | Restart systemd service |
| `slogs <svc>` | View service logs |

### FZF Functions

> **Requires:** fzf installed (`sudo apt install fzf`)

| Function | Description |
|----------|-------------|
| `fcd` | Fuzzy cd into directory |
| `fe` | Fuzzy edit file |
| `fh` | Fuzzy search command history |

### Keybindings

Vi-mode enabled with:

| Key | Action |
|-----|--------|
| `jk` | Exit insert mode (like Escape) |
| `↑` / `↓` | History search with prefix |
| `Ctrl+L` | Clear screen |

## Vim Features

Server-optimized configuration:

- Relative + absolute line numbers
- Persistent undo (`~/.vim/undo/`)
- Smart search (case-insensitive unless uppercase)
- 4-space indentation
- No swap files (cleaner remote editing)

## Customization

### Local Overrides

Create `~/.config/bash/local.bash` for machine-specific settings:

```bash
# Not tracked in git
export MY_VAR="value"
alias myalias='my-command'
```

### Adding Packages

1. Create package directory in `dotfiles/`:

```bash
mkdir -p dotfiles/mypackage/.config/myapp
```

2. Add to `STOW_PACKAGES` in `cli/bootstrap/phases/dotfiles.sh`:

```bash
readonly STOW_PACKAGES=(bash vim mypackage)
```

3. Restow:

```bash
homelab dotfiles restow
```

## Management Commands

### Via CLI

```bash
homelab dotfiles stow      # Install symlinks
homelab dotfiles unstow    # Remove symlinks
homelab dotfiles restow    # Reinstall (after changes)
homelab dotfiles verify    # Check symlinks
homelab dotfiles status    # Show package status
```

### Via Make

```bash
make dotfiles              # Install
make dotfiles-unstow       # Remove
make dotfiles-restow       # Reinstall
make dotfiles-verify       # Verify
make dotfiles-status       # Status
```

## Backup

Existing files are backed up before stowing:

```text
~/.dotfiles_backup/YYYYMMDD_HHMMSS/
```

Restore manually if needed:

```bash
cp ~/.dotfiles_backup/*/bashrc ~/.bashrc
```
