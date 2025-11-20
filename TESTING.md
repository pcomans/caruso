# Testing Guide

Comprehensive guide for running and writing tests for Caruso.

## Quick Start

```bash
# Install dependencies
bundle install

# Run offline tests
bundle exec rake spec

# Run all tests (including live marketplace integration)
bundle exec rake spec:all
```

## Test Types

### Offline Tests (Default)

Fast tests that don't require network access. These tests verify:
- Configuration management
- CLI argument parsing
- File structure validation
- Error handling

Run with:
```bash
bundle exec rake spec
# or
bundle exec rspec --tag ~live
```

### Live Tests

Integration tests that interact with the real Claude Code marketplace. These tests:
- Fetch actual marketplace data
- Install real plugins
- Validate file conversion with real content
- Test end-to-end workflows

Run with:
```bash
bundle exec rake spec:all
# or
RUN_LIVE_TESTS=true bundle exec rspec
```

## Test Organization

```
spec/
├── spec_helper.rb              # RSpec configuration and helpers
└── integration/
    ├── init_spec.rb            # Initialization tests
    ├── marketplace_spec.rb     # Marketplace management tests
    ├── plugin_spec.rb          # Plugin installation tests
    └── file_validation_spec.rb # File conversion validation tests
```

## Running Specific Tests

### By File

```bash
# Run only initialization tests
bundle exec rspec spec/integration/init_spec.rb

# Run only marketplace tests
bundle exec rspec spec/integration/marketplace_spec.rb
```

### By Description

```bash
# Run tests matching a pattern
bundle exec rspec -e "initializes Caruso"

# Run all tests in a describe block
bundle exec rspec -e "Marketplace Management"
```

### By Tag

```bash
# Run only live tests
bundle exec rspec --tag live

# Exclude live tests (default)
bundle exec rspec --tag ~live

# Run integration tests
bundle exec rspec --tag integration
```

### By Line Number

```bash
# Run test at specific line
bundle exec rspec spec/integration/init_spec.rb:15
```

## Test Output Formats

### Documentation Format (Default)

```bash
bundle exec rspec --format documentation
```

Output:
```
Caruso Initialization
  caruso init
    ✓ initializes Caruso with cursor IDE
    ✓ creates valid config file
    ✓ shows project directory in output
```

### Progress Format

```bash
bundle exec rspec --format progress
```

Output: `.....F..`

### JSON Format

```bash
bundle exec rspec --format json --out results.json
```

## Writing Tests

### Test Structure

```ruby
require "spec_helper"

RSpec.describe "Feature Name", type: :integration do
  # Runs before each test - creates isolated test directory
  before do
    init_caruso  # Helper method from spec_helper
  end

  describe "specific functionality" do
    it "does something" do
      result = run_caruso("command args")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("expected text")
    end
  end
end
```

### Available Helper Methods

From `spec_helper.rb`:

```ruby
# Directory helpers
test_dir          # Current test directory path

# Command helpers
run_caruso(*args) # Run caruso command, returns {output:, exit_code:}

# File path helpers
config_file       # Path to .caruso.json
manifest_file     # Path to .cursor/rules/caruso.json
mdc_files         # Array of .mdc file paths

# Data helpers
load_config       # Parse and return config JSON
load_manifest     # Parse and return manifest JSON

# Setup helpers
init_caruso(ide: "cursor")          # Initialize Caruso
add_marketplace(url, name = nil)    # Add a marketplace
```

### Example Test

```ruby
it "creates valid config file" do
  init_caruso

  config = load_config
  expect(config["ide"]).to eq("cursor")
  expect(config["target_dir"]).to eq(".cursor/rules")
  expect(config["version"]).to eq("1.0.0")
end
```

### Testing Live Features

Mark tests that require network access:

```ruby
describe "caruso plugin install", :live do
  before do
    skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]
  end

  it "installs a plugin" do
    result = run_caruso("plugin install some-plugin@claude-code")
    expect(result[:exit_code]).to eq(0)
  end
end
```

## Test Isolation

Each test runs in its own isolated temporary directory:

```ruby
RSpec.configure do |config|
  config.around(:each) do |example|
    Dir.mktmpdir("caruso-test-") do |dir|
      @test_dir = dir
      Dir.chdir(dir) do
        example.run
      end
    end
  end
end
```

Benefits:
- ✓ No test pollution
- ✓ Automatic cleanup
- ✓ Safe to run in parallel
- ✓ Can test filesystem operations

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Run offline tests
        run: bundle exec rake spec

      - name: Run all tests
        run: bundle exec rake spec:all
        env:
          RUN_LIVE_TESTS: true
