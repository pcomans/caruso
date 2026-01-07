# Steering Docs

**Steering docs** are files and configurations that direct an AI agent's behavior, capabilities, and workflows. They act as the "operating system" for the agent, defining what it can do, how it should act, and what rules it must follow.

## Claude Code Supported Types

Claude Code uses a plugin-based architecture where steering docs are organized into specific directories within a plugin or project structure.

1.  **Commands** (`commands/*.md`)
    *   **Definition:** Custom slash commands (e.g., `/deploy`) invoked by the user.
    *   **Format:** Markdown files with frontmatter describing the command's intent and logic.

2.  **Agents** (`agents/*.md`)
    *   **Definition:** Specialized sub-personas (e.g., "Security Reviewer") that Claude can invoke automatically or users can call manually.
    *   **Format:** Markdown files defining the agent's capabilities and prompt instructions.

3.  **Skills** (`skills/*/SKILL.md`)
    *   **Definition:** Discrete capabilities (e.g., "PDF Reader", "API Client") that Claude figures out how to use autonomously.
    *   **Format:** Directories containing a `SKILL.md` file and optional supporting scripts.

4.  **Hooks** (`hooks/hooks.json`)
    *   **Definition:** Event handlers that trigger scripts based on system lifecycle events (e.g., `PostToolUse`, `SessionStart`).
    *   **Format:** JSON configuration mapping events to scripts.

5.  **MCP Servers** (`.mcp.json`)
    *   **Definition:** Connections to external tools, databases, and APIs via the Model Context Protocol.
    *   **Format:** JSON file configuring local servers (environment variables, command arguments).

## Cursor Supported Types

Cursor uses a file-based configuration system, typically stored in a `.cursor/` directory at the project root.

1.  **Rules** (`.cursor/rules/*.md`)
    *   **Definition:** Persistent, context-aware instructions injected into the agent's prompt.
    *   **Application:** Can be applied always (`alwaysApply: true`), intelligently based on description, to specific files (globs), or manually via `@mention`.

2.  **Commands** (`.cursor/commands/*.md`)
    *   **Definition:** User-triggered workflows (e.g., `/onboard`) defined as standardized prompts.
    *   **Role:** Replaces the deprecated "Custom Modes" feature.

3.  **Hooks** (`.cursor/hooks.json`)
    *   **Definition:** Scripts that run before or after agent/IDE actions (e.g., `beforeShellExecution`, `afterFileEdit`).
    *   **Scope:** Supports distinct events for both the Agent (Cmd+K) and Tab (inline autocomplete).

4.  **Modes** (Built-in)
    *   **Definition:** High-level operational states: **Agent** (coding), **Ask** (read-only), **Plan** (architecture), and **Debug** (diagnosis).
    *   **Note:** Custom modes are deprecated in favor of Commands.

## Feature Mapping: Claude Code vs. Cursor

| Claude Code Type | Cursor Equivalent | Justification | Caveats |
| :--- | :--- | :--- | :--- |
| **Commands** | **Commands** | Both are user-triggered workflows invoked via `/` (e.g., `/test`). | Cursor Commands are simple markdown prompts; Claude Code Commands can be more complex plugins with executable code. |
| **Agents** | **Rules** (partial) | Cursor Rules can define persona/behavior, which is similar to an Agent identity. | Cursor "Rules" are context injections, not autonomous loops. Claude Agents are distinct sub-personas that can have their own loops and tools. |
| **Skills** | **Rules** | Both are "model-invoked" capabilities. Cursor's "Apply Intelligently" mirrors Claude's autonomous skill selection. | **Pros:** Markdown-based, semantic alignment (teaching the agent). **Cons:** Cursor Rules are text context; they don't natively "bundle" executable scripts like a Plugin/Skill structure might. |
| **Hooks** | **Hooks** | Both intercept lifecycle events to run scripts (e.g., pre-command, post-edit). | Event names differ (e.g., `PostToolUse` vs `afterShellExecution`). Cursor distinguishes between "Main Agent" and "Tab" events. |
| **MCP Servers** | **MCP Servers** | Direct 1:1 mapping. Both use the Model Context Protocol to connect to external tools. | Configuration syntax might differ slightly (e.g., `.mcp.json` vs Cursor settings), but the protocol is identical. |
