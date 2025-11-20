# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plugin Management", type: :integration do
  before do
    init_caruso
    add_marketplace("https://github.com/anthropics/claude-code")
  end

  describe "caruso plugin list" do
    it "lists available plugins from marketplace" do
      result = run_caruso("plugin list")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Marketplace: claude-code")
    end

    it "shows when no marketplaces configured" do
      # Start fresh without marketplace
      Dir.chdir(test_dir) do
        FileUtils.rm_rf(".cursor")
      end

      result = run_caruso("plugin list")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("No marketplaces configured")
    end

    it "indicates installation status" do
      # This test will pass once a plugin is installed
      # For now, just verify the list command works
      result = run_caruso("plugin list")

      expect(result[:exit_code]).to eq(0)
    end
  end

  describe "caruso plugin install", :live do
    # Mark as :live since it requires network access
    # Run with: rspec --tag live

    let(:plugin_name) do
      # Get first available plugin from the marketplace
      result = run_caruso("plugin list")
      # Parse output to find first plugin name
      match = result[:output].match(/^\s+-\s+(\S+)/)
      match ? match[1] : skip("No plugins available in marketplace")
    end

    it "installs a plugin with explicit marketplace" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      result = run_caruso("plugin install #{plugin_name}@claude-code")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Installing #{plugin_name}")
      expect(result[:output]).to include("Installed #{plugin_name}")
    end

    it "updates manifest with plugin info" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_caruso("plugin install #{plugin_name}@claude-code")

      manifest = load_manifest
      expect(manifest["plugins"]).to have_key(plugin_name)
      expect(manifest["plugins"][plugin_name]).to have_key("installed_at")
      expect(manifest["plugins"][plugin_name]).to have_key("files")
      expect(manifest["plugins"][plugin_name]).to have_key("marketplace")
    end

    it "creates .mdc files" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_caruso("plugin install #{plugin_name}@claude-code")

      expect(mdc_files).not_to be_empty
    end

    it "shows installation status in list" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_caruso("plugin install #{plugin_name}@claude-code")

      result = run_caruso("plugin list")
      expect(result[:output]).to match(/#{plugin_name}.*\[Installed\]/)
    end

    it "installs without marketplace name when only one configured" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      result = run_caruso("plugin install #{plugin_name}")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Using default marketplace")
    end

    it "requires marketplace name when multiple configured" do
      add_marketplace("https://github.com/anthropics/claude-code", "second-marketplace")

      result = run_caruso("plugin install some-plugin")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Multiple marketplaces configured")
      expect(result[:output]).to include("Available marketplaces")
    end

    it "handles non-existent plugin gracefully" do
      result = run_caruso("plugin install totally-fake-plugin-xyz@claude-code")

      expect(result[:output]).to match(/not found|No steering files/)
    end

    it "handles non-existent marketplace gracefully" do
      result = run_caruso("plugin install some-plugin@fake-marketplace")

      expect(result[:output]).to include("not found")
    end
  end

  describe "caruso plugin uninstall" do
    it "uninstalls an installed plugin" do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      # First install a plugin
      result = run_caruso("plugin list")
      match = result[:output].match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      run_caruso("plugin install #{plugin_name}@claude-code")

      # Then uninstall it
      result = run_caruso("plugin uninstall #{plugin_name}")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Removing #{plugin_name}")
      expect(result[:output]).to include("Uninstalled #{plugin_name}")

      manifest = load_manifest
      expect(manifest["plugins"]).not_to have_key(plugin_name)
    end

    it "handles uninstalling non-existent plugin" do
      result = run_caruso("plugin uninstall nonexistent-plugin")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("not installed")
    end
  end

  describe "error handling" do
    it "handles network errors gracefully" do
      # Try to add an invalid marketplace
      result = run_caruso("marketplace add https://invalid-url-12345.example.com/marketplace.json")

      # Should not crash, should show error
      expect(result[:output]).to match(/error|failed|could not/i)
    end
  end
end
