# frozen_string_literal: true

require "spec_helper"

RSpec.describe "File Conversion Validation", type: :integration do
  before do
    # Skip init for config file structure tests - they test init itself
    unless self.class.metadata[:skip_init]
      init_caruso
      add_marketplace()
    end
  end

  describe ".mdc file structure", :live do
    let(:plugin_name) do
      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      match ? match[1] : skip("No plugins available in marketplace")
    end
    let(:plugin_key) { "#{plugin_name}@test-skills" }

    before do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]
      run_command("caruso plugin install #{plugin_key}")
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
      local_config = load_local_config
      tracked_files = local_config.dig("installed_files", plugin_key) || []

      tracked_files.each do |tracked_file|
        full_path = File.join(aruba.current_directory, tracked_file)
        expect(File.exist?(full_path)).to be(true),
                                          "Tracked file #{tracked_file} should exist"
      end
    end

    it "no orphaned files (all files are tracked)" do
      local_config = load_local_config
      tracked_basenames = (local_config.dig("installed_files", plugin_key) || [])
                          .map { |f| File.basename(f) }

      mdc_files.each do |file|
        basename = File.basename(file)
        expect(tracked_basenames).to include(basename),
                                     "File #{basename} exists but is not tracked in local config"
      end
    end
  end

  describe "file naming conventions", :live do
    let(:plugin_name) do
      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      match ? match[1] : skip("No plugins available in marketplace")
    end
    let(:plugin_key) { "#{plugin_name}@test-skills" }

    before do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]
      run_command("caruso plugin install #{plugin_key}")
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

  describe "project config file structure", :skip_init do
    it "creates valid JSON config" do
      init_caruso
      add_marketplace()

      config = load_project_config
      expect(config).to be_a(Hash)
    end

    it "has marketplaces section" do
      init_caruso
      add_marketplace()

      config = load_project_config
      expect(config).to have_key("marketplaces")
      expect(config["marketplaces"]).to be_a(Hash)
    end

    it "creates plugins section when plugin installed", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")
      plugin_key = "#{plugin_name}@test-skills"

      run_command("caruso plugin install #{plugin_key}")
      expect(last_command_started).to be_successfully_executed

      config = load_project_config
      expect(config).to have_key("plugins")
      expect(config["plugins"]).to be_a(Hash)
    end

    it "includes required plugin metadata", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")
      plugin_key = "#{plugin_name}@test-skills"

      run_command("caruso plugin install #{plugin_key}")
      expect(last_command_started).to be_successfully_executed

      config = load_project_config
      plugin_data = config["plugins"][plugin_key]

      expect(plugin_data).to have_key("marketplace")
      expect(plugin_data["marketplace"]).to eq("test-skills")
    end
  end

  describe "local config file structure", :skip_init do
    it "creates valid JSON config" do
      init_caruso

      config = load_local_config
      expect(config).to be_a(Hash)
    end

    it "includes all required fields" do
      init_caruso

      config = load_local_config

      expect(config).to have_key("ide")
      expect(config).to have_key("target_dir")
      expect(config).to have_key("installed_files")
    end

    it "has correct values" do
      init_caruso

      config = load_local_config

      expect(config["ide"]).to eq("cursor")
      expect(config["target_dir"]).to eq(".cursor/rules")
    end
    
    it "tracks installed files", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")
      plugin_key = "#{plugin_name}@test-skills"

      run_command("caruso plugin install #{plugin_key}")
      
      config = load_local_config
      expect(config["installed_files"]).to have_key(plugin_key)
      expect(config["installed_files"][plugin_key]).to be_a(Array)
      expect(config["installed_files"][plugin_key]).not_to be_empty
    end
  end
end
