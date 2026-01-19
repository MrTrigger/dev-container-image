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
echo "User: magnus (home=/home/magnus)"

# Start SSH daemon
/usr/sbin/sshd -D &
echo "SSH daemon started"

# Start code-server as magnus user
echo "Starting code-server..."
exec su - magnus -c 'code-server --bind-addr 0.0.0.0:8080 --auth none /workspace'
