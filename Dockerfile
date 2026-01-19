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
    eza \
    bat \
    starship \
    sops \
    age \
    go-task \
    zsh \
    && pacman -Scc --noconfirm

# Create magnus user (uid 1000)
RUN useradd -m -u 1000 -s /bin/bash -G wheel,docker magnus \
    && echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# SSH setup
RUN ssh-keygen -A \
    && mkdir -p /run/sshd \
    && echo -e "PermitRootLogin no\nPasswordAuthentication yes\nAllowUsers magnus" > /etc/ssh/sshd_config.d/magnus-container.conf

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

# Switch to magnus user for user-level installs
USER magnus
WORKDIR /home/magnus

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

# Environment
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.local/share/fnm:$HOME/.local/bin:$PATH"
eval "$(fnm env)" 2>/dev/null || true

# Editors
alias vim='nvim'
alias vi='nvim'
alias v='nvim'
alias vf='nvim $(fzf --height 40% --layout reverse --preview "bat --style=numbers --color=always {} | head -500")'

# Git
alias lg='lazygit'
alias gst='git status'
alias gco='git checkout'
alias gpl='git pull'
alias gps='git push'
alias gd='git diff'
alias gdc='git diff --cached'
alias gl='git log --oneline --graph --decorate'

# Kubernetes
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'

# Claude
alias cl='claude --dangerously-skip-permissions'

# Tools
alias tree='eza --tree --icons'
alias tree2='eza --tree --icons --level=2'
alias tree3='eza --tree --icons --level=3'
alias cat='bat'
alias grep='grep --color'
alias rg='rg --smart-case'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'

# FZF functions
fcd() { local dir; dir=$(fd --type d --hidden --follow --exclude .git . "${1:-.}" | fzf --height 40% --layout=reverse --preview 'eza -al --icons --color=always {}') && cd "$dir"; }
ff() { local file; file=$(fd --type f --hidden --follow --exclude .git . "${1:-.}" | fzf --height 80% --layout=reverse --preview 'bat --style=numbers --color=always --line-range :500 {}'); [[ -n "$file" ]] && ${EDITOR:-nvim} "$file"; }
fkill() { local pid; pid=$(ps aux | sed 1d | fzf -m --height 40% --layout=reverse | awk '{print $2}'); [[ -n "$pid" ]] && echo $pid | xargs kill -${1:-9}; }
gcb() { local branch; branch=$(git branch -a | grep -v HEAD | fzf --height 40% --layout=reverse | sed 's/.* //' | sed 's#remotes/[^/]*/##'); [[ -n "$branch" ]] && git checkout "$branch"; }

source /usr/share/fzf/key-bindings.bash 2>/dev/null || true
source /usr/share/fzf/completion.bash 2>/dev/null || true

# Starship prompt
eval "$(starship init bash)"

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
