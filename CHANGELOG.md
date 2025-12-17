# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.2] - 2025-12-17

### Fixed
- `marketplace remove` now exits gracefully (code 0) when marketplace is not found, making it idempotent
- Documented idempotent behavior of `marketplace remove` and `plugin uninstall` in README

## [0.6.0] - 2025-11-24

### Security
- **CRITICAL**: Addressed "Uncontrolled data used in path expression" vulnerabilities (CodeQL)
- Introduced `Caruso::SafeFile` for secure file reading with strict path sanitization
- Introduced `Caruso::SafeDir` for secure directory operations (globbing, existence checks)
- Replaced all vulnerable `File` and `Dir` calls in `Adapter` and `Fetcher` with safe alternatives
- Removed redundant string-based path validation in favor of robust `Pathname` canonicalization

### Changed
- `Adapter` now strictly validates file existence and raises errors instead of silently skipping invalid files
- `Fetcher` now filters glob results to ensure they remain within trusted plugin directories


## [0.5.3] - 2025-11-23

### Changed
- Updated GitHub Actions workflow to only trigger on version tags (`v*`) instead of every push to main

### Fixed
- Added debugging to verify RubyGems API token is loaded correctly in CI/CD

### Note
- This release and versions 0.5.0-0.5.2 were used to test and configure continuous deployment to RubyGems and GitHub Packages

## [0.5.2] - 2025-11-23

### Note
- Testing continuous deployment workflow

## [0.5.1] - 2025-11-23

### Note
- Testing continuous deployment workflow

## [0.5.0] - 2025-11-23

### Changed
- Removed automatic `.gitignore` editing - developers now manage their own .gitignore
- Improved `caruso init` output to clearly show which files should be committed vs gitignored
- Updated CLI output to provide recommended .gitignore entries without modifying the file

### Added
- Clear VCS documentation in README explaining which files to track
- Example `.gitignore` snippet in README for easy copy-paste
- Helpful init output showing "(commit this)" and "(add to .gitignore)" labels

### Removed
- `update_gitignore` method from ConfigManager
- Automatic .gitignore modification during initialization

## [0.4.0] - 2025-11-23

### Changed
- **BREAKING**: Marketplace names now read from `marketplace.json` `name` field (required)
- **BREAKING**: Removed optional `NAME` parameter from `marketplace add` command
- Cache directory now based on URL for stability, while marketplace name comes from manifest
- Marketplace.json `name` field is now the authoritative source of truth for marketplace identity

### Fixed
- Marketplace name resolution now matches Claude Code behavior
- `https://github.com/anthropics/claude-code` correctly resolves to `claude-code-plugins` (from manifest)
- Local directory marketplace paths now properly detected and processed

### Added
- `Fetcher#extract_marketplace_name` public method for reading marketplace names from manifest
- Support for directory paths in marketplace URLs (auto-detects `.claude-plugin/marketplace.json`)
- Clear error message when marketplace.json is missing required `name` field
- Comprehensive test fixtures for offline testing (`spec/fixtures/test-marketplace/`, `spec/fixtures/other-marketplace/`)

### Implementation Details
This release aligns with Claude Code specification where marketplace `name` field is required. The implementation follows a clean approach with no defensive fallbacks - if marketplace.json is invalid, it fails with a clear error rather than guessing.

Cache directories remain URL-based (`~/.caruso/marketplaces/claude-code/`) for stability, while logical marketplace names (`claude-code-plugins`) come from the manifest, properly decoupling these concerns.

## [0.3.0] - 2025-11-22

### Changed
- **BREAKING**: Refactored state management to use centralized `ConfigManager`
- **BREAKING**: Split configuration into `caruso.json` (project settings) and `.caruso.local.json` (local state)
- **BREAKING**: Plugins now installed to `.cursor/rules/caruso/` vendor directory
- **BREAKING**: Removed `ManifestManager` class and `.cursor/rules/caruso.json` manifest file
- Updated `init` command to create both config files and add local config to `.gitignore`
- Updated plugin installation to use composite keys (`plugin@marketplace`) for uniqueness
- Improved `uninstall` command to rely on strict file tracking in `.caruso.local.json`

### Added
- Vendor directory strategy for better separation of managed vs user files
- Deterministic file tracking for robust uninstalls
- Support for multiple marketplaces with same plugin names via composite keys

## [0.2.0] - 2025-11-22

### Added
- **MarketplaceRegistry**: New persistent registry at `~/.caruso/known_marketplaces.json` tracking marketplace metadata
- `marketplace info NAME` command to view detailed marketplace information (source, URL, location, last updated, ref, cache status)
- Support for Git ref/branch pinning via `--ref` option on `marketplace add` command
- Marketplace source type tracking (git, github, url, local, directory)
- SSH authentication error detection with helpful error messages
- Registry schema validation with corruption handling and automatic backups
- `CARUSO_TESTING_SKIP_CLONE` environment variable for testing without network access

