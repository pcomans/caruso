# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Management", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace add" do
    it "adds a marketplace from GitHub URL" do
      run_command("caruso marketplace add https://github.com/anthropics/claude-code")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Added marketplace/)
      expect(last_command_started).to have_output(/claude-code/)
    end

    it "creates manifest file" do
      add_marketplace("https://github.com/anthropics/claude-code")

      expect(File.exist?(manifest_file)).to be true
    end

    it "registers marketplace in manifest" do
      add_marketplace("https://github.com/anthropics/claude-code")

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("claude-code")
      expect(manifest["marketplaces"]["claude-code"]).to include("claude-code")
    end

    it "adds marketplace with custom name" do
      run_command("caruso marketplace add https://github.com/anthropics/claude-code custom-name")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/custom-name/)

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("custom-name")
    end

    it "extracts name from URL if not provided" do
      add_marketplace("https://github.com/anthropics/claude-code")

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("claude-code")
    end

    it "handles .git extension in URL" do
      run_command("caruso marketplace add https://github.com/anthropics/claude-code.git")

      expect(last_command_started).to be_successfully_executed

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("claude-code")
    end
  end

  describe "caruso marketplace list" do
    it "shows no marketplaces when empty" do
      run_command("caruso marketplace list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/No marketplaces configured/)
    end

    it "lists configured marketplaces" do
      add_marketplace("https://github.com/anthropics/claude-code")

      run_command("caruso marketplace list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Configured Marketplaces:/)
      expect(last_command_started).to have_output(/claude-code/)
      expect(last_command_started).to have_output(/github\.com\/anthropics\/claude-code/)
    end

    it "lists multiple marketplaces" do
      add_marketplace("https://github.com/anthropics/claude-code", "marketplace-1")
      add_marketplace("https://github.com/anthropics/claude-code", "marketplace-2")

      run_command("caruso marketplace list")

      expect(last_command_started).to have_output(/marketplace-1/)
      expect(last_command_started).to have_output(/marketplace-2/)
    end
  end

  describe "caruso marketplace remove" do
    it "removes a marketplace" do
      add_marketplace("https://github.com/anthropics/claude-code")

      run_command("caruso marketplace remove claude-code")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Removed marketplace/)

      manifest = load_manifest
      expect(manifest["marketplaces"]).not_to have_key("claude-code")
    end

    it "handles removing non-existent marketplace gracefully" do
      run_command("caruso marketplace remove nonexistent")

      expect(last_command_started).to be_successfully_executed
    end
  end

  describe "marketplace manifest structure" do
    it "creates proper JSON structure" do
      add_marketplace("https://github.com/anthropics/claude-code")

      manifest = load_manifest
      expect(manifest).to be_a(Hash)
      expect(manifest["marketplaces"]).to be_a(Hash)
    end

    it "maintains plugins section separately" do
      add_marketplace("https://github.com/anthropics/claude-code")

      manifest = load_manifest
      expect(manifest.keys).to include("marketplaces")
      # Plugins section added later during plugin installation
    end
  end
end
