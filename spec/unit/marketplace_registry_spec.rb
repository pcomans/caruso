# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Caruso::MarketplaceRegistry do
  let(:home_dir) { Dir.mktmpdir }
  let(:registry_path) { File.join(home_dir, ".caruso", "known_marketplaces.json") }
  let(:registry) { described_class.new }

  before do
    allow(Dir).to receive(:home).and_return(home_dir)
  end

  after do
    FileUtils.rm_rf(home_dir)
  end

  describe "#add_marketplace" do
    it "adds a marketplace to the registry" do
      registry.add_marketplace(
        "test-marketplace",
        "https://github.com/example/test",
        "/home/user/.caruso/marketplaces/test-marketplace"
      )

      marketplace = registry.get_marketplace("test-marketplace")
      expect(marketplace).to include(
        "url" => "https://github.com/example/test",
        "install_location" => "/home/user/.caruso/marketplaces/test-marketplace",
        "source" => "git"
      )
      expect(marketplace["last_updated"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "supports source type tracking" do
      registry.add_marketplace(
        "github-marketplace",
        "https://github.com/example/repo",
        "/path/to/cache",
        source: "github"
      )

      marketplace = registry.get_marketplace("github-marketplace")
      expect(marketplace["source"]).to eq("github")
    end

    it "supports ref/branch pinning" do
      registry.add_marketplace(
        "pinned-marketplace",
        "https://github.com/example/repo",
        "/path/to/cache",
        ref: "v1.0.0"
      )

      marketplace = registry.get_marketplace("pinned-marketplace")
      expect(marketplace["ref"]).to eq("v1.0.0")
    end

    it "omits nil values from the registry entry" do
      registry.add_marketplace(
        "simple-marketplace",
        "https://github.com/example/repo",
        "/path/to/cache"
      )

      marketplace = registry.get_marketplace("simple-marketplace")
      expect(marketplace.key?("ref")).to be false
    end

    it "creates the registry file with proper formatting" do
      registry.add_marketplace(
        "test",
        "https://example.com",
        "/path/to/cache"
      )

      expect(File.exist?(registry_path)).to be true
      content = File.read(registry_path)
      expect { JSON.parse(content) }.not_to raise_error
    end
  end

  describe "#get_marketplace" do
    it "retrieves a marketplace by name" do
      registry.add_marketplace("test", "https://example.com", "/path")
      marketplace = registry.get_marketplace("test")

      expect(marketplace).to be_a(Hash)
      expect(marketplace["url"]).to eq("https://example.com")
    end

    it "returns nil for non-existent marketplace" do
      marketplace = registry.get_marketplace("nonexistent")
      expect(marketplace).to be_nil
    end
  end

  describe "#list_marketplaces" do
    it "returns empty hash when no marketplaces exist" do
      expect(registry.list_marketplaces).to eq({})
    end

    it "returns all registered marketplaces" do
      registry.add_marketplace("marketplace1", "https://example1.com", "/path1")
      registry.add_marketplace("marketplace2", "https://example2.com", "/path2")

      marketplaces = registry.list_marketplaces
      expect(marketplaces.keys).to contain_exactly("marketplace1", "marketplace2")
    end
  end

  describe "#remove_marketplace" do
    it "removes a marketplace from the registry" do
      registry.add_marketplace("test", "https://example.com", "/path")
      registry.remove_marketplace("test")

      expect(registry.get_marketplace("test")).to be_nil
    end

    it "handles removing non-existent marketplace gracefully" do
      expect { registry.remove_marketplace("nonexistent") }.not_to raise_error
    end

    it "persists the removal to disk" do
      registry.add_marketplace("test1", "https://example1.com", "/path1")
      registry.add_marketplace("test2", "https://example2.com", "/path2")
      registry.remove_marketplace("test1")

      # Create new registry instance to verify persistence
      new_registry = described_class.new
      expect(new_registry.get_marketplace("test1")).to be_nil
      expect(new_registry.get_marketplace("test2")).not_to be_nil
    end
  end

  describe "#update_timestamp" do
    it "updates the last_updated timestamp" do
      registry.add_marketplace("test", "https://example.com", "/path")

      original_marketplace = registry.get_marketplace("test")
      original_timestamp = original_marketplace["last_updated"]

      sleep 1 # Ensure time difference (ISO8601 has second-level precision)
      registry.update_timestamp("test")

      updated_marketplace = registry.get_marketplace("test")
      updated_timestamp = updated_marketplace["last_updated"]

      expect(updated_timestamp).not_to eq(original_timestamp)
      expect(Time.iso8601(updated_timestamp)).to be > Time.iso8601(original_timestamp)
    end

    it "handles updating non-existent marketplace gracefully" do
      expect { registry.update_timestamp("nonexistent") }.not_to raise_error
    end
  end

  describe "schema validation" do
    it "validates required fields on load" do
      # Manually create invalid registry file
      FileUtils.mkdir_p(File.dirname(registry_path))
      invalid_data = {
        "test" => {
          "url" => "https://example.com"
          # Missing install_location and last_updated
        }
      }
      File.write(registry_path, JSON.generate(invalid_data))

      # Should warn and return empty registry
      expect { registry.list_marketplaces }.to output(/Invalid marketplace entry/).to_stderr
      expect(registry.list_marketplaces).to eq({})
    end

    it "validates timestamp format" do
      FileUtils.mkdir_p(File.dirname(registry_path))
      invalid_data = {
        "test" => {
          "url" => "https://example.com",
          "install_location" => "/path",
          "last_updated" => "not-a-timestamp"
        }
      }
      File.write(registry_path, JSON.generate(invalid_data))

      expect { registry.list_marketplaces }.to output(/Invalid marketplace entry/).to_stderr
      expect(registry.list_marketplaces).to eq({})
    end
  end

  describe "registry corruption handling" do
    it "backs up corrupted registry and starts fresh" do
      FileUtils.mkdir_p(File.dirname(registry_path))
      File.write(registry_path, "{ invalid json }")

      expect { registry.list_marketplaces }.to output(/Marketplace registry corrupted/).to_stderr
      expect(registry.list_marketplaces).to eq({})

      # Check backup was created
      backup_files = Dir.glob("#{registry_path}.corrupted.*")
      expect(backup_files.length).to eq(1)
      expect(File.read(backup_files.first)).to eq("{ invalid json }")
    end

    it "includes error message in corruption warning" do
      FileUtils.mkdir_p(File.dirname(registry_path))
      File.write(registry_path, "{ invalid json }")

      expect { registry.list_marketplaces }.to output(/Error:.*/).to_stderr
    end

    it "preserves original corrupted file with timestamp" do
      FileUtils.mkdir_p(File.dirname(registry_path))
      File.write(registry_path, "corrupted content")

      registry.list_marketplaces

      backup_files = Dir.glob("#{registry_path}.corrupted.*")
      expect(backup_files.length).to eq(1)
      expect(backup_files.first).to match(/known_marketplaces\.json\.corrupted\.\d+/)
    end
  end

  describe "persistence across instances" do
    it "persists data across registry instances" do
      registry.add_marketplace("test", "https://example.com", "/path", source: "github", ref: "main")

      # Create new instance
      new_registry = described_class.new
      marketplace = new_registry.get_marketplace("test")

      expect(marketplace["url"]).to eq("https://example.com")
      expect(marketplace["source"]).to eq("github")
      expect(marketplace["ref"]).to eq("main")
    end
  end

  describe "source type tracking" do
    it "supports different source types" do
      source_types = %w[git github url local directory]

      source_types.each_with_index do |source, index|
        registry.add_marketplace(
          "marketplace-#{index}",
          "https://example.com/#{index}",
          "/path/#{index}",
          source: source
        )

        marketplace = registry.get_marketplace("marketplace-#{index}")
        expect(marketplace["source"]).to eq(source)
      end
    end

    it "defaults to 'git' when source not specified" do
      registry.add_marketplace("default-source", "https://example.com", "/path")
      marketplace = registry.get_marketplace("default-source")
      expect(marketplace["source"]).to eq("git")
    end
  end
end
