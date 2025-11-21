# frozen_string_literal: true

require "thor"
require_relative "../caruso"

module Caruso
  class Marketplace < Thor
    desc "add URL [NAME]", "Add a marketplace"
    def add(url, name = nil)
      config_manager = load_config
      target_dir = config_manager.full_target_path

      # Extract name from URL if not provided
      name ||= url.split("/").last.sub(".git", "")

      manager = Caruso::ManifestManager.new(target_dir)
      manager.add_marketplace(name, url)
      puts "Added marketplace '#{name}' from #{url}"
    end

    desc "list", "List configured marketplaces"
    def list
      config_manager = load_config
      target_dir = config_manager.full_target_path

      manager = Caruso::ManifestManager.new(target_dir)
      marketplaces = manager.list_marketplaces

      if marketplaces.empty?
        puts "No marketplaces configured."
      else
        puts "Configured Marketplaces:"
        marketplaces.each do |name, url|
          puts "  - #{name}: #{url}"
        end
      end
    end

    desc "remove NAME", "Remove a marketplace"
    def remove(name)
      config_manager = load_config
      target_dir = config_manager.full_target_path

      manager = Caruso::ManifestManager.new(target_dir)
      manager.remove_marketplace(name)
      puts "Removed marketplace '#{name}'"
    end

    private

    def load_config
      Caruso::ConfigManager.new
    rescue Caruso::Error => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  class Plugin < Thor
    desc "install PLUGIN_NAME", "Install a plugin (format: plugin@marketplace or just plugin)"
    def install(plugin_ref)
      config_manager = load_config
      target_dir = config_manager.full_target_path
      ide = config_manager.ide

      plugin_name, marketplace_name = plugin_ref.split("@")

      manager = Caruso::ManifestManager.new(target_dir)
      marketplaces = manager.list_marketplaces

      marketplace_url = nil

      if marketplace_name
        marketplace_url = manager.get_marketplace_url(marketplace_name)
        unless marketplace_url
          puts "Error: Marketplace '#{marketplace_name}' not found. Add it with 'caruso marketplace add <url>'."
          puts "Available marketplaces: #{marketplaces.keys.join(', ')}" unless marketplaces.empty?
          return
        end
      elsif marketplaces.empty?
        # Try to find plugin in any configured marketplace
        # Or default to the first one if only one exists
        puts "Error: No marketplaces configured. Add one with 'caruso marketplace add <url>'."
        return
      elsif marketplaces.size == 1
        marketplace_name = marketplaces.keys.first
        marketplace_url = marketplaces.values.first
        puts "Using default marketplace: #{marketplace_name}"
      else
        puts "Error: Multiple marketplaces configured. Please specify which one to use: plugin@marketplace"
        puts "Available marketplaces: #{marketplaces.keys.join(', ')}"
        return
      end

      puts "Installing #{plugin_name} from #{marketplace_name}..."

      begin
        fetcher = Caruso::Fetcher.new(marketplace_url)
        files = fetcher.fetch(plugin_name)
      rescue Caruso::PluginNotFoundError => e
        puts "Error: #{e.message}"
        puts "Available plugins: #{e.available_plugins.join(', ')}" unless e.available_plugins.empty?
        return
      end

      if files.empty?
        puts "No steering files found for #{plugin_name}."
        return
      end

      adapter = Caruso::Adapter.new(
        files,
        target_dir: target_dir,
        agent: ide.to_sym
      )
      created_filenames = adapter.adapt

      # Convert filenames to relative paths from project root
      created_files = created_filenames.map { |f| File.join(config_manager.target_dir, f) }

      manager.add_plugin(plugin_name, created_files, marketplace_uri: marketplace_url)
      puts "Installed #{plugin_name}!"
    end

    desc "uninstall PLUGIN_NAME", "Uninstall a plugin"
    def uninstall(plugin_name)
      config_manager = load_config
      target_dir = config_manager.full_target_path

      manager = Caruso::ManifestManager.new(target_dir)

      unless manager.plugin_installed?(plugin_name)
        puts "Plugin #{plugin_name} is not installed."
        return
      end

      puts "Removing #{plugin_name} from manifest..."
      manager.remove_plugin(plugin_name)
      puts "Uninstalled #{plugin_name}. (Files pending deletion)"
    end

    desc "list", "List available and installed plugins"
    def list
      config_manager = load_config
      target_dir = config_manager.full_target_path

      manager = Caruso::ManifestManager.new(target_dir)
      marketplaces = manager.list_marketplaces
      installed = manager.list_plugins

      if marketplaces.empty?
        puts "No marketplaces configured. Use 'caruso marketplace add <url>' to get started."
        return
      end

      marketplaces.each do |name, url|
        puts "\nMarketplace: #{name} (#{url})"
        begin
          fetcher = Caruso::Fetcher.new(url)
          available = fetcher.list_available_plugins

          available.each do |plugin|
            status = installed.key?(plugin[:name]) ? "[Installed]" : ""
            puts "  - #{plugin[:name]} #{status}"
            puts "    #{plugin[:description]}"
          end
        rescue StandardError => e
          puts "  Error fetching marketplace: #{e.message}"
        end
      end
    end

    private

    def load_config
      Caruso::ConfigManager.new
    rescue Caruso::Error => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  class CLI < Thor
    desc "init [PATH]", "Initialize Caruso in a directory"
    method_option :ide, required: true, desc: "Target IDE (currently: cursor)"
    def init(path = ".")
      config_manager = Caruso::ConfigManager.new(path)

      begin
        config = config_manager.init(ide: options[:ide])

        puts "✓ Initialized Caruso for #{config['ide']}"
        puts "  Project directory: #{config_manager.project_dir}"
        puts "  Target directory: #{config['target_dir']}"
        puts "  Config saved to: #{config_manager.config_path}"
      rescue ArgumentError => e
        puts "Error: #{e.message}"
        exit 1
      rescue Caruso::Error => e
        puts "Error: #{e.message}"
        exit 1
      end
    end

    desc "marketplace SUBCOMMAND", "Manage marketplaces"
    subcommand "marketplace", Marketplace

    desc "plugin SUBCOMMAND", "Manage plugins"
    subcommand "plugin", Plugin

    desc "version", "Print version"
    def version
      puts "Caruso v#{Caruso::VERSION}"
    end
  end
end
