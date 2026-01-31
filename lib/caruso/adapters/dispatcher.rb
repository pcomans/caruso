# frozen_string_literal: true

require_relative "markdown_adapter"
require_relative "skill_adapter"
require_relative "command_adapter"
require_relative "hook_adapter"

module Caruso
  module Adapters
    class Dispatcher
      def self.adapt(files, target_dir:, marketplace_name:, plugin_name:, agent: :cursor)
        created_files = []
        remaining_files = files.dup

        # 1. Identify and Process Skill Clusters
        # Find all SKILL.md files to serve as anchors
        skill_anchors = remaining_files.select { |f| File.basename(f).casecmp("skill.md").zero? }

        skill_anchors.each do |anchor|
          skill_dir = File.dirname(anchor)

          # Find all files that belong to this skill's directory (recursive)
          skill_cluster = remaining_files.select { |f| f.start_with?(skill_dir) }

          # Use SkillAdapter for this cluster
          adapter = SkillAdapter.new(
            skill_cluster,
            target_dir: target_dir,
            marketplace_name: marketplace_name,
            plugin_name: plugin_name,
            agent: agent
          )
          created_files.concat(adapter.adapt)

          # Remove processed files
          remaining_files -= skill_cluster
        end

        # 2. Identify and Process Commands
        commands = remaining_files.select { |f| f.include?("/commands/") }

        if commands.any?
          adapter = CommandAdapter.new(
            commands,
            target_dir: target_dir, # Not used by CommandAdapter, but required by base
            marketplace_name: marketplace_name,
            plugin_name: plugin_name,
            agent: agent
          )
          created_files.concat(adapter.adapt)
          remaining_files -= commands
        end

        # 3. Identify and Process Hooks
        installed_hooks = {}
        hooks_files = remaining_files.select { |f| File.basename(f) =~ /hooks\.json\z/ }

        if hooks_files.any?
          adapter = HookAdapter.new(
            hooks_files,
            target_dir: target_dir,
            marketplace_name: marketplace_name,
            plugin_name: plugin_name,
            agent: agent
          )
          created_files.concat(adapter.adapt)
          installed_hooks = adapter.translated_hooks
          remaining_files -= hooks_files
        end

        # 4. Skip Agents Entirely
        # Agents cannot be properly represented in Cursor (no context isolation)
        agents = remaining_files.select { |f| f.include?("/agents/") }

        if agents.any?
          puts "Skipping #{agents.size} agent(s): Agents require context isolation not available in Cursor"
          remaining_files -= agents
        end

        # 5. Warn About Remaining Unprocessed Files
        if remaining_files.any?
          puts "Warning: #{remaining_files.size} file(s) could not be categorized and were skipped:"
          remaining_files.each { |f| puts "  - #{f}" }
        end

        { files: created_files, hooks: installed_hooks }
      end
    end
  end
end
