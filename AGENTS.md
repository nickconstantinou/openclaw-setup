# AGENTS.md

This file serves as the persistent memory for autonomous agents working on **Antigravity Workflows**.
It captures high-level context, architectural patterns, "gotchas," and lessons learned to ensure continuity between sessions.

## 🌟 The Golden Rules (Operational Constraints)

1.  **Workflows-Only**: This repository is a library of workflows. Do not add component or application logic here.
2.  **Mirror Structure**: The repository layout MUST mirror a target project's `.agent/workflows` directory.
3.  **Self-Contained**: Each workflow should contain its own procedural knowledge.

## 🏗️ Architecture Patterns
- **Modular Bash**: Large scripts MUST be decomposed into `lib/XX-name.sh` modules and sourced by a thin orchestrator.
- **Skill Folders**: Skills MUST follow the folder-per-skill pattern with a `SKILL.md` (YAML frontmatter + Markdown).
- **Hardening**: All shell scripts MUST pass ShellCheck analysis.
- **Technology Layer**: Workflows assume a Supabase (Backend) + Expo (Frontend) stack unless otherwise specified.

## 🔄 Available Workflows
- **[/create-issue](file://./.agent/workflows/create-issue.md)**: Architecture Discovery.
- **[/create-plan](file://./.agent/workflows/create-plan.md)**: Unified Research & Implementation Planning.
- **[/execute](file://./.agent/workflows/execute.md)**: Deterministic Code Generation.
- **[/refactor](file://./.agent/workflows/refactor.md)**: Migrate code to Atomic Blueprint.
- **[/peer-review](file://./.agent/workflows/peer-review.md)**: Senior Architect audit.
- **[/synthesis](file://./.agent/workflows/synthesis.md)**: Synthesis of multiple reviews & bug-fixes.
- **[/test](file://./.agent/workflows/test.md)**: Quad Gate verification.
- **[/close-issue](file://./.agent/workflows/close-issue.md)**: Memory consolidation & hygiene.
- **[/cto](file://./.agent/workflows/cto.md)**: Technical Brainstorming & Plan Critique.
- **[/learning-opportunity](file://./.agent/workflows/learning-opportunity.md)**: Deep Dive into technical topics & architectural "why".

## 🛡️ Security & Risks
- **Security**: Never include secrets in workflow files.
- **Persistence**: Multi-stage (Epoch) workflows MUST use artifacts in `~/.gemini/antigravity/brain/` for state management across sessions.

'' Openclaw Docs
- Read all docs in `docs/` directory.