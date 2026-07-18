# node:22 base, NOT ubuntu+apt-nodejs: Ubuntu 22.04's archive nodejs is v12,
# which can't parse the hooks (optional chaining) — every hook would exit 1 with
# a SyntaxError, which Claude Code treats as non-blocking, silently disabling
# the whole protection layer (#8). The image must match a supported runtime.
FROM node:22-bookworm-slim

# Remaining runtime deps for claude-setup: git, curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
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