### Changed
- **BREAKING**: Marketplace cache moved from `/tmp/caruso_cache/` to `~/.caruso/marketplaces/<marketplace-name>/`
- **BREAKING**: No backwards compatibility with previous cache location (clean break)
- Marketplace metadata now persists across system reboots in registry
- Fetcher tracks marketplace updates with timestamps
- Comprehensive test suite with 22 new MarketplaceRegistry unit tests (all passing)

### Fixed
- Made `clone_git_repo` public for CLI access
- Integration tests now skip Git cloning in test mode for reliable offline testing
- All 158 test examples passing (0 failures)

### Implementation Details
This release adopts Claude Code's proven architecture patterns:
- Persistent cache in `~/.caruso/` following XDG-style conventions
- Metadata registry for tracking marketplace state
- Git ref support for version pinning
- Graceful error handling for network and authentication issues

## [0.1.4] - 2025-11-21

### Added
- Support for custom component paths in marketplace entries (`commands`, `agents`, `skills` arrays)
- Comprehensive unit test suite for fetcher with 9 tests covering all component types
- Support for both string and array formats for custom component paths
- File deduplication when paths appear in both default and custom locations

### Changed
- Fetcher now handles custom paths for all component types (commands, agents, skills) consistently
- Custom paths now supplement (rather than replace) default directories as per specification
- Test suite improvements with better success assertions and deterministic timing

### Fixed
- Plugin installation from anthropics/skills marketplace now works correctly
- Integration tests reduced from 17 failures to 0 with proper assertions
- Test isolation issues resolved for more reliable test runs

### Added (Development)
- Aruba for professional CLI testing
- RuboCop as development dependency for code quality
- Comprehensive improvement checklist in IMPROVEMENTS.md

### Changed (Development)
- Consolidated all dependencies to gemspec (removed duplication in Gemfile)
- Updated RSpec to 3.13 for consistency
- Simplified Gemfile to only contain source and gemspec

## [0.1.3] - 2025-11-20

### Changed
- Updated caruso gem metadata and dependencies

### Fixed
- Improved error handling for missing marketplaces
- Enhanced error messages when plugins are not found
- Better error handling throughout plugin operations

## [0.1.2] - 2025-11-20

### Added
- Rake tasks for automated semantic version bumping (`rake bump:patch`, `rake bump:minor`, `rake bump:major`)
- Script to automate version management workflow

### Fixed
- Require `time` in config manager
- Add `lib` directory to executable load path

## [0.1.1] - 2025-11-19

### Added
- Cursor frontmatter now includes `alwaysApply: false` metadata
- Ensures `globs: []` is set in Cursor frontmatter for proper scoping

### Changed
- Updated README mission statement to clarify Claude Code plugin conversion
- Adapter now returns created filenames for proper plugin registration

### Improved
- Enhanced `init` command `--ide` flag tests
- Better plugin network error handling in tests
- Refactored file validation test setup

## [0.1.0] - 2025-11-19

### Added
- Initial release of Caruso gem
- Marketplace management commands (`marketplace add`, `marketplace list`, `marketplace remove`)
- Plugin installation and uninstallation (`plugin install`, `plugin uninstall`, `plugin list`)
- Configuration management with `.caruso.json`
- Manifest tracking for installed plugins
- Support for Cursor IDE integration
- Git-based marketplace cloning and plugin fetching
- Comprehensive integration test suite with RSpec
- Documentation in README and TESTING.md

### Features
- Initialize Caruso in a project with `caruso init --ide=cursor`
- Add multiple marketplaces from GitHub repositories
- Install plugins from configured marketplaces
- Track installed plugins in manifest file
- Automatic conversion of Claude Code plugins to Cursor Rules format
- Plugin metadata preservation and frontmatter injection

[Unreleased]: https://github.com/pcomans/caruso/compare/v0.5.3...HEAD
[0.5.3]: https://github.com/pcomans/caruso/releases/tag/v0.5.3
[0.5.2]: https://github.com/pcomans/caruso/releases/tag/v0.5.2
[0.5.1]: https://github.com/pcomans/caruso/releases/tag/v0.5.1
[0.5.0]: https://github.com/pcomans/caruso/releases/tag/v0.5.0
[0.4.0]: https://github.com/pcomans/caruso/releases/tag/v0.4.0
[0.3.0]: https://github.com/pcomans/caruso/releases/tag/v0.3.0
[0.2.0]: https://github.com/pcomans/caruso/releases/tag/v0.2.0
[0.1.4]: https://github.com/pcomans/caruso/releases/tag/v0.1.4
[0.1.3]: https://github.com/pcomans/caruso/releases/tag/v0.1.3
[0.1.2]: https://github.com/pcomans/caruso/releases/tag/v0.1.2
[0.1.1]: https://github.com/pcomans/caruso/releases/tag/v0.1.1
[0.1.0]: https://github.com/pcomans/caruso/releases/tag/v0.1.0
