# frozen_string_literal: true

require "json"
require "set"
require_relative "marketplace_registry"

module Caruso
  class Remover
    attr_reader :config_manager

    def initialize(config_manager)
      @config_manager = config_manager
    end

    def remove_marketplace(name)
      # 1. Remove from config and get associated plugin files/hooks
      result = config_manager.remove_marketplace_with_plugins(name)

      # 2. Delete the actual files and remove hooks
      delete_files(result[:files])
      remove_plugin_hooks(result[:hooks]) if result[:hooks] && !result[:hooks].empty?

      # 3. Clean up registry cache
      remove_from_registry(name)
    end

    def remove_plugin(name)
      # 1. Remove from config
      result = config_manager.remove_plugin(name)

      # 2. Delete files and remove hooks
      delete_files(result[:files])
      remove_plugin_hooks(result[:hooks]) if result[:hooks] && !result[:hooks].empty?
    end

    private

    def delete_files(files)
      # Skip hooks.json — it's a merged file handled separately by remove_plugin_hooks
      files.reject { |f| File.basename(f) == "hooks.json" && f.include?(".cursor") }.each do |file|
        full_path = File.join(config_manager.project_dir, file)
        if File.exist?(full_path)
          File.delete(full_path)
          puts "  Deleted #{file}"
          cleanup_empty_parents(full_path)
        end
      end
    end

    # Walk up from a deleted file's parent, removing empty directories
    # until we hit .cursor/ itself or a non-empty directory.
    def cleanup_empty_parents(file_path)
      cursor_dir = File.join(config_manager.project_dir, ".cursor")
      dir = File.dirname(file_path)

      while dir != cursor_dir && dir.start_with?(cursor_dir)
        break unless Dir.exist?(dir) && Dir.empty?(dir)

        Dir.rmdir(dir)
        dir = File.dirname(dir)
      end
    end

    # Remove specific hook entries from .cursor/hooks.json using tracked metadata.
    # installed_hooks is a hash: { "event_name" => [{ "command" => "..." }, ...] }
    def remove_plugin_hooks(installed_hooks)
      hooks_path = File.join(config_manager.project_dir, ".cursor", "hooks.json")
      return unless File.exist?(hooks_path)

      begin
        data = JSON.parse(File.read(hooks_path))
        hooks = data["hooks"] || {}
      rescue JSON::ParserError
        return
      end

      changed = false
      installed_hooks.each do |event, entries|
        next unless hooks[event]

        # Build set of commands to remove for this event
        commands_to_remove = entries.map { |e| e["command"] }.compact.to_set

        before_count = hooks[event].length
        hooks[event].reject! { |entry| commands_to_remove.include?(entry["command"]) }
        changed = true if hooks[event].length != before_count
      end

      # Remove empty event arrays
      hooks.reject! { |_, entries| entries.empty? }

      if changed
        if hooks.empty?
          File.delete(hooks_path)
          puts "  Deleted .cursor/hooks.json (empty after plugin removal)"
        else
          File.write(hooks_path, JSON.pretty_generate({ "version" => 1, "hooks" => hooks }))
          puts "  Updated .cursor/hooks.json (removed plugin hooks)"
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
