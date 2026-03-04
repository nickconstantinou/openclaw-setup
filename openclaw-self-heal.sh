#!/usr/bin/env bash
###############################################################################
# OPENCLAW ENTERPRISE ORCHESTRATOR
# Version: 2026.8-modular
# 
# Refactored for Atomic Modularity and maintainability.
###############################################################################

set -Eeuo pipefail
IFS=$'\n\t'

# ── LOGGING SETUP ────────────────────────────────────────────────────────────
export SCRIPT_VERSION="2026.8-modular"
export LOG_FILE="/var/log/openclaw-deploy.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

sudo touch "$LOG_FILE"
sudo chmod 600 "$LOG_FILE"

# ── SOURCE LIBRARIES ──────────────────────────────────────────────────────────
# shellcheck source=lib/00-common.sh
source "$SCRIPT_DIR/lib/00-common.sh"
# shellcheck source=lib/01-env.sh
source "$SCRIPT_DIR/lib/01-env.sh"
# shellcheck source=lib/02-install-core.sh
source "$SCRIPT_DIR/lib/02-install-core.sh"
# shellcheck source=lib/03-skills.sh
source "$SCRIPT_DIR/lib/03-skills.sh"
# shellcheck source=lib/04-ollama.sh
source "$SCRIPT_DIR/lib/04-ollama.sh"
# shellcheck source=lib/05-apparmor.sh
source "$SCRIPT_DIR/lib/05-apparmor.sh"
# shellcheck source=lib/06-network.sh
source "$SCRIPT_DIR/lib/06-network.sh"
# shellcheck source=lib/07-integrations.sh
source "$SCRIPT_DIR/lib/07-integrations.sh"
# shellcheck source=lib/08-config.sh
source "$SCRIPT_DIR/lib/08-config.sh"
# shellcheck source=lib/09-ops.sh
source "$SCRIPT_DIR/lib/09-ops.sh"
# shellcheck source=lib/10-gateway.sh
source "$SCRIPT_DIR/lib/10-gateway.sh"
# shellcheck source=lib/11-health.sh
source "$SCRIPT_DIR/lib/11-health.sh"
# shellcheck source=lib/12-notify.sh
source "$SCRIPT_DIR/lib/12-notify.sh"

trap 'die "Unexpected failure at line $LINENO. See $LOG_FILE"' ERR

# ── MAIN EXECUTION FLOW ───────────────────────────────────────────────────────
main() {
    log "Starting OpenClaw Modular Deployment ($SCRIPT_VERSION)"

    # 1. Environment & Requirements
    resolve_user_context
    validate_env
    validate_system
    check_resources
    setup_shell_profile

    # 2. Installation
    install_openclaw
    install_playwright
    install_python_packages
    install_pandoc_toolchain
    install_gogcli
    install_claude_code
    install_acpx_plugin
    setup_agent_dirs
    install_post_bridge

    # 3. Assets & Security
    deploy_skills
    install_ollama
    configure_ollama
    setup_apparmor
    setup_network

    # 4. Configuration
    setup_github_cli
    setup_obsidian_vault
    stop_gateway
    setup_systemd_env
    enable_linger
    harden_permissions
    backup_config
    patch_config

    # 5. Launch & Operations
    migrate_secrets
    scrub_auth_profile_plaintext
    run_security_audit
    optimize_sqlite
    onboard_gateway
    reapply_models
    install_gateway_service
    
    # 6. Post-Launch Health
    init_memory_index
    run_doctor
    rotate_device_scopes
    run_health_suite
    
    # 7. Summary & Notifications
    print_summary
    send_telegram_notification

    log "Deployment complete. OpenClaw $SCRIPT_VERSION is running."
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
