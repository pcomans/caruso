# frozen_string_literal: true

require "thor"
require_relative "../caruso"

module Caruso
  class Marketplace < Thor
    desc "add URL", "Add a marketplace"
    method_option :ref, type: :string, desc: "Git branch or tag to checkout"
    def add(url)
      config_manager = load_config

      # Determine source type
      source = "git"
      if url.match?(%r{\Ahttps://github\.com/[^/]+/[^/]+}) || url.match?(%r{\A[^/]+/[^/]+\z})
        source = "github"
      end

      # Initialize fetcher and clone repository (cache dir is URL-based)
      fetcher = Caruso::Fetcher.new(url, ref: options[:ref])

      # For Git repos, clone/update the cache (skip in test mode to allow fake URLs)
      # Fixed ReDoS: Use anchored regex and limit input length to prevent catastrophic backtracking
      is_owner_repo = url.length < 256 && url.match?(%r{\A[^/]+/[^/]+\z})
      if (source == "github" || url.match?(/\Ahttps?:/) || is_owner_repo) && !ENV["CARUSO_TESTING_SKIP_CLONE"]
        fetcher.clone_git_repo({ "url" => url, "source" => source })
      end

      # Read marketplace name from marketplace.json
      marketplace_name = fetcher.extract_marketplace_name

      # Register in the persistent marketplace registry (only after name is known)
      fetcher.register_marketplace(marketplace_name)

      config_manager.add_marketplace(marketplace_name, url, source: source, ref: options[:ref])

      puts "Added marketplace '#{marketplace_name}' from #{url}"
      puts "  Cached at: #{fetcher.cache_dir}"
      puts "  Ref: #{options[:ref]}" if options[:ref]
    end

    desc "list", "List configured marketplaces"
    def list
      config_manager = load_config
      marketplaces = config_manager.list_marketplaces

      if marketplaces.empty?
        puts "No marketplaces configured."
      else
        puts "Configured Marketplaces:"
        marketplaces.each do |name, details|
          puts "  - #{name}: #{details['url']} (Ref: #{details['ref'] || 'HEAD'})"
        end
      end
    end

    desc "remove NAME_OR_URL", "Remove a marketplace"
    def remove(name_or_url)
      config_manager = load_config
      marketplaces = config_manager.list_marketplaces

      # Try to find by name first
      if marketplaces.key?(name_or_url)
        name = name_or_url
      else
        # Try to find by URL
        # We need to check exact match or maybe normalized match
        match = marketplaces.find { |_, details| details["url"] == name_or_url || details["url"].chomp(".git") == name_or_url }
        if match
          name = match[0]
        else
          puts "Marketplace '#{name_or_url}' not found."
          return
        end
      end

      # Use Remover to handle cleanup
      remover = Caruso::Remover.new(config_manager)
      remover.remove_marketplace(name)

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
      puts "  Source: #{marketplace['source']}" if marketplace["source"]
      puts "  URL: #{marketplace['url']}"
      puts "  Location: #{marketplace['install_location']}"
      puts "  Last Updated: #{marketplace['last_updated']}"
      puts "  Ref: #{marketplace['ref']}" if marketplace["ref"]

      # Check if directory actually exists
      if Dir.exist?(marketplace["install_location"])
        puts "  Status: ✓ Cached locally"
      else
        puts "  Status: ✗ Cache directory missing"
      end
    end

    desc "update [NAME]", "Update marketplace metadata (updates all if no name given)"
    def update(name = nil)
      config_manager = load_config
      marketplaces = config_manager.list_marketplaces

      if marketplaces.empty?
        puts "No marketplaces configured. Use 'caruso marketplace add <url>' to get started."
        return
      end
      if name
        # Update specific marketplace

        marketplace_details = config_manager.get_marketplace_details(name)
        unless marketplace_details
          puts "Error: Marketplace '#{name}' not found."
          puts "Available marketplaces: #{marketplaces.keys.join(', ')}"
          return
        end

        puts "Updating marketplace '#{name}'..."
        begin
          fetcher = Caruso::Fetcher.new(marketplace_details["url"], marketplace_name: name,
                                                                    ref: marketplace_details["ref"])
          fetcher.update_cache
          puts "Updated marketplace '#{name}'"
        rescue StandardError => e
          puts "Error updating marketplace: #{e.message}"
        end
      else
        # Update all marketplaces

        puts "Updating all marketplaces..."
        success_count = 0
        error_count = 0

        marketplaces.each do |marketplace_name, details|
          puts "  Updating #{marketplace_name}..."
          fetcher = Caruso::Fetcher.new(details["url"], marketplace_name: marketplace_name, ref: details["ref"])
          fetcher.update_cache
          success_count += 1
        rescue StandardError => e
          puts "  Error updating #{marketplace_name}: #{e.message}"
          error_count += 1
        end

        puts "\nUpdated #{success_count} marketplace(s)" + (error_count.positive? ? " (#{error_count} failed)" : "")
      end
    end

    private

    def load_config
      manager = Caruso::ConfigManager.new
      manager.load
      manager
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

      marketplaces = config_manager.list_marketplaces

      marketplace_url = nil

      if marketplace_name
        marketplace_details = config_manager.get_marketplace_details(marketplace_name)
        unless marketplace_details
          puts "Error: Marketplace '#{marketplace_name}' not found. Add it with 'caruso marketplace add <url>'."
          puts "Available marketplaces: #{marketplaces.keys.join(', ')}" unless marketplaces.empty?
          return
        end
        marketplace_url = marketplace_details["url"]
      elsif marketplaces.empty?
        # Try to find plugin in any configured marketplace
        # Or default to the first one if only one exists
        puts "Error: No marketplaces configured. Add one with 'caruso marketplace add <url>'."
        return
      elsif marketplaces.size == 1
        marketplace_name = marketplaces.keys.first
        marketplace_url = marketplaces.values.first["url"]
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
        agent: ide.to_sym,
        marketplace_name: marketplace_name,
        plugin_name: plugin_name
      )
      created_filenames = adapter.adapt

      # Convert filenames to project-relative paths.
      # Paths already starting with .cursor/ (commands, hooks) are already project-relative.
      # Others (rules from SkillAdapter/MarkdownAdapter) are relative to target_dir.
      created_files = created_filenames.map do |f|
        if f.start_with?(".cursor/") || File.absolute_path?(f)
          f
        else
          File.join(config_manager.target_dir, f)
        end
      end

      # Use composite key for uniqueness
      plugin_key = "#{plugin_name}@#{marketplace_name}"
      config_manager.add_plugin(plugin_key, created_files, marketplace_name: marketplace_name,
                                                           hooks: adapter.installed_hooks)
      puts "Installed #{plugin_name}!"
    end

    desc "uninstall PLUGIN_NAME", "Uninstall a plugin"
    def uninstall(plugin_ref)
      config_manager = load_config

      # Handle both "plugin" and "plugin@marketplace" formats
      # If just "plugin", we need to find the full key
      plugin_key = plugin_ref
      unless plugin_ref.include?("@")
        installed = config_manager.list_plugins
        matches = installed.keys.select { |k| k.start_with?("#{plugin_ref}@") }
        if matches.size == 1
          plugin_key = matches.first
        elsif matches.size > 1
          puts "Error: Multiple plugins match '#{plugin_ref}'. Please specify marketplace: #{matches.join(', ')}"
          return
        elsif !installed.key?(plugin_ref) # Check exact match just in case
          puts "Plugin #{plugin_ref} is not installed."
          return
        end
      end

      unless config_manager.plugin_installed?(plugin_key)
        puts "Plugin #{plugin_key} is not installed."
        return
      end

      puts "Removing #{plugin_key}..."

      remover = Caruso::Remover.new(config_manager)
      remover.remove_plugin(plugin_key)

      puts "Uninstalled #{plugin_key}."
    end

    desc "list", "List available and installed plugins"
    def list
      config_manager = load_config
      marketplaces = config_manager.list_marketplaces
      installed = config_manager.list_plugins

      if marketplaces.empty?
        puts "No marketplaces configured. Use 'caruso marketplace add <url>' to get started."
        return
      end

      marketplaces.each do |name, details|
        puts "\nMarketplace: #{name} (#{details['url']})"
        begin
          fetcher = Caruso::Fetcher.new(details["url"], marketplace_name: name, ref: details["ref"])
          available = fetcher.list_available_plugins

          available.each do |plugin|
            plugin_key = "#{plugin[:name]}@#{name}"
            status = installed.key?(plugin_key) ? "[Installed]" : ""
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
    def update(plugin_ref = nil)
      config_manager = load_config
      installed_plugins = config_manager.list_plugins

      if options[:all]
        # Update all plugins
        if installed_plugins.empty?
          puts "No plugins installed."
          return
        end

        puts "Updating all plugins..."
        success_count = 0
        error_count = 0

        installed_plugins.each do |key, plugin_data|
          puts "  Updating #{key}..."
          update_single_plugin(key, plugin_data, config_manager)
          success_count += 1
        rescue StandardError => e
          puts "  Error updating #{key}: #{e.message}"
          error_count += 1
        end

        puts "\nUpdated #{success_count} plugin(s)" + (error_count.positive? ? " (#{error_count} failed)" : "")
      else
        # Update single plugin
        unless plugin_ref
          puts "Error: Please specify a plugin name (plugin@marketplace) or use --all to update all plugins."
          return
        end

        # Resolve key
        plugin_key = plugin_ref
        unless plugin_ref.include?("@")
          matches = installed_plugins.keys.select { |k| k.start_with?("#{plugin_ref}@") }
          if matches.size == 1
            plugin_key = matches.first
          elsif matches.size > 1
            puts "Error: Multiple plugins match '#{plugin_ref}'. Please specify marketplace: #{matches.join(', ')}"
            return
          elsif !installed_plugins.key?(plugin_ref)
            puts "Error: Plugin '#{plugin_ref}' is not installed."
            puts "Use 'caruso plugin install #{plugin_ref}' to install it."
            return
          end
        end

        plugin_data = installed_plugins[plugin_key]
        unless plugin_data
          puts "Error: Plugin '#{plugin_key}' is not installed."
          return
        end

        puts "Updating #{plugin_key}..."
        begin
          update_single_plugin(plugin_key, plugin_data, config_manager)
          puts "Updated #{plugin_key}!"
        rescue StandardError => e
          puts "Error updating plugin: #{e.message}"
          exit 1
        end
      end
    end

    desc "outdated", "Show plugins with available updates"
    def outdated
      config_manager = load_config
      config_manager.full_target_path

      installed_plugins = config_manager.list_plugins

      if installed_plugins.empty?
        puts "No plugins installed."
        return
      end

      puts "Checking for updates..."
      outdated_plugins = []

      config_manager.list_marketplaces

      installed_plugins.each do |key, plugin_data|
        marketplace_name = plugin_data["marketplace"]
        next unless marketplace_name

        marketplace_details = config_manager.get_marketplace_details(marketplace_name)
        next unless marketplace_details

        begin
          Caruso::Fetcher.new(marketplace_details["url"], marketplace_name: marketplace_name,
                                                          ref: marketplace_details["ref"])
          # For now, we'll just report that updates might be available
          # Full version comparison would require version tracking in marketplace.json
          outdated_plugins << {
            name: key,
            current_version: "unknown", # Version tracking not fully implemented yet
            marketplace: marketplace_name
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

    def update_single_plugin(plugin_key, plugin_data, config_manager)
      marketplace_name = plugin_data["marketplace"]
      unless marketplace_name
        raise "No marketplace information found for #{plugin_key}"
      end

      marketplace_details = config_manager.get_marketplace_details(marketplace_name)
      unless marketplace_details
        raise "Marketplace '#{marketplace_name}' not found in config"
      end

      # Update marketplace cache first
      fetcher = Caruso::Fetcher.new(marketplace_details["url"], marketplace_name: marketplace_name,
                                                                ref: marketplace_details["ref"])
      fetcher.update_cache

      # Parse plugin name from key (plugin@marketplace)
      plugin_name = plugin_key.split("@").first

      # Fetch latest plugin files
      files = fetcher.fetch(plugin_name)

      if files.empty?
        raise "No steering files found for #{plugin_name}"
      end

      # Adapt files to target IDE
      adapter = Caruso::Adapter.new(
        files,
        target_dir: config_manager.full_target_path,
        agent: config_manager.ide.to_sym,
        marketplace_name: marketplace_name,
        plugin_name: plugin_name
      )
      created_filenames = adapter.adapt

      # Convert filenames to project-relative paths (same logic as install)
      created_files = created_filenames.map do |f|
        if f.start_with?(".cursor/") || File.absolute_path?(f)
          f
        else
          File.join(config_manager.target_dir, f)
        end
      end

      # Cleanup: Delete files that are no longer present
      old_files = config_manager.get_installed_files(plugin_key)
      files_to_delete = old_files - created_files
      files_to_delete.each do |file|
        full_path = File.join(config_manager.project_dir, file)
        if File.exist?(full_path)
          File.delete(full_path)
          puts "  Deleted obsolete file: #{file}"
        end
      end

      # Update plugin in config
      config_manager.add_plugin(plugin_key, created_files, marketplace_name: marketplace_name,
                                                           hooks: adapter.installed_hooks)
    end

    def load_config
      manager = Caruso::ConfigManager.new
      manager.load
      manager
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
        puts ""
        puts "Created files:"
        puts "  ✓ caruso.json (commit this)"
        puts "  ✓ .caruso.local.json (add to .gitignore)"
        puts ""
        puts "Recommended .gitignore entries:"
        puts "  .caruso.local.json"
        puts "  #{config['target_dir']}/caruso/"
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
