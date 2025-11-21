# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/pcomans/caruso/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/pcomans/caruso/releases/tag/v0.1.4
[0.1.3]: https://github.com/pcomans/caruso/releases/tag/v0.1.3
[0.1.2]: https://github.com/pcomans/caruso/releases/tag/v0.1.2
[0.1.1]: https://github.com/pcomans/caruso/releases/tag/v0.1.1
[0.1.0]: https://github.com/pcomans/caruso/releases/tag/v0.1.0
