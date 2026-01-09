# frozen_string_literal: true

require_relative "adapters/dispatcher"

module Caruso
  class Adapter
    # Preserving the interface for CLI compatibility
    def initialize(files, target_dir:, marketplace_name:, plugin_name:, agent: :cursor)
      @files = files
      @target_dir = target_dir
      @marketplace_name = marketplace_name
      @plugin_name = plugin_name
      @agent = agent
    end

    def adapt
      Caruso::Adapters::Dispatcher.adapt(
        @files,
        target_dir: @target_dir,
        marketplace_name: @marketplace_name,
        plugin_name: @plugin_name,
        agent: @agent
      )
    end
  end
end
