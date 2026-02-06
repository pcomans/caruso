# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mission

Caruso is a Ruby gem CLI that bridges the gap between AI coding assistants. It fetches "steering documentation" (commands, agents, skills) from Claude Code Marketplaces and converts them to formats compatible with other IDEs, currently Cursor.

## Source of Truth: Official Documentation

**IMPORTANT:** The authoritative sources for Claude Code and Cursor specifications are the official docs. Reference links are in `/Users/philipp/code/caruso/reference/`:

- `claude_code.md` - Links to official Claude Code docs (hooks, plugins, marketplaces, skills)
- `cursor.md` - Links to official Cursor docs (hooks, modes, rules, commands)

When implementing features or fixing bugs, **always fetch the latest docs from these official URLs**. If the implementation conflicts with the official docs, the docs are correct and the code should be updated to match.

## Development Commands

### Build and Install
```bash
# Build the gem
gem build caruso.gemspec

# Install locally
gem install caruso-*.gem

# Verify installation
caruso version
```

### Testing
```bash
# Run offline tests only (default)
bundle exec rake spec
# or
bundle exec rspec

# Run all tests including live marketplace integration
bundle exec rake spec:all
# or
RUN_LIVE_TESTS=1 bundle exec rspec

# Run only live tests
bundle exec rake spec:live

# Run specific test file
bundle exec rspec spec/integration/plugin_spec.rb

# Run specific test
bundle exec rspec spec/integration/plugin_spec.rb:42
```

**Important:** Live tests (tagged with `:live`) interact with real marketplaces (anthropics/skills) and require network access. They can be slow (~7 minutes). Marketplace cache is stored in `~/.caruso/marketplaces/`. Integration tests set `CARUSO_TESTING_SKIP_CLONE=true` to skip Git cloning for fast offline testing.

### Linting
```bash
bundle exec rubocop
```

### Version Management
```bash
# Bump patch version (0.1.3 → 0.1.4)
bundle exec rake bump:patch

# Bump minor version (0.1.4 → 0.2.0)
bundle exec rake bump:minor

# Bump major version (0.1.4 → 1.0.0)
bundle exec rake bump:major
```

## Architecture

### Core Pipeline: Fetch → Adapt → Track

Caruso follows a three-stage pipeline for plugin management:

1. **Fetch** (`Fetcher`) - Clones Git repositories, resolves marketplace.json, finds plugin markdown files
2. **Adapt** (`Adapter`) - Converts Claude Code markdown to target IDE format with metadata injection
3. **Track** (`ConfigManager`) - Records installations in `caruso.json` and `.caruso.local.json`

### Key Components

#### ConfigManager (`lib/caruso/config_manager.rb`)
Manages configuration and state. Splits data between:

**1. Project Config (`caruso.json`)**
- `ide`: Target IDE (currently only "cursor" supported)
- `target_dir`: Where to write converted files (`.cursor/rules` for Cursor)
- `marketplaces`: Name → URL mapping
- `plugins`: Name → metadata (marketplace source)
- `version`: Config schema version

**2. Local Config (`.caruso.local.json`)**
- `installed_files`: Plugin Name → Array of file paths
- `initialized_at`: Timestamp

Must run `caruso init --ide=cursor` before other commands. ConfigManager handles loading/saving both files and ensures `.caruso.local.json` is gitignored.

#### MarketplaceRegistry (`lib/caruso/marketplace_registry.rb`)
Manages persistent marketplace metadata registry at `~/.caruso/known_marketplaces.json`. Contains:
- `source`: Marketplace type (git, github, url, local, directory)
- `url`: Original marketplace URL
- `install_location`: Local cache path (e.g., `~/.caruso/marketplaces/skills/`)
- `last_updated`: ISO8601 timestamp of last update
- `ref`: Optional Git ref/branch/tag for pinning

