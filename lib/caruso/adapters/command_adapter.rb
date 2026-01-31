# frozen_string_literal: true

require_relative "base"

module Caruso
  module Adapters
    class CommandAdapter < Base
      def adapt
        created_files = []
        files.each do |file_path|
          content = SafeFile.read(file_path)
          adapted_content = adapt_command_content(content, file_path)

          # Commands are flat .md files in .cursor/commands/
          # NOT nested like rules, so we override the save behavior
          created_file = save_command_file(file_path, adapted_content)

          created_files << created_file
        end
        created_files
      end

      private

      def adapt_command_content(content, file_path)
        # Preserve or add frontmatter, but don't add Cursor-specific rule fields
        if content.match?(/\A---\s*\n.*?\n---\s*\n/m)
          # Frontmatter exists - preserve command-specific fields
          preserve_command_frontmatter(content, file_path)
        else
          # No frontmatter - create minimal description
          create_command_frontmatter(file_path) + content
        end
      end

      def preserve_command_frontmatter(content, _file_path)
        # Commands support: description, argument-hint, allowed-tools, model
        # We don't need globs or alwaysApply (those are for rules)
        # Just return content as-is, Claude Code commands are already compatible

        # Add note about bash execution if it contains ! prefix
        if content.include?("!`")
          add_bash_execution_note(content)
        else
          content
        end
      end

      def create_command_frontmatter(file_path)
        filename = File.basename(file_path)
        <<~YAML
          ---
          description: Command from #{filename}
          ---
        YAML
      end

      def add_bash_execution_note(content)
        match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
        return content unless match

        note = "\n**Note:** This command originally used Claude Code's `!` prefix for bash execution. " \
               "Cursor does not support this feature. The bash commands are documented below for reference.\n"

        "---\n#{match[1]}\n---\n#{note}#{match.post_match}"
      end

      def save_command_file(relative_path, content)
        filename = File.basename(relative_path, ".*")
        output_filename = "#{filename}.md"

        # Commands go to .cursor/commands/caruso/<marketplace>/<plugin>/
        # Flat structure, no component subdirectory
        subdirs = File.join("caruso", marketplace_name, plugin_name)
        output_dir = File.join(".cursor", "commands", subdirs)

        FileUtils.mkdir_p(output_dir)
        target_path = File.join(output_dir, output_filename)

        File.write(target_path, content)
        puts "Saved command: #{target_path}"

        # Return relative path for tracking
        File.join(".cursor/commands", subdirs, output_filename)
      end
    end
  end
end
