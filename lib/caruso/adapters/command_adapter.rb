# frozen_string_literal: true

require_relative "base"

module Caruso
  module Adapters
    class CommandAdapter < Base
      def adapt
        created_files = []
        files.each do |file_path|
          content = SafeFile.read(file_path)
          rewritten_content, copied_scripts = copy_command_scripts_and_rewrite_paths(content, file_path)
          adapted_content = adapt_command_content(rewritten_content, file_path)

          # Commands are flat .md files in .cursor/commands/
          # NOT nested like rules, so we override the save behavior
          created_file = save_command_file(file_path, adapted_content)

          created_files << created_file
          created_files.concat(copied_scripts)
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
        if content.include?("`!")
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

      def copy_command_scripts_and_rewrite_paths(content, command_file)
        command_root = File.join(".cursor", "commands", "caruso", marketplace_name, plugin_name)

        copied_scripts = extract_plugin_script_paths(content).filter_map do |relative_path|
          copy_script(relative_path, command_file, command_root)
        end

        rewritten_content = content.gsub("${CLAUDE_PLUGIN_ROOT}", command_root)
        [rewritten_content, copied_scripts]
      end

      def extract_plugin_script_paths(content)
        content.scan(%r{\$\{CLAUDE_PLUGIN_ROOT\}/([A-Za-z0-9._\-/]+)}).flatten.uniq
      end

      def copy_script(relative_path, command_file, command_root)
        source_path = locate_script_source(relative_path, command_file)
        unless source_path
          puts "Warning: Referenced command script not found for #{command_file}: #{relative_path}"
          return nil
        end

        target_path = File.join(command_root, relative_path)
        FileUtils.mkdir_p(File.dirname(target_path))
        FileUtils.cp(source_path, target_path)
        File.chmod(0o755, target_path)
        puts "Copied command script: #{target_path}"

        target_path
      end

      def locate_script_source(relative_path, command_file)
        current_dir = File.dirname(command_file)

        loop do
          candidate = File.join(current_dir, relative_path)
          return candidate if File.exist?(candidate)

          parent_dir = File.dirname(current_dir)
          break if parent_dir == current_dir

          current_dir = parent_dir
        end

        nil
      end
    end
  end
end
