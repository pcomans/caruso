# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Removal", type: :integration do
  before do
    init_caruso
  end

  describe "caruso marketplace remove" do
    context "when marketplace exists" do
      it "removes marketplace from manifest" do
        add_marketplace("https://github.com/anthropics/skills")

        # Verify it was added
        expect(load_manifest["marketplaces"]).to have_key("skills")

        run_command("caruso marketplace remove skills")

        expect(last_command_started).to be_successfully_executed
        manifest = load_manifest
        expect(manifest["marketplaces"]).not_to have_key("skills")
      end

      it "shows confirmation message" do
        add_marketplace("https://github.com/anthropics/skills", "test-marketplace")

        run_command("caruso marketplace remove test-marketplace")

        expect(last_command_started).to have_output(/Removed marketplace 'test-marketplace'/)
      end

      it "preserves other marketplaces when removing one" do
        add_marketplace("https://github.com/anthropics/skills", "marketplace-1")
        add_marketplace("https://github.com/example/other", "marketplace-2")
        add_marketplace("https://github.com/example/third", "marketplace-3")

        # Verify all were added
        manifest_before = load_manifest
        expect(manifest_before["marketplaces"].keys).to include("marketplace-1", "marketplace-2", "marketplace-3")

        run_command("caruso marketplace remove marketplace-2")

        expect(last_command_started).to be_successfully_executed

        manifest = load_manifest
        expect(manifest["marketplaces"]).to have_key("marketplace-1")
        expect(manifest["marketplaces"]).not_to have_key("marketplace-2")
        expect(manifest["marketplaces"]).to have_key("marketplace-3")
      end

      it "does not affect plugins section when removing marketplace" do
        add_marketplace("https://github.com/anthropics/skills")

        # Simulate having a plugin installed
        manifest = load_manifest
        manifest["plugins"] = {
          "test-plugin" => {
            "installed_at" => Time.now.iso8601,
            "files" => [".cursor/rules/test.mdc"],
            "marketplace" => "https://github.com/anthropics/skills"
          }
        }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso marketplace remove skills")

        updated_manifest = load_manifest
        expect(updated_manifest["plugins"]).to have_key("test-plugin")
        expect(updated_manifest["plugins"]["test-plugin"]["marketplace"]).to eq("https://github.com/anthropics/skills")
      end
    end

    context "when marketplace does not exist" do
      it "handles gracefully without error" do
        run_command("caruso marketplace remove nonexistent-marketplace")

        expect(last_command_started).to be_successfully_executed
      end

      it "does not modify manifest when removing non-existent marketplace" do
        add_marketplace("https://github.com/anthropics/skills")

        manifest_before = load_manifest
        run_command("caruso marketplace remove nonexistent")
        manifest_after = load_manifest

        expect(manifest_after).to eq(manifest_before)
      end
    end

    context "when removing last marketplace" do
      it "leaves empty marketplaces hash" do
        add_marketplace("https://github.com/anthropics/skills")

        # Verify it was added
        expect(load_manifest["marketplaces"]).to have_key("skills")

        run_command("caruso marketplace remove skills")

        expect(last_command_started).to be_successfully_executed

        manifest = load_manifest
        expect(manifest["marketplaces"]).to be_a(Hash)
        expect(manifest["marketplaces"]).to be_empty
      end

      it "maintains manifest structure with other sections" do
        add_marketplace("https://github.com/anthropics/skills")

        # Add a plugin to ensure other sections remain
        manifest = load_manifest
        manifest["plugins"] = { "test" => { "installed_at" => Time.now.iso8601 } }
        File.write(manifest_file, JSON.pretty_generate(manifest))

        run_command("caruso marketplace remove skills")

        updated_manifest = load_manifest
        expect(updated_manifest).to have_key("marketplaces")
        expect(updated_manifest).to have_key("plugins")
        expect(updated_manifest["plugins"]).to have_key("test")
      end
    end

    context "marketplace list after removal" do
      it "shows no marketplaces message after removing all" do
        # Start with no marketplaces by not adding any
        run_command("caruso marketplace list")

        expect(last_command_started).to have_output(/No marketplaces configured/)
      end

      it "lists remaining marketplaces after partial removal" do
        add_marketplace("https://github.com/anthropics/skills", "marketplace-1")
        add_marketplace("https://github.com/example/other", "marketplace-2")

        # Verify both were added
        expect(load_manifest["marketplaces"].keys).to include("marketplace-1", "marketplace-2")

        run_command("caruso marketplace remove marketplace-2")

        expect(last_command_started).to be_successfully_executed

        run_command("caruso marketplace list")

        expect(last_command_started).to have_output(/marketplace-1/)
        expect(last_command_started).not_to have_output(/marketplace-2/)
      end
    end
  end

  describe "marketplace removal edge cases" do
    it "handles removal from manifest with no marketplaces section" do
      # Start fresh without adding any marketplaces
      # The manifest will have no marketplaces section
      run_command("caruso marketplace remove any-name")

      expect(last_command_started).to be_successfully_executed
    end

    it "handles removal with corrupted marketplace name" do
      add_marketplace("https://github.com/anthropics/skills")

      run_command("caruso marketplace remove 'name with spaces'")

      expect(last_command_started).to be_successfully_executed
    end

    it "preserves marketplace URLs correctly after removal" do
      add_marketplace("https://github.com/anthropics/skills", "marketplace-1")
      add_marketplace("https://github.com/example/plugins.git", "marketplace-2")

      run_command("caruso marketplace remove marketplace-1")

      manifest = load_manifest
      expect(manifest["marketplaces"]["marketplace-2"]).to eq("https://github.com/example/plugins.git")
    end
  end
end
