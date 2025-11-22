# frozen_string_literal: true

require "thor"
require_relative "../caruso"

module Caruso
  class Marketplace < Thor
    desc "add URL [NAME]", "Add a marketplace"
    method_option :ref, type: :string, desc: "Git branch or tag to checkout"
    def add(url, name = nil)
      config_manager = load_config
      target_dir = config_manager.full_target_path

      # Extract name from URL if not provided
      name ||= url.split("/").last.sub(".git", "")

      # Initialize fetcher and clone repository
      fetcher = Caruso::Fetcher.new(url, marketplace_name: name, ref: options[:ref])

      # For Git repos, clone/update the cache (skip in test mode to allow fake URLs)
      if (url.match?(/\Ahttps?:/) || url.match?(%r{[^/]+/[^/]+})) && !ENV["CARUSO_TESTING_SKIP_CLONE"]
        fetcher.clone_git_repo({"url" => url, "source" => "git"})
      end

      manager = Caruso::ManifestManager.new(target_dir)
      manager.add_marketplace(name, url)

      puts "Added marketplace '#{name}' from #{url}"
      puts "  Cached at: #{fetcher.cache_dir}"
      puts "  Ref: #{options[:ref]}" if options[:ref]
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

      # Remove from manifest
      manager = Caruso::ManifestManager.new(target_dir)
      manager.remove_marketplace(name)

      # Remove from registry
      registry = Caruso::MarketplaceRegistry.new
      marketplace = registry.get_marketplace(name)
      if marketplace
        cache_dir = marketplace["install_location"]
        registry.remove_marketplace(name)

        # Inform about cache directory
        if Dir.exist?(cache_dir)
          puts "Cache directory still exists at: #{cache_dir}"
          puts "Run 'rm -rf #{cache_dir}' to delete it if desired."
        end
      end

      puts "Removed marketplace '#{name}'"
    end

    desc "info NAME", "Show marketplace information"
    def info(name)
      registry = Caruso::MarketplaceRegistry.new
      marketplace = registry.get_marketplace(name)

      unless marketplace
        puts "Error: Marketplace '#{name}' not found in registry."
        available = registry.list_marketplaces.keys
        puts "Available marketplaces: #{available.join(', ')}" unless available.empty?
        return
      end

      puts "Marketplace: #{name}"
      puts "  Source: #{marketplace['source']}" if marketplace['source']
      puts "  URL: #{marketplace['url']}"
      puts "  Location: #{marketplace['install_location']}"
      puts "  Last Updated: #{marketplace['last_updated']}"
      puts "  Ref: #{marketplace['ref']}" if marketplace['ref']

      # Check if directory actually exists
      if Dir.exist?(marketplace['install_location'])
        puts "  Status: ✓ Cached locally"
      else
        puts "  Status: ✗ Cache directory missing"
      end
    end

    desc "update [NAME]", "Update marketplace metadata (updates all if no name given)"
    def update(name = nil)
      config_manager = load_config
      target_dir = config_manager.full_target_path

      manager = Caruso::ManifestManager.new(target_dir)
      marketplaces = manager.list_marketplaces

      if name
        # Update specific marketplace
        if marketplaces.empty?
          puts "No marketplaces configured. Use 'caruso marketplace add <url>' to get started."
          return
        end

        marketplace_url = manager.get_marketplace_url(name)
        unless marketplace_url
          puts "Error: Marketplace '#{name}' not found."
          puts "Available marketplaces: #{marketplaces.keys.join(', ')}"
          return
        end

        puts "Updating marketplace '#{name}'..."
        begin
          fetcher = Caruso::Fetcher.new(marketplace_url, marketplace_name: name)
          fetcher.update_cache
          puts "Updated marketplace '#{name}'"
        rescue StandardError => e
          puts "Error updating marketplace: #{e.message}"
        end
      else
        # Update all marketplaces
        if marketplaces.empty?
          puts "No marketplaces configured. Use 'caruso marketplace add <url>' to get started."
          return
        end

        puts "Updating all marketplaces..."
        success_count = 0
        error_count = 0

        marketplaces.each do |marketplace_name, marketplace_url|
          begin
            puts "  Updating #{marketplace_name}..."
            fetcher = Caruso::Fetcher.new(marketplace_url, marketplace_name: marketplace_name)
            fetcher.update_cache
            success_count += 1
          rescue StandardError => e
            puts "  Error updating #{marketplace_name}: #{e.message}"
            error_count += 1
          end
        end

        puts "\nUpdated #{success_count} marketplace(s)" + (error_count.positive? ? " (#{error_count} failed)" : "")
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
        fetcher = Caruso::Fetcher.new(marketplace_url, marketplace_name: marketplace_name)
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
          fetcher = Caruso::Fetcher.new(url, marketplace_name: name)
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

    desc "update PLUGIN_NAME", "Update a plugin to the latest version"
    method_option :all, type: :boolean, aliases: "-a", desc: "Update all installed plugins"
    def update(plugin_name = nil)
      config_manager = load_config
      target_dir = config_manager.full_target_path
      ide = config_manager.ide

      manager = Caruso::ManifestManager.new(target_dir)
      installed_plugins = manager.list_plugins

      if options[:all]
        # Update all plugins
        if installed_plugins.empty?
          puts "No plugins installed."
          return
        end

        puts "Updating all plugins..."
        success_count = 0
        error_count = 0

        installed_plugins.each do |name, plugin_data|
          begin
            puts "  Updating #{name}..."
            update_single_plugin(name, plugin_data, manager, config_manager)
            success_count += 1
          rescue StandardError => e
            puts "  Error updating #{name}: #{e.message}"
            error_count += 1
          end
        end

        puts "\nUpdated #{success_count} plugin(s)" + (error_count.positive? ? " (#{error_count} failed)" : "")
      else
        # Update single plugin
        unless plugin_name
          puts "Error: Please specify a plugin name or use --all to update all plugins."
          return
        end

        plugin_data = installed_plugins[plugin_name]
        unless plugin_data
          puts "Error: Plugin '#{plugin_name}' is not installed."
          puts "Use 'caruso plugin install #{plugin_name}' to install it."
          return
        end

        puts "Updating #{plugin_name}..."
        begin
          update_single_plugin(plugin_name, plugin_data, manager, config_manager)
          puts "Updated #{plugin_name}!"
        rescue StandardError => e
          puts "Error updating plugin: #{e.message}"
          exit 1
        end
      end
    end

    desc "outdated", "Show plugins with available updates"
    def outdated
      config_manager = load_config
      target_dir = config_manager.full_target_path

      manager = Caruso::ManifestManager.new(target_dir)
      installed_plugins = manager.list_plugins

      if installed_plugins.empty?
        puts "No plugins installed."
        return
      end

      puts "Checking for updates..."
      outdated_plugins = []

      marketplaces = manager.list_marketplaces

      installed_plugins.each do |name, plugin_data|
        marketplace_url = plugin_data["marketplace"]
        next unless marketplace_url

        begin
          marketplace_name = marketplaces.key(marketplace_url)
          fetcher = Caruso::Fetcher.new(marketplace_url, marketplace_name: marketplace_name)
          # For now, we'll just report that updates might be available
          # Full version comparison would require version tracking in marketplace.json
          outdated_plugins << {
            name: name,
            current_version: plugin_data["version"] || "unknown",
            marketplace: marketplace_url
          }
        rescue StandardError
          # Skip plugins with inaccessible marketplaces
          next
        end
      end

      if outdated_plugins.empty?
        puts "All plugins are up to date."
      else
        puts "\nPlugins installed:"
        outdated_plugins.each do |plugin|
          puts "  - #{plugin[:name]} (version: #{plugin[:current_version]})"
        end
        puts "\nRun 'caruso plugin update --all' to update all plugins."
      end
    end

    private

    def update_single_plugin(plugin_name, plugin_data, manager, config_manager)
      marketplace_url = plugin_data["marketplace"]
      unless marketplace_url
        raise "No marketplace information found for #{plugin_name}"
      end

      # Get marketplace name from manifest
      marketplaces = manager.list_marketplaces
      marketplace_name = marketplaces.key(marketplace_url)

      # Update marketplace cache first
      fetcher = Caruso::Fetcher.new(marketplace_url, marketplace_name: marketplace_name)
      fetcher.update_cache

      # Fetch latest plugin files
      files = fetcher.fetch(plugin_name)

      if files.empty?
        raise "No steering files found for #{plugin_name}"
      end

      # Adapt files to target IDE
      adapter = Caruso::Adapter.new(
        files,
        target_dir: config_manager.full_target_path,
        agent: config_manager.ide.to_sym
      )
      created_filenames = adapter.adapt

      # Convert filenames to relative paths from project root
      created_files = created_filenames.map { |f| File.join(config_manager.target_dir, f) }

      # Update plugin in manifest
      manager.add_plugin(plugin_name, created_files, marketplace_uri: marketplace_url)
    end

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
