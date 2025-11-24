# frozen_string_literal: true

require "json"
require "fileutils"

module Caruso
  class MarketplaceRegistry
    REGISTRY_FILENAME = "known_marketplaces.json"

    def initialize
      @registry_path = File.join(Dir.home, ".caruso", REGISTRY_FILENAME)
    end

    # Enhancement #1: Add source type tracking
    def add_marketplace(name, url, install_location, ref: nil, source: "git")
      data = load_registry
      data[name] = {
        "source" => source, # github, git, url, local, directory
        "url" => url,
        "install_location" => install_location,
        "last_updated" => Time.now.iso8601,
        "ref" => ref
      }.compact
      save_registry(data)
    end

    def get_marketplace(name)
      data = load_registry
      data[name]
    end

    def update_timestamp(name)
      data = load_registry
      return unless data[name]

      data[name]["last_updated"] = Time.now.iso8601
      save_registry(data)
    end

    def list_marketplaces
      load_registry
    end

    def remove_marketplace(name)
      data = load_registry
      data.delete(name)
      save_registry(data)
    end

    private

    # Enhancement #3: Schema validation
    def validate_marketplace_entry(entry)
      required = %w[url install_location last_updated]
      missing = required - entry.keys

      unless missing.empty?
        raise Caruso::Error, "Invalid marketplace entry: missing #{missing.join(', ')}"
      end

      # Validate timestamp format
      Time.iso8601(entry["last_updated"])
    rescue ArgumentError
      raise Caruso::Error, "Invalid timestamp format in marketplace entry"
    end

    # Enhancement #4: Registry corruption handling
    def load_registry
      return {} unless File.exist?(@registry_path)

      data = JSON.parse(File.read(@registry_path))

      # Validate each entry
      data.each_value do |entry|
        validate_marketplace_entry(entry)
      end

      data
    rescue JSON::ParserError => e
      handle_corrupted_registry(e)
      {}
    rescue Caruso::Error => e
      warn "Warning: Invalid marketplace entry: #{e.message}"
      warn "Continuing with partial registry data."
      {}
    end

    def handle_corrupted_registry(error)
      corrupted_path = "#{@registry_path}.corrupted.#{Time.now.to_i}"
      FileUtils.cp(@registry_path, corrupted_path)

      warn "Marketplace registry corrupted. Backup saved to: #{corrupted_path}"
      warn "Error: #{error.message}"
      warn "Starting with empty registry."
    end

    def save_registry(data)
      FileUtils.mkdir_p(File.dirname(@registry_path))
      File.write(@registry_path, JSON.pretty_generate(data))
    end
  end
end
