# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Management", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace add" do
    it "adds a marketplace from GitHub URL" do
      run_command("caruso marketplace add https://github.com/anthropics/skills")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Added marketplace/)
      expect(last_command_started).to have_output(/skills/)
    end

    it "creates config file" do
      add_marketplace("https://github.com/anthropics/skills", "skills")

      expect(File.exist?(config_file)).to be true
    end

    it "registers marketplace in config" do
      add_marketplace("https://github.com/anthropics/skills", "skills")

      config = load_project_config
      expect(config["marketplaces"]).to have_key("skills")
      expect(config["marketplaces"]["skills"]["url"]).to include("skills")
    end

    it "adds marketplace with custom name" do
      run_command("caruso marketplace add https://github.com/anthropics/skills custom-name")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/custom-name/)

      config = load_project_config
      expect(config["marketplaces"]).to have_key("custom-name")
    end

    it "extracts name from URL if not provided" do
      add_marketplace("https://github.com/anthropics/skills")

      config = load_project_config
      expect(config["marketplaces"]).to have_key("skills")
    end

    it "handles .git extension in URL" do
      run_command("caruso marketplace add https://github.com/anthropics/skills.git")

      expect(last_command_started).to be_successfully_executed

      config = load_project_config
      expect(config["marketplaces"]).to have_key("skills")
    end
  end

  describe "caruso marketplace list" do
    it "shows no marketplaces when empty" do
      run_command("caruso marketplace list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/No marketplaces configured/)
    end

    it "lists configured marketplaces" do
      add_marketplace("https://github.com/anthropics/skills", "skills")

      run_command("caruso marketplace list")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Configured Marketplaces:/)
      expect(last_command_started).to have_output(/skills/)
      expect(last_command_started).to have_output(%r{github\.com/anthropics/skills})
    end

    it "lists multiple marketplaces" do
      add_marketplace("https://github.com/anthropics/skills", "marketplace-1")
      add_marketplace("https://github.com/anthropics/skills", "marketplace-2")

      run_command("caruso marketplace list")

      expect(last_command_started).to have_output(/marketplace-1/)
      expect(last_command_started).to have_output(/marketplace-2/)
    end
  end

  describe "caruso marketplace remove" do
    it "removes a marketplace" do
      add_marketplace("https://github.com/anthropics/skills", "skills")

      run_command("caruso marketplace remove skills")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/Removed marketplace/)

      config = load_project_config
      expect(config["marketplaces"]).not_to have_key("skills")
    end

    it "handles removing non-existent marketplace gracefully" do
      run_command("caruso marketplace remove nonexistent")

      expect(last_command_started).to be_successfully_executed
    end
  end

  describe "marketplace config structure" do
    it "creates proper JSON structure" do
      add_marketplace("https://github.com/anthropics/skills", "skills")

      config = load_project_config
      expect(config).to be_a(Hash)
      expect(config["marketplaces"]).to be_a(Hash)
    end

    it "maintains plugins section separately" do
      add_marketplace("https://github.com/anthropics/skills", "skills")

      config = load_project_config
      expect(config.keys).to include("marketplaces")
      # Plugins section added later during plugin installation
    end
  end
end
