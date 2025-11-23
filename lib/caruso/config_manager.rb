# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module Caruso
  class ConfigManager
    PROJECT_CONFIG_FILENAME = "caruso.json"
    LOCAL_CONFIG_FILENAME = ".caruso.local.json"
    SUPPORTED_IDES = ["cursor"].freeze
    IDE_TARGET_DIRS = {
      "cursor" => ".cursor/rules"
    }.freeze

    attr_reader :project_dir, :project_config_path, :local_config_path

    def initialize(project_dir = Dir.pwd)
      @project_dir = File.expand_path(project_dir)
      @project_config_path = File.join(@project_dir, PROJECT_CONFIG_FILENAME)
      @local_config_path = File.join(@project_dir, LOCAL_CONFIG_FILENAME)
    end

    def init(ide:)
      unless SUPPORTED_IDES.include?(ide)
        raise ArgumentError, "Unsupported IDE: #{ide}. Supported: #{SUPPORTED_IDES.join(', ')}"
      end

      if config_exists?
        raise Error, "Caruso is already initialized in #{@project_dir}."
      end

      # Create project config (caruso.json)
      project_config = {
        "version" => "1.0.0",
        "marketplaces" => {},
        "plugins" => {}
      }
      save_project_config(project_config)

      # Create local config (.caruso.local.json)
      local_config = {
        "ide" => ide,
        "target_dir" => IDE_TARGET_DIRS[ide],
        "installed_files" => {}
      }
      save_local_config(local_config)

      # Add to .gitignore if it exists and doesn't already have it
      update_gitignore

      { **project_config, **local_config }
    end

    def load
      unless config_exists?
        raise Error, "Caruso not initialized. Run 'caruso init --ide=cursor' first."
      end

      project_data = load_project_config
      local_data = load_local_config

      # Merge data for easier access, but keep them conceptually separate
      project_data.merge(local_data)
    end

    def config_exists?
      File.exist?(@project_config_path) && File.exist?(@local_config_path)
    end

    def target_dir
      load["target_dir"]
    end

    def full_target_path
      File.join(@project_dir, target_dir)
    end

    def ide
      load["ide"]
    end

    # Plugin Management

    def add_plugin(name, files, marketplace_name:)
      # Update project config (Intent)
      project_data = load_project_config
      project_data["plugins"] ||= {}
      project_data["plugins"][name] = {
        "marketplace" => marketplace_name
      }
      save_project_config(project_data)

      # Update local config (Files)
      local_data = load_local_config
      local_data["installed_files"] ||= {}
      local_data["installed_files"][name] = files
      save_local_config(local_data)
    end

    def remove_plugin(name)
      # Get files to remove from local config
      local_data = load_local_config
      files = local_data.dig("installed_files", name) || []

      # Remove from local config
      if local_data["installed_files"]
        local_data["installed_files"].delete(name)
        save_local_config(local_data)
      end

      # Remove from project config
      project_data = load_project_config
      if project_data["plugins"]
        project_data["plugins"].delete(name)
        save_project_config(project_data)
      end

      files
    end

    def list_plugins
      load_project_config["plugins"] || {}
    end

    def plugin_installed?(name)
      plugins = list_plugins
      plugins.key?(name)
    end

    def get_installed_files(name)
      load_local_config.dig("installed_files", name) || []
    end

    # Marketplace Management

    def add_marketplace(name, url, source: "git", ref: nil)
      data = load_project_config
      data["marketplaces"] ||= {}
      data["marketplaces"][name] = {
        "url" => url,
        "source" => source,
        "ref" => ref
      }.compact
      save_project_config(data)
    end

    def remove_marketplace(name)
      data = load_project_config
      return unless data["marketplaces"]

      data["marketplaces"].delete(name)
      save_project_config(data)
    end

    def list_marketplaces
      load_project_config["marketplaces"] || {}
    end

    def get_marketplace_details(name)
      load_project_config.dig("marketplaces", name)
    end

    def get_marketplace_url(name)
      details = get_marketplace_details(name)
      details ? details["url"] : nil
    end

    private

    def load_project_config
      return {} unless File.exist?(@project_config_path)
      JSON.parse(File.read(@project_config_path))
    rescue JSON::ParserError
      {}
    end

    def save_project_config(data)
      File.write(@project_config_path, JSON.pretty_generate(data))
    end

    def load_local_config
      return {} unless File.exist?(@local_config_path)
      JSON.parse(File.read(@local_config_path))
    rescue JSON::ParserError
      {}
    end

    def save_local_config(data)
      File.write(@local_config_path, JSON.pretty_generate(data))
    end

    def update_gitignore
      gitignore_path = File.join(@project_dir, ".gitignore")
      content = File.exist?(gitignore_path) ? File.read(gitignore_path) : ""
      
      unless content.include?(LOCAL_CONFIG_FILENAME)
        File.open(gitignore_path, "a") do |f|
          f.puts
          f.puts "# Caruso local configuration"
          f.puts LOCAL_CONFIG_FILENAME
        end
      end
    end
  end
end
