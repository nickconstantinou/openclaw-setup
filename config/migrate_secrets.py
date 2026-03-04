#!/usr/bin/env python3
"""
@intent Automate SecretRef migration for OpenClaw. Transforms plaintext API keys to {source: "env"} refs.
@complexity 2
"""
import json
import os
import sys
import argparse

def run_migration(config):
    """
    Core migration logic:
    1. Ensures 'secrets.providers.default = {source: "env"}'
    2. Maps plaintext keys to SecretRefs in providers and skills.
    3. Generates a 'secrets apply' plan.
    """
    plan = {
        "version": 1,
        "protocolVersion": 1,
        "targets": []
    }
    
    # 1. Ensure providers.default exists
    config.setdefault("secrets", {}).setdefault("providers", {}).setdefault("default", {"source": "env"})
    
    # 2. Define targets for migration
    targets = [
        # (Config Path, Env Var Name, Target Type, Provider ID)
        ("models.providers.minimax.apiKey",    "MINIMAX_API_KEY",    "models.providers.apiKey", "minimax"),
        ("models.providers.nvidia.apiKey",     "NVIDIA_API_KEY",     "models.providers.apiKey", "nvidia"),
        ("skills.entries.tavily.apiKey",       "TAVILY_API_KEY",     "skills.entries.apiKey",   "tavily"),
    ]
    
    for path, env_var, t_type, p_id in targets:
        # Traverse to find the value
        keys = path.split('.')
        curr = config
        found = True
        for k in keys[:-1]:
            if k not in curr:
                found = False
                break
            curr = curr[k]
        
        if found and keys[-1] in curr:
            val = curr[keys[-1]]
            # Only migrate if it's currently a plaintext string (not yet a SecretRef dict)
            if isinstance(val, str) and val.strip() != "":
                # Create the SecretRef
                ref = {"source": "env", "provider": "default", "id": env_var}
                curr[keys[-1]] = ref
                
                # Add to plan
                plan["targets"].append({
                    "type": t_type,
                    "path": path,
                    "pathSegments": keys,
                    "providerId": p_id,
                    "ref": ref
                })
                
    return {"updated_config": config, "plan": plan}

def main():
    parser = argparse.ArgumentParser(description='Migrate OpenClaw plaintext secrets to SecretRefs.')
    parser.add_argument('--config', required=True, help='Path to openclaw.json')
    parser.add_argument('--plan-out', required=True, help='Path to write migration plan (JSON)')
    args = parser.parse_args()

    cfg_path = args.config
    try:
        with open(cfg_path, 'r') as f:
            config = json.load(f)
    except Exception as e:
        print(f"Error reading config: {e}")
        sys.exit(1)

    result = run_migration(config)
    
    # Write updated config back
    with open(cfg_path, 'w') as f:
        json.dump(result["updated_config"], f, indent=2)
    
    # Write plan
    with open(args.plan_out, 'w') as f:
        json.dump(result["plan"], f, indent=2)
    
    print(f"Migration complete. {len(result['plan']['targets'])} secrets mapped to SecretRefs.")

if __name__ == '__main__':
    main()
