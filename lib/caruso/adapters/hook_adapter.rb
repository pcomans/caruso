# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "base"

module Caruso
  module Adapters
    class HookAdapter < Base
      # Claude Code events that map to Cursor events.
      # Each CC event maps to a single Cursor event name.
      # Matchers are lost in translation (Cursor has no matcher concept).
      EVENT_MAP = {
        "PreToolUse" => "beforeShellExecution",
        "PostToolUse" => "afterShellExecution",
        "UserPromptSubmit" => "beforeSubmitPrompt",
        "Stop" => "stop"
      }.freeze

      # PostToolUse with Write|Edit matchers should map to afterFileEdit instead.
      # We detect this via the matcher pattern.
      FILE_EDIT_MATCHERS = /\A(Write|Edit|Write\|Edit|Edit\|Write|Notebook.*)\z/i.freeze

      # Events that have no Cursor equivalent and must be skipped.
      UNSUPPORTED_EVENTS = %w[
        SessionStart
        SessionEnd
        SubagentStop
        PreCompact
        Notification
        PermissionRequest
      ].freeze

      # After adapt(), contains the translated hook commands keyed by event.
      # Used by callers to track which hooks were installed for clean uninstall.
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

        # Merge into existing .cursor/hooks.json
        merge_hooks(cursor_hooks)

        # Store for tracking
        @translated_hooks = cursor_hooks

        # Return list of created/modified files for tracking
        created = [".cursor/hooks.json"]
        created += copied_scripts
        created
      end

      private

      def find_hooks_file
        # files array contains the hooks.json path passed in by the Dispatcher.
        # Also matches .caruso_inline_hooks.json written by Fetcher for inline plugin.json hooks.
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

          matchers.each do |matcher_entry|
            hooks_array = matcher_entry["hooks"] || []
            matcher = matcher_entry["matcher"]

            hooks_array.each do |hook|
              # Skip prompt-based hooks (Cursor doesn't support LLM evaluation in hooks)
              if hook["type"] == "prompt"
                skipped_prompts += 1
                next
              end

              command = hook["command"]
              next unless command

              cursor_event = resolve_cursor_event(event_name, matcher)
              cursor_hook = { "command" => command }
              cursor_hook["timeout"] = hook["timeout"] if hook["timeout"]

              cursor_hooks[cursor_event] ||= []
              cursor_hooks[cursor_event] << cursor_hook
            end
          end
        end

        # Warn about skipped items
        if skipped_events.any?
          unique_skipped = skipped_events.uniq
          puts "Skipping #{unique_skipped.size} unsupported hook event(s): #{unique_skipped.join(", ")}"
          puts "  (Cursor has no equivalent for these Claude Code lifecycle events)"
        end

        if skipped_prompts > 0
          puts "Skipping #{skipped_prompts} prompt-based hook(s): Cursor does not support LLM evaluation in hooks"
        end

        cursor_hooks
      end

      def resolve_cursor_event(cc_event, matcher)
        # PostToolUse with file-related matchers maps to afterFileEdit
        if cc_event == "PostToolUse" && matcher && FILE_EDIT_MATCHERS.match?(matcher)
          return "afterFileEdit"
        end

        EVENT_MAP[cc_event] || "afterShellExecution"
      end

      def rewrite_script_path(command, hooks_file)
        # Replace ${CLAUDE_PLUGIN_ROOT} with path relative to .cursor/hooks.json
        # Plugin scripts land in .cursor/hooks/caruso/<marketplace>/<plugin>/
        plugin_script_dir = File.join("hooks", "caruso", marketplace_name, plugin_name)

        command.gsub("${CLAUDE_PLUGIN_ROOT}", plugin_script_dir)
      end

      def plugin_root_from_hooks_file(hooks_file)
        # ${CLAUDE_PLUGIN_ROOT} refers to the plugin root directory.
        # hooks.json is typically at <plugin_root>/hooks/hooks.json,
        # so the plugin root is the parent of the hooks/ directory.
        hooks_dir = File.dirname(hooks_file)
        if File.basename(hooks_dir) == "hooks"
          File.dirname(hooks_dir)
        else
          hooks_dir
        end
      end

      def copy_hook_scripts(cursor_hooks, hooks_file)
        plugin_root = plugin_root_from_hooks_file(hooks_file)
        copied = []

        cursor_hooks.each_value do |hook_entries|
          hook_entries.each do |hook|
            command = hook["command"]
            next unless command&.include?("${CLAUDE_PLUGIN_ROOT}")

            # Extract the relative path after ${CLAUDE_PLUGIN_ROOT}
            relative_path = command.sub("${CLAUDE_PLUGIN_ROOT}/", "")
            source_path = File.join(plugin_root, relative_path)
            next unless File.exist?(source_path)

            # Target: .cursor/hooks/caruso/<marketplace>/<plugin>/<relative_path>
            target_path = File.join(
              ".cursor", "hooks", "caruso", marketplace_name, plugin_name, relative_path
            )

            FileUtils.mkdir_p(File.dirname(target_path))
            FileUtils.cp(source_path, target_path)
            File.chmod(0o755, target_path)
            puts "Copied hook script: #{target_path}"

            # Rewrite the command in-place to use the new relative path
            hook["command"] = rewrite_script_path(command, hooks_file)
            copied << target_path
          end
        end

        copied
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
