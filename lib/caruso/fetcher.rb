# frozen_string_literal: true

require "json"
require "faraday"
require "fileutils"
require "uri"
require "git"

module Caruso
  class Fetcher
    attr_reader :marketplace_uri, :cache_dir

    def initialize(marketplace_uri, cache_dir: "/tmp/caruso_cache")
      @marketplace_uri = marketplace_uri
      @cache_dir = cache_dir
      FileUtils.mkdir_p(@cache_dir)
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
      # For git-based marketplaces, update the cached repository
      if github_repo?
        url = if @marketplace_uri.match?(%r{\Ahttps://github\.com/[^/]+/[^/]+})
                @marketplace_uri
              else
                "https://github.com/#{@marketplace_uri}.git"
              end

        repo_name = URI.parse(url).path.split("/").last.sub(".git", "")
        target_path = File.join(@cache_dir, repo_name)

        if Dir.exist?(target_path)
          # Update existing repository
          begin
            git = Git.open(target_path)
            git.pull
          rescue StandardError => e
            raise "Failed to update marketplace cache: #{e.message}"
          end
        else
          # Clone if not cached yet
          Git.clone(url, repo_name, path: @cache_dir)
        end
      elsif local_path?
        # Local paths don't need updating
        nil
      else
        # Remote JSON files don't need caching
        nil
      end
    end

    private

    def load_marketplace
      if local_path?
        @base_dir = File.dirname(@marketplace_uri)
        # Heuristic: if we are in .claude-plugin, the real root is one level up
        if File.basename(@base_dir) == ".claude-plugin"
          @base_dir = File.dirname(@base_dir)
        end

        JSON.parse(File.read(@marketplace_uri))
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

        JSON.parse(File.read(json_path))
      else
        response = Faraday.get(@marketplace_uri)
        JSON.parse(response.body)
      end
    end

    def github_repo?
      @marketplace_uri.match?(%r{\Ahttps://github\.com/[^/]+/[^/]+}) ||
        @marketplace_uri.match?(%r{\A[^/]+/[^/]+\z}) # owner/repo format
    end

    def fetch_plugin(plugin)
      source = plugin["source"]
      plugin_path = resolve_plugin_path(source)
      return [] unless plugin_path && Dir.exist?(plugin_path)

      find_steering_files(plugin_path)
    end

    def resolve_plugin_path(source)
      if source.is_a?(Hash) && %w[git github].include?(source["source"])
        clone_git_repo(source)
      elsif local_path? && source.is_a?(String) && source.start_with?(".")
        File.expand_path(source, @base_dir)
      elsif source.is_a?(String) && source.match?(/\Ahttps?:/)
        # Assume it's a git URL if it ends in .git or we treat it as such
        clone_git_repo("url" => source)
      else
        # Fallback or error
        puts "Warning: Could not resolve source for plugin: #{source}"
        nil
      end
    end

    def clone_git_repo(source_config)
      url = source_config["url"] || source_config["repo"]
      url = "https://github.com/#{url}.git" if source_config["source"] == "github" && !url.match?(/\Ahttps?:/)

      repo_name = URI.parse(url).path.split("/").last.sub(".git", "")
      target_path = File.join(@cache_dir, repo_name)

      unless Dir.exist?(target_path)
        # Clone the repository if not cached
        Git.clone(url, repo_name, path: @cache_dir)
      end

      target_path
    rescue StandardError => e
      puts "Error cloning #{url}: #{e.message}"
      nil
    end

    def find_steering_files(plugin_path)
      Dir.glob(File.join(plugin_path, "{commands,agents,skills}/**/*.md")).reject do |file|
        basename = File.basename(file).downcase
        ["readme.md", "license.md"].include?(basename)
      end
    end

    def local_path?
      !@marketplace_uri.match?(/\Ahttps?:/)
    end
  end
end
