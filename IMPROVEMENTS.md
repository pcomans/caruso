# Caruso Gem - Improvement Checklist

Based on the Ruby CLI Gem Best Practices evaluation, here are the remaining tasks to bring Caruso to production-ready standards.

## ✅ Completed

- [x] Fix dependency management - consolidate all dependencies to gemspec
- [x] Update RSpec to 3.13 (was inconsistent between Gemfile and gemspec)
- [x] Add Aruba for professional CLI testing (Note: Cucumber is a transitive dependency but won't be used)
- [x] Add RuboCop to gemspec development dependencies
- [x] Clean up Gemfile to only contain `source` and `gemspec`

> **Note on Cucumber:** Aruba requires Cucumber as a dependency, but it won't be used in this project. We only use Aruba's RSpec integration. This is normal and harmless - Cucumber won't run unless you create `.feature` files.

## 🔴 Critical Priority (Do First)

- [ ] **Add GitHub Actions CI workflow** _(Deferred for later)_
  - Create `.github/workflows/ci.yml`
  - Test on Ruby 3.0, 3.1, 3.2, 3.3
  - Run tests automatically on push/PR
  - Run RuboCop in CI
  - See template in this document below

- [x] **Create CHANGELOG.md**
  - Follow [Keep a Changelog](https://keepachangelog.com/) format
  - Document all existing versions (0.1.0, 0.1.1, 0.1.2, 0.1.3)
  - Add Unreleased section for upcoming changes

- [x] **Add LICENSE.txt file**
  - MIT License with proper copyright attribution
  - Now matches gemspec declaration

## 🟡 High Priority

- [x] **Migrate tests to use Aruba**
  - Updated `spec/spec_helper.rb` to configure Aruba
  - Replaced custom `run_caruso` helper with Aruba's `run_command`
  - Migrated all 4 integration test files to use Aruba API
  - All 32 tests passing with improved isolation and cleaner assertions

- [ ] **Add release automation workflow**
  - Create `.github/workflows/release.yml`
  - Auto-publish to RubyGems when git tag is pushed
  - Add `RUBYGEMS_API_KEY` secret to GitHub repo
  - See template in this document below

- [x] **Create RuboCop configuration**
  - Added `.rubocop.yml` with sensible defaults
  - Configured for Ruby 3.0+ with NewCops enabled
  - Auto-corrected 57 violations (frozen string literals, string quotes, trailing whitespace, etc.)
  - Fixed void context issue in fetcher.rb
  - All 16 files passing with 0 offenses
  - Tests verified passing after corrections

## 🟢 Medium Priority

- [ ] **Add multi-OS testing in CI**
  - Test on Ubuntu, macOS, and Windows
  - Ensures cross-platform compatibility
  - Update CI matrix to include `os: [ubuntu-latest, macos-latest, windows-latest]`

- [ ] **Add bundler-audit for security**
  - Add `bundler-audit` to dev dependencies
  - Add security check step in CI
  - Catches vulnerable dependencies early

- [ ] **Improve release documentation**
  - Add "Releasing" section to README.md
  - Document the release process step-by-step
  - Integrate with new bump tasks and GitHub Actions

- [ ] **Add Dependabot configuration**
  - Create `.github/dependabot.yml`
  - Automatically update dependencies
  - Keep gem secure and up-to-date

## 📝 Nice to Have

- [ ] **Add .editorconfig**
  - Ensures consistent formatting across editors
  - Standardizes indentation, line endings, etc.

- [ ] **Add code coverage reporting**
  - Use SimpleCov for test coverage
  - Add coverage badge to README
  - Consider integrating with Codecov or Coveralls

- [ ] **Add more comprehensive tests**
  - Edge cases for CLI argument parsing
  - Error handling scenarios
  - Network failure simulation

---

## Templates and Migration Guides

### GitHub Actions CI Template

Create `.github/workflows/ci.yml`:

```yaml
name: Ruby CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        ruby-version: ['3.0', '3.1', '3.2', '3.3']

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby-version }}
          bundler-cache: true

      - name: Run tests
        run: bundle exec rake spec

      - name: Run RuboCop
        run: bundle exec rubocop
        if: matrix.ruby-version == '3.3'  # Only run once
```

### GitHub Actions Release Template

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest

    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Build gem
        run: bundle exec rake build

      - name: Publish to RubyGems
        env:
          GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_API_KEY }}
        run: |
          mkdir -p ~/.gem
          echo ":rubygems_api_key: ${GEM_HOST_API_KEY}" > ~/.gem/credentials
          chmod 0600 ~/.gem/credentials
          gem push pkg/*.gem

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: pkg/*.gem
          generate_release_notes: true
```

**Setup:**
1. Go to https://rubygems.org/settings/edit
2. Create an API key
3. Add it to GitHub repo: Settings → Secrets → Actions → New secret
4. Name: `RUBYGEMS_API_KEY`

### CHANGELOG.md Template

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Aruba for professional CLI testing
- RuboCop for code quality

### Changed
- Consolidated all dependencies to gemspec
- Updated RSpec to 3.13

## [0.1.3] - 2025-11-20

### Added
- Improved error handling for missing marketplaces and plugins

### Changed
- Updated caruso gem dependencies

## [0.1.2] - 2025-11-XX

### Added
- Rake tasks for automated semantic version bumping
- Script to automate version bumping

## [0.1.0] - 2025-11-XX

### Added
- Initial release
- Marketplace management (add, list, remove)
- Plugin installation and uninstallation
- Support for Cursor IDE integration
- Configuration management
- Manifest tracking for installed plugins

[Unreleased]: https://github.com/pcomans/caruso/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/pcomans/caruso/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/pcomans/caruso/compare/v0.1.0...v0.1.2
[0.1.0]: https://github.com/pcomans/caruso/releases/tag/v0.1.0
```

### Aruba Migration Guide

**Before (current custom approach):**

```ruby
# spec/spec_helper.rb
def run_caruso(*args)
  cmd = "caruso #{args.join(' ')}"
  output = `#{cmd} 2>&1`
  { output: output, exit_code: $?.exitstatus }
end

# In tests:
result = run_caruso("marketplace add https://github.com/...")
expect(result[:exit_code]).to eq(0)
expect(result[:output]).to include("Added marketplace")
```

**After (with Aruba):**

```ruby
# spec/spec_helper.rb
require 'aruba/rspec'

RSpec.configure do |config|
  config.include Aruba::Api, type: :integration

  # ... rest of config ...
end

# In tests:
RSpec.describe "Marketplace Management", type: :integration do
  it "adds a marketplace" do
    run_command("caruso marketplace add https://github.com/...")

    expect(last_command_started).to be_successfully_executed
    expect(last_command_started).to have_output(/Added marketplace/)
  end

  it "handles errors gracefully" do
    run_command("caruso marketplace remove nonexistent")

    expect(last_command_started).to have_exit_status(0)
    # or check for specific error output
  end
end
```

**Key Aruba Benefits:**
- Automatic command isolation
- Better stderr/stdout separation
- Rich matchers (`be_successfully_executed`, `have_output`)
- Support for interactive commands
- File system helpers (automatic cleanup)
- Environment variable manipulation

**Aruba Useful Methods:**
- `run_command(cmd)` - Run a command
- `last_command_started` - Access last command
- `have_output(content)` - Check output
- `be_successfully_executed` - Check exit code 0
- `have_exit_status(code)` - Check specific exit code
- `stop_all_commands` - Clean up background processes

### .rubocop.yml Starter

```yaml
AllCops:
  TargetRubyVersion: 3.0
  NewCops: enable
  Exclude:
    - 'vendor/**/*'
    - 'pkg/**/*'

# Adjust these to your preferences
Layout/LineLength:
  Max: 120

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - 'Rakefile'

Style/Documentation:
  Enabled: false  # Enable this if you want to enforce class documentation

Style/StringLiterals:
  EnforcedStyle: double_quotes  # or single_quotes, your choice
```

---

## Progress Tracking

Update this section as you complete tasks:

**Completed:** 9/26 tasks (35%)

**Last Updated:** 2025-11-20
