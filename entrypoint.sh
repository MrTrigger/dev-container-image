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

# Ensure .zshrc exists with required config (handles persistent volume overwrite)
if [ ! -f /home/magnus/.zshrc ] || ! grep -q "starship init zsh" /home/magnus/.zshrc 2>/dev/null; then
    echo "Setting up .zshrc..."
    cp /etc/skel/.zshrc /home/magnus/.zshrc
    chown magnus:magnus /home/magnus/.zshrc
fi

# Ensure starship config exists
if [ ! -f /home/magnus/.config/starship.toml ] && [ -f /etc/skel/.config/starship.toml ]; then
    mkdir -p /home/magnus/.config
    cp /etc/skel/.config/starship.toml /home/magnus/.config/starship.toml
    chown -R magnus:magnus /home/magnus/.config
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
exec su - magnus -c 'code-server --bind-addr 0.0.0.0:8080 --auth none /workspace'
