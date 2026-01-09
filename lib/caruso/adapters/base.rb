# frozen_string_literal: true

require "fileutils"
require "yaml"
require_relative "../safe_file"
require_relative "../path_sanitizer"

module Caruso
  module Adapters
    class Base
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
        raise NotImplementedError, "#{self.class.name}#adapt must be implemented"
      end

      protected

      def save_file(relative_path, content, extension: nil)
        filename = File.basename(relative_path, ".*")
        
        # Preserve original extension if none provided
        ext = extension || File.extname(relative_path)
        
        # Rename SKILL.md to the skill name (parent directory) to avoid collisions
        # This is specific to Skills, might move to SkillAdapter later, but keeping behavior for now
        if filename.casecmp("skill").zero?
          filename = File.basename(File.dirname(relative_path))
        end

        output_filename = "#{filename}#{ext}"

        # Build nested directory structure: .cursor/rules/caruso/marketplace/plugin/component/file
        # Component type is derived from the class name or passed in?
        # For base, we might need a way to determine output path more flexibly.
        # But sticking to current behavior:
        
        component_type = extract_component_type(relative_path)
        subdirs = File.join("caruso", marketplace_name, plugin_name, component_type)
        output_dir = File.join(target_dir, subdirs)
        
        FileUtils.mkdir_p(output_dir)
        target_path = File.join(output_dir, output_filename)

        File.write(target_path, content)
        puts "Saved: #{target_path}"

        File.join(subdirs, output_filename)
      end

      def extract_component_type(file_path)
        # Extract component type (commands/agents/skills) from path
        return "commands" if file_path.include?("/commands/")
        return "agents" if file_path.include?("/agents/")
        return "skills" if file_path.include?("/skills/")
        
        # Fallback or specific handling for other types
        "misc"
      end

      def inject_metadata(content, file_path)
        if content.match?(/\A---\s*\n.*?\n---\s*\n/m)
          ensure_cursor_globs(content) if agent == :cursor
        else
          create_frontmatter(file_path) + content
        end
      end

      def ensure_cursor_globs(content)
        unless content.include?("globs:")
          content.sub!(/\A---\s*\n/, "---\nglobs: []\n")
        end

        unless content.include?("alwaysApply:")
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
    end
  end
end
