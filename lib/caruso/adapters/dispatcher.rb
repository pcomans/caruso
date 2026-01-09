# frozen_string_literal: true

require_relative "markdown_adapter"
require_relative "skill_adapter"

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

        # 2. Process Remaining Files (Commands, Agents, etc.) via MarkdownAdapter
        if remaining_files.any?
          adapter = MarkdownAdapter.new(
            remaining_files,
            target_dir: target_dir,
            marketplace_name: marketplace_name,
            plugin_name: plugin_name,
            agent: agent
          )
          created_files.concat(adapter.adapt)
        end

        created_files
      end
    end
  end
end
