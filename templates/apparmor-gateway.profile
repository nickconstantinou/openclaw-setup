# ── OPENCLAW GATEWAY APPARMOR PROFILE ──────────────────────────────────────────
# @intent Security sandbox for the OpenClaw agent gateway.
# @complexity 4
# 

#include <tunables/global>

profile openclaw-gateway {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ssl_certs>

  # ── Node runtime ────────────────────────────────────────────────────────────
  /usr/bin/node                        ix,
  /usr/bin/node                        mr,
  /usr/bin/env                         ix,

  # Node.js modules — native addons (.node ELF shared libs) need mr for dlopen
  /usr/lib/node_modules/**             r,
  /usr/lib/node_modules/**.node        mr,
  /usr/local/lib/node_modules/**       r,
  /usr/local/lib/node_modules/**.node  mr,

  # OpenClaw installation
  /usr/lib/openclaw/**                 r,
  /usr/lib/openclaw/**.node            mr,
  /usr/share/openclaw/**               r,

  # ── Shell binaries ──────────────────────────────────────────────────────────
  # Gateway spawns subshells for hooks, health-monitor, and agent exec calls
  # Shells need rix (not ix) — the kernel reads the script file before executing it
  /usr/bin/dash                        rix,
  /bin/dash                            rix,
  /usr/bin/sh                          rix,
  /bin/sh                              rix,
  /usr/bin/bash                        rix,
  /bin/bash                            rix,
  # Git hook scripts in project repos — agent runs these during git commit/push
  @{HOME}/obsidian/vault/.git/hooks/** rix,
  @{HOME}/.openclaw/workspace/**/.git/hooks/** rix,
  /tmp/**/.git/hooks/**                rix,

  # Shell profile reads — sourced during subprocess env setup
  @{HOME}/.bashrc                      r,
  @{HOME}/.profile                     r,
  @{HOME}/.bash_profile                r,
  /etc/bash.bashrc                     r,
  /etc/profile                         r,
  /etc/profile.d/                      r,
  /etc/profile.d/*                     r,
  /etc/environment                     r,

  # ── Python ──────────────────────────────────────────────────────────────────
  # Allow direct python3 execution — agent previously had to roundtrip via Node.js
  # child_process. File-system access is still governed by the rules below.
  /usr/bin/python3                     ix,
  /usr/bin/python3.*                   ix,
  /usr/lib/python3/**                  r,
  /usr/lib/python3*/                   r,
  /usr/local/lib/python3*/             r,
  /usr/local/lib/python3/**            r,

  # ── Git + GitHub CLI ────────────────────────────────────────────────────────
  # git: native CLI for local repo operations
  # gh: GitHub CLI for PRs, issues, CI, API — installed via apt in §12
  /usr/bin/git                         ix,
  /usr/lib/git-core/                   r,
  /usr/lib/git-core/**                 ix,
  /usr/share/git-core/**               r,
  /usr/bin/gh                          rix,
  # gh reads its own libexec helpers
  /usr/lib/gh/**                       ix,
  /usr/share/gh/**                     r,
  # Global git config — read from HOME (system default)
  @{HOME}/.gitconfig                   rw,
  @{HOME}/.git-credentials             rw,
  @{HOME}/.config/git/                 rw,
  @{HOME}/.config/git/**               rw,
  # gh config + auth token — gh reads this on every invocation
  @{HOME}/.config/gh/                  rw,
  @{HOME}/.config/gh/**                rw,
  # Per-repo .gitignore and .gitconfig — agent sets GIT_CONFIG_GLOBAL and
  # GIT_DIR explicitly so git finds config in the workspace, not just $HOME.
  # Allow read of gitignore/gitconfig from anywhere under the workspace.
  @{HOME}/.openclaw/workspace/**/.gitignore   r,
  @{HOME}/.openclaw/workspace/**/.gitconfig   rw,
  @{HOME}/.openclaw/workspace/**/.git/        rw,
  @{HOME}/.openclaw/workspace/**/.git/**      rw,
  /etc/gitconfig                       r,

  # ── pip / Python packages ────────────────────────────────────────────────────
  # pip and pytest run inside the sandbox — user installs land in ~/.local
  /usr/bin/pip                         ix,
  /usr/bin/pip3                        ix,
  /usr/bin/pip3.*                      ix,
  /usr/bin/pytest                      ix,
  /usr/bin/py.test                     ix,
  /usr/local/bin/pip                   ix,
  /usr/local/bin/pip3                  rix,
  /usr/local/bin/pip                   rix,
  /usr/bin/pip3                        rix,
  /usr/bin/pip                         rix,
  /usr/local/bin/pytest                ix,
  # User site-packages — pip install --user writes here
  # IMPORTANT: pip --user installs to ~/.local/lib/python3.x/site-packages/
  # NOT /usr/local/lib/python3*/dist-packages/ — native .so files need mr here
  @{HOME}/.local/                      rw,
  @{HOME}/.local/**                    rw,
  # Native C-extension .so files in user site-packages need map+read (mr)
  # This covers: numpy, lxml, av (PyAV), ctranslate2, faster-whisper, and any
  # other pip --user package with native extensions
  @{HOME}/.local/lib/                              r,
  @{HOME}/.local/lib/python3*/                     r,
  @{HOME}/.local/lib/python3*/site-packages/       r,
  @{HOME}/.local/lib/python3*/site-packages/**     mrwixk,
  # System pip cache
  @{HOME}/.cache/pip/                  rw,
  @{HOME}/.cache/pip/**                rw,
  # Python bytecode cache
  @{HOME}/.cache/__pycache__/          rw,
  @{HOME}/.cache/__pycache__/**        rw,

  # ── Common shell tools ──────────────────────────────────────────────────────
  /usr/bin/env                         ix,
  /usr/bin/cat                         ix,
  /usr/bin/echo                        ix,
  /usr/bin/grep                        ix,
  /usr/bin/sed                         ix,
  /usr/bin/awk                         ix,
  /usr/bin/cut                         ix,
  /usr/bin/tr                          ix,
  /usr/bin/head                        ix,
  /usr/bin/tail                        ix,
  /usr/bin/wc                          ix,
  /usr/bin/date                        ix,
  /usr/bin/curl                        ix,
  /usr/lib/curl/**                     r,

  # ── File management tools ───────────────────────────────────────────────────
  # These don't expand the writable surface (defined by path rules below),
  # they just allow the agent to use native binaries instead of Node.js fs.
  /usr/bin/ls                          ix,
  /usr/bin/cp                          ix,
  /usr/bin/mv                          ix,
  /usr/bin/mkdir                       ix,
  /usr/bin/rm                          ix,
  /usr/bin/chmod                       ix,
  /usr/bin/find                        ix,
  /usr/bin/rsync                       ix,
  /usr/bin/touch                       ix,
  /usr/bin/sort                        ix,
  /usr/bin/uniq                        ix,
  /usr/bin/xargs                       ix,
  /usr/bin/tee                         ix,
  /usr/bin/base64                      ix,
  /usr/bin/stat                        ix,
  /usr/bin/diff                        ix,
  /usr/bin/patch                       ix,
  /usr/bin/jq                          ix,
  # Process / shell utilities the agent commonly calls from bash snippets
  /usr/bin/ln                          ix,
  /usr/bin/timeout                     ix,
  /usr/bin/ps                          ix,
  /usr/bin/sleep                       ix,
  /usr/bin/whoami                      ix,
  /usr/bin/id                          ix,
  /usr/bin/tr                          ix,
  /usr/bin/head                        ix,
  /usr/bin/tail                        ix,
  /usr/bin/cut                         ix,
  /usr/bin/wc                          ix,
  /usr/bin/sed                         ix,
  /usr/bin/which                       ix,
  /usr/bin/dirname                     ix,
  /usr/bin/basename                    ix,
  /usr/bin/realpath                    ix,

  # ── Systemd user timer scheduling ──────────────────────────────────────────
  # Agent may create/manage .service and .timer unit files in the user slice.
  # crontab is explicitly DENIED below — all scheduling goes through systemd
  # user timers so jobs run inside this AppArmor profile, not unconfined.
  /usr/bin/systemctl                   ix,
  /usr/bin/systemd-run                 ix,
  /usr/lib/systemd/systemd            rix,
  @{HOME}/.config/systemd/            rw,
  @{HOME}/.config/systemd/user/       rw,
  @{HOME}/.config/systemd/user/**     rw,
  /run/systemd/private/**              r,
  /run/user/@{uid}/systemd/           rw,
  /run/user/@{uid}/systemd/**         rw,

  # ── Docker (sandbox execution) ─────────────────────────────────────────────
  # OpenClaw spawns docker to run agent sandboxes (agents.defaults.sandbox)
  /usr/bin/docker                      rix,
  /usr/libexec/docker/cli-plugins/     r,
  /usr/libexec/docker/cli-plugins/**   rix,
  /run/docker.sock                     rw,
  /var/run/docker.sock                 rw,

  # ── Network / ip ────────────────────────────────────────────────────────────
  /usr/bin/ip                          ix,
  /usr/sbin/ip                         ix,

  # ── Kernel / system info reads ──────────────────────────────────────────────
  /proc/version                        r,
  # pandoc names its worker threads by writing to /proc/<pid>/task/<tid>/comm
  /proc/@{pid}/task/                   r,
  /proc/@{pid}/task/**                 rw,
  # ffmpeg reads NUMA node topology for memory allocation decisions
  /sys/devices/system/node/            r,
  /sys/devices/system/node/**          r,
  # yt-dlp reads /usr/bin/ directory to locate helper binaries (ffmpeg, ffprobe, etc.)
  /usr/bin/                            r,
  # yt-dlp calls `file` to detect media type before muxing
  /usr/bin/file                        ix,
  /usr/lib/file/                       r,
  /usr/lib/file/**                     r,
  /usr/share/file/                     r,
  /usr/share/file/**                   r,
  /usr/share/misc/magic*               r,
  /proc/version_signature              r,
  /proc/meminfo                        r,
  /proc/cpuinfo                        r,
  /proc/sys/kernel/hostname            r,
  /proc/self/**                        r,
  /proc/@{pid}/**                      r,
  /etc/hostname                        r,
  /etc/hosts                           r,
  /etc/resolv.conf                     r,
  /etc/nsswitch.conf                   r,
  /etc/os-release                      r,

  # ── OpenClaw state ──────────────────────────────────────────────────────────
  @{HOME}/.openclaw/                   rw,
  @{HOME}/.openclaw/**                 rwk,
  @{HOME}/.openclaw/workspace/**       rwk,
  @{HOME}/.openclaw/workspace/skills/**/*.py  rix,   # allow agent to exec Python skill scripts
  @{HOME}/.openclaw/workspace/skills/**/venv/bin/python[0-9.]* rix, # allow venv python execution
  @{HOME}/.openclaw/workspace/images/         rwk,   # image generation output dir
  @{HOME}/.openclaw/workspace/images/**       rwk,
  @{HOME}/.openclaw/agents/                  rw,    # named agent dirs (main, family)
  @{HOME}/.openclaw/agents/**                rwk,

  # ── Temp workspace ──────────────────────────────────────────────────────────
  /tmp/openclaw/                       rw,
  /tmp/openclaw/**                     rw,
  /tmp/                                rw,
  /tmp/**                              rw,

  # ── Network ─────────────────────────────────────────────────────────────────
  network inet  stream,
  network inet6 stream,
  network inet  dgram,
  network unix  stream,
  network unix  dgram,
  network netlink raw,
  /run/user/@{uid}/                    rw,
  /run/user/@{uid}/**                  rw,
  /sys/fs/cgroup/**                    r,
  /dev/urandom                         r,
  /dev/null                            rw,
  /dev/tty                             rw,

  # ── Logging ─────────────────────────────────────────────────────────────────
  /var/log/openclaw-deploy.log         w,

  # ── TOOL_RULES_BEGIN ─────────────────────────────────────────────────────────
  # (tool-specific rules injected here by setup_apparmor in lib/05-apparmor.sh)
  # ── TOOL_RULES_END ───────────────────────────────────────────────────────────

  # ── Google Workspace CLI (gws) ───────────────────────────────────────────────
  /usr/local/bin/gws                  rix,
  /usr/bin/gws                        rix,
  /usr/lib/node_modules/@googleworkspace/cli/node_modules/.bin_real/gws  ix,
  /usr/lib/node_modules/@googleworkspace/cli/bin/gws  ix,
  @{HOME}/.config/gws/                rw,
  @{HOME}/.config/gws/**              rw,

  # ── DENY — explicit blocks ──────────────────────────────────────────────────
  # crontab: would spawn unconfined jobs via the system cron daemon.
  # All scheduling must use systemd user timers (confined by this profile).
  deny /usr/bin/crontab                x,
  deny /var/spool/cron/**              rw,
  deny /etc/cron*                      rw,

  # Privilege escalation and sensitive system paths
  deny /usr/bin/sudo                   x,
  deny /usr/bin/su                     x,
  deny /etc/shadow                     r,
  deny /root/**                        rw,
  deny /home/*/.*ssh/**                rw,
  deny /home/*/.gnupg/**               rw,
  deny /etc/sudoers                    r,
  deny /etc/sudoers.d/**               r,
  deny /proc/*/mem                     rw,
  deny /sys/kernel/security/**         rw,

  # Package management — agent should not install system packages
  deny /usr/bin/apt                    x,
  deny /usr/bin/apt-get                x,
  deny /usr/bin/dpkg                   x,
  deny /usr/bin/snap                   x,

  # Network scanning / lateral movement
  deny /usr/bin/ssh                    x,
  deny /usr/bin/scp                    x,
  deny /usr/bin/nc                     x,
  deny /usr/bin/nmap                   x,
  deny /usr/bin/ncat                   x,
}
