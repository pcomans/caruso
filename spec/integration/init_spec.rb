# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Caruso Initialization", type: :integration do
  describe "caruso init" do
    it "initializes Caruso with cursor IDE" do
      run_command("caruso init --ide=cursor")

      expect(last_command_started).to be_successfully_executed
      expect(last_command_started).to have_output(/✓ Initialized Caruso for cursor/)
      expect(File.exist?(config_file)).to be true
    end

    it "creates valid config file" do
      init_caruso

      config = load_config
      expect(config["ide"]).to eq("cursor")
      expect(config["target_dir"]).to eq(".cursor/rules")
      expect(config["version"]).to eq("1.0.0")
      expect(config["initialized_at"]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "shows project directory in output" do
      run_command("caruso init --ide=cursor")

      expect(last_command_started).to have_output(/Project directory:/)
      expect(last_command_started).to have_output(/Target directory: \.cursor\/rules/)
      expect(last_command_started).to have_output(/Config saved to:/)
    end

    it "prevents double initialization" do
      init_caruso

      run_command("caruso init --ide=cursor")

      expect(last_command_started).to have_exit_status(1)
      expect(last_command_started).to have_output(/already initialized/)
    end

    it "rejects unsupported IDE" do
      run_command("caruso init --ide=vscode")

      expect(last_command_started).to have_exit_status(1)
      expect(last_command_started).to have_output(/Unsupported IDE/)
    end

    it "requires --ide flag" do
      run_command("caruso init")

      # Thor may show help or error - either way should mention --ide
      expect(last_command_started).to have_output(/--ide|required/)
    end

    it "initializes in specific directory" do
      run_command("mkdir -p subproject")
      run_command("caruso init subproject --ide=cursor")

      expect(last_command_started).to be_successfully_executed
      expect(File.exist?(File.join(aruba.current_directory, "subproject", ".caruso.json"))).to be true
    end
  end

  describe "commands without initialization" do
    it "marketplace commands require init" do
      run_command("caruso marketplace list")

      expect(last_command_started).to have_exit_status(1)
      expect(last_command_started).to have_output(/not initialized/)
      expect(last_command_started).to have_output(/caruso init/)
    end

    it "plugin commands require init" do
      run_command("caruso plugin list")

      expect(last_command_started).to have_exit_status(1)
      expect(last_command_started).to have_output(/not initialized/)
    end
  end
end
