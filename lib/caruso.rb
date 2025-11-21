# frozen_string_literal: true

require_relative "caruso/version"
require_relative "caruso/config_manager"
require_relative "caruso/fetcher"
require_relative "caruso/adapter"
require_relative "caruso/manifest_manager"
require_relative "caruso/cli"

module Caruso
  class Error < StandardError; end
  
  class PluginNotFoundError < Error
    attr_reader :available_plugins
    
    def initialize(message, available_plugins = [])
      super(message)
      @available_plugins = available_plugins
    end
  end
end
