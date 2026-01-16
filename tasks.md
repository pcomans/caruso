# Implementation Tasks: Skill Support Refactor

## Phase 1: Foundation (Refactor)
- [x] Create `lib/caruso/adapters/base.rb` (Base class for shared logic)
- [x] Create `lib/caruso/adapters/dispatcher.rb` (Dispatcher to select adapter based on type)
- [x] Refactor `lib/caruso/adapter.rb` to use the Dispatcher
- [x] Update `lib/caruso/cli.rb` to use the new Adapter architecture (Implicit)

## Phase 2: Skills Support
- [x] Update `lib/caruso/fetcher.rb` to support `skills/` directory recursion
- [x] Implement `check_resource_types` in Fetcher (Logic integrated in `find_steering_files`)
- [x] Create `lib/caruso/adapters/skill_adapter.rb`
- [x] Implement script copying to `.cursor/scripts/caruso/...`
- [x] Implement rule generation (`SKILL.md` -> `.cursor/rules/...`)
- [x] Add header/frontmatter to rule pointing to script location
- [x] Create unit tests for `SkillAdapter` & `Fetcher`
- [x] Verify implementation with tests
- [x] Refactor `Dispatcher` logic for robust skill clustering <!-- id: 11 -->
- [x] Refactor `SkillAdapter` to preserve script directory structure <!-- id: 12 -->



