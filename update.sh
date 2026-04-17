#!/usr/bin/env bash
# openclaw-update.sh — safe day-to-day update for a running installation.
#
# Use this instead of re-running openclaw-self-heal.sh when the gateway is
# already installed and you just need to update the binary, sync skills,
# or apply a config/key change.
#
# Does NOT tear down the systemd unit, touch AppArmor, or reinstall tools.

set -euo pipefail
IFS=$'\n\t'

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[UPDATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
die()  { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
ENV_FILE="$ACTUAL_HOME/.openclaw/.env"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
    set -o allexport
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +o allexport
fi

# ── 1. Update openclaw binary ─────────────────────────────────────────────────
log "Checking openclaw version..."
CURRENT=$(sudo /usr/bin/node /usr/lib/node_modules/openclaw/dist/index.js --version 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
LATEST=$(npm view openclaw version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

if [[ "$CURRENT" == "$LATEST" ]] && [[ "$CURRENT" != "unknown" ]]; then
    log "openclaw already at latest ($CURRENT). Skipping binary update."
else
    log "Updating openclaw: $CURRENT → $LATEST"
    sudo npm install -g "openclaw@$LATEST" --quiet \
        || die "npm install failed. Check: sudo npm install -g openclaw@latest"
    log "openclaw updated to $LATEST"
fi

# ── 2. Sync skills from workspace ─────────────────────────────────────────────
SKILLS_SRC="$ACTUAL_HOME/.openclaw/workspace/skills"
SKILLS_DST="$ACTUAL_HOME/.openclaw/skills"
if [[ -d "$SKILLS_SRC" ]]; then
    log "Syncing skills..."
    rsync -a --delete "$SKILLS_SRC/" "$SKILLS_DST/" 2>/dev/null \
        || warn "rsync not available — skipping skill sync (run: sudo apt-get install rsync)"
fi

# ── 3. Update service unit MINIMAX key if it contains 'test' ─────────────────
UNIT_FILE="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service"
if [[ -f "$UNIT_FILE" ]] && grep -q 'MINIMAX_API_KEY=test' "$UNIT_FILE"; then
    warn "Service unit has MINIMAX_API_KEY=test — replacing with key from .env"
    if [[ -n "${MINIMAX_API_KEY:-}" ]] && [[ "$MINIMAX_API_KEY" != "test" ]]; then
        sed -i "s|Environment=MINIMAX_API_KEY=.*|Environment=MINIMAX_API_KEY=$MINIMAX_API_KEY|" "$UNIT_FILE"
        log "MINIMAX_API_KEY updated in service unit."
    else
        warn "MINIMAX_API_KEY in .env is also 'test' or unset — update ~/.openclaw/.env first."
    fi
fi

# ── 4. Reload systemd and restart gateway ────────────────────────────────────
log "Reloading systemd and restarting gateway..."
sudo -u "$ACTUAL_USER" \
    env XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user daemon-reload

sudo -u "$ACTUAL_USER" \
    env XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user restart openclaw-gateway

# ── 5. Wait for ready ────────────────────────────────────────────────────────
log "Waiting for gateway to be ready (up to 90s)..."
READY=0
for i in $(seq 1 45); do
    if sudo -u "$ACTUAL_USER" \
        env XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
        journalctl --user -u openclaw-gateway --since "${i}s ago" 2>/dev/null \
        | grep -q "ready"; then
        READY=1
        break
    fi
    # Also check via port binding as a fallback
    if ss -tlnp 2>/dev/null | grep -q ':18789'; then
        READY=1
        break
    fi
    sleep 2
done

if [[ $READY -eq 1 ]]; then
    log "Gateway is ready."
else
    warn "Gateway did not report ready within 90s. Check: journalctl --user -u openclaw-gateway -n 50"
fi

# ── 6. Brief channel status ───────────────────────────────────────────────────
log "Checking channel status..."
sudo -u "$ACTUAL_USER" \
    env XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" HOME="$ACTUAL_HOME" \
    openclaw channels status 2>/dev/null || warn "Could not get channel status — gateway may still be initialising."

log "Update complete."
