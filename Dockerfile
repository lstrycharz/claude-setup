FROM ubuntu:22.04

# Minimum runtime deps for claude-setup: bash, node, git, curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      git \
      nodejs \
      curl \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Non-root user so we test under realistic permissions
RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /home/tester/claude-setup

# Copy repo
COPY --chown=tester:tester . .

# Ensure scripts are executable (.gitignore or git attrs might not preserve +x)
RUN chmod +x install.sh test.sh uninstall.sh bin/init-claude hooks/*.mjs

CMD ["./test.sh"]
