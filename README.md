# Caruso

**Caruso** is a tool that bridges the gap between AI coding assistants. It allows you to take "steering documentation" (rules, context, capabilities) from **Claude Code Marketplaces** and make them available to other agents like **Cursor** or **Antigravity**.

## Mission

Enable any coding agent to consume high-quality, community-curated instructions regardless of their original format.

## Features

*   **Universal Fetcher**: Downloads plugins from local paths, HTTP URLs, or GitHub repositories (e.g., `anthropics/claude-code`).
*   **Smart Adapter**: Automatically converts Claude Plugin Markdown files into **Cursor Rules** (`.mdc`), injecting necessary metadata (like `globs: ["*"]`) to ensure they work out of the box.
*   **Simple CLI**: A single command to sync everything.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'caruso'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install caruso

## Usage

### Syncing from a Marketplace

The primary command is `sync`. It fetches plugins from a marketplace and saves them to your target directory.

**From a GitHub Repository (e.g., the official Claude Code Marketplace):**

```bash
caruso sync https://github.com/anthropics/claude-code --target .cursor/rules
```

**From a local file:**

```bash
caruso sync ./path/to/marketplace.json --target .cursor/rules
```

**Options:**

*   `--target`, `-t`: Target directory for rules (default: `.cursor/rules`)
*   `--agent`, `-a`: Target agent format (default: `cursor`)

### How it works

1.  **Fetch**: Caruso resolves the marketplace URI. If it's a Git repo, it clones it. It then finds all `marketplace.json` and referenced plugins.
2.  **Scan**: It looks for "steering files" within plugins—specifically Markdown files in `commands/`, `agents/`, and `skills/` directories.
3.  **Adapt**: It reads each file, checks for frontmatter, and injects agent-specific metadata (like `globs` for Cursor) if missing.
4.  **Save**: It writes the adapted files to your target directory with the correct extension (e.g., `.mdc`).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
