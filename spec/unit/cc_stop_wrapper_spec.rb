# frozen_string_literal: true

require "spec_helper"
require "open3"
require "json"
require "tmpdir"

# Integration tests that execute the actual bash wrapper script against mock CC hooks.
# Verifies the bash implementation matches StopHookTranslator behavior.
RSpec.describe "cc_stop_wrapper.sh" do
  let(:wrapper) { File.expand_path("../../lib/caruso/scripts/cc_stop_wrapper.sh", __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      example.run
    end
  end

  def write_mock_hook(name, content)
    path = File.join(@tmpdir, name)
    File.write(path, content)
    File.chmod(0o755, path)
    path
  end

  def run_wrapper(hook_path)
    stdout, stderr, status = Open3.capture3(wrapper, hook_path)
    { stdout: stdout.strip, stderr: stderr.strip, exit_code: status.exitstatus }
  end

  context "CC hook exits 2 with stderr (block)" do
    it "translates stderr to Cursor followup_message" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        echo "Keep going, tests are failing" >&2
        exit 2
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      parsed = JSON.parse(result[:stdout])
      expect(parsed["followup_message"]).to eq("Keep going, tests are failing")
    end

    it "returns empty output when stderr is empty" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        exit 2
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      expect(result[:stdout]).to eq("")
    end
  end

  context "CC hook exits 0 with decision=block JSON" do
    it "translates to Cursor followup_message" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        echo '{"decision":"block","reason":"Not done yet"}'
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      parsed = JSON.parse(result[:stdout])
      expect(parsed["followup_message"]).to eq("Not done yet")
    end

    it "returns empty output when reason is missing" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        echo '{"decision":"block"}'
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      expect(result[:stdout]).to eq("")
    end
  end

  context "CC hook exits 0 with no blocking decision" do
    it "passes through non-decision JSON" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        echo '{"some":"data"}'
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      expect(result[:stdout]).to eq('{"some":"data"}')
    end

    it "passes through plain text" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        echo "all good"
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      expect(result[:stdout]).to eq("all good")
    end

    it "passes through empty output" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        exit 0
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(0)
      expect(result[:stdout]).to eq("")
    end
  end

  context "CC hook exits with other codes" do
    it "passes through exit code 1" do
      hook = write_mock_hook("hook.sh", <<~SH)
        #!/bin/bash
        echo "error output"
        exit 1
      SH

      result = run_wrapper(hook)

      expect(result[:exit_code]).to eq(1)
      expect(result[:stdout]).to eq("error output")
    end
  end
end
