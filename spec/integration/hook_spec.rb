# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Hook Installation", type: :integration do
  before do
    init_caruso
    add_marketplace
  end

  describe "caruso plugin install with hooks" do
    it "creates .cursor/hooks.json after installing a plugin with hooks" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      expect(File.exist?(hooks_path)).to be true

      hooks_data = JSON.parse(File.read(hooks_path))
      expect(hooks_data["version"]).to eq(1)
      expect(hooks_data["hooks"]).to be_a(Hash)
    end

    it "translates PostToolUse Write|Edit to afterFileEdit" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      hooks_data = JSON.parse(File.read(hooks_path))

      expect(hooks_data["hooks"]["afterFileEdit"]).to be_an(Array)
      expect(hooks_data["hooks"]["afterFileEdit"]).not_to be_empty
    end

    it "translates Stop to stop" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      hooks_data = JSON.parse(File.read(hooks_path))

      expect(hooks_data["hooks"]["stop"]).to be_an(Array)
      stop_commands = hooks_data["hooks"]["stop"].map { |h| h["command"] }
      expect(stop_commands).to include("echo 'Plugin stop hook executed'")
    end

    it "copies referenced hook scripts and rewrites paths" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      # Script should be copied to .cursor/hooks/caruso/<marketplace>/<plugin>/
      script_path = File.join(
        aruba.current_directory, ".cursor", "hooks", "caruso", "test-skills", "test-plugin",
        "hooks", "scripts", "format.sh"
      )
      expect(File.exist?(script_path)).to be true

      # Script should be executable
      expect(File.stat(script_path).mode & 0o755).to eq(0o755)

      # Command in hooks.json should NOT contain ${CLAUDE_PLUGIN_ROOT}
      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      hooks_data = JSON.parse(File.read(hooks_path))
      all_commands = hooks_data["hooks"].values.flatten.map { |h| h["command"] }
      expect(all_commands.none? { |c| c.include?("${CLAUDE_PLUGIN_ROOT}") }).to be true
    end

    it "preserves timeout values" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      hooks_data = JSON.parse(File.read(hooks_path))

      # The PostToolUse hook in our fixture has timeout: 15
      file_edit_hooks = hooks_data["hooks"]["afterFileEdit"] || []
      hook_with_timeout = file_edit_hooks.find { |h| h["timeout"] }
      expect(hook_with_timeout).not_to be_nil
      expect(hook_with_timeout["timeout"]).to eq(15)
    end

    it "tracks hooks.json in installed_files" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      local_config = load_local_config
      installed = local_config["installed_files"]["test-plugin@test-skills"]
      expect(installed).to be_an(Array)
      expect(installed.any? { |f| f.include?("hooks.json") }).to be true
    end
  end

  describe "uninstalling a plugin with hooks" do
    it "removes plugin hooks from .cursor/hooks.json on uninstall" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      expect(File.exist?(hooks_path)).to be true

      # Verify hooks exist before uninstall
      hooks_before = JSON.parse(File.read(hooks_path))
      expect(hooks_before["hooks"]).not_to be_empty

      # Uninstall the plugin
      run_command("caruso plugin uninstall test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      # hooks.json should be deleted since it's the only plugin
      expect(File.exist?(hooks_path)).to be false
    end

    it "removes only this plugin's hooks when other hooks exist" do
      # Pre-populate hooks.json with an existing hook from another source
      hooks_dir = File.join(aruba.current_directory, ".cursor")
      FileUtils.mkdir_p(hooks_dir)
      existing_hooks = {
        "version" => 1,
        "hooks" => {
          "stop" => [{ "command" => "./other-plugin-script.sh" }]
        }
      }
      File.write(File.join(hooks_dir, "hooks.json"), JSON.pretty_generate(existing_hooks))

      # Install our plugin (which adds its own hooks)
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(hooks_dir, "hooks.json")
      hooks_after_install = JSON.parse(File.read(hooks_path))
      # Should have both the existing hook and our plugin's hooks
      expect(hooks_after_install["hooks"]["stop"].length).to be >= 2

      # Uninstall our plugin
      run_command("caruso plugin uninstall test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      # hooks.json should still exist with the other plugin's hook
      expect(File.exist?(hooks_path)).to be true
      remaining_hooks = JSON.parse(File.read(hooks_path))
      stop_commands = remaining_hooks["hooks"]["stop"].map { |h| h["command"] }
      expect(stop_commands).to include("./other-plugin-script.sh")
      # Our plugin's stop hook should be gone
      expect(stop_commands).not_to include("echo 'Plugin stop hook executed'")
    end

    it "removes hook scripts on uninstall" do
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      script_path = File.join(
        aruba.current_directory, ".cursor", "hooks", "caruso", "test-skills", "test-plugin",
        "hooks", "scripts", "format.sh"
      )
      expect(File.exist?(script_path)).to be true

      run_command("caruso plugin uninstall test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      expect(File.exist?(script_path)).to be false
    end
  end

  describe "reinstalling a plugin with hooks" do
    it "deduplicates hook commands on reinstall" do
      # Install once
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      hooks_path = File.join(aruba.current_directory, ".cursor", "hooks.json")
      first_hooks = JSON.parse(File.read(hooks_path))
      first_stop_count = (first_hooks["hooks"]["stop"] || []).length

      # Install again (reinstall)
      run_command("caruso plugin install test-plugin@test-skills")
      expect(last_command_started).to be_successfully_executed

      second_hooks = JSON.parse(File.read(hooks_path))
      second_stop_count = (second_hooks["hooks"]["stop"] || []).length

      # Count should not increase on reinstall
      expect(second_stop_count).to eq(first_stop_count)
    end
  end
end
