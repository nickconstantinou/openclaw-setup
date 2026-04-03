#!/usr/bin/env python3
"""
Helpers for reading OpenClaw config files safely.

OpenClaw's config format is JSON5, but these setup scripts only need to write
plain JSON back out because JSON is valid JSON5.
"""
import json
import shutil
import subprocess


def _load_via_node(path):
    """Fallback JSON5 parser using Node's JS parser for local trusted config."""
    node = shutil.which("node")
    if not node:
        raise RuntimeError(
            "Config uses JSON5 syntax, but neither Python json nor Node.js parsing is available."
        )

    script = r"""
const fs = require('fs');
const vm = require('vm');

const path = process.argv[1];
const source = fs.readFileSync(path, 'utf8');
const value = vm.runInNewContext('(' + source + '\n)', Object.create(null), {
  timeout: 1000,
});
process.stdout.write(JSON.stringify(value));
"""
    proc = subprocess.run(
        [node, "-e", script, path],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(proc.stdout)


def load_config(path):
    with open(path, "r", encoding="utf-8") as fh:
        source = fh.read()

    try:
        return json.loads(source)
    except json.JSONDecodeError:
        return _load_via_node(path)


def dump_config(path, config):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(config, fh, indent=2)
        fh.write("\n")
