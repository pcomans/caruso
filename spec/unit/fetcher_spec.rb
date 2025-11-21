# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Caruso::Fetcher do
  let(:cache_dir) { Dir.mktmpdir }
  let(:marketplace_dir) { Dir.mktmpdir }
  let(:marketplace_json) { File.join(marketplace_dir, ".claude-plugin", "marketplace.json") }

  after do
    FileUtils.rm_rf(cache_dir)
    FileUtils.rm_rf(marketplace_dir)
  end

  def create_plugin_structure(plugin_dir, files)
    files.each do |file_path|
      full_path = File.join(plugin_dir, file_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, "# #{File.basename(file_path)}\n\nContent")
    end
  end

  def create_marketplace(plugins)
    FileUtils.mkdir_p(File.dirname(marketplace_json))
    marketplace_data = {
      "name" => "test-marketplace",
      "owner" => { "name" => "Test" },
      "plugins" => plugins
    }
    File.write(marketplace_json, JSON.pretty_generate(marketplace_data))
  end

  describe "#fetch_plugin with standard structure" do
    it "finds files in default directories" do
      plugin_dir = File.join(marketplace_dir, "standard-plugin")
      create_plugin_structure(plugin_dir, [
        "commands/deploy.md",
        "agents/reviewer.md",
        "skills/pdf/SKILL.md"
      ])

      create_marketplace([{
        "name" => "standard-plugin",
        "source" => "./standard-plugin"
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("standard-plugin")

      expect(files.length).to eq(3)
      expect(files.map { |f| File.basename(f) }).to contain_exactly("deploy.md", "reviewer.md", "SKILL.md")
    end

    it "excludes README.md and LICENSE.md" do
      plugin_dir = File.join(marketplace_dir, "standard-plugin")
      create_plugin_structure(plugin_dir, [
        "commands/deploy.md",
        "commands/README.md",
        "skills/LICENSE.md"
      ])

      create_marketplace([{
        "name" => "standard-plugin",
        "source" => "./standard-plugin"
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("standard-plugin")

      expect(files.length).to eq(1)
      expect(File.basename(files.first)).to eq("deploy.md")
    end
  end

  describe "#fetch_plugin with custom commands array" do
    it "includes both default and custom command paths" do
      plugin_dir = File.join(marketplace_dir, "custom-commands")
      create_plugin_structure(plugin_dir, [
        "commands/standard.md",
        "custom/special.md",
        "experimental/beta.md"
      ])

      create_marketplace([{
        "name" => "custom-commands",
        "source" => "./custom-commands",
        "commands" => ["./custom/special.md", "./experimental/"]
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("custom-commands")

      expect(files.length).to eq(3)
      expect(files.map { |f| File.basename(f) }).to contain_exactly("standard.md", "special.md", "beta.md")
    end

    it "handles string format for commands" do
      plugin_dir = File.join(marketplace_dir, "custom-commands")
      create_plugin_structure(plugin_dir, [
        "commands/standard.md",
        "custom/special.md"
      ])

      create_marketplace([{
        "name" => "custom-commands",
        "source" => "./custom-commands",
        "commands" => "./custom/special.md"
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("custom-commands")

      expect(files.length).to eq(2)
      expect(files.map { |f| File.basename(f) }).to contain_exactly("standard.md", "special.md")
    end
  end

  describe "#fetch_plugin with custom agents array" do
    it "includes both default and custom agent paths" do
      plugin_dir = File.join(marketplace_dir, "custom-agents")
      create_plugin_structure(plugin_dir, [
        "agents/standard.md",
        "custom/agents/security.md",
        "experimental/agents/ai.md"
      ])

      create_marketplace([{
        "name" => "custom-agents",
        "source" => "./custom-agents",
        "agents" => ["./custom/agents/", "./experimental/agents/"]
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("custom-agents")

      expect(files.length).to eq(3)
      expect(files.map { |f| File.basename(f) }).to contain_exactly("standard.md", "security.md", "ai.md")
    end
  end

  describe "#fetch_plugin with custom skills array" do
    it "includes both default and custom skill paths" do
      plugin_dir = File.join(marketplace_dir, "custom-skills")
      create_plugin_structure(plugin_dir, [
        "skills/pdf/SKILL.md",
        "document-skills/xlsx/SKILL.md",
        "document-skills/docx/SKILL.md"
      ])

      create_marketplace([{
        "name" => "custom-skills",
        "source" => "./custom-skills",
        "skills" => ["./document-skills/xlsx", "./document-skills/docx"]
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("custom-skills")

      expect(files.length).to eq(3)
      expect(files.select { |f| f.include?("xlsx") }.length).to eq(1)
      expect(files.select { |f| f.include?("docx") }.length).to eq(1)
      expect(files.select { |f| f.include?("skills/pdf") }.length).to eq(1)
    end
  end

  describe "#fetch_plugin with all custom paths" do
    it "handles commands, agents, and skills together" do
      plugin_dir = File.join(marketplace_dir, "all-custom")
      create_plugin_structure(plugin_dir, [
        "commands/standard.md",
        "agents/standard.md",
        "skills/standard/SKILL.md",
        "custom/cmd/special.md",
        "custom/agents/special.md",
        "custom/skills/special/SKILL.md"
      ])

      create_marketplace([{
        "name" => "all-custom",
        "source" => "./all-custom",
        "commands" => ["./custom/cmd/"],
        "agents" => ["./custom/agents/"],
        "skills" => ["./custom/skills/"]
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("all-custom")

      expect(files.length).to eq(6)
    end
  end

  describe "#fetch_plugin deduplication" do
    it "deduplicates files that appear in both default and custom paths" do
      plugin_dir = File.join(marketplace_dir, "duplicate-plugin")
      create_plugin_structure(plugin_dir, [
        "commands/deploy.md"
      ])

      create_marketplace([{
        "name" => "duplicate-plugin",
        "source" => "./duplicate-plugin",
        "commands" => ["./commands/deploy.md"]
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("duplicate-plugin")

      # Should only return the file once, even though it's in both default and custom paths
      expect(files.length).to eq(1)
    end
  end

  describe "#fetch_plugin with non-existent custom paths" do
    it "gracefully handles missing custom path directories" do
      plugin_dir = File.join(marketplace_dir, "missing-paths")
      create_plugin_structure(plugin_dir, [
        "commands/standard.md"
      ])

      create_marketplace([{
        "name" => "missing-paths",
        "source" => "./missing-paths",
        "commands" => ["./nonexistent/dir/"]
      }])

      fetcher = described_class.new(marketplace_json, cache_dir: cache_dir)
      files = fetcher.fetch("missing-paths")

      # Should still find the standard command
      expect(files.length).to eq(1)
      expect(File.basename(files.first)).to eq("standard.md")
    end
  end
end
