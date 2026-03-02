#!/usr/bin/env bash
# 
# @intent Deploy agent skills from external files to the workspace (§7h).
# @complexity 2
# 

deploy_skills() {
    log "Deploying agent skills from external files..."
    local skill_root="$ACTUAL_HOME/.openclaw/workspace/skills"
    local local_skills_dir="$SCRIPT_DIR/skills"

    # Each skill is a folder containing SKILL.md and optional supporting files.
    # This loop copies the entire folder structure to the target workspace.
    for skill_dir in "$local_skills_dir"/*/; do
        local skill_name; skill_name=$(basename "$skill_dir")
        local target_dir="$skill_root/$skill_name"
        mkdir -p "$target_dir"

        # Copy all files from the skill directory (as root, then fix ownership)
        for f in "$skill_dir"*; do
            [[ -f "$f" ]] || continue
            cp -f "$f" "$target_dir/$(basename "$f")"
        done

        # Handle nested subdirectories (e.g. marketing/brand-voice/)
        for sub in "$skill_dir"*/; do
            [[ -d "$sub" ]] || continue
            local sub_name; sub_name=$(basename "$sub")
            local sub_target="$target_dir/$sub_name"
            mkdir -p "$sub_target"
            for f in "$sub"*; do
                [[ -f "$f" ]] || continue
                cp -f "$f" "$sub_target/$(basename "$f")"
            done
        done

        # Ensure generate.py is executable if present
        [[ -f "$target_dir/generate.py" ]] && chmod +x "$target_dir/generate.py"

        chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$target_dir"
        log "  Skill deployed: $skill_name"
    done
}
