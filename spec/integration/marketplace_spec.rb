# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Management", type: :integration do
  let(:test_marketplace_path) { File.expand_path("../fixtures/test-marketplace", __dir__) }

  before do
    init_caruso
  end

  describe "caruso marketplace add" do
    it "adds a marketplace from local path" do
      run_command("caruso marketplace add #{test_marketplace_path}")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Added marketplace/)
      expect(last_command_started).to have_output(/test-skills/)
    end

    it "creates config file" do
      add_marketplace(test_marketplace_path)

      expect(File.exist?(config_file)).to be true
    end

    it "registers marketplace in config with name from marketplace.json" do
      add_marketplace(test_marketplace_path)

      config = load_project_config
      expect(config["marketplaces"]).to have_key("test-skills")
      expect(config["marketplaces"]["test-skills"]["url"]).to eq(test_marketplace_path)
    end

    it "extracts name from marketplace.json" do
      add_marketplace(test_marketplace_path)

      config = load_project_config
      expect(config["marketplaces"]).to have_key("test-skills")
    end
  end

  describe "caruso marketplace list" do
    it "shows no marketplaces when empty" do
      run_command("caruso marketplace list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/No marketplaces configured/)
    end

    it "lists configured marketplaces" do
      add_marketplace(test_marketplace_path)

      run_command("caruso marketplace list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Configured Marketplaces:/)
      expect(last_command_started).to have_output(/test-skills/)
      expect(last_command_started).to have_output(/test-marketplace/)
    end
  end

  describe "caruso marketplace remove" do
    it "removes a marketplace" do
      add_marketplace(test_marketplace_path)

      run_command("caruso marketplace remove test-skills")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Removed marketplace/)

      config = load_project_config
      expect(config["marketplaces"]).not_to have_key("test-skills")
    end

    it "handles removing non-existent marketplace gracefully" do
      run_command("caruso marketplace remove nonexistent")

      expect(last_command_started).to be_successfully_executed
    end
  end

  describe "marketplace config structure" do
    it "creates proper JSON structure" do
      add_marketplace(test_marketplace_path)

      config = load_project_config
      expect(config).to be_a(Hash)
      expect(config["marketplaces"]).to be_a(Hash)
    end

    it "maintains plugins section separately" do
      add_marketplace(test_marketplace_path)

      config = load_project_config
      expect(config.keys).to include("marketplaces")
      # Plugins section added later during plugin installation
    end
  end
end
