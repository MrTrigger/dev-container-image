#!/bin/bash
set -e

echo "=== Dev Container Starting ==="

# Set user password if provided
if [ -n "$USER_PASSWORD" ]; then
    echo "magnus:$USER_PASSWORD" | chpasswd
    echo "Password set for magnus user"
fi

# Fix home directory ownership (for mounted volumes)
chown -R magnus:magnus /home/magnus 2>/dev/null || true

# Persist SSH host keys on the volume (prevents host key change warnings)
SSH_KEY_DIR="/home/magnus/.ssh-host-keys"
if [ ! -d "$SSH_KEY_DIR" ]; then
    echo "Generating persistent SSH host keys..."
    mkdir -p "$SSH_KEY_DIR"
    ssh-keygen -A
    cp /etc/ssh/ssh_host_* "$SSH_KEY_DIR/"
    chown -R root:root "$SSH_KEY_DIR"
    chmod 600 "$SSH_KEY_DIR"/*_key
    chmod 644 "$SSH_KEY_DIR"/*.pub
else
    echo "Using persisted SSH host keys..."
    cp "$SSH_KEY_DIR"/ssh_host_* /etc/ssh/
fi

# Ensure .zshrc exists with required config (handles persistent volume overwrite)
# Check for 'alias ll' as marker - this ensures we update when adding new aliases
if [ ! -f /home/magnus/.zshrc ] || ! grep -q "alias ll=" /home/magnus/.zshrc 2>/dev/null; then
    echo "Setting up .zshrc..."
    cp /etc/skel/.zshrc /home/magnus/.zshrc
    chown magnus:magnus /home/magnus/.zshrc
fi

# Ensure .zprofile exists (sources .zshrc for login shells like SSH)
if [ ! -f /home/magnus/.zprofile ]; then
    echo "Setting up .zprofile..."
    cp /etc/skel/.zprofile /home/magnus/.zprofile
    chown magnus:magnus /home/magnus/.zprofile
fi

# Ensure starship config exists
if [ ! -f /home/magnus/.config/starship.toml ] && [ -f /etc/skel/.config/starship.toml ]; then
    mkdir -p /home/magnus/.config
    cp /etc/skel/.config/starship.toml /home/magnus/.config/starship.toml
    chown -R magnus:magnus /home/magnus/.config
fi

# Ensure fnm and Node.js are installed (handles persistent volume overwrite)
if [ ! -f /home/magnus/.local/share/fnm/fnm ]; then
    echo "Installing fnm and Node.js..."
    su - magnus -c '
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env)"
        fnm install --lts
        fnm default lts-latest
    '
fi

# Fix fnm aliases if they point to old /config/ path (from linuxserver image)
FNM_ALIASES="/home/magnus/.local/share/fnm/aliases"
if [ -d "$FNM_ALIASES" ] && ls -la "$FNM_ALIASES" 2>/dev/null | grep -q "/config/"; then
    echo "Fixing fnm aliases..."
    rm -f "$FNM_ALIASES"/*
    NODE_VERSION=$(ls /home/magnus/.local/share/fnm/node-versions/ 2>/dev/null | head -1)
    if [ -n "$NODE_VERSION" ]; then
        ln -sf "/home/magnus/.local/share/fnm/node-versions/$NODE_VERSION/installation" "$FNM_ALIASES/default"
    fi
    rm -rf /home/magnus/.local/state/fnm_multishells/* 2>/dev/null || true
fi

# Ensure Claude Code is installed
if ! su - magnus -c 'source ~/.zshrc 2>/dev/null; fnm use default 2>/dev/null; which claude' >/dev/null 2>&1; then
    echo "Installing Claude Code..."
    su - magnus -c 'source ~/.zshrc; fnm use default 2>/dev/null; npm install -g @anthropic-ai/claude-code' || true
fi

# Run any environment-specific init scripts
if [ -d /init.d ] && [ "$(ls -A /init.d 2>/dev/null)" ]; then
    echo "Running init scripts..."
    for script in /init.d/*.sh; do
        if [ -x "$script" ]; then
            echo "  Running: $script"
            "$script"
        fi
    done
fi

echo "=== Dev Container Ready ==="
echo "User: magnus (shell: zsh)"

# Start SSH daemon
/usr/sbin/sshd -D &
echo "SSH daemon started"

# Start code-server as magnus user
echo "Starting code-server..."
exec su - magnus -c 'code-server --bind-addr 0.0.0.0:8080 --auth none'
