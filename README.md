# Caruso

**Caruso** is a tool that bridges the gap between AI coding assistants. It allows you to take "steering documentation" (rules, context, capabilities) from **Claude Code Marketplaces** and make them available to **Cursor**.

## Mission

Enable Cursor to consume Claude Code plugins from marketplaces by converting them to Cursor-compatible rules.

## Features

*   **One-time Configuration**: Initialize once with `caruso init --ide=cursor` and all commands automatically use the right settings.
*   **Universal Fetcher**: Downloads plugins from local paths, HTTP URLs, or GitHub repositories.
*   **Smart Adapter**: Automatically converts Claude Plugin Markdown files into **Cursor Rules** (`.mdc`), injecting necessary metadata (`globs: []`, `alwaysApply: false`) to ensure they work out of the box.
*   **Package Manager**: Install, uninstall, and list plugins selectively. Tracks project configuration in `caruso.json` and local state in `.caruso.local.json`.

## Installation

### Install from RubyGems

```bash
gem install caruso
```

Verify the installation:

```bash
caruso version
```

### Install from Source (Development)

For development or testing unreleased features:

```bash
git clone https://github.com/pcomans/caruso.git
cd caruso
gem build caruso.gemspec
gem install caruso-*.gem
```

## Usage

Caruso mirrors the Claude Code CLI structure, providing a familiar interface for marketplace and plugin management.

### Getting Started

Before using Caruso, initialize it in your project directory:

```bash
# Navigate to your project
cd /path/to/your/project

# Initialize for Cursor (currently the only supported IDE)
caruso init --ide=cursor
```

This creates a `caruso.json` config file for project settings and `.caruso.local.json` for local state. You only need to do this once per project.

**What happens during init:**
- Creates `caruso.json` and `.caruso.local.json` in your project root
- Configures target directory (`.cursor/rules` for Cursor)
- All subsequent commands automatically use this configuration

**Version Control:**
- ✅ **Commit to VCS:** `caruso.json` - Contains project plugin configuration (shared with team)
- ❌ **Add to .gitignore:** `.caruso.local.json` - Contains local state (machine-specific)
- ❌ **Add to .gitignore:** `.cursor/rules/caruso/` - Generated plugin files (build artifacts)

Add these to your `.gitignore`:
```
# Caruso
.caruso.local.json
.cursor/rules/caruso/
```

### Marketplace commands

Manage plugin marketplaces to discover and install plugins from different sources.

#### Add a marketplace

Add the official Claude Code marketplace:

```bash
caruso marketplace add https://github.com/anthropics/claude-code
```

The marketplace name is automatically read from the `marketplace.json` file in the repository (in this case, `claude-code-plugins`).

Supported marketplace sources:
- **GitHub repositories**: `https://github.com/owner/repo`
- **Git repositories**: Any Git URL (e.g., `https://gitlab.com/company/plugins.git`)
- **Local paths**: `./path/to/marketplace` or `./path/to/marketplace.json`

#### List marketplaces

View all configured marketplaces:

```bash
caruso marketplace list
```

#### Remove a marketplace

Remove a marketplace from your configuration:

```bash
caruso marketplace remove claude-code
```

<Warning>
  Removing a marketplace will not automatically uninstall plugins from that marketplace. Uninstall plugins first if you want to remove them.
</Warning>

### Plugin commands

Discover, install, and manage plugins from configured marketplaces.

#### List available plugins

See all available plugins across configured marketplaces:

```bash
caruso plugin list
```

This shows:
- All plugins from each marketplace
- Installation status for each plugin
- Plugin descriptions

#### Install a plugin

Install from a specific marketplace:

```bash
caruso plugin install frontend-design@claude-code
```

Install when only one marketplace is configured (marketplace name is optional):

```bash
caruso plugin install frontend-design
```

**What happens during installation:**
1. Fetches plugin files from the marketplace
2. Scans `commands/`, `agents/`, and `skills/` directories
3. Converts Claude Plugin Markdown to Cursor Rules (`.mdc` format)
4. Injects Cursor-specific metadata (`globs: []`, `alwaysApply: false`)
5. Saves converted files to `.cursor/rules/caruso/` (vendor directory)
6. Updates `.caruso.local.json` with installed file list

