# frozen_string_literal: true

require "thor"
require_relative "../caruso"

module Caruso
  class CLI < Thor
    desc "list MARKETPLACE_URI", "List available plugins in a marketplace"
    method_option :target, aliases: "-t", default: ".cursor/rules", desc: "Target directory"
    def list(marketplace_uri)
      fetcher = Caruso::Fetcher.new(marketplace_uri)
      available = fetcher.list_available_plugins
      
      manager = Caruso::ManifestManager.new(options[:target])
      installed = manager.list_plugins

      puts "Available Plugins:"
      available.each do |plugin|
        status = installed.key?(plugin[:name]) ? "[Installed]" : ""
        puts "  - #{plugin[:name]} #{status}"
        puts "    #{plugin[:description]}"
      end
    end

    desc "install PLUGIN_NAME MARKETPLACE_URI", "Install a specific plugin"
    method_option :target, aliases: "-t", default: ".cursor/rules", desc: "Target directory"
    method_option :agent, aliases: "-a", default: "cursor", desc: "Target agent"
    def install(plugin_name, marketplace_uri)
      puts "Installing #{plugin_name}..."
      
      fetcher = Caruso::Fetcher.new(marketplace_uri)
      files = fetcher.fetch(plugin_name)
      
      if files.empty?
        puts "No steering files found for #{plugin_name}."
        return
      end

      adapter = Caruso::Adapter.new(
        files, 
        target_dir: options[:target], 
        agent: options[:agent].to_sym
      )
      adapter.adapt

      # Update Manifest
      manager = Caruso::ManifestManager.new(options[:target])
      # We need to know which files were created. 
      # For now, Adapter doesn't return them, but we can infer or update Adapter.
      # Quick fix: Adapter saves files. We can just list what we fetched? 
      # Actually, Adapter renames files. We should update Adapter to return saved paths.
      # For this iteration, let's just store the source paths as a proxy or list the target dir.
      # Better: Let's assume Adapter worked and we store the *source* file list for now, 
      # or update Adapter to return the list of created files.
      
      # Let's update Adapter to return saved files in a future step. 
      # For now, we'll just record that it's installed.
      manager.add_plugin(plugin_name, files, marketplace_uri: marketplace_uri)
      
      puts "Installed #{plugin_name}!"
    end

    desc "remove PLUGIN_NAME", "Remove an installed plugin"
    method_option :target, aliases: "-t", default: ".cursor/rules", desc: "Target directory"
    def remove(plugin_name)
      manager = Caruso::ManifestManager.new(options[:target])
      
      unless manager.plugin_installed?(plugin_name)
        puts "Plugin #{plugin_name} is not installed."
        return
      end

      # This is tricky because we need to know the *adapted* filenames to delete them.
      # The manifest currently stores the *source* filenames (from fetcher).
      # We need to reconstruct the target filename or store the target filename in manifest.
      # For this MVP, we'll just remove the entry from manifest and warn user.
      # Ideally, we update Adapter to return target paths and store THOSE in manifest.
      
      puts "Removing #{plugin_name} from manifest..."
      manager.remove_plugin(plugin_name)
      puts "Removed #{plugin_name}. Note: Actual files were not deleted in this version (pending Adapter refactor)."
    end

    desc "sync MARKETPLACE_URI", "Sync all plugins (Legacy)"
    method_option :target, aliases: "-t", default: ".cursor/rules", desc: "Target directory"
    method_option :agent, aliases: "-a", default: "cursor", desc: "Target agent"
    def sync(marketplace_uri)
      puts "Fetching all from #{marketplace_uri}..."
      fetcher = Caruso::Fetcher.new(marketplace_uri)
      files = fetcher.fetch
      
      puts "Found #{files.count} steering files."
      
      adapter = Caruso::Adapter.new(
        files, 
        target_dir: options[:target], 
        agent: options[:agent].to_sym
      )
      adapter.adapt
      
      puts "Sync complete!"
    end
    
    desc "version", "Print version"
    def version
      puts "Caruso v#{Caruso::VERSION}"
    end
  end
end
