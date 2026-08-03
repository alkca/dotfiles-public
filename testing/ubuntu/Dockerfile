# Ubuntu Docker container for testing chezmoi dotfiles
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base dependencies required for chezmoi and testing
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    file \
    git \
    procps \
    sudo \
    ca-certificates \
    lsb-release \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

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
