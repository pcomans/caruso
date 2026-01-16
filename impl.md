# Implementation Plan - Evolve Caruso for Claude Code Support

Refining caruso to provide robust support for Claude Code's Commands, Skills, and Hooks, adapting them specifically for the Cursor environment.

## Goal Description

The goal is to transform caruso from a simple markdown copier into a smart adapter that bridges the gap between Claude Code's plugin architecture and Cursor's steering mechanisms. This involves:

- **Skills**: deeply adapting skills by not just copying the markdown, but also bundling associated scripts/ and making them executable.
- **Commands**: mapping Claude Code commands to Cursor's new .cursor/commands/ structure.
- **Hooks**: translating Claude Code's hooks/hooks.json events into Cursor's .cursor/hooks.json format.
- **Fetcher**: upgrading the fetcher to retrieve auxiliary files (scripts, configs) beyond just `.md` files.

## User Review Required

> [!NOTE]
> **Script Execution Security:** We will trust the "trusted workspace" model of Cursor. This means we will automatically fetch scripts and make them executable (`chmod +x`). Users relying on Caruso are expected to audit the plugins they install, similar to how they would audit an npm package.

## Proposed Changes

### 1. Fetcher Upgrades (`lib/caruso/fetcher.rb`)

The current fetcher is overly focused on *.md files. We need to broaden it to fetch associated resources using an Additive Strategy.

#### [MODIFY] `fetcher.rb`

- **Additive Discovery**: In `fetch_plugin`:
  - **Logic**:
    1. **Check Manifest**: Look for `skills` field in `plugin` object (string or array).
    2. **If Present**: Recursively fetch all files in those specific paths.
    3. **If Absent**: Fallback to scanning the default `skills/` directory (recursively).
    4. **Other Components**: Continue scanning for `commands/`, `agents/`, `hooks/` as before.

- **Support Resource Types**:
  - `skills`: Fetch `SKILL.md` AND recursively fetch `scripts/` directories if found within the skill path.

  - `hooks`: Fetch the `hooks/hooks.json` file (or inline config).
  - `commands`: Fetch markdown files.
  - `agents`: Fetch markdown files.

### 2. Adapter Architecture Refactor (`lib/caruso/`)

Refactor the monolithic Adapter class into a dispatcher with specialized strategies.

#### [MODIFY] `adapter.rb`
Change `Adapter#adapt` to identify the component type and delegate to the appropriate sub-adapter.

#### [NEW] `adapters/base.rb`
Shared logic for file writing, frontmatter injection, and path sanitization.

#### [NEW] `adapters/skill_adapter.rb`
**Input:** `skills/<name>/SKILL.md` + `skills/<name>/scripts/*`
**Output:**
- `.cursor/rules/caruso/<marketplace>/<skill>/<skill>.mdc` (The rule)
- `.cursor/scripts/caruso/<marketplace>/<skill>/*` (The scripts)

**Logic:**
1. Copy scripts to `.cursor/scripts/caruso/<marketplace>/<skill>/`.
2. Ensure scripts are executable (`chmod +x`).
3. **Paths:** Do NOT rewrite paths in the markdown (to avoid messiness).
4. **Context:** Inject a location hint into the Rule's frontmatter `description` or prepended content:
   ```yaml
   description: Imported from <skill>. Scripts located at: .cursor/scripts/caruso/<marketplace>/<skill>/
   ```

#### [NEW] `adapters/agent_adapter.rb`
**Input:** `agents/<name>.md`
**Output:** `.cursor/rules/caruso/<marketplace>/agents/<name>.mdc`
**Logic:**
- Copy content.
- Wrap as a "Persona" rule if needed, or simple markdown rule.

#### [NEW] `adapters/command_adapter.rb`
**Input:** `commands/<name>.md`
**Output:** `.cursor/commands/<name>.md`
**Logic:**
- Basic markdown copy.
- Frontmatter cleanup (remove Claude-specific fields if necessary).

#### [NEW] `adapters/hook_adapter.rb`
**Input:** `hooks/hooks.json`
**Output:** Merged/Updated `.cursor/hooks.json`
**Logic:**
- Parse source JSON.
- Map events (e.g., `PostToolUse` -> `afterFileEdit`).
- Write/Merge into project's `hooks.json`.

### 3. CLI Updates (`lib/caruso/cli.rb`)

#### [MODIFY] `cli.rb`
- Update `install` command to handle multiple file types returned by the upgraded fetcher.
- Ensure `uninstall` cleans up the directories (scripts, etc) correctly.

## Verification Plan

### Automated Tests
- **Fetcher Tests**: Mock a plugin structure with `scripts/` and verify they are returned in the file list.
- **Adapter Tests**:
  - Feed a `SKILL.md` + script to `SkillAdapter` and verify output structure and chmod.
  - Feed a `hooks.json` and verify the event translation.

### Manual Verification
- **Skills**: Install a plugin with a script (e.g., a "linter" skill).
  - Verify file exists at `.cursor/scripts/.../lint.sh`.
  - Verify it is executable.
  - Verify the Rule markdown is present.
- **Commands**: Install a command plugin.
  - Verify file exists at `.cursor/commands/...`.
  - Test running the command in Cursor (Cmd+K `/command`).
- **Hooks**: Install a hook plugin.
  - Check `.cursor/hooks.json` contains the mapped event.