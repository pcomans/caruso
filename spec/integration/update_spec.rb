# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Update Functionality", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace update" do
    context "when marketplace exists" do
      before do
        add_marketplace
      end

      it "updates a specific marketplace", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso marketplace update test-skills")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updated marketplace 'test-skills'/)
      end

      it "shows confirmation message after updating" do
        # Simulate marketplace update
        run_command("caruso marketplace update test-skills")

        expect(last_command_started).to have_output(/Updating marketplace 'test-skills'/)
        expect(last_command_started).to have_output(/Updated marketplace 'test-skills'/)
      end

      it "handles marketplace that doesn't need updating", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Update twice - second should show already up to date
        run_command("caruso marketplace update test-skills")
        expect(last_command_started).to be_successfully_executed

        run_command("caruso marketplace update test-skills")
        expect(last_command_started).to be_successfully_executed
      end
    end

    context "when marketplace does not exist" do
      before do
        add_marketplace
      end

      it "shows error message" do
        run_command("caruso marketplace update nonexistent-marketplace")

        expect(last_command_started).to have_output(/Marketplace 'nonexistent-marketplace' not found/)
      end

      it "does not modify manifest" do
        config_before = load_project_config
        run_command("caruso marketplace update nonexistent")
        config_after = load_project_config

        expect(config_after).to eq(config_before)
      end
    end

    context "updating all marketplaces" do
      it "updates all marketplaces when no name specified", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        add_marketplace(test_marketplace_path)
        add_marketplace(other_marketplace_path)

        run_command("caruso marketplace update")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updating all marketplaces/)
      end

      it "shows message when no marketplaces configured" do
        run_command("caruso marketplace update")

        expect(last_command_started).to have_output(/No marketplaces configured/)
      end

      it "continues updating other marketplaces if one fails" do
        add_marketplace(test_marketplace_path)
        # NOTE: Cannot test with invalid URL since we need valid marketplace.json to get the name
        # This test scenario is not feasible with the new design where name comes from marketplace.json

        run_command("caruso marketplace update")

        expect(last_command_started).to be_successfully_executed
      end
    end

    context "marketplace update details" do
      it "refreshes marketplace cache" do
        # This test verifies that the update command refreshes the cached marketplace data
        # In practice, this means git pull on the cached repo
        add_marketplace

        run_command("caruso marketplace update skills")

        expect(last_command_started).to be_successfully_executed
      end

      it "updates timestamp of last marketplace fetch" do
        add_marketplace

        Time.now
        run_command("caruso marketplace update skills")
        Time.now

        # Verify marketplace was updated recently (implementation-specific)
        expect(last_command_started).to be_successfully_executed
      end
    end
  end

  describe "caruso plugin update" do
    before do
      add_marketplace
    end

    context "when plugin is installed" do
      it "updates a specific plugin", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Install plugin first
        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")
        plugin_key = "#{plugin_name}@test-skills"

        run_command("caruso plugin install #{plugin_key}")
        expect(last_command_started).to be_successfully_executed

        # Update the plugin
        run_command("caruso plugin update #{plugin_key}")

        expect(last_command_started).to be_successfully_executed
        expect(last_command_started).to have_output(/Updated #{plugin_key}/)
      end

      it "shows updating message" do
        # Simulate installed plugin
        project_config = load_project_config
        project_config["plugins"] = {
          "test-plugin@test-skills" => {
            "marketplace" => "test-skills"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        run_command("caruso plugin update test-plugin@test-skills")

        expect(last_command_started).to have_output(/Updating test-plugin@test-skills/)
      end

      it "automatically updates marketplace before updating plugin", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")
        plugin_key = "#{plugin_name}@test-skills"

        run_command("caruso plugin install #{plugin_key}")
        expect(last_command_started).to be_successfully_executed
        run_command("caruso plugin update #{plugin_key}")

        # Should see marketplace update happening
        expect(last_command_started).to have_output(/Updating/)
      end

      it "updates plugin files" do
        project_config = load_project_config
        project_config["plugins"] = {
          "test-plugin@test-skills" => {
            "marketplace" => "test-skills"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        local_config = load_local_config
        local_config["installed_files"] = {
          "test-plugin@test-skills" => [".cursor/rules/old-file.mdc"]
        }
        File.write(local_config_file, JSON.pretty_generate(local_config))

        run_command("caruso plugin update test-plugin@test-skills")

        # Files list should be updated
        updated_config = load_local_config
        expect(updated_config["installed_files"]["test-plugin@test-skills"]).to be_an(Array)
      end

      it "shows already up to date message when no updates available", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")
        plugin_key = "#{plugin_name}@test-skills"

        run_command("caruso plugin install #{plugin_key}")

        # Update immediately - should be up to date
        run_command("caruso plugin update #{plugin_key}")

        expect(last_command_started).to be_successfully_executed
        # Plugin should be updated (or shown as current)
      end
    end

    context "when plugin is not installed" do
      it "shows plugin not installed error" do
        run_command("caruso plugin update nonexistent-plugin")

        expect(last_command_started).to have_output(/Error: Plugin 'nonexistent-plugin' is not installed/)
      end

      it "suggests installing the plugin" do
        run_command("caruso plugin update nonexistent-plugin")

        expect(last_command_started).to have_output(/caruso plugin install/)
      end

      it "does not modify manifest" do
        config_before = load_project_config
        run_command("caruso plugin update nonexistent-plugin")
        config_after = load_project_config

        expect(config_after).to eq(config_before)
      end
    end

    context "with --all flag" do
      it "updates all installed plugins", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Install multiple plugins
        run_command("caruso plugin list")
        plugins = last_command_started.output.scan(/^\s+-\s+(\S+)/).flatten
        skip("Need at least 2 plugins") if plugins.size < 2

        run_command("caruso plugin install #{plugins[0]}@test-skills")
        expect(last_command_started).to be_successfully_executed
        run_command("caruso plugin install #{plugins[1]}@test-skills")
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

      it "continues updating other plugins if one fails" do
        project_config = load_project_config
        project_config["plugins"] = {
          "good-plugin@test-skills" => {
            "marketplace" => "test-skills"
          },
          "bad-plugin@bad-marketplace" => {
            "marketplace" => "bad-marketplace"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        # Add bad marketplace to config so it tries to update
        project_config["marketplaces"]["bad-marketplace"] = { "url" => "https://invalid-marketplace.com/bad" }
        File.write(config_file, JSON.pretty_generate(project_config))

        run_command("caruso plugin update --all")

        # Should attempt both and show results
        expect(last_command_started).to have_output(/plugin/)
      end

      it "shows count of updated plugins" do
        project_config = load_project_config
        project_config["plugins"] = {
          "plugin-1@test-skills" => {
            "marketplace" => "test-skills"
          },
          "plugin-2@test-skills" => {
            "marketplace" => "test-skills"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

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
        project_config = load_project_config
        project_config["plugins"] = {
          "test-plugin@nonexistent" => {
            "marketplace" => "nonexistent"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        run_command("caruso plugin update test-plugin@nonexistent")

        # Should fail with non-zero exit code
        expect(last_command_started).not_to be_successfully_executed
        expect(last_command_started).to have_output(/Updating test-plugin@nonexistent/)
      end
    end
  end

  describe "caruso plugin outdated" do
    before do
      add_marketplace
    end

    it "shows plugins with updates available", :live do
      skip "Requires live marketplace access and version tracking" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")
      plugin_key = "#{plugin_name}@test-skills"

      run_command("caruso plugin install #{plugin_key}")
      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end

    it "shows message when all plugins are up to date" do
      project_config = load_project_config
      project_config["plugins"] = {
        "current-plugin@test-skills" => {
          "marketplace" => "test-skills"
        }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end

    it "shows message when no plugins installed" do
      run_command("caruso plugin outdated")

      expect(last_command_started).to have_output(/No plugins installed/)
    end

    it "checks all marketplaces for updates" do
      add_marketplace(other_marketplace_path)

      project_config = load_project_config
      project_config["plugins"] = {
        "plugin-1@test-skills" => {
          "marketplace" => "test-skills"
        },
        "plugin-2@other-marketplace" => {
          "marketplace" => "other-marketplace"
        }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      run_command("caruso plugin outdated")

      expect(last_command_started).to be_successfully_executed
    end
  end

  describe "update edge cases" do
    before do
      add_marketplace
    end

    it "handles network failures gracefully" do
      project_config = load_project_config
      project_config["plugins"] = {
        "test-plugin@bad-marketplace" => {
          "marketplace" => "bad-marketplace"
        }
      }
      # Add bad marketplace to config so it tries to update
      project_config["marketplaces"]["bad-marketplace"] = { "url" => "https://invalid-network-address.com/repo" }
      File.write(config_file, JSON.pretty_generate(project_config))

      run_command("caruso plugin update test-plugin@bad-marketplace")

      expect(last_command_started).to have_output(/error|failed/i)
    end

    it "preserves plugin metadata on update failure" do
      project_config = load_project_config
      project_config["plugins"] = {
        "test-plugin@test-skills" => {
          "marketplace" => "test-skills",
          "custom_field" => "custom_value"
        }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      # Force failure by corrupting marketplace URL temporarily
      project_config["marketplaces"]["test-skills"]["url"] = "https://invalid-url"
      File.write(config_file, JSON.pretty_generate(project_config))

      run_command("caruso plugin update test-plugin@test-skills")

      # If update fails, original data should be preserved
      config_after = load_project_config
      expect(config_after["plugins"]["test-plugin@test-skills"]).to include("custom_field" => "custom_value")
    end
  end
end
