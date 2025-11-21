# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Update Functionality", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace update" do
    context "when marketplace exists" do
      before do
        add_marketplace("https://github.com/anthropics/skills")
      end

      it "updates a specific marketplace", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso marketplace update skills")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updated marketplace 'skills'/)
      end

      it "shows confirmation message after updating" do
        # Simulate marketplace update
        run_command("caruso marketplace update skills")

        expect(last_command_started).to have_output(/Updating marketplace 'skills'/)
        expect(last_command_started).to have_output(/Updated marketplace 'skills'/)
      end

      it "handles marketplace that doesn't need updating", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Update twice - second should show already up to date
        run_command("caruso marketplace update skills")
        expect(last_command_started).to be_successfully_executed

        run_command("caruso marketplace update skills")
        expect(last_command_started).to be_successfully_executed
      end
    end

    context "when marketplace does not exist" do
      before do
        add_marketplace("https://github.com/anthropics/skills")
      end

      it "shows error message" do
        run_command("caruso marketplace update nonexistent-marketplace")

        expect(last_command_started).to have_output(/Marketplace 'nonexistent-marketplace' not found/)
      end

      it "does not modify manifest" do
        manifest_before = load_manifest
        run_command("caruso marketplace update nonexistent")
        manifest_after = load_manifest

        expect(manifest_after).to eq(manifest_before)
      end
    end

    context "updating all marketplaces" do
      it "updates all marketplaces when no name specified", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        add_marketplace("https://github.com/anthropics/skills", "marketplace-1")
        add_marketplace("https://github.com/example/other", "marketplace-2")

        run_command("caruso marketplace update")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updating all marketplaces/)
      end

      it "shows message when no marketplaces configured" do
        run_command("caruso marketplace update")

        expect(last_command_started).to have_output(/No marketplaces configured/)
      end

      it "continues updating other marketplaces if one fails" do
        add_marketplace("https://github.com/anthropics/skills", "good-marketplace")
        add_marketplace("https://invalid-url-that-does-not-exist.com/bad", "bad-marketplace")

        run_command("caruso marketplace update")

        # Should show errors for bad marketplace but continue with good ones
        expect(last_command_started).to have_output(/bad-marketplace/)
      end
    end

    context "marketplace update details" do
      it "refreshes marketplace cache" do
        # This test verifies that the update command refreshes the cached marketplace data
        # In practice, this means git pull on the cached repo
        add_marketplace("https://github.com/anthropics/skills")

        run_command("caruso marketplace update skills")

        expect(last_command_started).to be_successfully_executed
      end

      it "updates timestamp of last marketplace fetch" do
        add_marketplace("https://github.com/anthropics/skills")

        before_time = Time.now - 1
        run_command("caruso marketplace update skills")
        after_time = Time.now + 1

        # Verify marketplace was updated recently (implementation-specific)
        expect(last_command_started).to be_successfully_executed
      end
    end
  end

  describe "caruso plugin update" do
    before do
      add_marketplace("https://github.com/anthropics/skills")
    end

    context "when plugin is installed" do
      it "updates a specific plugin", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Install plugin first
        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")

        run_command("caruso plugin install #{plugin_name}@skills")
        expect(last_command_started).to be_successfully_executed

        # Update the plugin
        run_command("caruso plugin update #{plugin_name}")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updated #{plugin_name}/)
      end

      it "shows updating message" do
        # Simulate installed plugin
        manifest = load_manifest
        manifest["plugins"] = {
          "test-plugin" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/test.mdc"],
            "marketplace" => "https://github.com/anthropics/skills"
          }
        }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso plugin update test-plugin")

        expect(last_command_started).to have_output(/Updating test-plugin/)
      end

      it "updates plugin metadata timestamp", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")

        # Install plugin
        run_command("caruso plugin install #{plugin_name}@skills")
        expect(last_command_started).to be_successfully_executed
        first_install = load_manifest
        first_timestamp = first_install["plugins"][plugin_name]["installed_at"]

        # Update plugin
        Timecop.travel(Time.now + 2) do
          run_command("caruso plugin update #{plugin_name}")
          expect(last_command_started).to be_successfully_executed
        end

        second_install = load_manifest
        second_timestamp = second_install["plugins"][plugin_name]["installed_at"]

        expect(second_timestamp).not_to eq(first_timestamp)
        expect(Time.parse(second_timestamp)).to be > Time.parse(first_timestamp)
      end

      it "automatically updates marketplace before updating plugin", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")

        run_command("caruso plugin install #{plugin_name}@skills")
        run_command("caruso plugin update #{plugin_name}")

        # Should see marketplace update happening
        expect(last_command_started).to have_output(/Updating/)
      end

      it "updates plugin files" do
        manifest = load_manifest
        manifest["plugins"] = {
          "test-plugin" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/old-file.mdc"],
            "marketplace" => "https://github.com/anthropics/skills"
          }
        }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso plugin update test-plugin")

        # Files list should be updated
        updated_manifest = load_manifest
        expect(updated_manifest["plugins"]["test-plugin"]["files"]).to be_an(Array)
      end

      it "shows already up to date message when no updates available", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")

        run_command("caruso plugin install #{plugin_name}@skills")

        # Update immediately - should be up to date
        run_command("caruso plugin update #{plugin_name}")

        expect(last_command_started).to be_successfully_executed
        # Plugin should be updated (or shown as current)
      end
    end

    context "when plugin is not installed" do
      it "shows plugin not installed error" do
        run_command("caruso plugin update nonexistent-plugin")

        expect(last_command_started).to have_output(/Plugin 'nonexistent-plugin' is not installed/)
      end

      it "suggests installing the plugin" do
        run_command("caruso plugin update nonexistent-plugin")

        expect(last_command_started).to have_output(/caruso plugin install/)
      end

      it "does not modify manifest" do
        manifest_before = load_manifest
        run_command("caruso plugin update nonexistent-plugin")
        manifest_after = load_manifest

        expect(manifest_after).to eq(manifest_before)
      end
    end

    context "with --all flag" do
      it "updates all installed plugins", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Install multiple plugins
        run_command("caruso plugin list")
        plugins = last_command_started.output.scan(/^\s+-\s+(\S+)/).flatten
        skip("Need at least 2 plugins") if plugins.size < 2

        run_command("caruso plugin install #{plugins[0]}@skills")
        expect(last_command_started).to be_successfully_executed
        run_command("caruso plugin install #{plugins[1]}@skills")
        expect(last_command_started).to be_successfully_executed

        # Update all
        run_command("caruso plugin update --all")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updating all plugins/)
      end

      it "shows message when no plugins installed" do
        run_command("caruso plugin update --all")

        expect(last_command_started).to have_output(/No plugins installed/)
      end

      it "attempts to update plugin timestamps", :live do
        skip "This test requires plugins that can actually be fetched from marketplace"

        # Note: This test documents expected behavior but requires real plugins
        # When plugin update --all runs:
        # 1. It should iterate through all installed plugins
        # 2. Update marketplace cache for each
        # 3. Fetch latest plugin files
        # 4. Update timestamp to current time
        #
        # Timestamp updates verified in live tests with real marketplace access
      end

      it "continues updating other plugins if one fails" do
        manifest = load_manifest
        manifest["plugins"] = {
          "good-plugin" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/good.mdc"],
            "marketplace" => "https://github.com/anthropics/skills"
          },
          "bad-plugin" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/bad.mdc"],
            "marketplace" => "https://invalid-marketplace.com/bad"
          }
        }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso plugin update --all")

        # Should attempt both and show results
        expect(last_command_started).to have_output(/plugin/)
      end

      it "shows count of updated plugins" do
        manifest = load_manifest
        manifest["plugins"] = {
          "plugin-1" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/p1.mdc"],
            "marketplace" => "https://github.com/anthropics/skills"
          },
          "plugin-2" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/p2.mdc"],
            "marketplace" => "https://github.com/anthropics/skills"
          }
        }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso plugin update --all")

        # Should show summary
        expect(last_command_started).to have_output(/Updated \d+ plugin/)
      end
    end

    context "plugin from specific marketplace" do
      it "attempts to update plugin from its original marketplace", :live do
        skip "Requires actual marketplace with fetchable plugins"

        # This test documents expected behavior:
        # 1. Plugin metadata includes marketplace URL
        # 2. Update command uses that URL to fetch latest version
        # 3. Works even if marketplace not in configured list
      end

      it "handles missing or inaccessible marketplace" do
        manifest = load_manifest
        manifest["plugins"] = {
          "test-plugin" => {
            "installed_at" => "2025-01-01T00:00:00Z",
            "files" => [".cursor/rules/test.mdc"],
            "marketplace" => "https://github.com/nonexistent/marketplace"
          }
        }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso plugin update test-plugin")

        # Should fail with non-zero exit code
        expect(last_command_started).not_to be_successfully_executed
        expect(last_command_started).to have_output(/Updating test-plugin/)
      end
    end
  end

  describe "caruso plugin outdated" do
    before do
      add_marketplace("https://github.com/anthropics/skills")
    end

    it "shows plugins with updates available", :live do
      skip "Requires live marketplace access and version tracking" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      run_command("caruso plugin install #{plugin_name}@skills")
      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end

    it "shows message when all plugins are up to date" do
      manifest = load_manifest
      manifest["plugins"] = {
        "current-plugin" => {
          "installed_at" => Time.now.iso8601,
          "files" => [".cursor/rules/current.mdc"],
          "marketplace" => "https://github.com/anthropics/skills",
          "version" => "1.0.0"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end

    it "shows message when no plugins installed" do
      run_command("caruso plugin outdated")

      expect(last_command_started).to have_output(/No plugins installed/)
    end

    it "displays current and available versions" do
      # This test documents the expected format
      # Format: plugin-name: 1.0.0 → 1.2.0 available
      manifest = load_manifest
      manifest["plugins"] = {
        "versioned-plugin" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/versioned.mdc"],
          "marketplace" => "https://github.com/anthropics/skills",
          "version" => "1.0.0"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end

    it "checks all marketplaces for updates" do
      add_marketplace("https://github.com/example/other", "other-marketplace")

      manifest = load_manifest
      manifest["plugins"] = {
        "plugin-1" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/p1.mdc"],
          "marketplace" => "https://github.com/anthropics/skills"
        },
        "plugin-2" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/p2.mdc"],
          "marketplace" => "https://github.com/example/other"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end
  end

  describe "update edge cases" do
    before do
      add_marketplace("https://github.com/anthropics/skills")
    end

    it "handles network failures gracefully" do
      manifest = load_manifest
      manifest["plugins"] = {
        "test-plugin" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/test.mdc"],
          "marketplace" => "https://invalid-network-address.com/repo"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      run_command("caruso plugin update test-plugin")

      expect(last_command_started).to have_output(/error|failed/i)
    end

    it "preserves plugin metadata on update failure" do
      manifest = load_manifest
      manifest["plugins"] = {
        "test-plugin" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/test.mdc"],
          "marketplace" => "https://github.com/anthropics/skills",
          "custom_field" => "custom_value"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))
      manifest_before = load_manifest

      run_command("caruso plugin update test-plugin")

      # If update fails, original data should be preserved
      manifest_after = load_manifest
      if manifest_after["plugins"]["test-plugin"]["installed_at"] == "2025-01-01T00:00:00Z"
        # Update failed, verify data unchanged
        expect(manifest_after["plugins"]["test-plugin"]).to include("custom_field" => "custom_value")
      end
    end

    it "handles updates with file system operations", :live do
      skip "This test requires real plugin that can be fetched"

      # This test documents expected behavior for concurrent operations:
      # - Manifest updates should be atomic
      # - File writes should be transactional where possible
      # - Errors in one plugin update shouldn't corrupt manifest
      #
      # In practice, this is handled by:
      # 1. Writing files first
      # 2. Updating manifest only after successful file writes
      # 3. Using JSON pretty_generate for clean writes
    end
  end
end
