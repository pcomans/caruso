# frozen_string_literal: true

require "fileutils"
require "yaml"

module Caruso
  class Adapter
    attr_reader :files, :target_dir, :agent

    def initialize(files, target_dir:, agent: :cursor)
      @files = files
      @target_dir = target_dir
      @agent = agent
      FileUtils.mkdir_p(@target_dir)
    end

    def adapt
      created_files = []
      files.each do |file_path|
        content = File.read(file_path)
        adapted_content = inject_metadata(content, file_path)
        created_file = save_file(file_path, adapted_content)
        created_files << created_file
      end
      created_files
    end

    private

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
      target_path = File.join(@target_dir, output_filename)

      File.write(target_path, content)
      puts "Saved: #{target_path}"

      # Return just the filename, not the full path
      output_filename
    end
  end
end
