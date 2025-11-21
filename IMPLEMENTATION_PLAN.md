# Implementation Plan: Move Marketplace Cache to ~/.caruso

## Overview

Replace `/tmp/caruso_cache/` with `~/.caruso/marketplaces/` for persistent, tracked marketplace storage following Claude Code's pattern.

**Note:** No backwards compatibility needed - clean break from `/tmp` approach.

## Goals

1. Move marketplace Git checkouts to `~/.caruso/marketplaces/<marketplace-name>/`
2. Add marketplace registry at `~/.caruso/known_marketplaces.json`
3. Track marketplace metadata (URL, location, last updated timestamp)
4. Support optional Git ref/branch pinning
5. Update all tests to use new location

## Directory Structure

```
~/.caruso/
├── known_marketplaces.json          # Marketplace registry (NEW)
└── marketplaces/                    # Git checkouts (NEW)
    ├── skills/                      # Example: anthropics/skills
    │   ├── .git/
    │   ├── marketplace.json
    │   └── ...
    └── custom-marketplace/
        └── ...
```

## Registry Format

`~/.caruso/known_marketplaces.json`:
```json
{
  "skills": {
    "source": "github",
    "url": "https://github.com/anthropics/skills",
    "install_location": "/Users/philipp/.caruso/marketplaces/skills",
    "last_updated": "2025-11-21T10:00:00Z",
    "ref": "main"
  }
}
```

**Source types** (following Claude Code pattern):
- `"github"` - GitHub repository
- `"git"` - Generic Git URL
- `"url"` - Direct marketplace.json URL
- `"local"` - Local file path
- `"directory"` - Local directory path

## Implementation Steps

### Step 1: Create MarketplaceRegistry Class

**File:** `lib/caruso/marketplace_registry.rb`

```ruby
# frozen_string_literal: true

require "json"
require "fileutils"

module Caruso
  class MarketplaceRegistry
    REGISTRY_FILENAME = "known_marketplaces.json"

    def initialize
      @registry_path = File.join(Dir.home, ".caruso", REGISTRY_FILENAME)
    end

    # Enhancement #1: Add source type tracking
    def add_marketplace(name, url, install_location, ref: nil, source: "git")
      data = load_registry
      data[name] = {
        "source" => source,  # github, git, url, local, directory
        "url" => url,
        "install_location" => install_location,
        "last_updated" => Time.now.iso8601,
        "ref" => ref
      }.compact
      save_registry(data)
    end

    def get_marketplace(name)
      data = load_registry
      data[name]
    end

    def update_timestamp(name)
      data = load_registry
      return unless data[name]

      data[name]["last_updated"] = Time.now.iso8601
      save_registry(data)
    end

    def list_marketplaces
      load_registry
    end

    def remove_marketplace(name)
      data = load_registry
      data.delete(name)
      save_registry(data)
    end

    private

    # Enhancement #3: Schema validation
    def validate_marketplace_entry(entry)
      required = ["url", "install_location", "last_updated"]
      missing = required - entry.keys

      unless missing.empty?
        raise Caruso::Error, "Invalid marketplace entry: missing #{missing.join(', ')}"
      end

      # Validate timestamp format
      Time.iso8601(entry["last_updated"])
    rescue ArgumentError
      raise Caruso::Error, "Invalid timestamp format in marketplace entry"
    end

    # Enhancement #4: Registry corruption handling
    def load_registry
      return {} unless File.exist?(@registry_path)

      data = JSON.parse(File.read(@registry_path))

      # Validate each entry
      data.each do |name, entry|
        validate_marketplace_entry(entry)
      end

      data
    rescue JSON::ParserError => e
      handle_corrupted_registry(e)
      {}
    rescue Caruso::Error => e
      warn "Warning: Invalid marketplace entry: #{e.message}"
      warn "Continuing with partial registry data."
      {}
    end

    def handle_corrupted_registry(error)
      corrupted_path = "#{@registry_path}.corrupted.#{Time.now.to_i}"
      FileUtils.cp(@registry_path, corrupted_path)

      warn "Marketplace registry corrupted. Backup saved to: #{corrupted_path}"
      warn "Error: #{error.message}"
      warn "Starting with empty registry."
    end

    def save_registry(data)
      FileUtils.mkdir_p(File.dirname(@registry_path))
      File.write(@registry_path, JSON.pretty_generate(data))
    end
  end
end
```

**Actions:**
- Create file
- Add require in `lib/caruso.rb`

### Step 2: Update Fetcher Class

**File:** `lib/caruso/fetcher.rb`

**Changes:**

