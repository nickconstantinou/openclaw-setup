#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PYTHON = sys.executable


class TestConfigScripts(unittest.TestCase):
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
                "allowedAgents": ["codex", "claude"]
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
        self.assertEqual(cfg["acp"]["allowedAgents"], ["codex", "claude"])
        self.assertTrue(cfg["plugins"]["entries"]["acpx"]["enabled"])
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["permissionMode"], "approve-all")
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["nonInteractivePermissions"], "fail")
        self.assertFalse(cfg["plugins"]["entries"]["acpx"]["config"]["pluginToolsMcpBridge"])
        self.assertEqual(cfg["plugins"]["entries"]["acpx"]["config"]["command"], "/custom/acpx")
        self.assertEqual(cfg["agents"]["defaults"]["model"]["fallbacks"], ["minimax/MiniMax-M2.5"])


if __name__ == "__main__":
    unittest.main()