**Key features:**
- **Schema validation**: Validates required fields and timestamp format on load
- **Corruption handling**: Backs up corrupted registry to `.corrupted.<timestamp>` and continues with empty registry
- **Timestamp tracking**: Updates `last_updated` when marketplace cache is refreshed
- **Source type tracking**: Enables future support for multiple marketplace sources

This registry enables persistent tracking of marketplace state across reboots, unlike the previous `/tmp` approach.

#### Fetcher (`lib/caruso/fetcher.rb`)
Resolves and fetches plugins from marketplaces. Supports:
- GitHub repos: `https://github.com/owner/repo`
- Git URLs: Any Git-cloneable URL
- Local paths: `./path/to/marketplace` or `./path/to/marketplace.json`

**Key behavior:**
- Clones Git repos to `~/.caruso/marketplaces/<marketplace-name>/` (persistent across reboots)
- Registers marketplace metadata in `~/.caruso/known_marketplaces.json` (via MarketplaceRegistry)
- Supports Git ref/branch pinning for version control
- Reads `marketplace.json` to find available plugins
- Supports custom component paths: plugins can specify `commands`, `agents`, `skills` arrays pointing to non-standard locations
- Scans standard directories: `{commands,agents,skills}/**/*.md`
- Excludes README.md and LICENSE.md files
- **Custom paths supplement (not replace) default directories** - this is critical
- Detects SSH authentication errors and provides helpful error messages

**marketplace.json structure:**
```json
{
  "plugins": [
    {
      "name": "document-skills",
      "description": "Work with documents",
      "source": "./document-skills",
      "skills": ["./document-skills/xlsx", "./document-skills/pdf"]
    }
  ]
}
```

The `commands`, `agents`, and `skills` fields accept:
- String: `"./custom/path"`
- Array: `["./path1", "./path2"]`

Both files and directories are supported. Fetcher recursively finds all `.md` files.

#### Adapter (`lib/caruso/adapter.rb`)
Converts Claude Code markdown files to target IDE format. For Cursor:
- Renames `.md` → `.mdc`
- Injects YAML frontmatter with required Cursor metadata:
  - `globs: []` - Enables semantic search (Apply Intelligently)
  - `alwaysApply: false` - Prevents auto-application to every chat
  - `description` - Preserved from original or generated
- Preserves existing frontmatter if present, adds missing fields
- Handles special case: `SKILL.md` → named after parent directory to avoid collisions

Returns array of created filenames (not full paths) for manifest tracking.

#### CLI (`lib/caruso/cli.rb`)
Thor-based CLI with nested commands:
- `caruso init [PATH] --ide=cursor`
- `caruso marketplace add URL [--ref=BRANCH]` - Add marketplace with optional Git ref pinning (name comes from marketplace.json)
- `caruso marketplace list` - List configured marketplaces
- `caruso marketplace remove NAME` - Remove marketplace from manifest and registry
- `caruso marketplace update [NAME]` - Update marketplace cache (all if no name given)
- `caruso marketplace info NAME` - Show detailed marketplace information from registry
- `caruso plugin install|uninstall|list|update|outdated`

**Important patterns:**
- All commands except `init` require existing `caruso.json` (enforced by `load_config` helper)
- Plugin install format: `plugin@marketplace` or just `plugin` (if only one marketplace configured)
- Update commands refresh marketplace cache (git pull) before fetching latest plugin files
- Marketplace add eagerly clones repos unless `CARUSO_TESTING_SKIP_CLONE` env var is set (used in tests)
- **Marketplace names for GitHub sources are derived as `owner-repo`** (matching Claude Code behavior). For non-GitHub sources, names come from marketplace.json `name` field (required). No custom names allowed.
- Errors use descriptive messages with suggestions (e.g., "use 'caruso marketplace add <url>'")

### Data Flow Example

User runs: `caruso plugin install document-skills@skills`