1. **Add registry and ref support to initializer:**
```ruby
def initialize(marketplace_url, marketplace_name: nil, ref: nil)
  @marketplace_url = marketplace_url
  @marketplace_name = marketplace_name || extract_name_from_url(marketplace_url)
  @ref = ref
  @registry = MarketplaceRegistry.new
end
```

2. **Update cache_dir method:**
```ruby
def cache_dir
  File.join(Dir.home, ".caruso", "marketplaces", @marketplace_name)
end
```

3. **Update clone_repo method:**
```ruby
def clone_repo
  FileUtils.mkdir_p(File.dirname(cache_dir))

  if Dir.exist?(cache_dir)
    update_cache
  else
    system("git", "clone", @marketplace_url, cache_dir, exception: true)
    checkout_ref if @ref

    @registry.add_marketplace(
      @marketplace_name,
      @marketplace_url,
      cache_dir,
      ref: @ref
    )
  end
end
```

4. **Update update_cache method with SSH error handling (Enhancement #2):**
```ruby
def update_cache
  return unless Dir.exist?(cache_dir)

  Dir.chdir(cache_dir) do
    if @ref
      system("git", "fetch", "origin", @ref, exception: true)
      system("git", "checkout", @ref, exception: true)
    end
    system("git", "pull", "origin", "HEAD", exception: true)
  end

  @registry.update_timestamp(@marketplace_name)
rescue => e
  handle_git_error(e)
end
```

5. **Add handle_git_error method (Enhancement #2):**
```ruby
private

def handle_git_error(error)
  msg = error.message.to_s
  if msg.include?("Permission denied") ||
     msg.include?("publickey") ||
     msg.include?("Could not read from remote")
    raise Caruso::Error, "SSH authentication failed while accessing marketplace.\n" \
                         "Please ensure your SSH keys are configured for #{@marketplace_url}"
  end
  raise error
end
```

6. **Add checkout_ref method:**
```ruby
private

def checkout_ref
  return unless @ref

  Dir.chdir(cache_dir) do
    system("git", "checkout", @ref, exception: true)
  end
end
```

7. **Add extract_name_from_url method:**
```ruby
def extract_name_from_url(url)
  url.split("/").last.sub(".git", "")
end
```

**Actions:**
- Modify existing methods
- Add new private methods
- Add `@registry` instance variable
- Add `@ref` instance variable

### Step 3: Update CLI Commands

**File:** `lib/caruso/cli.rb`

**Changes to Marketplace class:**

1. **Update `add` command:**
```ruby
desc "add URL [NAME]", "Add a marketplace"
method_option :ref, type: :string, desc: "Git branch or tag to checkout"
def add(url, name = nil)
  config_manager = load_config
  target_dir = config_manager.full_target_path

  # Extract name from URL if not provided
  name ||= url.split("/").last.sub(".git", "")

  # Initialize fetcher with ref support
  fetcher = Caruso::Fetcher.new(url, marketplace_name: name, ref: options[:ref])
  fetcher.clone_repo

  manager = Caruso::ManifestManager.new(target_dir)
  manager.add_marketplace(name, url)

  puts "Added marketplace '#{name}' from #{url}"
  puts "  Cached at: #{fetcher.cache_dir}"
  puts "  Ref: #{options[:ref]}" if options[:ref]
end
```

2. **Add `info` command:**
```ruby
desc "info NAME", "Show marketplace information"
def info(name)
  registry = Caruso::MarketplaceRegistry.new
  marketplace = registry.get_marketplace(name)

  unless marketplace
    puts "Error: Marketplace '#{name}' not found in registry."
    puts "Available marketplaces: #{registry.list_marketplaces.keys.join(', ')}"
    return
  end

  puts "Marketplace: #{name}"
  puts "  Source: #{marketplace['source']}" if marketplace['source']
  puts "  URL: #{marketplace['url']}"
  puts "  Location: #{marketplace['install_location']}"
  puts "  Last Updated: #{marketplace['last_updated']}"
  puts "  Ref: #{marketplace['ref']}" if marketplace['ref']

  # Check if directory actually exists
  if Dir.exist?(marketplace['install_location'])
    puts "  Status: ✓ Cached locally"
  else
    puts "  Status: ✗ Cache directory missing"
  end
end
```

3. **Update `remove` command to clean up registry:**
```ruby
desc "remove NAME", "Remove a marketplace"
def remove(name)
  config_manager = load_config
  target_dir = config_manager.full_target_path

  # Remove from manifest
  manager = Caruso::ManifestManager.new(target_dir)
  manager.remove_marketplace(name)

  # Remove from registry
  registry = Caruso::MarketplaceRegistry.new
  marketplace = registry.get_marketplace(name)
  if marketplace
    cache_dir = marketplace['install_location']
    registry.remove_marketplace(name)

    # Optionally delete cache directory
    if Dir.exist?(cache_dir)
      puts "Cache directory still exists at: #{cache_dir}"
      puts "Run 'rm -rf #{cache_dir}' to delete it."
    end
  end

  puts "Removed marketplace '#{name}'"
end
```

**Actions:**
- Add `--ref` option to `add` command
- Create new `info` command
- Update `remove` command to clean registry
- Update all Fetcher instantiations to pass `marketplace_name:`

### Step 4: Update All Fetcher Instantiations

**Files to update:**
- `lib/caruso/cli.rb` (Plugin class methods)

**Pattern:**
```ruby
# OLD
fetcher = Caruso::Fetcher.new(marketplace_url)

# NEW
fetcher = Caruso::Fetcher.new(marketplace_url, marketplace_name: name)
```

**Locations:**
- `Plugin#install` - line ~155
- `Plugin#list` - line ~216
- `Plugin#update_single_plugin` - line ~343
- `Marketplace#update` - lines ~73, ~93

**Actions:**
- Find all `Fetcher.new` calls
- Add `marketplace_name:` parameter
- Get marketplace name from ManifestManager or context

### Step 5: Update Test Infrastructure

**File:** `spec/spec_helper.rb`

**Changes:**

1. **Update cache cleanup:**
```ruby
config.before(:suite) do
  # Clean up ~/.caruso/marketplaces/ for live tests
  caruso_dir = File.join(Dir.home, ".caruso")
  if ENV["RUN_LIVE_TESTS"] && Dir.exist?(caruso_dir)
    # Clean marketplaces and registry for fresh test run
    FileUtils.rm_rf(File.join(caruso_dir, "marketplaces"))
    FileUtils.rm_f(File.join(caruso_dir, "known_marketplaces.json"))
  end
end
```

2. **Add helper methods:**
```ruby
def registry_file
  File.join(Dir.home, ".caruso", "known_marketplaces.json")
end

def load_registry
  return {} unless File.exist?(registry_file)
  JSON.parse(File.read(registry_file))
end

def marketplace_cache_dir(name)
  File.join(Dir.home, ".caruso", "marketplaces", name)
end
```

**Actions:**
- Update cache cleanup location
- Add registry helper methods
- Remove `/tmp/caruso_cache` references

### Step 6: Update Unit Tests

**File:** `spec/unit/fetcher_spec.rb`

**Changes:**
- Update expected cache path from `/tmp/caruso_cache/` to `~/.caruso/marketplaces/`
- Add tests for registry tracking
- Test ref/branch checkout

**New test cases:**
```ruby
describe "registry tracking" do
  it "adds marketplace to registry on clone" do
    # Test registry.add_marketplace is called
  end

  it "updates timestamp on cache update" do
    # Test registry.update_timestamp is called
  end
end

describe "git ref support" do
  it "checks out specific ref when provided" do
    # Test git checkout with ref
  end

  it "uses default branch when no ref provided" do
    # Test git clone without ref
  end
end
```

**File:** `spec/unit/marketplace_registry_spec.rb` (NEW)

**Create comprehensive tests for:**
- `add_marketplace`
- `get_marketplace`
- `update_timestamp`
- `list_marketplaces`
- `remove_marketplace`
- Registry file creation
- JSON parsing errors

### Step 7: Update Integration Tests

**Files:**
- `spec/integration/marketplace_spec.rb`
- `spec/integration/plugin_spec.rb`
- All other integration specs

**Changes:**
- Update assertions about cache directory location
- Add tests for `marketplace info` command
- Add tests for `--ref` option
- Verify registry file is created/updated

**Example changes:**
```ruby
# OLD
expect(Dir.exist?("/tmp/caruso_cache/skills")).to be true

# NEW
expect(Dir.exist?(marketplace_cache_dir("skills"))).to be true
expect(load_registry["skills"]["url"]).to eq("https://github.com/anthropics/skills")
```

**Actions:**
- Find all `/tmp/caruso_cache` references
- Replace with `marketplace_cache_dir` helper
- Add registry assertions where appropriate

### Step 8: Update Documentation

**Files:**
- `README.md` - Mention cache location for transparency
- `CLAUDE.md` - Update Fetcher section with new cache location
- `CHANGELOG.md` - Add breaking change note for next release

**CLAUDE.md changes:**
```markdown
#### Fetcher (`lib/caruso/fetcher.rb`)
...
**Key behavior:**
- Clones Git repos to `~/.caruso/marketplaces/<marketplace-name>/` (persistent)
- Tracks marketplaces in `~/.caruso/known_marketplaces.json` registry
- Supports Git ref/branch pinning via `--ref` option
- Updates timestamp on `marketplace update` commands
...
```

**CHANGELOG.md:**
```markdown
## [Unreleased]

### Changed
- **BREAKING**: Marketplace cache moved from `/tmp/caruso_cache/` to `~/.caruso/marketplaces/`
- Marketplace metadata now tracked in `~/.caruso/known_marketplaces.json`
- Added `caruso marketplace info NAME` command to view marketplace details
- Added `--ref` option to `caruso marketplace add` for Git branch/tag pinning

### Removed
- No automatic migration from `/tmp` - users should re-add marketplaces
```

## Testing Plan

### Unit Tests
1. **MarketplaceRegistry**
   - File creation in `~/.caruso/`
   - JSON read/write operations
   - Timestamp updates
   - Entry removal

2. **Fetcher**
   - Cache directory path resolution
   - Registry tracking on clone
   - Registry timestamp updates
   - Git ref checkout

### Integration Tests
1. **Marketplace Commands**
   - `marketplace add` creates cache and registry entry
   - `marketplace add --ref` checks out specific branch
   - `marketplace info` displays correct metadata
   - `marketplace remove` cleans up registry
   - `marketplace update` updates timestamp

2. **Plugin Commands**
   - Plugin install works with new cache location
   - Plugin list fetches from new cache location
   - Plugin update refreshes cache correctly

3. **Live Tests**
   - Test with real anthropics/skills marketplace
   - Verify cache persistence across commands
   - Verify registry tracking

### Manual Testing
1. Add marketplace and verify `~/.caruso/` directory created
2. Check `known_marketplaces.json` contains correct metadata
3. Run `marketplace info` to see details
4. Install plugin and verify it uses cached marketplace
5. Update marketplace and verify timestamp changes
6. Remove marketplace and verify cleanup

## Implementation Order

1. ✅ Create `lib/caruso/marketplace_registry.rb`
2. ✅ Update `lib/caruso/fetcher.rb` (add registry, change cache path)
3. ✅ Update `lib/caruso.rb` (require new file)
4. ⏸️ Update `lib/caruso/cli.rb` (add --ref, info command, update Fetcher calls) - IN PROGRESS
5. ⏸️ Create `spec/unit/marketplace_registry_spec.rb` - TODO
6. ⏸️ Update `spec/unit/fetcher_spec.rb` - TODO
7. ⏸️ Update `spec/spec_helper.rb` (new cache location, helpers) - TODO
8. ⏸️ Update all integration specs - TODO
9. ⏸️ Run full test suite: `bundle exec rake spec:all` - TODO
10. ⏸️ Update documentation (README, CLAUDE.md, CHANGELOG) - TODO
11. ⏸️ Manual testing with live marketplace - TODO

## Files to Create
- `lib/caruso/marketplace_registry.rb`
- `spec/unit/marketplace_registry_spec.rb`

## Files to Modify
- `lib/caruso.rb`
- `lib/caruso/fetcher.rb`
- `lib/caruso/cli.rb`
- `spec/spec_helper.rb`
- `spec/unit/fetcher_spec.rb`
- `spec/integration/marketplace_spec.rb`
- `spec/integration/plugin_spec.rb`
- `README.md`
- `CLAUDE.md`
- `CHANGELOG.md`

## Breaking Changes

**For Users:**
- Existing `/tmp/caruso_cache/` will NOT be automatically migrated
- Users should re-add marketplaces with `caruso marketplace add`
- New cache location: `~/.caruso/marketplaces/`

**For Developers:**
- `Fetcher.new(url)` now requires `marketplace_name:` parameter
- Tests must use new cache location helpers

## Success Criteria

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Live tests pass with real marketplace
- [ ] `marketplace info` command works
- [ ] `marketplace add --ref` checks out correct branch
- [ ] Registry file created and maintained correctly
- [ ] Cache persists in `~/.caruso/` across runs
- [ ] Documentation updated
- [ ] Manual testing successful

## Rollout

1. Complete implementation on feature branch
2. Run full test suite including live tests
3. Manual testing with anthropics/skills marketplace
4. Update CHANGELOG with breaking changes
5. Bump to 0.2.0 (breaking change = minor version bump)
6. Merge to main
7. Tag release
8. Update README with migration instructions

## Notes

- No backwards compatibility = cleaner implementation
- Users will need to re-add marketplaces (simple one-time step)
- Registry enables future features (marketplace search, version tracking)
- Aligns with Claude Code's architecture for familiarity
