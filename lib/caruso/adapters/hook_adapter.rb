# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "base"

module Caruso
  module Adapters
    class HookAdapter < Base
      # CC events map to Cursor events; matchers are lost (Cursor has no matcher concept).
      EVENT_MAP = {
        "PreToolUse" => "beforeShellExecution",
        "PostToolUse" => "afterShellExecution",
        "UserPromptSubmit" => "beforeSubmitPrompt",
        "Stop" => "stop",
        "SessionStart" => "sessionStart",
        "SessionEnd" => "sessionEnd",
        "SubagentStop" => "subagentStop",
        "PreCompact" => "preCompact"
      }.freeze

      # PostToolUse with Write|Edit matchers maps to afterFileEdit instead.
      FILE_EDIT_MATCHERS = /\A(Write|Edit|Write\|Edit|Edit\|Write|Notebook.*)\z/i

      # Events with no Cursor equivalent.
      UNSUPPORTED_EVENTS = %w[
        Notification
        PermissionRequest
      ].freeze

      # Cursor stop events need output format translation and loop_limit.
      STOP_EVENTS = %w[stop subagentStop].freeze

      WRAPPER_PATH = File.join(".cursor", "hooks", "caruso", "_cc_stop_wrapper.sh").freeze

      # Translates Claude Code stop hook output to Cursor format.
      # CC: {"decision":"block","reason":"..."} or exit 2 with stderr
      # Cursor: {"followup_message":"..."}
      CC_STOP_WRAPPER = <<~'BASH'
        #!/bin/bash
        set -uo pipefail
        SCRIPT="$1"
        shift
        STDERR_TMP=$(mktemp) || exit 1
        trap 'rm -f "$STDERR_TMP"' EXIT
        OUTPUT=$("$SCRIPT" "$@" 2>"$STDERR_TMP")
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 2 ]; then
          REASON=$(cat "$STDERR_TMP")
          if [ -n "$REASON" ] && command -v jq >/dev/null 2>&1; then
            jq -n --arg msg "$REASON" '{"followup_message": $msg}'
          fi
          exit 0
        fi
        if [ $EXIT_CODE -eq 0 ] && [ -n "$OUTPUT" ] && command -v jq >/dev/null 2>&1; then
          DECISION=$(echo "$OUTPUT" | jq -r '.decision // empty' 2>/dev/null)
          if [ "$DECISION" = "block" ]; then
            REASON=$(echo "$OUTPUT" | jq -r '.reason // empty' 2>/dev/null)
            [ -n "$REASON" ] && jq -n --arg msg "$REASON" '{"followup_message": $msg}'
            exit 0
          fi
        fi
        [ -n "$OUTPUT" ] && echo "$OUTPUT"
        exit $EXIT_CODE
      BASH

      # Contains translated hook commands keyed by event (for clean uninstall tracking).
      attr_reader :translated_hooks

      def adapt
        @translated_hooks = {}

        hooks_file = find_hooks_file
        return [] unless hooks_file

        plugin_hooks = parse_hooks_file(hooks_file)
        return [] if plugin_hooks.nil? || plugin_hooks.empty?

        cursor_hooks = translate_hooks(plugin_hooks)
        return [] if cursor_hooks.empty?

        # Copy any referenced scripts
        copied_scripts = copy_hook_scripts(cursor_hooks, hooks_file)

        # Wrap stop hook commands for Cursor compatibility (CC→Cursor output translation)
        wrapper_scripts = wrap_stop_hooks(cursor_hooks)

        # Merge into existing .cursor/hooks.json
        merge_hooks(cursor_hooks)

        # Store for tracking
        @translated_hooks = cursor_hooks

        # Return list of created/modified files for tracking
        created = [".cursor/hooks.json"]
        created += copied_scripts
        created += wrapper_scripts
        created
      end

      private

      def find_hooks_file
        files.find { |f| File.basename(f) =~ /hooks\.json\z/ }
      end

      def parse_hooks_file(hooks_file)
        content = SafeFile.read(hooks_file)
        data = JSON.parse(content)
        data["hooks"]
      rescue JSON::ParserError => e
        puts "Warning: Could not parse hooks.json: #{e.message}"
        nil
      end

      def translate_hooks(plugin_hooks)
        cursor_hooks = {}
        skipped_events = []
        skipped_prompts = 0

        plugin_hooks.each do |event_name, matchers|
          if UNSUPPORTED_EVENTS.include?(event_name)
            skipped_events << event_name
            next
          end

          result = translate_event_hooks(event_name, matchers)
          result[:hooks].each { |event, entries| (cursor_hooks[event] ||= []).concat(entries) }
          skipped_prompts += result[:skipped_prompts]
        end

        warn_skipped(skipped_events, skipped_prompts)
        cursor_hooks
      end

      def translate_event_hooks(event_name, matchers)
        hooks = {}
        skipped = 0

        matchers.each do |matcher_entry|
          matcher = matcher_entry["matcher"]
          (matcher_entry["hooks"] || []).each do |hook|
            if hook["type"] == "prompt"
              skipped += 1
              next
            end

            command = hook["command"]
            next unless command

            cursor_event = resolve_cursor_event(event_name, matcher)
            cursor_hook = { "command" => command }
            cursor_hook["timeout"] = hook["timeout"] if hook["timeout"]
            cursor_hook["loop_limit"] = nil if STOP_EVENTS.include?(cursor_event)
            (hooks[cursor_event] ||= []) << cursor_hook
          end
        end

        { hooks: hooks, skipped_prompts: skipped }
      end

      def warn_skipped(skipped_events, skipped_prompts)
        if skipped_events.any?
          unique_skipped = skipped_events.uniq
          puts "Skipping #{unique_skipped.size} unsupported hook event(s): #{unique_skipped.join(', ')}"
          puts "  (Cursor has no equivalent for these Claude Code lifecycle events)"
        end

        return unless skipped_prompts.positive?

        puts "Skipping #{skipped_prompts} prompt-based hook(s): Cursor does not support LLM evaluation in hooks"
      end

      def resolve_cursor_event(cc_event, matcher)
        # PostToolUse with file-related matchers maps to afterFileEdit
        if cc_event == "PostToolUse" && matcher && FILE_EDIT_MATCHERS.match?(matcher)
          return "afterFileEdit"
        end

        EVENT_MAP[cc_event] || "afterShellExecution"
      end

      def rewrite_script_path(command)
        plugin_script_dir = File.join(".cursor", "hooks", "caruso", marketplace_name, plugin_name)
        command.gsub("${CLAUDE_PLUGIN_ROOT}", plugin_script_dir)
      end

      def plugin_root_from_hooks_file(hooks_file)
        # Plugin root is parent of hooks/ dir (hooks.json is at <plugin_root>/hooks/hooks.json)
        hooks_dir = File.dirname(hooks_file)
        if File.basename(hooks_dir) == "hooks"
          File.dirname(hooks_dir)
        else
          hooks_dir
        end
      end

      def copy_hook_scripts(cursor_hooks, hooks_file)
        plugin_root = plugin_root_from_hooks_file(hooks_file)

        cursor_hooks.each_value.flat_map do |hook_entries|
          hook_entries.filter_map { |hook| copy_single_script(hook, plugin_root) }
        end
      end

      def copy_single_script(hook, plugin_root)
        command = hook["command"]
        return unless command&.include?("${CLAUDE_PLUGIN_ROOT}")

        # Extract path after placeholder (handles "python3 ${CLAUDE_PLUGIN_ROOT}/script.py")
        match = command.match(%r{\$\{CLAUDE_PLUGIN_ROOT\}/([^\s]+)})
        return unless match

        relative_path = match[1]
        source_path = File.join(plugin_root, relative_path)
        return unless File.exist?(source_path)

        target_path = File.join(".cursor", "hooks", "caruso", marketplace_name, plugin_name, relative_path)
        FileUtils.mkdir_p(File.dirname(target_path))
        FileUtils.cp(source_path, target_path)
        File.chmod(0o755, target_path)
        puts "Copied hook script: #{target_path}"

        hook["command"] = rewrite_script_path(command)
        target_path
      end

      def wrap_stop_hooks(cursor_hooks)
        has_stop = STOP_EVENTS.any? { |event| cursor_hooks.key?(event) }
        return [] unless has_stop

        wrapper_path = install_wrapper_script

        STOP_EVENTS.each do |event|
          next unless cursor_hooks[event]

          cursor_hooks[event].each do |hook|
            hook["command"] = "#{WRAPPER_PATH} #{hook['command']}"
          end
        end

        [wrapper_path]
      end

      def install_wrapper_script
        FileUtils.mkdir_p(File.dirname(WRAPPER_PATH))
        File.write(WRAPPER_PATH, CC_STOP_WRAPPER)
        File.chmod(0o755, WRAPPER_PATH)
        puts "Installed stop hook wrapper: #{WRAPPER_PATH}"
        WRAPPER_PATH
      end

      def merge_hooks(new_hooks)
        hooks_path = File.join(".cursor", "hooks.json")
        existing = read_existing_hooks(hooks_path)

        # Merge: append new hook entries to existing event arrays
        new_hooks.each do |event, entries|
          existing[event] ||= []
          entries.each do |entry|
            # Deduplicate: don't add if an identical command already exists
            unless existing[event].any? { |e| e["command"] == entry["command"] }
              existing[event] << entry
            end
          end
        end

        FileUtils.mkdir_p(".cursor")
        File.write(hooks_path, JSON.pretty_generate({ "version" => 1, "hooks" => existing }))
        puts "Merged hooks into #{hooks_path}"
      end

      def read_existing_hooks(hooks_path)
        return {} unless File.exist?(hooks_path)

        data = JSON.parse(File.read(hooks_path))
        data["hooks"] || {}
      rescue JSON::ParserError
        puts "Warning: Existing hooks.json is malformed, starting fresh"
        {}
      end
    end
  end
end
