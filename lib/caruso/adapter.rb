# frozen_string_literal: true

require "fileutils"
require "yaml"
require_relative "path_sanitizer"

module Caruso
  class Adapter
    attr_reader :files, :target_dir, :agent, :marketplace_name, :plugin_name

    def initialize(files, target_dir:, marketplace_name:, plugin_name:, agent: :cursor)
      @files = files
      @target_dir = target_dir
      @agent = agent
      @marketplace_name = marketplace_name
      @plugin_name = plugin_name
      FileUtils.mkdir_p(@target_dir)
    end

    def adapt
      created_files = []
      files.each do |file_path|
        # Validate file_path before reading
        # Files should come from trusted sources (fetcher returns paths from cache or validated local dirs)
        # However, we validate to ensure they're legitimate markdown files
        begin
          validate_file_path(file_path)
          content = File.read(file_path)
        rescue PathSanitizer::PathTraversalError => e
          warn "Skipping invalid file path '#{file_path}': #{e.message}"
          next
        rescue Errno::ENOENT => e
          warn "Skipping non-existent file '#{file_path}': #{e.message}"
          next
        end

        adapted_content = inject_metadata(content, file_path)
        created_file = save_file(file_path, adapted_content)
        created_files << created_file
      end
      created_files
    end

    private

    def validate_file_path(file_path)
      # Ensure the file exists and is a regular file
      unless File.file?(file_path)
        raise PathSanitizer::PathTraversalError, "Not a regular file: #{file_path}"
      end

      # Ensure it's a markdown file
      unless file_path.end_with?(".md")
        raise PathSanitizer::PathTraversalError, "Not a markdown file: #{file_path}"
      end

      # Validate against expected source directories
      # Files should come from either ~/.caruso cache or validated local paths
      caruso_cache = File.join(Dir.home, ".caruso")

      # Check if path is within a trusted location
      expanded_path = File.expand_path(file_path)
      is_in_cache = expanded_path.start_with?(caruso_cache)

      # For cache paths, validate they're within the cache directory
      if is_in_cache
        PathSanitizer.sanitize_path(expanded_path, base_dir: caruso_cache)
      end

      # If not in cache, it's a local file that was validated by the fetcher
      # We still check it's a real file (done above) but allow it through

      true
    end

    def inject_metadata(content, file_path)
      # Check if frontmatter exists
      if content.match?(/\A---\s*\n.*?\n---\s*\n/m)
        # If it exists, we might need to append to it or modify it
        # For now, we assume existing frontmatter is "good enough" but might need 'globs' for Cursor
        ensure_cursor_globs(content) if agent == :cursor
      else
        # No frontmatter, prepend it
        create_frontmatter(file_path) + content
      end
    end

    def ensure_cursor_globs(content)
      # Add required Cursor metadata fields if missing
      # globs: [] enables semantic search (Apply Intelligently)
      # alwaysApply: false means it won't apply to every chat session

      unless content.include?("globs:")
        content.sub!(/\A---\s*\n/, "---\nglobs: []\n")
      end

      unless content.include?("alwaysApply:")
        # Add after the first line of frontmatter
        content.sub!(/\A---\s*\n/, "---\nalwaysApply: false\n")
      end

      content
    end

    def create_frontmatter(file_path)
      filename = File.basename(file_path)
      <<~YAML
        ---
        description: Imported rule from #{filename}
        globs: []
        alwaysApply: false
        ---
      YAML
    end

    def save_file(original_path, content)
      filename = File.basename(original_path, ".*")

      # Rename SKILL.md to the skill name (parent directory) to avoid collisions
      if filename.casecmp("skill").zero?
        filename = File.basename(File.dirname(original_path))
      end

      extension = agent == :cursor ? ".mdc" : ".md"
      output_filename = "#{filename}#{extension}"

      # Extract component type from original path (commands/agents/skills)
      component_type = extract_component_type(original_path)

      # Build nested directory structure for Cursor
      # Build nested directory structure for Cursor
      # Structure: .cursor/rules/caruso/marketplace/plugin/component-type/file.mdc
      subdirs = File.join("caruso", marketplace_name, plugin_name, component_type)
      output_dir = File.join(@target_dir, subdirs)
      FileUtils.mkdir_p(output_dir)
      target_path = File.join(output_dir, output_filename)

      File.write(target_path, content)
      puts "Saved: #{target_path}"

      # Return relative path from target_dir
      File.join(subdirs, output_filename)
    end

    def extract_component_type(file_path)
      # Extract component type (commands/agents/skills) from path
      return "commands" if file_path.include?("/commands/")
      return "agents" if file_path.include?("/agents/")
      return "skills" if file_path.include?("/skills/")

      raise Caruso::Error, "Cannot determine component type from path: #{file_path}"
    end
  end
end
