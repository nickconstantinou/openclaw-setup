#!/usr/bin/env bash
# scripts/sandbox-setup.sh
# 
# @intent Build the minimal Docker image for OpenClaw sandbox execution.
# @complexity 1
#

set -Eeuo pipefail
IFS=$'\n\t'

# Use the same actual user resolution pattern if available, or default to current
if [[ -n "${ACTUAL_USER:-}" ]]; then
    TARGET_USER="$ACTUAL_USER"
else
    # Fallback to SUDO_USER or current user
    TARGET_USER="${SUDO_USER:-$(whoami)}"
fi

echo "Building OpenClaw Sandbox image: openclaw-sandbox:bookworm-slim..."

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

# Install global NPM packages (gws, playwright, claude-code) as root
RUN npm install -g @googleworkspace/cli playwright @anthropic-ai/claude-code

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
