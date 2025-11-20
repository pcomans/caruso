# Caruso

**Caruso** is a tool that bridges the gap between AI coding assistants. It allows you to take "steering documentation" (rules, context, capabilities) from **Claude Code Marketplaces** and make them available to **Cursor**.

## Mission

Enable Cursor to consume high-quality, community-curated instructions regardless of their original format.

## Features

*   **Universal Fetcher**: Downloads plugins from local paths, HTTP URLs, or GitHub repositories (e.g., `anthropics/claude-code`).
*   **Smart Adapter**: Automatically converts Claude Plugin Markdown files into **Cursor Rules** (`.mdc`), injecting necessary metadata (like `globs: []`) to ensure they work out of the box.
*   **Package Manager**: Install, remove, and list plugins selectively. Tracks installed plugins via a `caruso.json` manifest.

## Installation

### Option 1: Install from Source (Recommended)

Clone the repository and build the gem:

```bash
git clone https://github.com/pcomans/caruso.git
cd caruso
gem build caruso.gemspec
gem install caruso-*.gem
```

### Option 2: Using `specific_install`

If you have the `specific_install` gem, you can install directly from GitHub:

```bash
gem install specific_install
gem specific_install -l https://github.com/pcomans/caruso.git
```

## Usage

Caruso works like a package manager for your Cursor rules.

### List Available Plugins

See what's available in a marketplace:

```bash
caruso list https://github.com/anthropics/claude-code --target .cursor/rules
```

### Install a Plugin

Fetch a specific plugin and convert it to Cursor rules:

```bash
caruso install frontend-design https://github.com/anthropics/claude-code --target .cursor/rules
```

This will:
1.  Fetch the plugin files.
2.  Convert them to `.mdc`.
3.  Save them to `.cursor/rules/`.
4.  Update `.cursor/rules/caruso.json` to track the installation.

### Remove a Plugin

Remove a plugin from your manifest:

```bash
caruso remove frontend-design --target .cursor/rules
```

### Sync (Legacy)

Fetch ALL plugins from a marketplace (not recommended for large marketplaces):

```bash
caruso sync https://github.com/anthropics/claude-code --target .cursor/rules
```

## Options

*   `--target`, `-t`: Target directory for rules (default: `.cursor/rules`)

## How it works

1.  **Fetch**: Caruso resolves the marketplace URI. If it's a Git repo, it clones it.
2.  **Scan**: It looks for "steering files" within plugins—specifically Markdown files in `commands/`, `agents/`, and `skills/` directories.
3.  **Adapt**: It reads each file, checks for frontmatter, and injects Cursor-specific metadata (like `globs: []` to enable semantic search).
4.  **Manage**: It tracks installed plugins in a `caruso.json` manifest file, allowing for easy updates and removal.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
