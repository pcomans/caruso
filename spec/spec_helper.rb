# frozen_string_literal: true

require "bundler/setup"
require "caruso"
require "fileutils"
require "json"
require "tmpdir"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Helper method to create isolated test directories
  config.around(:each) do |example|
    Dir.mktmpdir("caruso-test-") do |dir|
      @test_dir = dir
      Dir.chdir(dir) do
        example.run
      end
    end
  end

  # Helper methods available in all specs
  config.include(Module.new do
    def test_dir
      @test_dir
    end

    def run_caruso(*args)
      # Run caruso command and capture output
      cmd = "caruso #{args.join(' ')}"
      output = `#{cmd} 2>&1`
      { output: output, exit_code: $?.exitstatus }
    end

    def config_file
      File.join(test_dir, ".caruso.json")
    end

    def manifest_file
      File.join(test_dir, ".cursor", "rules", "caruso.json")
    end

    def load_config
      JSON.parse(File.read(config_file))
    end

    def load_manifest
      JSON.parse(File.read(manifest_file))
    end

    def mdc_files
      Dir.glob(File.join(test_dir, ".cursor", "rules", "*.mdc"))
    end

    def init_caruso(ide: "cursor")
      result = run_caruso("init --ide=#{ide}")
      expect(result[:exit_code]).to eq(0), "Init failed: #{result[:output]}"
    end

    def add_marketplace(url, name = nil)
      cmd = name ? "marketplace add #{url} #{name}" : "marketplace add #{url}"
      result = run_caruso(cmd)
      expect(result[:exit_code]).to eq(0), "Add marketplace failed: #{result[:output]}"
    end
  end)
end
