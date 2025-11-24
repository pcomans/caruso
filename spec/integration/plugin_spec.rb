# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plugin Removal", type: :integration do
  before do
    init_caruso
    add_marketplace
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
    end

    context "when plugin does not exist" do
      it "shows not installed message" do
        run_command("caruso plugin uninstall nonexistent-plugin")

        expect(last_command_started).to have_output(/is not installed/)
      end
    end
  end
end
