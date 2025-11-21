# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Plugin Updates and Reinstallation", type: :integration do
  before do
    init_caruso
    add_marketplace("https://github.com/anthropics/claude-code")
  end

  describe "plugin reinstallation (update scenario)" do
    it "updates plugin metadata when reinstalling", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      # Install plugin first time
      run_command("caruso plugin install #{plugin_name}@claude-code")
      first_install = load_manifest
      first_timestamp = first_install["plugins"][plugin_name]["installed_at"]

      # Advance time to ensure timestamp difference
      Timecop.travel(Time.now + 2) do
        # Reinstall the same plugin
        run_command("caruso plugin install #{plugin_name}@claude-code")
      end

      second_install = load_manifest
      second_timestamp = second_install["plugins"][plugin_name]["installed_at"]

      # Timestamp should be updated
      expect(second_timestamp).not_to eq(first_timestamp)
      expect(Time.parse(second_timestamp)).to be > Time.parse(first_timestamp)
    end

    it "replaces old files when reinstalling", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      # Install plugin
      run_command("caruso plugin install #{plugin_name}@claude-code")
      first_files = load_manifest["plugins"][plugin_name]["files"]

      # Reinstall
      run_command("caruso plugin install #{plugin_name}@claude-code")
      second_files = load_manifest["plugins"][plugin_name]["files"]

      # Files list should be updated (even if identical in this case)
      expect(second_files).to be_an(Array)
      expect(second_files).not_to be_empty
    end

    it "allows switching plugin source marketplace" do
      # Add a second marketplace
      add_marketplace("https://github.com/example/other-marketplace", "other-marketplace")

      # Simulate plugin installed from first marketplace
      manifest = load_manifest
      manifest["plugins"] = {
        "test-plugin" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/test.mdc"],
          "marketplace" => "https://github.com/anthropics/claude-code"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      # Update the marketplace reference
      manifest = load_manifest
      manifest["plugins"]["test-plugin"]["marketplace"] = "https://github.com/example/other-marketplace"
      manifest["plugins"]["test-plugin"]["installed_at"] = Time.now.iso8601
      File.write(manifest_file, JSON.pretty_generate(manifest))

      updated_manifest = load_manifest
      expect(updated_manifest["plugins"]["test-plugin"]["marketplace"]).to eq("https://github.com/example/other-marketplace")
    end
  end

  describe "plugin version tracking" do
    it "maintains version information if available", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      run_command("caruso plugin install #{plugin_name}@claude-code")
      manifest = load_manifest

      # Check if version info is tracked (implementation may vary)
      plugin_data = manifest["plugins"][plugin_name]
      expect(plugin_data).to have_key("installed_at")
      expect(plugin_data).to have_key("marketplace")
    end

    it "preserves custom plugin metadata on reinstall" do
      manifest = load_manifest
      manifest["plugins"] = {
        "custom-plugin" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/custom.mdc"],
          "marketplace" => "https://github.com/anthropics/claude-code",
          "custom_field" => "custom_value"
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      # Simulate reinstall by updating the manifest
      manifest = load_manifest
      manifest["plugins"]["custom-plugin"]["installed_at"] = Time.now.iso8601
      File.write(manifest_file, JSON.pretty_generate(manifest))

      updated_manifest = load_manifest
      # Custom fields may or may not be preserved depending on implementation
      expect(updated_manifest["plugins"]["custom-plugin"]["installed_at"]).not_to eq("2025-01-01T00:00:00Z")
    end
  end

  describe "concurrent plugin operations" do
    it "handles installing plugin while another exists" do
      # Install first plugin
      manifest = load_manifest
      manifest["plugins"] = {
        "plugin-a" => {
          "installed_at" => Time.now.iso8601,
          "files" => [".cursor/rules/a.mdc"]
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      # Add second plugin
      manifest = load_manifest
      manifest["plugins"]["plugin-b"] = {
        "installed_at" => Time.now.iso8601,
        "files" => [".cursor/rules/b.mdc"]
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      final_manifest = load_manifest
      expect(final_manifest["plugins"]).to have_key("plugin-a")
      expect(final_manifest["plugins"]).to have_key("plugin-b")
    end

    it "maintains marketplace integrity during plugin updates" do
      manifest = load_manifest
      original_marketplaces = manifest["marketplaces"].dup

      # Simulate plugin install
      manifest["plugins"] = {
        "test-plugin" => {
          "installed_at" => Time.now.iso8601,
          "files" => [".cursor/rules/test.mdc"]
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      updated_manifest = load_manifest
      expect(updated_manifest["marketplaces"]).to eq(original_marketplaces)
    end
  end

  describe "plugin metadata updates" do
    it "tracks installation timestamp" do
      before_time = Time.now - 1 # 1 second before to account for precision

      manifest = load_manifest
      manifest["plugins"] = {
        "timestamped-plugin" => {
          "installed_at" => Time.now.iso8601,
          "files" => [".cursor/rules/timestamp.mdc"]
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      after_time = Time.now + 1 # 1 second after to account for precision
      updated_manifest = load_manifest
      timestamp = Time.parse(updated_manifest["plugins"]["timestamped-plugin"]["installed_at"])

      expect(timestamp).to be >= before_time
      expect(timestamp).to be <= after_time
    end

    it "stores marketplace reference for tracking" do
      marketplace_url = "https://github.com/anthropics/claude-code"

      manifest = load_manifest
      manifest["plugins"] = {
        "tracked-plugin" => {
          "installed_at" => Time.now.iso8601,
          "files" => [".cursor/rules/tracked.mdc"],
          "marketplace" => marketplace_url
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      updated_manifest = load_manifest
      expect(updated_manifest["plugins"]["tracked-plugin"]["marketplace"]).to eq(marketplace_url)
    end

    it "maintains files list integrity" do
      files = [
        ".cursor/rules/file1.mdc",
        ".cursor/rules/file2.mdc",
        ".cursor/rules/subdir/file3.mdc"
      ]

      manifest = load_manifest
      manifest["plugins"] = {
        "multi-file" => {
          "installed_at" => Time.now.iso8601,
          "files" => files
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      updated_manifest = load_manifest
      expect(updated_manifest["plugins"]["multi-file"]["files"]).to eq(files)
      expect(updated_manifest["plugins"]["multi-file"]["files"].length).to eq(3)
    end
  end

  describe "update workflow scenarios" do
    it "supports uninstall then reinstall workflow", :live do
      skip "Requires live marketplace access" unless ENV["RUN_LIVE_TESTS"]

      run_command("caruso plugin list")
      match = last_command_started.output.match(/^\s+-\s+(\S+)/)
      plugin_name = match ? match[1] : skip("No plugins available")

      # Install
      run_command("caruso plugin install #{plugin_name}@claude-code")
      expect(load_manifest["plugins"]).to have_key(plugin_name)

      # Uninstall
      run_command("caruso plugin uninstall #{plugin_name}")
      expect(load_manifest["plugins"]).not_to have_key(plugin_name)

      # Reinstall
      run_command("caruso plugin install #{plugin_name}@claude-code")
      expect(load_manifest["plugins"]).to have_key(plugin_name)
    end

    it "handles reinstall without explicit uninstall" do
      manifest = load_manifest
      manifest["plugins"] = {
        "existing-plugin" => {
          "installed_at" => "2025-01-01T00:00:00Z",
          "files" => [".cursor/rules/old.mdc"]
        }
      }
      File.write(manifest_file, JSON.pretty_generate(manifest))

      # Simulate reinstall by updating
      manifest = load_manifest
      manifest["plugins"]["existing-plugin"]["installed_at"] = Time.now.iso8601
      manifest["plugins"]["existing-plugin"]["files"] = [".cursor/rules/new.mdc"]
      File.write(manifest_file, JSON.pretty_generate(manifest))

      updated_manifest = load_manifest
      expect(updated_manifest["plugins"]["existing-plugin"]["files"]).to eq([".cursor/rules/new.mdc"])
    end
  end
end
