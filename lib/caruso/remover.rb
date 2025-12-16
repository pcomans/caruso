# frozen_string_literal: true

require_relative "marketplace_registry"

module Caruso
  class Remover
    attr_reader :config_manager

    def initialize(config_manager)
      @config_manager = config_manager
    end

    def remove_marketplace(name)
      # 1. Remove from config and get associated plugin files
      # This updates both project config (plugins) and local config (files)
      files_to_remove = config_manager.remove_marketplace_with_plugins(name)

      # 2. Delete the actual files
      delete_files(files_to_remove)

      # 3. Clean up registry cache
      remove_from_registry(name)
    end

    def remove_plugin(name)
      # 1. Remove from config
      files_to_remove = config_manager.remove_plugin(name)

      # 2. Delete files
      delete_files(files_to_remove)
    end

    private

    def delete_files(files)
      files.each do |file|
        full_path = File.join(config_manager.project_dir, file)
        if File.exist?(full_path)
          File.delete(full_path)
          puts "  Deleted #{file}"
        end
      end
    end

    def remove_from_registry(name)
      registry = Caruso::MarketplaceRegistry.new
      marketplace = registry.get_marketplace(name)
      return unless marketplace

      cache_dir = marketplace["install_location"]
      registry.remove_marketplace(name)

      # Inform about cache directory
      return unless Dir.exist?(cache_dir)

      puts "Cache directory still exists at: #{cache_dir}"
      puts "Run 'rm -rf #{cache_dir}' to delete it if desired."
    end
  end
end
