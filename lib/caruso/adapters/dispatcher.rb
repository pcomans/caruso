# frozen_string_literal: true

require_relative "markdown_adapter"
require_relative "skill_adapter"
require_relative "command_adapter"
require_relative "hook_adapter"

module Caruso
  module Adapters
    class Dispatcher
      class << self
        def adapt(files, target_dir:, marketplace_name:, plugin_name:, agent: :cursor)
          ctx = { target_dir: target_dir, marketplace_name: marketplace_name, plugin_name: plugin_name, agent: agent }
          remaining = files.dup
          created = []

          created.concat(process_skills(remaining, ctx))
          created.concat(process_commands(remaining, ctx))

          hook_result = process_hooks(remaining, ctx)
          created.concat(hook_result[:created])

          skip_agents(remaining)
          warn_unprocessed(remaining)

          { files: created, hooks: hook_result[:hooks] }
        end

        private

        def process_skills(remaining, ctx)
          created = []
          skill_anchors = remaining.select { |f| File.basename(f).casecmp("skill.md").zero? }

          skill_anchors.each do |anchor|
            skill_dir = File.dirname(anchor)
            skill_cluster = remaining.select { |f| f.start_with?(skill_dir) }

            adapter = SkillAdapter.new(skill_cluster, **ctx)
            created.concat(adapter.adapt)
            remaining.delete_if { |f| skill_cluster.include?(f) }
          end

          created
        end

        def process_commands(remaining, ctx)
          commands = remaining.select { |f| f.include?("/commands/") }
          return [] unless commands.any?

          adapter = CommandAdapter.new(commands, **ctx)
          remaining.delete_if { |f| commands.include?(f) }
          adapter.adapt
        end

        def process_hooks(remaining, ctx)
          hooks_files = remaining.select { |f| File.basename(f) =~ /hooks\.json\z/ }
          return { created: [], hooks: {} } unless hooks_files.any?

          adapter = HookAdapter.new(hooks_files, **ctx)
          created = adapter.adapt
          remaining.delete_if { |f| hooks_files.include?(f) }
          { created: created, hooks: adapter.translated_hooks }
        end

        def skip_agents(remaining)
          agents = remaining.select { |f| f.include?("/agents/") }
          return unless agents.any?

          puts "Skipping #{agents.size} agent(s): Agents require context isolation not available in Cursor"
          remaining.delete_if { |f| agents.include?(f) }
        end

        def warn_unprocessed(remaining)
          return unless remaining.any?

          puts "Warning: #{remaining.size} file(s) could not be categorized and were skipped:"
          remaining.each { |f| puts "  - #{f}" }
        end
      end
    end
  end
end
