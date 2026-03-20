#!/usr/bin/env bash
# scripts/sandbox-setup.sh
#
# @intent Build the minimal Docker image for the family agent sandbox.
# @complexity 1
#
# This image is used exclusively by the family agent (WhatsApp/messaging profile).
# It does NOT include claude-code, gws, or document processing tools since the
# family agent runs with a messaging profile (no exec/bash/code execution).
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

TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GID=$(id -g "$TARGET_USER")

echo "Building OpenClaw family sandbox image: openclaw-sandbox:bookworm-slim..."

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

# Install essential tools for family agent skills:
# - Browser automation (playwright, lightpanda)
# - Media processing (ffmpeg, yt-dlp)
# - Python skill dependencies
# NOTE: No gcloud/gws, claude-code, pandoc, or texlive — not needed for messaging profile
RUN apt-get update && apt-get install -y --no-install-recommends \
    git nodejs npm python3 python3-pip python3-venv bash curl jq \
    libgbm1 libnss3 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libasound2 \
    ffmpeg sqlite3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set up sandbox user with host UID/GID so bind-mounted files are accessible
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd -g ${USER_GID} sandbox && useradd -u ${USER_UID} -g ${USER_GID} -m -s /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox
ENV PATH="/home/sandbox/.local/bin:${PATH}"

# Install Playwright + Chromium browser binaries as the sandbox user
RUN npm install --prefix /home/sandbox/.local/lib playwright \
 && npx --prefix /home/sandbox/.local/lib playwright install chromium

# Install LightPanda — fast headless CDP browser (10x faster than Chrome)
# postinstall script downloads binary to ~/.cache/lightpanda-node/lightpanda
RUN npm install --prefix /tmp/lp-install @lightpanda/browser \
 && rm -rf /tmp/lp-install

# Tavily requires no local binaries (it is an API skill)
# Python deps for family agent skills
RUN python3 -m pip install --user --break-system-packages \
    requests python-dotenv rich yt-dlp markitdown

CMD ["/bin/bash"]
EOF

echo "Building Docker image..."
docker build \
    --build-arg USER_UID="$TARGET_UID" \
    --build-arg USER_GID="$TARGET_GID" \
    -t openclaw-sandbox:bookworm-slim "$TEMP_DIR"

echo "✅ Successfully built openclaw-sandbox:bookworm-slim"
exit 0
