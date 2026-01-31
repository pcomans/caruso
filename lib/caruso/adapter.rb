# frozen_string_literal: true

require_relative "adapters/dispatcher"

module Caruso
  class Adapter
    # Hook commands installed by this adapter, keyed by Cursor event name.
    # Populated after adapt() is called. Used for tracking during install.
    attr_reader :installed_hooks

    # Preserving the interface for CLI compatibility
    def initialize(files, target_dir:, marketplace_name:, plugin_name:, agent: :cursor)
      @files = files
      @target_dir = target_dir
      @marketplace_name = marketplace_name
      @plugin_name = plugin_name
      @agent = agent
      @installed_hooks = {}
    end

    def adapt
      result = Caruso::Adapters::Dispatcher.adapt(
        @files,
        target_dir: @target_dir,
        marketplace_name: @marketplace_name,
        plugin_name: @plugin_name,
        agent: @agent
      )
      @installed_hooks = result.is_a?(Hash) ? (result[:hooks] || {}) : {}
      result.is_a?(Hash) ? result[:files] : result
    end
  end
end
