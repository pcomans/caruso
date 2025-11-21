# frozen_string_literal: true

require "bundler/setup"
require "caruso"
require "fileutils"
require "json"
require "aruba/rspec"
require "timecop"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset Timecop after each test
  config.after(:each) do
    Timecop.return
  end

  # Include Aruba for integration tests
  config.include Aruba::Api, type: :integration

  # Helper methods available in all specs
  config.include(Module.new do
    def config_file
      File.join(aruba.current_directory, ".caruso.json")
    end

    def manifest_file
      File.join(aruba.current_directory, ".cursor", "rules", "caruso.json")
    end

    def load_config
      JSON.parse(File.read(config_file))
    end

    def load_manifest
      JSON.parse(File.read(manifest_file))
    end

    def mdc_files
      Dir.glob(File.join(aruba.current_directory, ".cursor", "rules", "*.mdc"))
    end

    def init_caruso(ide: "cursor")
      run_command("caruso init --ide=#{ide}")
      expect(last_command_started).to be_successfully_executed
    end

    def add_marketplace(url, name = nil)
      cmd = name ? "marketplace add #{url} #{name}" : "marketplace add #{url}"
      run_command("caruso #{cmd}")
      expect(last_command_started).to be_successfully_executed
    end
  end)
end

# Configure Aruba
Aruba.configure do |config|
  # Set command timeout (default is 3 seconds, increase if needed)
  config.exit_timeout = 10
  config.io_wait_timeout = 5
end
