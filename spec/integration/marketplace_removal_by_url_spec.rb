# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Marketplace Cancellation", type: :integration do
  before do
    init_caruso
  end

  it "removes a marketplace by its URL" do
    # Setup: Add marketplace
    add_marketplace

    # Get the URL (we know it from add_marketplace helper or defaults)
    url = test_marketplace_path

    # Action: Remove by URL
    run_command("caruso marketplace remove #{url}")

    expect(last_command_started).to be_successfully_executed
    # Should resolve to the name and remove it
    expect(last_command_started).to have_output(/Removed marketplace 'test-skills'/)

    # Verify removal from config
    config = load_project_config
    expect(config["marketplaces"]).not_to include("test-skills")
  end

  it "errors when removing a non-existent marketplace" do
    run_command("caruso marketplace remove non-existent")

    expect(last_command_started).not_to be_successfully_executed
    expect(last_command_started).to have_output(/Marketplace 'non-existent' not found/)
  end
end
