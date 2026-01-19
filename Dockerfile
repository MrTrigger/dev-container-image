FROM archlinux:latest

# System packages
RUN pacman -Syu --noconfirm --needed \
    base-devel \
    git \
    openssh \
    curl \
    wget \
    tmux \
    htop \
    jq \
    unzip \
    neovim \
    iputils \
    bind \
    net-tools \
    iproute2 \
    traceroute \
    openbsd-netcat \
    ca-certificates \
    gnupg \
    python \
    python-pip \
    ripgrep \
    fd \
    fzf \
    tree \
    less \
    vim \
    nano \
    zip \
    gzip \
    tar \
    rsync \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    clang \
    lldb \
    gdb \
    valgrind \
    ninja \
    meson \
    ccache \
    protobuf \
    sudo \
    which \
    man-db \
    man-pages \
    docker \
    docker-compose \
    postgresql \
    && pacman -Scc --noconfirm

# Create dev user (uid 1000)
RUN useradd -m -u 1000 -s /bin/bash -G wheel,docker dev \
    && echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# SSH setup
RUN ssh-keygen -A \
    && mkdir -p /run/sshd \
    && echo -e "PermitRootLogin no\nPasswordAuthentication yes\nAllowUsers dev" > /etc/ssh/sshd_config.d/dev-container.conf

# Install code-server
RUN CODE_SERVER_VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') \
    && curl -fL "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz" -o /tmp/code-server.tar.gz \
    && tar -xzf /tmp/code-server.tar.gz -C /opt \
    && ln -sf /opt/code-server-*/bin/code-server /usr/local/bin/code-server \
    && rm /tmp/code-server.tar.gz

# Install lazygit
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') \
    && curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit \
    && rm /tmp/lazygit.tar.gz

# Switch to dev user for user-level installs
USER dev
WORKDIR /home/dev

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . ~/.cargo/env \
    && rustup component add rust-analyzer clippy rustfmt

# Install cargo tools
RUN . ~/.cargo/env && cargo install cargo-watch sqlx-cli

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Install fnm and Node.js
RUN curl -fsSL https://fnm.vercel.app/install | bash \
    && export PATH="$HOME/.local/share/fnm:$PATH" \
    && eval "$(fnm env)" \
    && fnm install --lts \
    && fnm default lts-latest

# Install Claude Code
RUN export PATH="$HOME/.local/share/fnm:$PATH" \
    && eval "$(fnm env)" \
    && npm install -g @anthropic-ai/claude-code

# Install LazyVim
RUN git clone https://github.com/LazyVim/starter ~/.config/nvim \
    && rm -rf ~/.config/nvim/.git

# Setup bashrc
RUN cat >> ~/.bashrc << 'BASHRC'

# Dev container config
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env)" 2>/dev/null || true

export PATH="$HOME/.local/bin:$PATH"

alias vim='nvim'
alias vi='nvim'
alias lg='lazygit'
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'

source /usr/share/fzf/key-bindings.bash 2>/dev/null || true
source /usr/share/fzf/completion.bash 2>/dev/null || true

cd /workspace 2>/dev/null || true
BASHRC

# Back to root for entrypoint
USER root

# Create init.d directory for environment-specific scripts
RUN mkdir -p /init.d

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 8080

ENTRYPOINT ["/entrypoint.sh"]
