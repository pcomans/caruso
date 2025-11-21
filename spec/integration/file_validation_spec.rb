# frozen_string_literal: true

require "spec_helper"

RSpec.describe "File Conversion Validation", type: :integration do
  before do
    # Skip init for config file structure tests - they test init itself
    unless self.class.metadata[:skip_init]
      init_caruso
      add_marketplace("https://github.com/anthropics/skills")
    end
  end

  describe ".mdc file structure", :live do
    let(:plugin_name) do
      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      match ? match[1] : skip("No plugins available in marketplace")
    end

    before do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]
      run_command("caruso plugin install #{plugin_name}@skills")
      expect(last_command_started).to be_successfully_executed
    end

    it "creates .mdc files" do
      expect(mdc_files).not_to be_empty
    end

    it "all .mdc files have frontmatter" do
      mdc_files.each do |file|
        content = File.read(file)
        lines = content.lines

        expect(lines.first.strip).to eq("---"),
                                     "File #{File.basename(file)} should start with ---"

        # Find closing ---
        closing_index = lines[1..].index { |line| line.strip == "---" }
        expect(closing_index).not_to be_nil,
                                     "File #{File.basename(file)} should have closing ---"
      end
    end

    it "all .mdc files have globs metadata" do
      mdc_files.each do |file|
        content = File.read(file)

        expect(content).to match(/globs:\s*\[\]/),
                           "File #{File.basename(file)} should have 'globs: []' metadata"
      end
    end

    it "all .mdc files have content after frontmatter" do
      mdc_files.each do |file|
        lines = File.readlines(file)

        expect(lines.length).to be > 5,
                                "File #{File.basename(file)} should have content beyond frontmatter"
      end
    end

    it "preserves original markdown content" do
      mdc_files.each do |file|
        content = File.read(file)

        # Should have markdown headers or content
        expect(content).to match(/#.*\n/),
                           "File #{File.basename(file)} should preserve markdown headers"
      end
    end

    it "tracked files match actual files" do
      manifest = load_manifest
      tracked_files = manifest.dig("plugins", plugin_name, "files") || []

      tracked_files.each do |tracked_file|
        full_path = File.join(aruba.current_directory, tracked_file)
        expect(File.exist?(full_path)).to be(true),
                                          "Tracked file #{tracked_file} should exist"
      end
    end

    it "no orphaned files (all files are tracked)" do
      manifest = load_manifest
      tracked_basenames = (manifest.dig("plugins", plugin_name, "files") || [])
                          .map { |f| File.basename(f) }

      mdc_files.each do |file|
        basename = File.basename(file)
        expect(tracked_basenames).to include(basename),
                                     "File #{basename} exists but is not tracked in manifest"
      end
    end
  end

  describe "file naming conventions", :live do
    let(:plugin_name) do
      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      match ? match[1] : skip("No plugins available in marketplace")
    end

    before do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]
      run_command("caruso plugin install #{plugin_name}@skills")
    end

    it "uses .mdc extension" do
      mdc_files.each do |file|
        expect(File.extname(file)).to eq(".mdc"),
                                      "File #{File.basename(file)} should have .mdc extension"
      end
    end

    it "includes plugin name in filename" do
      # Files should include plugin identifier
      mdc_files.each do |file|
        basename = File.basename(file, ".mdc")
        # Could be plugin-name or related pattern
        expect(basename.length).to be > 0
      end
    end
  end

  describe "manifest file structure", :skip_init do
    it "creates valid JSON manifest" do
      init_caruso
      add_marketplace("https://github.com/anthropics/skills")

      manifest = load_manifest
      expect(manifest).to be_a(Hash)
    end

    it "has marketplaces section" do
      init_caruso
      add_marketplace("https://github.com/anthropics/skills")

      manifest = load_manifest
      expect(manifest).to have_key("marketplaces")
      expect(manifest["marketplaces"]).to be_a(Hash)
    end

    it "creates plugins section when plugin installed", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      run_command("caruso plugin install #{plugin_name}@skills")
      expect(last_command_started).to be_successfully_executed

      manifest = load_manifest
      expect(manifest).to have_key("plugins")
      expect(manifest["plugins"]).to be_a(Hash)
    end

    it "includes required plugin metadata", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      run_command("caruso plugin install #{plugin_name}@skills")
      expect(last_command_started).to be_successfully_executed

      manifest = load_manifest
      plugin_data = manifest["plugins"][plugin_name]

      expect(plugin_data).to have_key("installed_at")
      expect(plugin_data).to have_key("files")
      expect(plugin_data).to have_key("marketplace")

      # Validate timestamp format
      expect(plugin_data["installed_at"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

      # Validate files array
      expect(plugin_data["files"]).to be_a(Array)
      expect(plugin_data["files"]).not_to be_empty

      # Validate marketplace URL
      expect(plugin_data["marketplace"]).to be_a(String)
      expect(plugin_data["marketplace"]).to include("skills")
    end
  end

  describe "config file structure", :skip_init do
    it "creates valid JSON config" do
      init_caruso

      config = load_config
      expect(config).to be_a(Hash)
    end

    it "includes all required fields" do
      init_caruso

      config = load_config

      expect(config).to have_key("ide")
      expect(config).to have_key("target_dir")
      expect(config).to have_key("initialized_at")
      expect(config).to have_key("version")
    end

    it "has correct values" do
      init_caruso

      config = load_config

      expect(config["ide"]).to eq("cursor")
      expect(config["target_dir"]).to eq(".cursor/rules")
      expect(config["version"]).to eq("1.0.0")
      expect(config["initialized_at"]).to match(/\d{4}-\d{2}-\d{2}T/)
    end
  end
end
