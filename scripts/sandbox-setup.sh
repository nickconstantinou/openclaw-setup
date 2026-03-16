#!/usr/bin/env bash
# scripts/sandbox-setup.sh
# 
# @intent Build the minimal Docker image for OpenClaw sandbox execution.
# @complexity 1
#

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use the same actual user resolution pattern if available, or default to current
if [[ -n "${ACTUAL_USER:-}" ]]; then
    TARGET_USER="$ACTUAL_USER"
else
    # Fallback to SUDO_USER or current user
    TARGET_USER="${SUDO_USER:-$(whoami)}"
fi

echo "Building OpenClaw Sandbox image: openclaw-sandbox:bookworm-slim..."

# Install seccomp profile
SECCOMP_DEST="/etc/docker/seccomp/openclaw-sandbox.json"
echo "Installing seccomp profile to $SECCOMP_DEST..."
if sudo mkdir -p /etc/docker/seccomp && sudo cp "$SCRIPT_DIR/../templates/seccomp-sandbox.json" "$SECCOMP_DEST"; then
    sudo chmod 644 "$SECCOMP_DEST"
    echo "✅ Seccomp profile installed."
else
    echo "WARNING: [SEC-005] Could not write seccomp profile to $SECCOMP_DEST. Docker will use default profile." >&2
fi

# Check if docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Please install Docker first." >&2
    exit 1
fi

# Check permissions/daemon
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to Docker daemon. Is it running? Does user '$TARGET_USER' have permissions?" >&2
    exit 1
fi

TEMP_DIR=$(mktemp -d /tmp/openclaw-sandbox-XXXXXX)

# Cleanup trap
trap 'rm -rf "$TEMP_DIR"' EXIT

# Create Dockerfile
cat > "$TEMP_DIR/Dockerfile" << 'EOF'
FROM debian:bookworm-slim

# Install essential tools for agent execution + Playwright deps + Pandoc/FFmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    git nodejs npm python3 python3-pip python3-venv bash curl jq \
    libgbm1 libnss3 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libasound2 \
    pandoc texlive-xetex poppler-utils ffmpeg sqlite3 \
    gnupg apt-transport-https ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud CLI
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# Install gws as a native Rust binary (bypasses npm JS shim + /usr/bin/env shebang issue)
RUN GWS_ARCH=$(dpkg --print-architecture | sed 's/amd64/x86_64/;s/arm64/aarch64/') \
 && GWS_VER=$(curl -fsSL https://api.github.com/repos/googleworkspace/cli/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4) \
 && curl -fsSL \
      "https://github.com/googleworkspace/cli/releases/download/${GWS_VER}/gws-${GWS_ARCH}-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin --wildcards --strip-components=1 "*/gws" \
 && chmod +x /usr/local/bin/gws

# Install claude-code and playwright, then patch shebang to bypass /usr/bin/env restriction
RUN npm install -g @anthropic-ai/claude-code playwright \
 && NODE_BIN=$(command -v node || command -v nodejs) \
 && find /usr/local/bin /usr/bin -maxdepth 1 -type f -name "claude" \
      -exec sed -i "1s|#!/usr/bin/env node|#!${NODE_BIN}|" {} \; \
 && find /usr/local/lib/node_modules /usr/lib/node_modules -maxdepth 8 \
      \( -name "claude" -o -name "claude.js" \) \
      \( -path "*/.bin/*" -o -path "*/.bin_real/*" \) \
      -exec sed -i "1s|#!/usr/bin/env node|#!${NODE_BIN}|" {} \; 2>/dev/null || true

# Set up a generic non-root user for the sandbox
RUN useradd -m -s /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
ENV PATH="/home/sandbox/.local/bin:${PATH}"

# Install browser binaries as the sandbox user
RUN npx playwright install chromium

# Tavily requires no local binaries (it is an API skill)
# Python deps for common skills (matches host env)
RUN python3 -m pip install --user --break-system-packages \
    pytest requests python-dotenv rich yt-dlp markitdown

CMD ["/bin/bash"]
EOF

echo "Building Docker image..."
docker build -t openclaw-sandbox:bookworm-slim "$TEMP_DIR"

echo "✅ Successfully built openclaw-sandbox:bookworm-slim"
exit 0
