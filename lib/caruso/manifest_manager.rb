# frozen_string_literal: true

require "json"
require "fileutils"

module Caruso
  class ManifestManager
    MANIFEST_FILENAME = "caruso.json"

    attr_reader :target_dir, :manifest_path

    def initialize(target_dir)
      @target_dir = target_dir
      @manifest_path = File.join(target_dir, MANIFEST_FILENAME)
    end

    def add_plugin(name, files, marketplace_uri: nil)
      data = load_manifest
      data["plugins"] ||= {}
      data["plugins"][name] = {
        "installed_at" => Time.now.iso8601,
        "files" => files,
        "marketplace" => marketplace_uri
      }
      save_manifest(data)
    end

    def remove_plugin(name)
      data = load_manifest
      return [] unless data["plugins"] && data["plugins"][name]

      files_to_remove = data["plugins"][name]["files"] || []
      data["plugins"].delete(name)
      save_manifest(data)

      files_to_remove
    end

    def list_plugins
      data = load_manifest
      data["plugins"] || {}
    end

    def plugin_installed?(name)
      data = load_manifest
      data["plugins"]&.key?(name)
    end

    # Marketplace Management
    def add_marketplace(name, url)
      data = load_manifest
      data["marketplaces"] ||= {}
      data["marketplaces"][name] = url
      save_manifest(data)
    end

    def remove_marketplace(name)
      data = load_manifest
      return unless data["marketplaces"]

      data["marketplaces"].delete(name)
      save_manifest(data)
    end

    def list_marketplaces
      data = load_manifest
      data["marketplaces"] || {}
    end

    def get_marketplace_url(name)
      data = load_manifest
      return nil unless data["marketplaces"]

      data["marketplaces"][name]
    end

    private

    def load_manifest
      return {} unless File.exist?(@manifest_path)

      JSON.parse(File.read(@manifest_path))
    rescue JSON::ParserError
      {}
    end

    def save_manifest(data)
      FileUtils.mkdir_p(@target_dir)
      File.write(@manifest_path, JSON.pretty_generate(data))
    end
  end
end
