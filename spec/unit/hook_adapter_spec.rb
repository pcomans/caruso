# frozen_string_literal: true

require "spec_helper"
require "caruso/adapters/hook_adapter"
require "tmpdir"
require "json"

RSpec.describe Caruso::Adapters::HookAdapter do
  let(:marketplace_name) { "test-marketplace" }
  let(:plugin_name) { "test-plugin" }

  # Create a temp dir to simulate a plugin with hooks.json and scripts
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @plugin_dir = dir
      @original_dir = Dir.pwd
      Dir.chdir(dir)
      example.run
      Dir.chdir(@original_dir)
    end
  end

  def write_hooks_json(hooks_data)
    hooks_file = File.join(@plugin_dir, "hooks.json")
    File.write(hooks_file, JSON.pretty_generate(hooks_data))
    hooks_file
  end

  def write_script(relative_path, content = "#!/bin/bash\nexit 0\n")
    full_path = File.join(@plugin_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    File.chmod(0o755, full_path)
    full_path
  end

  def build_adapter(hooks_file)
    Caruso::Adapters::HookAdapter.new(
      [hooks_file],
      target_dir: ".cursor/rules",
      marketplace_name: marketplace_name,
      plugin_name: plugin_name,
      agent: :cursor
    )
  end

  def read_cursor_hooks
    hooks_path = File.join(".cursor", "hooks.json")
    return nil unless File.exist?(hooks_path)

    JSON.parse(File.read(hooks_path))
  end

  describe "#adapt" do
    context "with no hooks.json in the file list" do
      it "returns empty and creates nothing" do
        adapter = Caruso::Adapters::HookAdapter.new(
          ["some/other/file.md"],
          target_dir: ".cursor/rules",
          marketplace_name: marketplace_name,
          plugin_name: plugin_name
        )
        expect(adapter.adapt).to eq([])
        expect(File.exist?(".cursor/hooks.json")).to be false
      end
    end

    context "with an empty hooks object" do
      it "returns empty" do
        hooks_file = write_hooks_json({ "hooks" => {} })
        adapter = build_adapter(hooks_file)
        expect(adapter.adapt).to eq([])
      end
    end

    describe "event translation" do
      it "translates PreToolUse to beforeShellExecution" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PreToolUse" => [
                                            { "matcher" => "Bash", "hooks" => [{ "type" => "command", "command" => "echo pre" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["beforeShellExecution"]).to include(hash_including("command" => "echo pre"))
      end

      it "translates PostToolUse with Bash matcher to afterShellExecution" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            { "matcher" => "Bash", "hooks" => [{ "type" => "command", "command" => "echo post-bash" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["afterShellExecution"]).to include(hash_including("command" => "echo post-bash"))
      end

      it "translates PostToolUse with Write matcher to afterFileEdit" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            { "matcher" => "Write", "hooks" => [{ "type" => "command", "command" => "echo post-write" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["afterFileEdit"]).to include(hash_including("command" => "echo post-write"))
      end

      it "translates PostToolUse with Edit|Write matcher to afterFileEdit" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            { "matcher" => "Edit|Write", "hooks" => [{ "type" => "command", "command" => "echo format" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["afterFileEdit"]).to include(hash_including("command" => "echo format"))
      end

      it "translates UserPromptSubmit to beforeSubmitPrompt" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "UserPromptSubmit" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo validate" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["beforeSubmitPrompt"]).to include(hash_including("command" => "echo validate"))
      end

      it "translates Stop to stop" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo stopping" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["stop"]).to include(hash_including("command" => "echo stopping"))
      end
    end

    describe "unsupported event skipping" do
      it "skips SessionStart with warning" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "SessionStart" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo session" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        expect { adapter.adapt }.to output(/Skipping.*SessionStart/).to_stdout

        # No hooks.json created since all hooks were skipped
        expect(File.exist?(".cursor/hooks.json")).to be false
      end

      it "skips SessionEnd, SubagentStop, PreCompact, Notification, PermissionRequest" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "SessionEnd" => [{ "hooks" => [{ "type" => "command", "command" => "echo end" }] }],
                                          "SubagentStop" => [{ "hooks" => [{ "type" => "command", "command" => "echo sub" }] }],
                                          "PreCompact" => [{ "hooks" => [{ "type" => "command", "command" => "echo compact" }] }],
                                          "Notification" => [{ "hooks" => [{ "type" => "command", "command" => "echo notify" }] }],
                                          "PermissionRequest" => [{ "hooks" => [{ "type" => "command", "command" => "echo perm" }] }]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        output = capture_output { adapter.adapt }

        expect(output).to include("SessionEnd")
        expect(output).to include("SubagentStop")
        expect(output).to include("PreCompact")
        expect(output).to include("Notification")
        expect(output).to include("PermissionRequest")
      end
    end

    describe "prompt-based hook skipping" do
      it "skips type: prompt hooks with warning" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            { "hooks" => [{ "type" => "prompt", "prompt" => "Should I stop?" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        expect { adapter.adapt }.to output(/prompt-based/).to_stdout
      end

      it "keeps type: command hooks alongside skipped prompt hooks" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            {
                                              "hooks" => [
                                                { "type" => "prompt", "prompt" => "Should I stop?" },
                                                { "type" => "command", "command" => "echo check" }
                                              ]
                                            }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["stop"]).to include(hash_including("command" => "echo check"))
      end
    end

    describe "timeout preservation" do
      it "preserves timeout from Claude Code hooks" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            {
                                              "matcher" => "Write",
                                              "hooks" => [{ "type" => "command", "command" => "echo fmt", "timeout" => 30 }]
                                            }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        hook = result["hooks"]["afterFileEdit"].find { |h| h["command"] == "echo fmt" }
        expect(hook["timeout"]).to eq(30)
      end

      it "omits timeout when not specified" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo done" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        hook = result["hooks"]["stop"].first
        expect(hook).not_to have_key("timeout")
      end
    end

    describe "script copying and path rewriting" do
      it "copies scripts referenced by ${CLAUDE_PLUGIN_ROOT} and rewrites paths" do
        write_script("scripts/format.sh")
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            {
                                              "matcher" => "Write",
                                              "hooks" => [{ "type" => "command", "command" => "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh" }]
                                            }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        # Script should be copied
        expected_script = File.join(".cursor", "hooks", "caruso", marketplace_name, plugin_name, "scripts", "format.sh")
        expect(File.exist?(expected_script)).to be true
        expect(File.stat(expected_script).mode & 0o755).to eq(0o755)

        # Command should be rewritten
        result = read_cursor_hooks
        hook = result["hooks"]["afterFileEdit"].first
        expect(hook["command"]).to eq("hooks/caruso/#{marketplace_name}/#{plugin_name}/scripts/format.sh")
        expect(hook["command"]).not_to include("${CLAUDE_PLUGIN_ROOT}")
      end

      it "does not fail if referenced script does not exist" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            {
                                              "matcher" => "Write",
                                              "hooks" => [{ "type" => "command", "command" => "${CLAUDE_PLUGIN_ROOT}/scripts/missing.sh" }]
                                            }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        # Should not raise
        adapter.adapt

        # Command is NOT rewritten since script wasn't copied
        result = read_cursor_hooks
        hook = result["hooks"]["afterFileEdit"].first
        expect(hook["command"]).to include("${CLAUDE_PLUGIN_ROOT}")
      end

      it "does not copy non-plugin-root commands" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            {
                                              "matcher" => "Write",
                                              "hooks" => [{ "type" => "command", "command" => "/usr/local/bin/formatter" }]
                                            }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        hook = result["hooks"]["afterFileEdit"].first
        # Absolute system path is preserved as-is
        expect(hook["command"]).to eq("/usr/local/bin/formatter")
      end
    end

    describe "merge strategy" do
      it "merges with existing hooks.json without overwriting" do
        # Pre-populate .cursor/hooks.json with existing hooks
        FileUtils.mkdir_p(".cursor")
        existing = {
          "version" => 1,
          "hooks" => {
            "afterFileEdit" => [{ "command" => "./existing-hook.sh" }]
          }
        }
        File.write(".cursor/hooks.json", JSON.pretty_generate(existing))

        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            { "matcher" => "Write", "hooks" => [{ "type" => "command", "command" => "echo new" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        # Both existing and new hooks should be present
        expect(result["hooks"]["afterFileEdit"]).to include(hash_including("command" => "./existing-hook.sh"))
        expect(result["hooks"]["afterFileEdit"]).to include(hash_including("command" => "echo new"))
      end

      it "deduplicates identical commands" do
        # Pre-populate with the same command that the plugin will add
        FileUtils.mkdir_p(".cursor")
        existing = {
          "version" => 1,
          "hooks" => {
            "stop" => [{ "command" => "echo done" }]
          }
        }
        File.write(".cursor/hooks.json", JSON.pretty_generate(existing))

        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo done" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        # Should only have one entry, not duplicated
        expect(result["hooks"]["stop"].count { |h| h["command"] == "echo done" }).to eq(1)
      end

      it "writes version: 1 in output" do
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo done" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["version"]).to eq(1)
      end

      it "handles malformed existing hooks.json gracefully" do
        FileUtils.mkdir_p(".cursor")
        File.write(".cursor/hooks.json", "not valid json {{{")

        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "Stop" => [
                                            { "hooks" => [{ "type" => "command", "command" => "echo recovered" }] }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        adapter.adapt

        result = read_cursor_hooks
        expect(result["hooks"]["stop"]).to include(hash_including("command" => "echo recovered"))
      end
    end

    describe "return value" do
      it "returns .cursor/hooks.json and any copied scripts" do
        write_script("scripts/lint.sh")
        hooks_file = write_hooks_json({
                                        "hooks" => {
                                          "PostToolUse" => [
                                            {
                                              "matcher" => "Write",
                                              "hooks" => [{ "type" => "command", "command" => "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh" }]
                                            }
                                          ]
                                        }
                                      })
        adapter = build_adapter(hooks_file)
        result = adapter.adapt

        expect(result).to include(".cursor/hooks.json")
        expect(result.any? { |f| f.include?("lint.sh") }).to be true
      end
    end
  end

  private

  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
