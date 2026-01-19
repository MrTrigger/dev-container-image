# Dev Container Image

Arch Linux-based development container with common tools pre-installed.

## Included Tools

**Languages & Runtimes:**
- Rust (rustup, cargo-watch, sqlx-cli)
- Node.js (via fnm)
- Bun
- Python 3

**Editors & CLI:**
- Neovim with LazyVim
- Claude Code CLI
- lazygit

**Build Tools:**
- GCC, Clang, CMake, Ninja, Meson
- Make, autoconf, automake

**Utilities:**
- ripgrep, fd, fzf, jq, htop, tmux
- Docker CLI, PostgreSQL client
- SSH server, code-server (VS Code in browser)

## Usage

```yaml
image: ghcr.io/nebulatechsolutions/dev-container-image:latest
```

### Environment Variables

- `USER_PASSWORD` - Password for the `magnus` user (SSH login)
- `TZ` - Timezone (default: UTC)

### Volumes

- `/home/dev` - User home directory (persist tools and config)
- `/workspace` - Working directory

### Init Scripts

Mount scripts to `/init.d/*.sh` to run environment-specific setup at container start.

## Ports

- `22` - SSH
- `8080` - code-server (VS Code web)
