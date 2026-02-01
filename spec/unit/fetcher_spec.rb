# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Caruso::Fetcher do
  let(:home_dir) { Dir.mktmpdir }
  let(:marketplace_dir) { Dir.mktmpdir }
  let(:marketplace_json) { File.join(marketplace_dir, ".claude-plugin", "marketplace.json") }
  let(:marketplace_name) { "test-marketplace" }

  before do
    allow(Dir).to receive(:home).and_return(home_dir)
  end

  after do
    FileUtils.rm_rf(home_dir)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
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

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("missing-paths")

      # Should still find the standard command
      expect(files.length).to eq(1)
      expect(File.basename(files.first)).to eq("standard.md")
    end
  end

  describe "#fetch_plugin with plugin.json" do
    it "reads component paths from plugin.json when marketplace entry omits them" do
      plugin_dir = File.join(marketplace_dir, "plugin-json-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/standard.md",
                                "custom/extra.md"
                              ])

      # Write plugin.json with custom commands path
      plugin_json_dir = File.join(plugin_dir, ".claude-plugin")
      FileUtils.mkdir_p(plugin_json_dir)
      File.write(File.join(plugin_json_dir, "plugin.json"), JSON.pretty_generate(
                                                              { "name" => "plugin-json-plugin", "commands" => ["./custom/"] }
                                                            ))

      create_marketplace([{
                           "name" => "plugin-json-plugin",
                           "source" => "./plugin-json-plugin"
                           # No commands field — should fall back to plugin.json
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("plugin-json-plugin")

      basenames = files.map { |f| File.basename(f) }
      expect(basenames).to include("standard.md") # default dir
      expect(basenames).to include("extra.md")    # from plugin.json
    end

    it "marketplace entry takes precedence over plugin.json" do
      plugin_dir = File.join(marketplace_dir, "precedence-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/standard.md",
                                "marketplace-custom/mp.md",
                                "plugin-custom/pj.md"
                              ])

      # plugin.json says use plugin-custom/
      plugin_json_dir = File.join(plugin_dir, ".claude-plugin")
      FileUtils.mkdir_p(plugin_json_dir)
      File.write(File.join(plugin_json_dir, "plugin.json"), JSON.pretty_generate(
                                                              { "name" => "precedence-plugin", "commands" => ["./plugin-custom/"] }
                                                            ))

      # marketplace says use marketplace-custom/ — this should win
      create_marketplace([{
                           "name" => "precedence-plugin",
                           "source" => "./precedence-plugin",
                           "commands" => ["./marketplace-custom/"]
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("precedence-plugin")

      basenames = files.map { |f| File.basename(f) }
      expect(basenames).to include("standard.md") # default dir always scanned
      expect(basenames).to include("mp.md")       # from marketplace entry
      expect(basenames).not_to include("pj.md")   # plugin.json overridden
    end

    it "handles missing plugin.json gracefully" do
      plugin_dir = File.join(marketplace_dir, "no-plugin-json")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])
      # No .claude-plugin/plugin.json

      create_marketplace([{
                           "name" => "no-plugin-json",
                           "source" => "./no-plugin-json"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("no-plugin-json")

      expect(files.length).to eq(1)
      expect(File.basename(files.first)).to eq("deploy.md")
    end

    it "handles malformed plugin.json gracefully" do
      plugin_dir = File.join(marketplace_dir, "bad-plugin-json")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])

      plugin_json_dir = File.join(plugin_dir, ".claude-plugin")
      FileUtils.mkdir_p(plugin_json_dir)
      File.write(File.join(plugin_json_dir, "plugin.json"), "not valid json {{{")

      create_marketplace([{
                           "name" => "bad-plugin-json",
                           "source" => "./bad-plugin-json"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("bad-plugin-json")

      # Should still work with defaults
      expect(files.length).to eq(1)
      expect(File.basename(files.first)).to eq("deploy.md")
    end

    it "reads inline hooks config from plugin.json" do
      plugin_dir = File.join(marketplace_dir, "inline-hooks-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])

      # plugin.json with inline hooks (object, not path)
      plugin_json_dir = File.join(plugin_dir, ".claude-plugin")
      FileUtils.mkdir_p(plugin_json_dir)
      File.write(File.join(plugin_json_dir, "plugin.json"), JSON.pretty_generate(
                                                              {
                                                                "name" => "inline-hooks-plugin",
                                                                "hooks" => {
                                                                  "hooks" => {
                                                                    "Stop" => [{ "hooks" => [{ "type" => "command", "command" => "echo inline" }] }]
                                                                  }
                                                                }
                                                              }
                                                            ))

      create_marketplace([{
                           "name" => "inline-hooks-plugin",
                           "source" => "./inline-hooks-plugin"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("inline-hooks-plugin")

      # Should include the generated inline hooks file
      hooks_files = files.select { |f| File.basename(f) =~ /hooks\.json\z/ }
      expect(hooks_files.length).to eq(1)
    end
  end

  describe "#fetch_plugin with hooks" do
    it "detects hooks.json in the default hooks/ directory" do
      plugin_dir = File.join(marketplace_dir, "hooks-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])
      # hooks.json is JSON, not markdown, so write it explicitly
      hooks_dir = File.join(plugin_dir, "hooks")
      FileUtils.mkdir_p(hooks_dir)
      File.write(File.join(hooks_dir, "hooks.json"), JSON.pretty_generate(
                                                       { "hooks" => { "PostToolUse" => [{ "matcher" => "Write", "hooks" => [{ "type" => "command", "command" => "echo test" }] }] } }
                                                     ))

      create_marketplace([{
                           "name" => "hooks-plugin",
                           "source" => "./hooks-plugin"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("hooks-plugin")

      basenames = files.map { |f| File.basename(f) }
      expect(basenames).to include("hooks.json")
      expect(basenames).to include("deploy.md")
    end

    it "detects hooks.json at a custom path from manifest" do
      plugin_dir = File.join(marketplace_dir, "custom-hooks-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])
      custom_hooks_dir = File.join(plugin_dir, "custom", "my-hooks")
      FileUtils.mkdir_p(custom_hooks_dir)
      File.write(File.join(custom_hooks_dir, "hooks.json"), JSON.pretty_generate(
                                                              { "hooks" => { "Stop" => [{ "hooks" => [{ "type" => "command", "command" => "echo stop" }] }] } }
                                                            ))

      create_marketplace([{
                           "name" => "custom-hooks-plugin",
                           "source" => "./custom-hooks-plugin",
                           "hooks" => "./custom/my-hooks"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("custom-hooks-plugin")

      basenames = files.map { |f| File.basename(f) }
      expect(basenames).to include("hooks.json")
    end

    it "detects hooks.json specified directly as a file path in manifest" do
      plugin_dir = File.join(marketplace_dir, "direct-hooks-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])
      hooks_file = File.join(plugin_dir, "my-hooks.json")
      File.write(hooks_file, JSON.pretty_generate(
                               { "hooks" => { "Stop" => [{ "hooks" => [{ "type" => "command", "command" => "echo stop" }] }] } }
                             ))
      # Rename to hooks.json for the adapter to recognize it
      FileUtils.mv(hooks_file, File.join(plugin_dir, "hooks.json"))

      create_marketplace([{
                           "name" => "direct-hooks-plugin",
                           "source" => "./direct-hooks-plugin",
                           "hooks" => "./hooks.json"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("direct-hooks-plugin")

      basenames = files.map { |f| File.basename(f) }
      expect(basenames).to include("hooks.json")
    end

    it "does not fail when no hooks directory exists" do
      plugin_dir = File.join(marketplace_dir, "no-hooks-plugin")
      create_plugin_structure(plugin_dir, [
                                "commands/deploy.md"
                              ])

      create_marketplace([{
                           "name" => "no-hooks-plugin",
                           "source" => "./no-hooks-plugin"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("no-hooks-plugin")

      expect(files.map { |f| File.basename(f) }).not_to include("hooks.json")
      expect(files.length).to eq(1)
    end
  end

  describe "#fetch_plugin with recursive skills" do
    it "recursively fetches all files in skill directories" do
      plugin_dir = File.join(marketplace_dir, "recursive-skills")
      create_plugin_structure(plugin_dir, [
                                "skills/my-skill/SKILL.md",
                                "skills/my-skill/scripts/run.sh",
                                "skills/my-skill/assets/data.json"
                              ])

      create_marketplace([{
                           "name" => "recursive-skills",
                           "source" => "./recursive-skills"
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("recursive-skills")

      expect(files.length).to eq(3)
      base_names = files.map { |f| File.basename(f) }
      expect(base_names).to include("SKILL.md", "run.sh", "data.json")
    end

    it "recursively fetches skills defined in manifest" do
      plugin_dir = File.join(marketplace_dir, "manifest-skills")
      create_plugin_structure(plugin_dir, [
                                "custom/skill/SKILL.md",
                                "custom/skill/lib/helper.rb"
                              ])

      create_marketplace([{
                           "name" => "manifest-skills",
                           "source" => "./manifest-skills",
                           "skills" => ["./custom/skill"]
                         }])

      fetcher = described_class.new(marketplace_json, marketplace_name: marketplace_name)
      files = fetcher.fetch("manifest-skills")

      expect(files.length).to eq(2)
      expect(files.map { |f| File.basename(f) }).to include("SKILL.md", "helper.rb")
    end
  end
end
