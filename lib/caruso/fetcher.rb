# frozen_string_literal: true

require "json"
require "faraday"
require "fileutils"
require "uri"
require "git"
require_relative "safe_file"
require_relative "safe_dir"
require_relative "path_sanitizer"

module Caruso
  class Fetcher
    attr_reader :marketplace_uri

    def initialize(marketplace_uri, marketplace_name: nil, ref: nil)
      @marketplace_uri = marketplace_uri
      @marketplace_name = marketplace_name
      @ref = ref
      @registry = MarketplaceRegistry.new
    end

    def cache_dir
      # Cache directory based on URL for stability (name comes from marketplace.json)
      url_based_name = extract_name_from_url(@marketplace_uri)
      File.join(Dir.home, ".caruso", "marketplaces", url_based_name)
    end

    def fetch(plugin_name)
      marketplace_data = load_marketplace
      plugins = marketplace_data["plugins"] || []

      plugin = plugins.find { |p| p["name"] == plugin_name }
      unless plugin
        available = plugins.map { |p| p["name"] }
        raise PluginNotFoundError.new("Plugin '#{plugin_name}' not found in marketplace", available)
      end

      fetch_plugin(plugin)
    end

    def list_available_plugins
      marketplace_data = load_marketplace
      plugins = marketplace_data["plugins"] || []
      plugins.map do |p|
        {
          name: p["name"],
          description: p["description"],
          version: p["version"]
        }
      end
    end

    def update_cache
      return unless SafeDir.exist?(cache_dir)

      Dir.chdir(cache_dir) do
        git = Git.open(".")
        if @ref
          git.fetch("origin", @ref)
          git.checkout(@ref)
        end
        git.pull("origin", "HEAD")
      end

      @registry.update_timestamp(@marketplace_name)
    rescue StandardError => e
      handle_git_error(e)
    end

    def clone_git_repo(source_config)
      url = source_config["url"] || source_config["repo"]
      url = "https://github.com/#{url}.git" if source_config["source"] == "github" && !url.match?(/\Ahttps?:/)

      URI.parse(url).path.split("/").last.sub(".git", "")
      target_path = cache_dir

      unless SafeDir.exist?(target_path)
        # Clone the repository
        FileUtils.mkdir_p(File.dirname(target_path))
        Git.clone(url, target_path)
        checkout_ref if @ref

        # Add to registry
        source_type = source_config["source"] || "git"
        @registry.add_marketplace(@marketplace_name, url, target_path, ref: @ref, source: source_type)
      end

      target_path
    rescue StandardError => e
      handle_git_error(e)
      nil
    end

    def extract_marketplace_name
      marketplace_data = load_marketplace
      name = marketplace_data["name"]

      unless name
        raise Caruso::Error, "Invalid marketplace: marketplace.json missing required 'name' field"
      end

      name
    end

    private

    def load_marketplace
      if local_path?
        # If marketplace_uri is a directory, find marketplace.json in it
        if SafeDir.exist?(@marketplace_uri)
          json_path = File.join(@marketplace_uri, ".claude-plugin", "marketplace.json")
          json_path = File.join(@marketplace_uri, "marketplace.json") unless File.exist?(json_path)

          unless File.exist?(json_path)
            raise Caruso::Error, "Could not find marketplace.json in #{@marketplace_uri}"
          end

          @marketplace_uri = json_path
        end

        @base_dir = File.dirname(@marketplace_uri)
        # Heuristic: if we are in .claude-plugin, the real root is one level up
        if File.basename(@base_dir) == ".claude-plugin"
          @base_dir = File.dirname(@base_dir)
        end

        JSON.parse(SafeFile.read(@marketplace_uri))
      elsif github_repo?
        # Clone repo and read marketplace.json from it
        repo_path = clone_git_repo("url" => @marketplace_uri, "source" => "github")
        # Try standard locations
        json_path = File.join(repo_path, ".claude-plugin", "marketplace.json")
        json_path = File.join(repo_path, "marketplace.json") unless File.exist?(json_path)

        unless File.exist?(json_path)
          raise "Could not find marketplace.json in #{@marketplace_uri}"
        end

        # Update marketplace_uri to point to the local file so relative paths work
        @marketplace_uri = json_path
        @base_dir = repo_path # Base dir is the repo root, regardless of where json is

        JSON.parse(SafeFile.read(json_path))
      else
        response = Faraday.get(@marketplace_uri)
        JSON.parse(response.body)
      end
    end

    def github_repo?
      # Fixed ReDoS: Add length check to prevent catastrophic backtracking
      # GitHub URLs and owner/repo format should be reasonably short
      return false if @marketplace_uri.length > 512

      @marketplace_uri.match?(%r{\Ahttps://github\.com/[^/]+/[^/]+}) ||
        @marketplace_uri.match?(%r{\A[^/]+/[^/]+\z}) # owner/repo format
    end

    def fetch_plugin(plugin)
      source = plugin["source"]
      plugin_path = resolve_plugin_path(source)
      return [] unless plugin_path

      # Validate that plugin_path is safe before using it
      # resolve_plugin_path returns paths from trusted sources:
      # - cache_dir (under ~/.caruso/marketplaces/)
      # - validated local paths relative to @base_dir
      # However, we still validate to ensure no path traversal
      begin
        # For paths under ~/.caruso, validate against home directory
        # For local paths, they're already validated in resolve_plugin_path
        if plugin_path.start_with?(File.join(Dir.home, ".caruso"))
          PathSanitizer.sanitize_path(plugin_path, base_dir: File.join(Dir.home, ".caruso"))
        end
      rescue PathSanitizer::PathTraversalError => e
        warn "Invalid plugin path '#{plugin_path}': #{e.message}"
        return []
      end

      return [] unless SafeDir.exist?(plugin_path)

      # Merge marketplace entry with plugin.json (marketplace takes precedence)
      merged_plugin_data = merge_with_plugin_json(plugin, plugin_path)

      files = find_steering_files(plugin_path, merged_plugin_data)

      files.uniq
    end

    # Read plugin.json and merge with marketplace entry.
    # Marketplace fields override plugin.json fields for component paths.
    def merge_with_plugin_json(marketplace_entry, plugin_path)
      plugin_json_path = File.join(plugin_path, ".claude-plugin", "plugin.json")
      return marketplace_entry unless File.exist?(plugin_json_path)

      begin
        plugin_data = JSON.parse(SafeFile.read(plugin_json_path))
      rescue JSON::ParserError => e
        puts "Warning: Could not parse plugin.json: #{e.message}"
        return marketplace_entry
      end

      component_fields = %w[commands agents skills hooks mcpServers]
      merged = marketplace_entry.dup

      component_fields.each do |field|
        # Only use plugin.json value if marketplace entry doesn't specify this field
        next if merged.key?(field)
        next unless plugin_data.key?(field)

        merged[field] = plugin_data[field]
      end

      merged
    end

    def resolve_plugin_path(source)
      if source.is_a?(Hash) && %w[git github].include?(source["source"])
        clone_git_repo(source)
      elsif local_path? && source.is_a?(String) && (source.start_with?(".") || source.start_with?("/"))
        if source.start_with?("/")
          source
        else
          File.expand_path(source, @base_dir)
        end
      elsif source.is_a?(String) && source.match?(/\Ahttps?:/)
        # Assume it's a git URL if it ends in .git or we treat it as such
        clone_git_repo("url" => source)
      else
        # Fallback or error
        puts "Warning: Could not resolve source for plugin: #{source}"
        nil
      end
    end

    # Find all steering files based on default locations and manifest overrides
    # RETURNS: unique list of absolute file paths to fetch
    def find_steering_files(plugin_path, plugin_data = nil)
      files = []

      # 1. ALWAYS scan default directories (Additive Strategy)
      files += glob_plugin_files(plugin_path, "commands", "**", "*.md")
      files += glob_plugin_files(plugin_path, "agents", "**", "*.md")

      # For skills, we want recursive default scan if 'skills/' exists
      # But careful: if we scan default 'skills' recursively here, and then scan strict paths from manifest...
      # Duplicate handling is fine via uniq.
      default_skills_path = File.join(plugin_path, "skills")
      if SafeDir.exist?(default_skills_path)
        files += find_recursive_component_files(plugin_path, "skills")
      end

      # 2. Add manifest-defined paths (if present)
      if plugin_data
        files += find_custom_component_files(plugin_path, plugin_data["commands"]) if plugin_data["commands"]
        files += find_custom_component_files(plugin_path, plugin_data["agents"]) if plugin_data["agents"]
        files += find_recursive_component_files(plugin_path, plugin_data["skills"]) if plugin_data["skills"]
      end

      # 3. Detect hooks files
      files += find_hooks_files(plugin_path, plugin_data)

      # Filter out noise
      files.uniq.reject do |file|
        basename = File.basename(file).downcase
        ["readme.md", "license.md", "plugin.json"].include?(basename) || File.directory?(file)
      end
    end

    # Helper to glob files safely
    def glob_plugin_files(plugin_path, *parts)
      pattern = PathSanitizer.safe_join(plugin_path, *parts)
      SafeDir.glob(pattern, base_dir: plugin_path)
    end

    # For Commands/Agents: typically just markdown files, flat or shallow
    def find_custom_component_files(plugin_path, paths)
      # Handle both string and array formats
      paths = [paths] if paths.is_a?(String)
      return [] unless paths.is_a?(Array)

      files = []
      paths.each do |path|
        full_path = resolve_safe_path(plugin_path, path)
        next unless full_path

        if File.file?(full_path) && full_path.end_with?(".md")
          files << full_path
        elsif SafeDir.exist?(full_path, base_dir: plugin_path)
          # Find all .md files in this directory
          glob_pattern = PathSanitizer.safe_join(full_path, "**", "*.md")
          files += SafeDir.glob(glob_pattern, base_dir: plugin_path)
        end
      end
      files
    end

    # For SKILLS: Recursive fetch of EVERYTHING (scripts, assets, md)
    def find_recursive_component_files(plugin_path, paths)
      paths = [paths] if paths.is_a?(String)
      return [] unless paths.is_a?(Array)

      files = []
      paths.each do |path|
        full_path = resolve_safe_path(plugin_path, path)
        next unless full_path

        if File.file?(full_path)
          files << full_path
        elsif SafeDir.exist?(full_path, base_dir: plugin_path)
          # Grab EVERYTHING recursively
          glob_pattern = PathSanitizer.safe_join(full_path, "**", "*")
          files += SafeDir.glob(glob_pattern, base_dir: plugin_path)
        end
      end
      files
    end

    def find_hooks_files(plugin_path, plugin_data)
      files = []

      # Default hooks/ directory
      default_hooks = File.join(plugin_path, "hooks", "hooks.json")
      files << default_hooks if File.exist?(default_hooks)

      # Custom hooks from manifest (inline config or path-based)
      return files unless plugin_data&.key?("hooks")

      hooks_value = plugin_data["hooks"]
      if hooks_value.is_a?(Hash)
        inline_path = File.join(plugin_path, ".caruso_inline_hooks.json")
        File.write(inline_path, JSON.pretty_generate(hooks_value))
        files << inline_path
      else
        files += find_custom_hooks_paths(plugin_path, hooks_value)
      end

      files
    end

    def find_custom_hooks_paths(plugin_path, hooks_value)
      files = []
      [hooks_value].flatten.each do |path|
        full_path = resolve_safe_path(plugin_path, path)
        next unless full_path

        if File.file?(full_path) && File.basename(full_path) == "hooks.json"
          files << full_path
        elsif SafeDir.exist?(full_path, base_dir: plugin_path)
          candidate = File.join(full_path, "hooks.json")
          files << candidate if File.exist?(candidate)
        end
      end
      files
    end

    def resolve_safe_path(plugin_path, relative_path)
      PathSanitizer.sanitize_path(File.expand_path(relative_path, plugin_path), base_dir: plugin_path)
    rescue PathSanitizer::PathTraversalError => e
      warn "Skipping path outside plugin directory '#{relative_path}': #{e.message}"
      nil
    end

    def local_path?
      !@marketplace_uri.match?(/\Ahttps?:/)
    end

    def handle_git_error(error)
      msg = error.message.to_s
      if msg.include?("Permission denied") ||
         msg.include?("publickey") ||
         msg.include?("Could not read from remote")
        raise Caruso::Error, "SSH authentication failed while accessing marketplace.\n" \
                             "Please ensure your SSH keys are configured for #{@marketplace_uri}"
      end
      raise error
    end

    def checkout_ref
      return unless @ref

      Dir.chdir(cache_dir) do
        git = Git.open(".")
        git.checkout(@ref)
      end
    end

    def extract_name_from_url(url)
      url.split("/").last.sub(".git", "")
    end
  end
end