1. **CLI** parses command, loads config from `caruso.json`
2. **ConfigManager** looks up marketplace "skills" URL
3. **Fetcher** clones/updates marketplace repo to `~/.caruso/marketplaces/skills/`
4. **Fetcher** registers/updates marketplace metadata in MarketplaceRegistry
5. **Fetcher** reads `marketplace.json`, finds document-skills plugin
6. **Fetcher** scans standard directories + custom paths from `skills: [...]` array
7. **Fetcher** returns list of `.md` file paths
8. **Adapter** converts each file: adds frontmatter, renames to `.mdc`, writes to `.cursor/rules/caruso/`
9. **Adapter** returns created filenames
10. **ConfigManager** records plugin in `caruso.json` and files in `.caruso.local.json`
11. **CLI** prints success message

### Testing Architecture

Uses **Aruba** for CLI integration testing. Test structure:
- `spec/unit/` - Direct class testing (ConfigManager, Fetcher logic)
- `spec/integration/` - Full CLI workflow tests via Aruba subprocess execution

**Aruba helpers in spec_helper.rb:**
- `init_caruso(ide: "cursor")` - Runs init command with success assertion
- `add_marketplace(url, name)` - Adds marketplace with success assertion
- `config_file`, `manifest_file`, `load_config`, `load_manifest` - File access helpers
- `mdc_files` - Glob for `.cursor/rules/*.mdc` files

**Critical testing pattern:**
```ruby
run_command("caruso plugin install foo@bar")
expect(last_command_started).to be_successfully_executed  # Always verify success first!
manifest = load_manifest  # Then access results
```

**Why this matters:** If command fails, manifest might not exist (nil). Always assert success before accessing command results to prevent confusing test failures.

**Live tests:**
- Tagged with `:live` metadata
- Run only when `RUN_LIVE_TESTS=1` environment variable set
- Interact with real anthropics/skills marketplace
- Cache cleared once at test suite start for performance
- Use `sleep` for timestamp resolution (not `Timecop`) because Caruso runs as subprocess

**Timecop limitation:** Cannot mock time in subprocesses. When testing timestamp updates in plugin reinstall scenarios, use `sleep 1.1` (ISO8601 has second precision) instead of `Timecop.travel`.

## Marketplace Compatibility

Caruso supports the Claude Code marketplace specification with custom component paths:

- Standard structure: `{commands,agents,skills}/**/*.md`
- Custom paths: `"commands": ["./custom/path"]` in marketplace.json
- Both string and array formats supported
- Custom paths **supplement** defaults (they don't replace)

Example: anthropics/skills marketplace uses custom paths:
```json
{
  "name": "document-skills",
  "skills": ["./document-skills/xlsx", "./document-skills/pdf"]
}
```

Fetcher will scan both:
1. `./document-skills/skills/**/*.md` (default)
2. `./document-skills/xlsx/**/*.md` (custom)
3. `./document-skills/pdf/**/*.md` (custom)

Results are deduplicated with `.uniq`.

## Release Process

1. Run tests: `bundle exec rake spec:all`
2. Bump version: `bundle exec rake bump:patch` (or minor/major)
3. Update CHANGELOG.md with release notes
4. Commit: `git commit -m "chore: Bump version to X.Y.Z"`
5. Tag: `git tag -a vX.Y.Z -m "Release version X.Y.Z"`
6. Build: `gem build caruso.gemspec`
7. Install and test: `gem install caruso-X.Y.Z.gem && caruso version`
8. Push: `git push origin main --tags`

Version is managed in `lib/caruso/version.rb`.

# Rules
- **NEVER force-push.** No `git push --force`, `git push --force-with-lease`, or `git push origin <tag> --force`. If a tag or commit was pushed wrong, fix forward with a new version.

# Memory
- The goal is a clean, correct, consistent implementation. Never implement fallbacks that hide errors or engage in defensive programming.
- **Idempotency**: Removal commands (`marketplace remove`, `plugin uninstall`) are designed to be idempotent. They exit successfully (0) if the target does not exist. This is intentional for automation friendliness and is NOT considered "hiding errors".
- Treat the vendor directory .cursor/rules/caruso/ as a build artifact