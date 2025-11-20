# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Caruso Initialization", type: :integration do
  describe "caruso init" do
    it "initializes Caruso with cursor IDE" do
      result = run_caruso("init --ide=cursor")

      expect(result[:exit_code]).to eq(0)
      expect(result[:output]).to include("✓ Initialized Caruso for cursor")
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
      result = run_caruso("init --ide=cursor")

      expect(result[:output]).to include("Project directory:")
      expect(result[:output]).to include("Target directory: .cursor/rules")
      expect(result[:output]).to include("Config saved to:")
    end

    it "prevents double initialization" do
      init_caruso

      result = run_caruso("init --ide=cursor")

      expect(result[:exit_code]).to eq(1)
      expect(result[:output]).to include("already initialized")
    end

    it "rejects unsupported IDE" do
      result = run_caruso("init --ide=vscode")

      expect(result[:exit_code]).to eq(1)
      expect(result[:output]).to include("Unsupported IDE")
    end

    it "requires --ide flag" do
      result = run_caruso("init")

      # Thor may show help or error - either way should mention --ide
      expect(result[:output]).to match(/--ide|required/)
    end

    it "initializes in specific directory" do
      subdir = File.join(test_dir, "subproject")
      FileUtils.mkdir_p(subdir)

      result = run_caruso("init #{subdir} --ide=cursor")

      expect(result[:exit_code]).to eq(0)
      expect(File.exist?(File.join(subdir, ".caruso.json"))).to be true
    end
  end

  describe "commands without initialization" do
    it "marketplace commands require init" do
      result = run_caruso("marketplace list")

      expect(result[:exit_code]).to eq(1)
      expect(result[:output]).to include("not initialized")
      expect(result[:output]).to include("caruso init")
    end

    it "plugin commands require init" do
      result = run_caruso("plugin list")

      expect(result[:exit_code]).to eq(1)
      expect(result[:output]).to include("not initialized")
    end
  end
end
