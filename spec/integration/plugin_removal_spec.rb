# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plugin Removal", type: :integration do
  before do
    init_caruso
    add_marketplace()
  end

  describe "caruso plugin uninstall" do
    context "when plugin is installed" do
      it "removes plugin from config and deletes files", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        # Install a plugin first
        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")

        run_command("caruso plugin install #{plugin_name}@test-skills")
        expect(last_command_started).to be_successfully_executed
        
        plugin_key = "#{plugin_name}@test-skills"
        expect(load_config["plugins"]).to have_key(plugin_key)

        # Uninstall it
        run_command("caruso plugin uninstall #{plugin_key}")
        expect(last_command_started).to be_successfully_executed

        config = load_config
        expect(config["plugins"]).not_to have_key(plugin_key)
        expect(config["installed_files"]).not_to have_key(plugin_key)
      end

      it "shows confirmation message" do
        # Simulate an installed plugin
        project_config = load_project_config
        project_config["plugins"] = {
          "test-plugin@test-skills" => {
            "marketplace" => "test-skills"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        local_config = load_local_config
        local_config["installed_files"] = {
          "test-plugin@test-skills" => [".cursor/rules/test.mdc"]
        }
        File.write(local_config_file, JSON.pretty_generate(local_config))

        run_command("caruso plugin uninstall test-plugin@test-skills")

        expect(last_command_started).to have_output(/Removing test-plugin@test-skills/)
        expect(last_command_started).to have_output(/Uninstalled test-plugin@test-skills/)
      end

      it "notes files deleted" do
        # Simulate an installed plugin with files
        project_config = load_project_config
        project_config["plugins"] = {
          "test-plugin@test-skills" => {
            "marketplace" => "test-skills"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        # Create dummy files
        FileUtils.mkdir_p(File.join(aruba.current_directory, ".cursor/rules"))
        File.write(File.join(aruba.current_directory, ".cursor/rules/test.mdc"), "content")
        File.write(File.join(aruba.current_directory, ".cursor/rules/test2.mdc"), "content")

        local_config = load_local_config
        local_config["installed_files"] = {
          "test-plugin@test-skills" => [".cursor/rules/test.mdc", ".cursor/rules/test2.mdc"]
        }
        File.write(local_config_file, JSON.pretty_generate(local_config))

        run_command("caruso plugin uninstall test-plugin@test-skills")

        expect(last_command_started).to have_output(/Deleted .cursor\/rules\/test.mdc/)
        expect(last_command_started).to have_output(/Deleted .cursor\/rules\/test2.mdc/)
        expect(File.exist?(".cursor/rules/test.mdc")).to be false
      end
    end

    context "when plugin does not exist" do
      it "shows not installed message" do
        run_command("caruso plugin uninstall nonexistent-plugin")

        expect(last_command_started).to have_output(/is not installed/)
      end

      it "does not modify config when plugin not found" do
        # Setup initial state
        project_config = load_project_config
        project_config["plugins"] = {
          "existing-plugin@test-skills" => { "marketplace" => "test-skills" }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        config_before = load_config
        run_command("caruso plugin uninstall nonexistent")
        config_after = load_config

        expect(config_after).to eq(config_before)
      end
    end

    context "plugin list after removal" do
      it "no longer shows removed plugin as installed", :live do
        skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

        run_command("caruso plugin list")
        match = last_command_started.output.match(/^\s+-\s+(\S+)/)
        plugin_name = match ? match[1] : skip("No plugins available")

        run_command("caruso plugin install #{plugin_name}@test-skills")
        run_command("caruso plugin uninstall #{plugin_name}@test-skills")
        run_command("caruso plugin list")

        expect(last_command_started.output).not_to match(/#{plugin_name}.*\[Installed\]/)
      end
    end
  end

  describe "plugin removal file tracking" do
    it "removes files listed in local config" do
      # Create dummy file
      FileUtils.mkdir_p(File.join(aruba.current_directory, ".cursor/rules"))
      File.write(File.join(aruba.current_directory, ".cursor/rules/file1.mdc"), "content")

      project_config = load_project_config
      project_config["plugins"] = {
        "multi-file-plugin@test-skills" => { "marketplace" => "test-skills" }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      local_config = load_local_config
      local_config["installed_files"] = {
        "multi-file-plugin@test-skills" => [".cursor/rules/file1.mdc"]
      }
      File.write(local_config_file, JSON.pretty_generate(local_config))

      run_command("caruso plugin uninstall multi-file-plugin@test-skills")

      expect(last_command_started).to be_successfully_executed
      expect(File.exist?(".cursor/rules/file1.mdc")).to be false
    end

    it "handles plugin with no files list" do
      project_config = load_project_config
      project_config["plugins"] = {
        "no-files-plugin@test-skills" => { "marketplace" => "test-skills" }
      }
      File.write(config_file, JSON.pretty_generate(project_config))

      # No entry in local config installed_files

      run_command("caruso plugin uninstall no-files-plugin@test-skills")

      expect(last_command_started).to be_successfully_executed
      expect(load_project_config["plugins"]).not_to have_key("no-files-plugin@test-skills")
    end
  end
end
