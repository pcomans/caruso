# frozen_string_literal: true

require "spec_helper"
require "caruso/adapters/command_adapter"
require "tmpdir"

RSpec.describe Caruso::Adapters::CommandAdapter do
  let(:marketplace_name) { "test-marketplace" }
  let(:plugin_name) { "test-plugin" }

  around do |example|
    Dir.mktmpdir do |dir|
      original_dir = Dir.pwd
      Dir.chdir(dir)
      example.run
      Dir.chdir(original_dir)
    end
  end

  def build_adapter(command_file)
    described_class.new(
      [command_file],
      target_dir: ".cursor/rules",
      marketplace_name: marketplace_name,
      plugin_name: plugin_name,
      agent: :cursor
    )
  end

  def write_command_and_script(command_dir: "commands", script_dir: "scripts")
    plugin_root = File.join(Dir.pwd, "plugin")
    command_file = File.join(plugin_root, command_dir, "ralph-loop.md")
    script_file = File.join(plugin_root, script_dir, "setup-ralph-loop.sh")

    FileUtils.mkdir_p(File.dirname(command_file))
    FileUtils.mkdir_p(File.dirname(script_file))
    File.write(script_file, "#!/usr/bin/env bash\necho ready\n")

    File.write(command_file, <<~MD)
      ---
      allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
      ---

      ```!
      "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" remove EarlyPay::CardsService and make tests pass
      ```
    MD

    command_file
  end

  it "copies scripts referenced via ${CLAUDE_PLUGIN_ROOT} and rewrites command paths" do
    command_file = write_command_and_script

    created = build_adapter(command_file).adapt

    expect(created).to include(".cursor/commands/caruso/test-marketplace/test-plugin/ralph-loop.md")
    expect(created).to include(".cursor/commands/caruso/test-marketplace/test-plugin/scripts/setup-ralph-loop.sh")

    installed_command = File.read(".cursor/commands/caruso/test-marketplace/test-plugin/ralph-loop.md")
    expect(installed_command).not_to include("${CLAUDE_PLUGIN_ROOT}")
    expect(installed_command).to include(".cursor/commands/caruso/test-marketplace/test-plugin/scripts/setup-ralph-loop.sh")
    expect(File.exist?(".cursor/commands/caruso/test-marketplace/test-plugin/scripts/setup-ralph-loop.sh")).to be true
  end

  it "finds scripts when command markdown is in a custom nested path" do
    command_file = write_command_and_script(command_dir: "custom/deep/commands")

    build_adapter(command_file).adapt

    installed_command = File.read(".cursor/commands/caruso/test-marketplace/test-plugin/ralph-loop.md")
    expect(installed_command).to include(".cursor/commands/caruso/test-marketplace/test-plugin/scripts/setup-ralph-loop.sh")
    expect(File.exist?(".cursor/commands/caruso/test-marketplace/test-plugin/scripts/setup-ralph-loop.sh")).to be true
  end
end
