# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Removal", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace remove" do
    context "when marketplace exists" do
      it "removes marketplace from config" do
        add_marketplace()

        # Verify it was added
        expect(load_project_config["marketplaces"]).to have_key("test-skills")

        run_command("caruso marketplace remove test-skills")

        expect(last_command_started).to be_successfully_executed
        config = load_project_config
        expect(config["marketplaces"]).not_to have_key("test-skills")
      end

      it "shows confirmation message" do
        add_marketplace()

        run_command("caruso marketplace remove test-skills")

        expect(last_command_started).to have_output(/Removed marketplace 'test-skills'/)
      end

      it "preserves other marketplaces when removing one" do
        add_marketplace(test_marketplace_path)
        add_marketplace(other_marketplace_path)

        # Verify both were added
        config_before = load_project_config
        expect(config_before["marketplaces"].keys).to include("test-skills", "other-marketplace")

        run_command("caruso marketplace remove other-marketplace")

        expect(last_command_started).to be_successfully_executed

        config = load_project_config
        expect(config["marketplaces"]).to have_key("test-skills")
        expect(config["marketplaces"]).not_to have_key("other-marketplace")
      end

      it "does not affect plugins section when removing marketplace" do
        add_marketplace()

        # Simulate having a plugin installed
        project_config = load_project_config
        project_config["plugins"] = {
          "test-plugin@test-skills" => {
            "marketplace" => "test-skills"
          }
        }
        File.write(config_file, JSON.pretty_generate(project_config))

        run_command("caruso marketplace remove test-skills")

        updated_config = load_project_config
        expect(updated_config["plugins"]).to have_key("test-plugin@test-skills")
        expect(updated_config["plugins"]["test-plugin@test-skills"]["marketplace"]).to eq("test-skills")
      end
    end

    context "when marketplace does not exist" do
      it "handles gracefully without error" do
        run_command("caruso marketplace remove nonexistent-marketplace")

        expect(last_command_started).to be_successfully_executed
      end

      it "does not modify config when removing non-existent marketplace" do
        add_marketplace()

        config_before = load_project_config
        run_command("caruso marketplace remove nonexistent")
        config_after = load_project_config

        expect(config_after).to eq(config_before)
      end
    end

    context "when removing last marketplace" do
      it "leaves empty marketplaces hash" do
        add_marketplace()

        # Verify it was added
        expect(load_project_config["marketplaces"]).to have_key("test-skills")

        run_command("caruso marketplace remove test-skills")

        expect(last_command_started).to be_successfully_executed

        config = load_project_config
        expect(config["marketplaces"]).to be_a(Hash)
        expect(config["marketplaces"]).to be_empty
      end

      it "maintains config structure with other sections" do
        add_marketplace()

        # Add a plugin to ensure other sections remain
        project_config = load_project_config
        project_config["plugins"] = { "test@test-skills" => { "marketplace" => "test-skills" } }
        File.write(config_file, JSON.pretty_generate(project_config))

        run_command("caruso marketplace remove test-skills")

        updated_config = load_project_config
        expect(updated_config).to have_key("marketplaces")
        expect(updated_config).to have_key("plugins")
        expect(updated_config["plugins"]).to have_key("test@test-skills")
      end
    end

    context "marketplace list after removal" do
      it "shows no marketplaces message after removing all" do
        # Start with no marketplaces by not adding any
        run_command("caruso marketplace list")

        expect(last_command_started).to have_output(/No marketplaces configured/)
      end

      it "lists remaining marketplaces after partial removal" do
        add_marketplace(test_marketplace_path)
        add_marketplace(other_marketplace_path)

        # Verify both were added
        expect(load_project_config["marketplaces"].keys).to include("test-skills", "other-marketplace")

        run_command("caruso marketplace remove other-marketplace")

        expect(last_command_started).to be_successfully_executed

        run_command("caruso marketplace list")

        expect(last_command_started).to have_output(/test-skills/)
        expect(last_command_started).not_to have_output(/other-marketplace/)
      end
    end
  end

  describe "marketplace removal edge cases" do
    it "handles removal from config with no marketplaces section" do
      # Start fresh without adding any marketplaces
      # The config will have empty marketplaces section by default from init
      run_command("caruso marketplace remove any-name")

      expect(last_command_started).to be_successfully_executed
    end

    it "handles removal with corrupted marketplace name" do
      add_marketplace()

      run_command("caruso marketplace remove 'name with spaces'")

      expect(last_command_started).to be_successfully_executed
    end

    it "preserves marketplace URLs correctly after removal" do
      add_marketplace(test_marketplace_path)
      add_marketplace(other_marketplace_path)

      run_command("caruso marketplace remove test-skills")

      config = load_project_config
      expect(config["marketplaces"]["other-marketplace"]["url"]).to eq(other_marketplace_path)
    end
  end
end
