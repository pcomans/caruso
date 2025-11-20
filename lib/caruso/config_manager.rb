# frozen_string_literal: true

require "json"
require "fileutils"

module Caruso
  class ConfigManager
    CONFIG_FILENAME = ".caruso.json"
    SUPPORTED_IDES = ["cursor"].freeze
    IDE_TARGET_DIRS = {
      "cursor" => ".cursor/rules"
    }.freeze

    attr_reader :project_dir, :config_path

    def initialize(project_dir = Dir.pwd)
      @project_dir = File.expand_path(project_dir)
      @config_path = File.join(@project_dir, CONFIG_FILENAME)
    end

    def init(ide:)
      unless SUPPORTED_IDES.include?(ide)
        raise ArgumentError, "Unsupported IDE: #{ide}. Supported: #{SUPPORTED_IDES.join(', ')}"
      end

      if config_exists?
        raise Error, "Caruso is already initialized in #{@project_dir}. Config exists at #{@config_path}"
      end

      config = {
        "ide" => ide,
        "target_dir" => IDE_TARGET_DIRS[ide],
        "initialized_at" => Time.now.iso8601,
        "version" => "1.0.0"
      }

      save_config(config)
      config
    end

    def load
      unless config_exists?
        raise Error, "Caruso not initialized. Run 'caruso init --ide=cursor' first."
      end

      JSON.parse(File.read(@config_path))
    rescue JSON::ParserError => e
      raise Error, "Invalid config file at #{@config_path}: #{e.message}"
    end

    def config_exists?
      File.exist?(@config_path)
    end

    def target_dir
      load["target_dir"]
    end

    def full_target_path
      File.join(@project_dir, target_dir)
    end

    def ide
      load["ide"]
    end

    private

    def save_config(data)
      File.write(@config_path, JSON.pretty_generate(data))
    end
  end
end
