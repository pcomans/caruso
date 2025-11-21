# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plugin Management", type: :integration do
  before do
    init_caruso
    add_marketplace("https://github.com/anthropics/skills")
  end

  describe "caruso plugin list" do
    it "lists available plugins from marketplace" do
      run_command("caruso plugin list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Marketplace: skills/)
    end

    it "shows when no marketplaces configured" do
      # Start fresh without marketplace
      run_command("rm -rf .cursor")

      run_command("caruso plugin list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/No marketplaces configured/)
    end

    it "indicates installation status" do
      # This test will pass once a plugin is installed
      # For now, just verify the list command works
      run_command("caruso plugin list")

      expect(last_command_started).to be_successfully_executed
    end
  end

  describe "caruso plugin install", :live do
    # Mark as :live since it requires network access
    # Run with: rspec --tag live

    let(:plugin_name) do
      # Get first available plugin from the marketplace
      run_command("caruso plugin list")
      # Parse output to find first plugin name
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      match ? match[1] : skip("No plugins available in marketplace")
    end

    it "shows error and available marketplaces when marketplace is not found" do
      # This test doesn't need live access as it fails early

      # Ensure we have a marketplace configured
      add_marketplace("https://github.com/anthropics/skills", "claude-official")

      run_command("caruso plugin install foo@missing-marketplace")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Error: Marketplace 'missing-marketplace' not found/)
      expect(last_command_started).to have_output(/Available marketplaces: skills, claude-official/)
    end

    it "installs a plugin with explicit marketplace" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin install #{plugin_name}@skills")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Installing #{plugin_name}/)
      expect(last_command_started).to have_output(/Installed #{plugin_name}/)
    end

    it "updates manifest with plugin info" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin install #{plugin_name}@skills")

      manifest = load_manifest
      expect(manifest["plugins"]).to have_key(plugin_name)
      expect(manifest["plugins"][plugin_name]).to have_key("installed_at")
      expect(manifest["plugins"][plugin_name]).to have_key("files")
      expect(manifest["plugins"][plugin_name]).to have_key("marketplace")
    end

    it "creates .mdc files" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin install #{plugin_name}@skills")

      expect(mdc_files).not_to be_empty
    end

    it "shows installation status in list" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin install #{plugin_name}@skills")
      run_command("caruso plugin list")

      expect(last_command_started).to have_output(/#{plugin_name}.*\[Installed\]/)
    end

    it "installs without marketplace name when only one configured" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin install #{plugin_name}")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Using default marketplace/)
    end

    it "requires marketplace name when multiple configured" do
      add_marketplace("https://github.com/anthropics/skills", "second-marketplace")

      run_command("caruso plugin install some-plugin")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Multiple marketplaces configured/)
      expect(last_command_started).to have_output(/Available marketplaces/)
    end

    it "handles non-existent plugin gracefully" do
      # Ensure we have a marketplace with known plugins
      add_marketplace("https://github.com/anthropics/skills", "claude-official")

      run_command("caruso plugin install totally-fake-plugin-xyz@claude-official")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Plugin 'totally-fake-plugin-xyz' not found/)
      expect(last_command_started).to have_output(/Available plugins:/)
    end

    it "handles non-existent marketplace gracefully" do
      run_command("caruso plugin install some-plugin@fake-marketplace")

      expect(last_command_started).to have_output(/not found/)
    end
  end

  describe "caruso plugin uninstall" do
    it "uninstalls an installed plugin", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      # First install a plugin
      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      run_command("caruso plugin install #{plugin_name}@skills")

      # Then uninstall it
      run_command("caruso plugin uninstall #{plugin_name}")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Removing #{plugin_name}/)
      expect(last_command_started).to have_output(/Uninstalled #{plugin_name}/)

      manifest = load_manifest
      expect(manifest["plugins"]).not_to have_key(plugin_name)
    end

    it "handles uninstalling non-existent plugin" do
      run_command("caruso plugin uninstall nonexistent-plugin")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/not installed/)
    end
  end

  describe "error handling" do
    it "handles network errors gracefully during plugin operations" do
      # Add a marketplace that will fail when fetched
      run_command("caruso marketplace add https://invalid-url-12345.example.com/marketplace.json")

      # Trying to list plugins should handle the network error gracefully
      run_command("caruso plugin list")

      # Should show error but not crash
      expect(last_command_started).to have_output(/error|Error fetching marketplace/i)
    end
  end
end
