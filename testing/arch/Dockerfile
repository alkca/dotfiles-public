# Arch Linux Docker container for testing chezmoi dotfiles
FROM archlinux:latest

# Update package database and install base dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    curl \
    file \
    git \
    procps-ng \
    sudo \
    ca-certificates \
    vim \
    wget \
    unzip \
    && pacman -Scc --noconfirm

# Create a test user with sudo privileges
RUN useradd -m -s /bin/bash testuser && \
    echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Install chezmoi
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /home/testuser/bin

# Add chezmoi to PATH
ENV PATH="/home/testuser/bin:$PATH"

# Set up git config (required for chezmoi)
RUN git config --global user.name "Test User" && \
    git config --global user.email "test@example.com" && \
    git config --global init.defaultBranch main

# Copy only the test runner from the allowlisted Docker build context
COPY --chown=testuser:testuser test-chezmoi.sh /home/testuser/test-chezmoi.sh
RUN chmod +x /home/testuser/test-chezmoi.sh

# Set default command
CMD ["/home/testuser/test-chezmoi.sh"]
