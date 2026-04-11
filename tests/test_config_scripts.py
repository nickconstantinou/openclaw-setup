#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PYTHON = sys.executable


class TestConfigScripts(unittest.TestCase):
    def _run_bash(self, script, extra_env=None):
        env = os.environ.copy()
        if extra_env:
            env.update(extra_env)

        return subprocess.run(
            ["bash", "-lc", script],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )

    def _run(self, script_rel, config_text, extra_env=None):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg = Path(tmpdir) / "openclaw.json"
            cfg.write_text(textwrap.dedent(config_text), encoding="utf-8")

            env = os.environ.copy()
            if extra_env:
                env.update(extra_env)

            proc = subprocess.run(
                [PYTHON, str(ROOT / script_rel), "--config", str(cfg)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
            )
            return proc, json.loads(cfg.read_text(encoding="utf-8"))

    def test_apply_config_accepts_json5_input(self):
        proc, cfg = self._run(
            "config/apply-config.py",
            """
            // valid JSON5 config
            {
              channels: {
                telegram: {
                  streaming: 'partial',
                },
              },
            }
            """,
            extra_env={
                "OPENCLAW_GATEWAY_TOKEN": "x" * 64,
                "TELEGRAM_BOT_TOKEN": "123:abc",
                "TELEGRAM_CHAT_ID": "12345",
                "ACTUAL_HOME": "/tmp/openclaw-home",
            },
        )

        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(
            cfg["channels"]["telegram"]["accounts"]["default"]["botToken"]["id"],
            "TELEGRAM_BOT_TOKEN",
        )
        self.assertEqual(cfg["gateway"]["auth"]["token"]["id"], "OPENCLAW_GATEWAY_TOKEN")
        self.assertEqual(
            cfg["agents"]["defaults"]["memorySearch"]["remote"]["apiKey"]["id"],
            "OLLAMA_API_KEY",
        )

    def test_reapply_models_preserves_existing_config_when_input_is_json5(self):
        proc, cfg = self._run(
            "config/reapply-models.py",
            """
            // valid JSON5 config
            {
              channels: {
                telegram: {
                  botToken: '123:abc',
                },
              },
            }
            """,
        )

        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(cfg["channels"]["telegram"]["botToken"], "123:abc")
        self.assertIn("agents", cfg)
        self.assertIn("tools", cfg)
        self.assertIn("minimax", cfg["models"]["providers"])
        self.assertNotIn("anthropic", cfg["models"]["providers"])
        self.assertNotIn("openai-codex/gpt-5.3-codex-spark", cfg["agents"]["defaults"]["models"])
        self.assertEqual(
            [model["id"] for model in cfg["models"]["providers"]["openai-codex"]["models"]],
            ["gpt-5.4"],
        )

    def test_patch_stale_keys_preserves_current_supported_fields(self):
        proc, cfg = self._run(
            "config/patch-stale-keys.py",
            """
            {
              "acp": {
                "enabled": true,
                "backend": "acpx",
                "allowedAgents": ["codex"]
              },
              "agents": {
                "defaults": {
                  "sandbox": {
                    "mode": "all",
                    "backend": "ssh",
                    "scope": "agent"
                  }
                },
                "list": [
                  {
                    "id": "family",
                    "sandbox": {
                      "mode": "all"
                    }
                  }
                ]
              },
              "plugins": {
                "entries": {
                  "acpx": {
                    "enabled": true,
                    "config": {
                      "permissionMode": "approve-all"
                    }
                  }
                }
              },
              "tools": {
                "exec": {
                  "ask": "always",
                  "strictInlineEval": true
                }
              },
              "channels": {
                "telegram": {
                  "botToken": "123:abc",
                  "dmPolicy": "allowlist",
                  "allowFrom": ["123"],
                  "streaming": "partial"
                },
                "whatsapp": {
                  "dmPolicy": "allowlist",
                  "allowFrom": ["+1555"],
                  "groupPolicy": "allowlist",
                  "groupAllowFrom": ["+1555"]
                }
              }
            }
            """,
        )

        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(cfg["acp"]["enabled"])
        self.assertEqual(cfg["acp"]["backend"], "acpx")
        self.assertEqual(cfg["agents"]["defaults"]["sandbox"]["mode"], "all")
        self.assertEqual(cfg["agents"]["defaults"]["sandbox"]["backend"], "ssh")
        self.assertEqual(cfg["agents"]["list"][0]["sandbox"]["mode"], "all")
        self.assertTrue(cfg["plugins"]["entries"]["acpx"]["enabled"])
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["permissionMode"], "approve-all")
        self.assertEqual(cfg["tools"]["exec"]["ask"], "always")
        self.assertTrue(cfg["tools"]["exec"]["strictInlineEval"])
        self.assertEqual(cfg["channels"]["telegram"]["streaming"], "partial")
        self.assertEqual(cfg["channels"]["telegram"]["botToken"], "123:abc")
        self.assertEqual(cfg["channels"]["whatsapp"]["dmPolicy"], "allowlist")
        self.assertNotIn("anthropic", cfg["models"]["providers"])
        self.assertNotIn("anthropic/claude-haiku-4-5-20251001", cfg["agents"]["defaults"]["models"])

    def test_apply_config_sets_documented_acp_defaults(self):
        proc, cfg = self._run(
            "config/apply-config.py",
            """
            {
              "plugins": {
                "entries": {
                  "acpx": {
                    "config": {
                      "command": "/custom/acpx"
                    }
                  }
                }
              }
            }
            """,
            extra_env={
                "OPENCLAW_GATEWAY_TOKEN": "x" * 64,
                "ACTUAL_HOME": "/tmp/openclaw-home",
            },
        )

        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(cfg["acp"]["enabled"])
        self.assertEqual(cfg["acp"]["backend"], "acpx")
        self.assertEqual(cfg["acp"]["defaultAgent"], "codex")
        self.assertEqual(cfg["acp"]["allowedAgents"], ["codex"])
        self.assertTrue(cfg["plugins"]["entries"]["acpx"]["enabled"])
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["permissionMode"], "approve-all")
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["nonInteractivePermissions"], "fail")
        self.assertFalse(cfg["plugins"]["entries"]["acpx"]["config"]["pluginToolsMcpBridge"])
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["command"], "/custom/acpx")
        self.assertEqual(cfg["agents"]["defaults"]["model"]["fallbacks"], ["minimax/MiniMax-M2.5"])
        self.assertEqual(cfg["channels"]["telegram"]["defaultAccount"], "default")
        self.assertNotIn("coding", {agent["id"] for agent in cfg["agents"]["list"]})
        self.assertNotIn("marketing", {agent["id"] for agent in cfg["agents"]["list"]})
        self.assertNotIn("claude", {agent["id"] for agent in cfg["agents"]["list"]})

        main_agent = next(agent for agent in cfg["agents"]["list"] if agent["id"] == "main")
        codex_agent = next(agent for agent in cfg["agents"]["list"] if agent["id"] == "codex")

        self.assertEqual(main_agent["subagents"]["allowAgents"], ["codex"])
        self.assertEqual(codex_agent["runtime"]["type"], "acp")
        self.assertEqual(codex_agent["runtime"]["acp"]["agent"], "codex")
        self.assertEqual(codex_agent["runtime"]["acp"]["backend"], "acpx")
        self.assertEqual(codex_agent["runtime"]["acp"]["mode"], "persistent")

    def test_shell_helpers_prefer_nvm_openclaw_over_homebrew(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            actual_home = tmp / "home"
            local_bin = actual_home / ".local" / "bin"
            brew_bin = tmp / "brew" / "bin"
            nvm_bin = tmp / "nvm" / "bin"
            local_bin.mkdir(parents=True)
            brew_bin.mkdir(parents=True)
            nvm_bin.mkdir(parents=True)

            for target, label in (
                (brew_bin / "openclaw", "brew"),
                (nvm_bin / "openclaw", "nvm"),
            ):
                target.write_text(f"#!/usr/bin/env bash\necho {label}\n", encoding="utf-8")
                target.chmod(0o755)

            script = textwrap.dedent(
                f"""
                source {shlex.quote(str(ROOT / "lib/00-common.sh"))}
                printf '%s\\n' "$(resolve_openclaw_bin)"
                printf '%s\\n' "$(build_user_path)"
                """
            )
            proc = self._run_bash(
                script,
                extra_env={
                    "ACTUAL_HOME": str(actual_home),
                    "BREW_BIN_DIR": str(brew_bin),
                    "NVM_NODE_DIR": str(nvm_bin),
                    "PATH": "/usr/bin",
                },
            )

            self.assertEqual(proc.returncode, 0, proc.stderr)
            resolved_bin, user_path = proc.stdout.strip().splitlines()
            self.assertEqual(resolved_bin, str(nvm_bin / "openclaw"))
            path_parts = user_path.split(":")
            self.assertLess(path_parts.index(str(nvm_bin)), path_parts.index(str(brew_bin)))


    def test_setup_systemd_env_reclaims_user_ownership_after_root_owned_swap(self):
        script = (ROOT / "lib/08-config.sh").read_text(encoding="utf-8")
        start = script.index("setup_systemd_env() {")
        end = script.index("\n# ── 12b. SYSTEMD LINGER", start)
        body = script[start:end]

        self.assertIn('touch "$envd_file"', body)
        self.assertIn('chown "$ACTUAL_USER:$ACTUAL_USER" "$envd_file"', body)
        self.assertRegex(
            body,
            r'mv "\$sanitized_envd" "\$envd_file"\n\s*chmod 600 "\$envd_file"\n\s*chown "\$ACTUAL_USER:\$ACTUAL_USER" "\$envd_file"',
        )

    def test_gateway_install_prefers_system_openclaw_and_health_checks_unit_config(self):
        install_script = (ROOT / "lib/10-gateway.sh").read_text(encoding="utf-8")
        core_script = (ROOT / "lib/02-install-core.sh").read_text(encoding="utf-8")
        health_script = (ROOT / "lib/11-health.sh").read_text(encoding="utf-8")

        self.assertIn('oc_bin=$(resolve_system_openclaw_bin)', install_script)
        self.assertIn('normalize_gateway_unit "$unit"', install_script)
        self.assertIn('gateway_unit_has_embedded_environment "$unit"', install_script)
        self.assertIn('gateway_unit_uses_version_manager_runtime "$unit"', install_script)
        self.assertIn('run_system_npm_global_install()', core_script)
        self.assertIn('check_gateway_service_config()', health_script)

if __name__ == "__main__":
    unittest.main()
