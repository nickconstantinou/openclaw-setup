#!/usr/bin/env bash
# 
# @intent Deploy agent skills from external files to the workspace (§7h).
# @complexity 2
# 

deploy_skills() {
    log "Deploying agent skills (main + family)..."
    local local_skills_dir="$SCRIPT_DIR/skills"

    # Categories to map to agents
    local categories=("general-agent" "family-agent")

    for category in "${categories[@]}"; do
        local category_dir="$local_skills_dir/$category"
        [[ -d "$category_dir" ]] || continue

        # Resolve target agent ID and workspace
        local agent_id="${category%-agent}"
        local target_workspace
        if [[ "$agent_id" == "general" ]]; then
            agent_id="main"
            target_workspace="$ACTUAL_HOME/.openclaw/workspace"
        else
            target_workspace="$ACTUAL_HOME/.openclaw/agents/$agent_id/workspace"
        fi

        log "  Deploying $category assets to $agent_id workspace..."
        mkdir -p "$target_workspace/skills"

        # 1. Deploy Workspace Templates (top-level .md files in category folder)
        for f in "$category_dir"/*.md; do
            [[ -f "$f" ]] || continue
            cp -f "$f" "$target_workspace/$(basename "$f")"
        done

        # 2. Deploy Skill Modules (subdirectories in category folder)
        for skill_dir in "$category_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name; skill_name=$(basename "$skill_dir")
            local target_skill_dir="$target_workspace/skills/$skill_name"
            
            mkdir -p "$target_skill_dir"
            cp -a "$skill_dir"* "$target_skill_dir/" 2>/dev/null || true
            
            # Ensure generate.py executable
            [[ -f "$target_skill_dir/generate.py" ]] && chmod +x "$target_skill_dir/generate.py"
        done

        # For family-agent: also copy all general-agent skill modules
        if [[ "$category" == "family-agent" ]]; then
            local general_skills="$local_skills_dir/general-agent"
            for skill_dir in "$general_skills"/*/; do
                [[ -d "$skill_dir" ]] || continue
                local skill_name; skill_name=$(basename "$skill_dir")
                local target_skill_dir="$target_workspace/skills/$skill_name"
                mkdir -p "$target_skill_dir"
                cp -a "$skill_dir"* "$target_skill_dir/" 2>/dev/null || true
                [[ -f "$target_skill_dir/generate.py" ]] && chmod +x "$target_skill_dir/generate.py"
            done
        fi

        # Finalize ownership
        chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$target_workspace"
        log "  Verification: $agent_id workspace populated."
    done
}
