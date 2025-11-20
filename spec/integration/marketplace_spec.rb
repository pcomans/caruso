# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Management", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace add" do
    it "adds a marketplace from GitHub URL" do
      result = run_caruso("marketplace add https://github.com/anthropics/claude-code")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Added marketplace")
      expect(result[:output]).to include("claude-code")
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
      result = run_caruso("marketplace add https://github.com/anthropics/claude-code custom-name")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("custom-name")

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("custom-name")
    end

    it "extracts name from URL if not provided" do
      add_marketplace("https://github.com/anthropics/claude-code")

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("claude-code")
    end

    it "handles .git extension in URL" do
      result = run_caruso("marketplace add https://github.com/anthropics/claude-code.git")

      expect(result[:exit_code]).to eq(0)

      manifest = load_manifest
      expect(manifest["marketplaces"]).to have_key("claude-code")
    end
  end

  describe "caruso marketplace list" do
    it "shows no marketplaces when empty" do
      result = run_caruso("marketplace list")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("No marketplaces configured")
    end

    it "lists configured marketplaces" do
      add_marketplace("https://github.com/anthropics/claude-code")

      result = run_caruso("marketplace list")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Configured Marketplaces:")
      expect(result[:output]).to include("claude-code")
      expect(result[:output]).to include("github.com/anthropics/claude-code")
    end

    it "lists multiple marketplaces" do
      add_marketplace("https://github.com/anthropics/claude-code", "marketplace-1")
      add_marketplace("https://github.com/anthropics/claude-code", "marketplace-2")

      result = run_caruso("marketplace list")

      expect(result[:output]).to include("marketplace-1")
      expect(result[:output]).to include("marketplace-2")
    end
  end

  describe "caruso marketplace remove" do
    it "removes a marketplace" do
      add_marketplace("https://github.com/anthropics/claude-code")

      result = run_caruso("marketplace remove claude-code")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("Removed marketplace")

      manifest = load_manifest
      expect(manifest["marketplaces"]).not_to have_key("claude-code")
    end

    it "handles removing non-existent marketplace gracefully" do
      result = run_caruso("marketplace remove nonexistent")

      expect(result[:exit_code]).to eq(0)
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
