# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Uninstall", type: :integration do
  before do
    init_caruso
  end

  it "removes installed plugins when marketplace is removed" do
    # 1. Setup: Add marketplace and install plugin

    # We need a plugin to install. We can fake the config for this test
    # to avoid needing a real network request or complex fixture setup
    # if we just want to test the CLI logic for removal.
    # However, to test full integration we might want to "install" carefully.

    # Let's manually inject the state into caruso.json and .caruso.local.json
    # to simulate an installed plugin, as if `caruso plugin install` had run.

    project_config = load_project_config
    project_config["marketplaces"]["test-skills"] = {
      "url" => "https://github.com/test/skills",
      "source" => "git"
    }
    project_config["plugins"]["test-plugin@test-skills"] = {
      "marketplace" => "test-skills"
    }
    File.write(config_file, JSON.pretty_generate(project_config))

    local_config = load_local_config
    plugin_file = ".cursor/rules/test-plugin.mdc"
    local_config["installed_files"]["test-plugin@test-skills"] = [plugin_file]
    File.write(local_config_file, JSON.pretty_generate(local_config))

    # Create the dummy file
    full_plugin_path = File.join(aruba.current_directory, plugin_file)
    FileUtils.mkdir_p(File.dirname(full_plugin_path))
    File.write(full_plugin_path, "Plugin content")

    expect(File.exist?(full_plugin_path)).to be true

    # 2. Action: Remove marketplace
    run_command("caruso marketplace remove test-skills")
    expect(last_command_started).to be_successfully_executed

    # 3. Assertion: Verify cleanup

    # Marketplace should be gone
    updated_project_config = load_project_config
    expect(updated_project_config["marketplaces"]).not_to include("test-skills")

    # Plugin config should be gone
    expect(updated_project_config["plugins"]).not_to include("test-plugin@test-skills")

    # Plugin files should be gone
    expect(File.exist?(full_plugin_path)).to be false
  end
end
