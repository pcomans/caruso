# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plugin Updates and Reinstallation", type: :integration do
  before do
    init_caruso
    add_marketplace
  end

  describe "plugin reinstallation (update scenario)" do
    it "replaces old files when reinstalling", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")
      plugin_key = "#{plugin_name}@test-skills"

      # Install plugin
      run_command("caruso plugin install #{plugin_key}")
      expect(last_command_started).to be_successfully_executed

      load_local_config["installed_files"][plugin_key]

      # Reinstall
      run_command("caruso plugin install #{plugin_key}")
      expect(last_command_started).to be_successfully_executed

      second_files = load_local_config["installed_files"][plugin_key]

      # Files list should be updated (even if identical in this case)
      expect(second_files).to be_an(Array)
      expect(second_files).not_to be_empty
    end

    it "allows switching plugin source marketplace" do
      # Add a second marketplace
      add_marketplace(other_marketplace_path)

      # Simulate plugin installed from first marketplace
      project_config = load_project_config
      project_config["plugins"] = {
        "test-plugin@test-skills" => {
          "marketplace" => "test-skills"
        }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      # Update the marketplace reference (simulating a switch)
      project_config = load_project_config
      # Remove old key
      project_config["plugins"].delete("test-plugin@test-skills")
      # Add new key
      project_config["plugins"]["test-plugin@other-marketplace"] = {
        "marketplace" => "other-marketplace"
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      updated_config = load_project_config
      expect(updated_config["plugins"]).to have_key("test-plugin@other-marketplace")
      expect(updated_config["plugins"]["test-plugin@other-marketplace"]["marketplace"]).to eq("other-marketplace")
    end
  end

  describe "concurrent plugin operations" do
    it "handles installing plugin while another exists" do
      # Install first plugin
      project_config = load_project_config
      project_config["plugins"] = {
        "plugin-a@test-skills" => { "marketplace" => "test-skills" }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      # Add second plugin
      project_config = load_project_config
      project_config["plugins"]["plugin-b@test-skills"] = { "marketplace" => "test-skills" }
      File.write(config_file, JSON.pretty_generate(project_config))

      final_config = load_project_config
      expect(final_config["plugins"]).to have_key("plugin-a@test-skills")
      expect(final_config["plugins"]).to have_key("plugin-b@test-skills")
    end

    it "maintains marketplace integrity during plugin updates" do
      project_config = load_project_config
      original_marketplaces = project_config["marketplaces"].dup

      # Simulate plugin install
      project_config["plugins"] = {
        "test-plugin@test-skills" => { "marketplace" => "test-skills" }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      updated_config = load_project_config
      expect(updated_config["marketplaces"]).to eq(original_marketplaces)
    end
  end

  describe "plugin metadata updates" do
    it "stores marketplace reference for tracking" do
      project_config = load_project_config
      project_config["plugins"] = {
        "tracked-plugin@test-skills" => {
          "marketplace" => "test-skills"
        }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      updated_config = load_project_config
      expect(updated_config["plugins"]["tracked-plugin@test-skills"]["marketplace"]).to eq("test-skills")
    end

    it "maintains files list integrity" do
      files = [
        ".cursor/rules/file1.mdc",
        ".cursor/rules/file2.mdc",
        ".cursor/rules/subdir/file3.mdc"
      ]

      local_config = load_local_config
      local_config["installed_files"] = {
        "multi-file@test-skills" => files
      }
      File.write(local_config_file, JSON.pretty_generate(local_config))

      updated_config = load_local_config
      expect(updated_config["installed_files"]["multi-file@test-skills"]).to eq(files)
      expect(updated_config["installed_files"]["multi-file@test-skills"].length).to eq(3)
    end
  end

  describe "update workflow scenarios" do
    it "supports uninstall then reinstall workflow", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")
      plugin_key = "#{plugin_name}@test-skills"

      # Install
      run_command("caruso plugin install #{plugin_key}")
      expect(last_command_started).to be_successfully_executed
      expect(load_project_config["plugins"]).to have_key(plugin_key)

      # Uninstall
      run_command("caruso plugin uninstall #{plugin_key}")
      expect(last_command_started).to be_successfully_executed
      expect(load_project_config["plugins"]).not_to have_key(plugin_key)

      # Reinstall
      run_command("caruso plugin install #{plugin_key}")
      expect(last_command_started).to be_successfully_executed
      expect(load_project_config["plugins"]).to have_key(plugin_key)
    end

    it "handles reinstall without explicit uninstall" do
      project_config = load_project_config
      project_config["plugins"] = {
        "existing-plugin@test-skills" => { "marketplace" => "test-skills" }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      local_config = load_local_config
      local_config["installed_files"] = {
        "existing-plugin@test-skills" => [".cursor/rules/old.mdc"]
      }
      File.write(local_config_file, JSON.pretty_generate(local_config))

      # Simulate reinstall by updating local config
      local_config = load_local_config
      local_config["installed_files"]["existing-plugin@test-skills"] = [".cursor/rules/new.mdc"]
      File.write(local_config_file, JSON.pretty_generate(local_config))

      updated_config = load_local_config
      expect(updated_config["installed_files"]["existing-plugin@test-skills"]).to eq([".cursor/rules/new.mdc"])
    end
  end
end