```

## Debugging Tests

### Verbose Output

```bash
bundle exec rspec --format documentation --backtrace
```

### Debugging a Failing Test

```bash
# Run only the failing test
bundle exec rspec spec/integration/init_spec.rb:15

# See full backtrace
bundle exec rspec --backtrace

# Use binding.pry (if pry is installed)
# Add to test:
require 'pry'; binding.pry
```

### Inspect Test Directory

Tests run in temporary directories that are automatically cleaned up. To inspect:

```ruby
it "creates files" do
  init_caruso

  # Print test directory for manual inspection
  puts "Test dir: #{test_dir}"

  # Keep directory by sleeping (then Ctrl+C to inspect)
  # sleep 60

  # Or copy files elsewhere
  FileUtils.cp_r(test_dir, "/tmp/debug-test")
end
```

## Test Coverage

Current coverage:

### Initialization (7 tests)
- ✓ Basic initialization
- ✓ Config file validation
- ✓ Double-init prevention
- ✓ Invalid IDE rejection
- ✓ Missing flag handling
- ✓ Specific directory initialization
- ✓ Commands without init

### Marketplace Management (9 tests)
- ✓ Add marketplace (GitHub URL)
- ✓ Add with custom name
- ✓ URL parsing (.git extension)
- ✓ List empty marketplaces
- ✓ List configured marketplaces
- ✓ Remove marketplace
- ✓ Manifest structure
- ✓ JSON validity
- ✓ Multiple marketplaces

### Plugin Management (11 tests - requires live)
- ✓ List available plugins
- ✓ Install with explicit marketplace
- ✓ Install with implicit marketplace
- ✓ Multiple marketplace error
- ✓ Uninstall plugin
- ✓ Installation status tracking
- ✓ Non-existent plugin handling
- ✓ Non-existent marketplace handling
- ✓ Manifest updates
- ✓ .mdc file creation
- ✓ Network error handling

### File Validation (11 tests - requires live)
- ✓ .mdc file structure
- ✓ Frontmatter presence
- ✓ Globs metadata injection
- ✓ Content preservation
- ✓ File tracking accuracy
- ✓ No orphaned files
- ✓ Naming conventions
- ✓ Manifest structure
- ✓ Config file structure
- ✓ Plugin metadata completeness
- ✓ Timestamp formats

**Total: 38 integration tests**

## Performance

### Test Speed

- **Offline tests**: ~2-5 seconds
- **Live tests**: ~30-60 seconds (depends on network and marketplace size)

### Parallel Execution

Tests are isolated and can run in parallel:

```bash
bundle exec rspec --format progress --order random
```

## Troubleshooting

### Tests Fail Locally

1. **Check Ruby version**: `ruby --version` (requires >= 3.0)
2. **Update dependencies**: `bundle install`
3. **Clean old test artifacts**: `rm -rf /tmp/caruso-test-*`
4. **Check Caruso is built**: `gem build caruso.gemspec && gem install caruso-*.gem`

### Live Tests Fail

1. **Check network connection**
2. **Verify marketplace URL is accessible**: `curl -I https://github.com/anthropics/claude-code`
3. **Check for rate limiting**
4. **Verify Git is installed**: `git --version`

### Tests Timeout

Increase timeout in spec_helper or skip slow tests:

```bash
bundle exec rspec --tag ~slow
```

## Best Practices

1. **Keep tests isolated** - Each test should be independent
2. **Use descriptive names** - Clear test descriptions help debugging
3. **Test behavior, not implementation** - Focus on what, not how
4. **Keep tests fast** - Mock external dependencies when possible
5. **Use before/after hooks wisely** - Don't overuse shared setup
6. **Tag appropriately** - Use :live, :slow, etc. for categorization
7. **Clean up resources** - Handled automatically by test isolation
8. **Document complex tests** - Add comments for non-obvious assertions

## Contributing

When adding new features:

1. Write tests first (TDD)
2. Ensure offline tests pass: `bundle exec rake spec`
3. Run live tests: `bundle exec rake spec:all`
4. Update this guide if adding new test patterns
5. Keep test coverage above 80%

## Resources

- [RSpec Documentation](https://rspec.info/)
- [Better Specs](https://www.betterspecs.org/)
- [Effective Testing with RSpec 3](https://pragprog.com/titles/rspec3/effective-testing-with-rspec-3/)
