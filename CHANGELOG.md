# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Modular Architecture**: Decomposed the monolithic `openclaw-self-heal.sh` into 13 single-responsibility bash modules in `lib/`.
- **Advanced Verification**: Created `tests/verify-repo.sh` with ShellCheck integration, function resolution audits, and environment variable coverage.
- **Anthropic-Standard Skills**: Reorganized `skills/` into a folder-per-skill structure with YAML-frontmatter `SKILL.md` files.
- **Agent Skill Integration**: Integrated 6 new skills (`requirement-gatherer`, `refactoring`, `rca`, `mobile-app-dev`, `frontend-design`, `code-review`) from `.agent/skills/`.
- **Bootstrap Installer**: Added `install.sh` for one-liner `curl | bash` deployments.
- **Environment Template**: Added `.env.example` with comprehensive documentation for all required API keys.

### Changed
- **Deployment Efficiency**: Updated `lib/03-skills.sh` to use recursive folder deployment, simplifying logic and increasing flexibility.
- **Hardening**: Applied ShellCheck fixes to all bash modules to prevent variable masking and logic errors.
- **Marketing Skill**: Consolidated 18 sub-skills into a unified `skills/marketing/SKILL.md` overview.

### Fixed
- **Gateway Installation**: Resolved systemd symlink collisions during re-runs.
- **AppArmor Fallback**: Restored missing fallback logic for non-AppArmor systems in the gateway module.
- **API Key Handling**: Corrected inconsistent environment variable names for GITHUB_TOKEN and GEMINI_API_KEY.
