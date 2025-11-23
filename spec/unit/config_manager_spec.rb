# frozen_string_literal: true

require "spec_helper"
require "caruso/config_manager"

RSpec.describe Caruso::ConfigManager do
  let(:project_dir) { Dir.mktmpdir }
  let(:manager) { described_class.new(project_dir) }
  let(:project_config_path) { File.join(project_dir, "caruso.json") }
  let(:local_config_path) { File.join(project_dir, ".caruso.local.json") }

  after do
    FileUtils.remove_entry(project_dir)
  end

  describe "#init" do
    it "creates both config files" do
      manager.init(ide: "cursor")

      expect(File.exist?(project_config_path)).to be true
      expect(File.exist?(local_config_path)).to be true
    end

    it "adds local config to gitignore" do
      manager.init(ide: "cursor")
      gitignore = File.read(File.join(project_dir, ".gitignore"))
      expect(gitignore).to include(".caruso.local.json")
    end

    it "raises error if already initialized" do
      manager.init(ide: "cursor")
      expect { manager.init(ide: "cursor") }.to raise_error(Caruso::Error)
    end
  end

  describe "#load" do
    before do
      manager.init(ide: "cursor")
    end

    it "loads and merges configuration" do
      config = manager.load
      expect(config["ide"]).to eq("cursor")
      expect(config["version"]).to eq("1.0.0")
    end
  end

  describe "Plugin Management" do
    before do
      manager.init(ide: "cursor")
    end

    it "adds plugin to project and local config" do
      manager.add_plugin("test-plugin@market", ["file1.md"], marketplace_name: "market")

      project_config = JSON.parse(File.read(project_config_path))
      local_config = JSON.parse(File.read(local_config_path))

      expect(project_config["plugins"]["test-plugin@market"]).to eq({ "marketplace" => "market" })
      expect(local_config["installed_files"]["test-plugin@market"]).to eq(["file1.md"])
    end

    it "removes plugin and returns files" do
      manager.add_plugin("test-plugin@market", ["file1.md"], marketplace_name: "market")
      files = manager.remove_plugin("test-plugin@market")

      expect(files).to eq(["file1.md"])

      project_config = JSON.parse(File.read(project_config_path))
      local_config = JSON.parse(File.read(local_config_path))

      expect(project_config["plugins"]).not_to have_key("test-plugin@market")
      expect(local_config["installed_files"]).not_to have_key("test-plugin@market")
    end
  end

  describe "Marketplace Management" do
    before do
      manager.init(ide: "cursor")
    end

    it "adds marketplace to project config" do
      manager.add_marketplace("test-market", "https://example.com/repo.git", source: "git", ref: "main")

      project_config = JSON.parse(File.read(project_config_path))
      expect(project_config["marketplaces"]["test-market"]).to include(
        "url" => "https://example.com/repo.git",
        "source" => "git",
        "ref" => "main"
      )
    end
  end
end