#### Uninstall a plugin

Remove a plugin and update the manifest:

```bash
caruso plugin uninstall frontend-design
```

### Complete workflow example

Here's a complete workflow from initialization to plugin installation:

```bash
# 1. Initialize Caruso in your project
caruso init --ide=cursor

# 2. Add the official Claude Code marketplace
caruso marketplace add https://github.com/anthropics/claude-code

# 3. Browse available plugins
caruso plugin list

# 4. Install a plugin
caruso plugin install frontend-design@claude-code

# 5. Your Cursor rules are now updated!
# 5. Your Cursor rules are now updated!
# Files are in .cursor/rules/caruso/ and tracked in .caruso.local.json
```

## CLI Reference

### Initialization

```bash
caruso init [PATH] --ide=IDE
```

Initialize Caruso in a directory. Creates `caruso.json` and `.caruso.local.json`.

**Arguments:**
- `PATH` - Project directory (optional, defaults to current directory)

**Options:**
- `--ide` - Target IDE (required). Currently supported: `cursor`

**Examples:**
```bash
caruso init --ide=cursor                    # Initialize current directory
caruso init . --ide=cursor                  # Explicit current directory
caruso init /path/to/project --ide=cursor   # Initialize specific directory
```

### Marketplace Management

```bash
caruso marketplace add URL             # Add a marketplace (name from marketplace.json)
caruso marketplace list                # List configured marketplaces
caruso marketplace remove NAME         # Remove a marketplace
```

### Plugin Management

```bash
caruso plugin list                     # List available and installed plugins
caruso plugin install PLUGIN[@MARKETPLACE]  # Install a plugin
caruso plugin uninstall PLUGIN         # Uninstall a plugin
```

### Version

```bash
caruso version                         # Print Caruso version
```

## How it works

1.  **Init**: Creates `caruso.json` and `.caruso.local.json` (one-time setup)
2.  **Fetch**: Resolves marketplace URI and clones Git repositories if needed
3.  **Scan**: Finds "steering files" in `commands/`, `agents/`, and `skills/` directories
4.  **Adapt**: Converts Claude Plugin Markdown to Cursor Rules (`.mdc`) with metadata injection
5.  **Manage**: Tracks installations in `.caruso.local.json` and project plugins in `caruso.json`

## Development

After checking out the repo:

```bash
# Install dependencies
bundle install

# Build and install the gem locally
gem build caruso.gemspec
gem install caruso-*.gem

# Run tests
bundle exec rake spec
```

### Testing

Caruso includes comprehensive test coverage with RSpec integration tests.

#### Run Tests

**Quick test (offline tests only):**
```bash
bundle exec rake spec
```

**All tests including live marketplace integration:**
```bash
bundle exec rake spec:all
# or
RUN_LIVE_TESTS=true bundle exec rspec
```

**Only live tests:**
```bash
bundle exec rake spec:live
```

**Run specific test file:**
```bash
bundle exec rspec spec/integration/init_spec.rb
```

#### Test Structure

Integration tests are organized in `spec/integration/`:

- **init_spec.rb** - Initialization and configuration tests
- **marketplace_spec.rb** - Marketplace management (add, list, remove)
- **plugin_spec.rb** - Plugin installation and uninstallation
- **file_validation_spec.rb** - .mdc file structure and manifest validation

#### Live Tests

Tests marked with `:live` tag require network access and interact with the real Claude Code marketplace:
- Plugin installation
- File conversion validation
- Marketplace fetching

To run live tests, set `RUN_LIVE_TESTS=true` or use `rake spec:all`.

#### Test Coverage

✓ **Initialization**
  - Config file creation and validation
  - IDE selection
  - Double-init prevention
  - Error handling

✓ **Marketplace Management**
  - Adding marketplaces (GitHub, Git, local)
  - Listing marketplaces
  - Removing marketplaces
  - Manifest structure

✓ **Plugin Management**
  - Listing available plugins
  - Installing plugins (explicit/implicit marketplace)
  - Uninstalling plugins
  - Installation status tracking

✓ **File Validation**
  - .mdc file structure (frontmatter, globs, content)
  - File naming conventions
  - Manifest accuracy
  - No orphaned files

For detailed testing documentation, see [TESTING.md](TESTING.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
