# frozen_string_literal: true

require "json"
require "open3"

module Caruso
  # Translates Claude Code stop hook output to Cursor format.
  #
  # Claude Code stop hooks communicate via:
  #   - Exit 2 + stderr message        → block (continue the conversation)
  #   - Exit 0 + {"decision":"block","reason":"..."} → block
  #   - Exit 0 + no decision           → allow stop
  #
  # Cursor stop hooks expect:
  #   - Exit 0 + {"followup_message":"..."} → continue with message
  #   - Exit 0 + no output                 → allow stop
  class StopHookTranslator
    def self.translate(stdout:, stderr:, exit_code:)
      new(stdout: stdout, stderr: stderr, exit_code: exit_code).translate
    end

    def initialize(stdout:, stderr:, exit_code:)
      @stdout = stdout.to_s.strip
      @stderr = stderr.to_s.strip
      @exit_code = exit_code
    end

    def translate
      return translate_exit2 if @exit_code == 2
      return translate_json_decision if @exit_code.zero? && block_decision?

      # Pass through: non-blocking exit 0 or any other exit code
      { stdout: @stdout, exit_code: @exit_code }
    end

    private

    def translate_exit2
      if @stderr.empty?
        { stdout: "", exit_code: 0 }
      else
        { stdout: JSON.generate({ "followup_message" => @stderr }), exit_code: 0 }
      end
    end

    def translate_json_decision
      reason = parsed_output&.fetch("reason", nil).to_s
      if reason.empty?
        { stdout: "", exit_code: 0 }
      else
        { stdout: JSON.generate({ "followup_message" => reason }), exit_code: 0 }
      end
    end

    def block_decision?
      parsed_output&.fetch("decision", nil) == "block"
    end

    def parsed_output
      return @parsed_output if defined?(@parsed_output)

      @parsed_output = @stdout.empty? ? nil : JSON.parse(@stdout)
    rescue JSON::ParserError
      @parsed_output = nil
    end
  end
end
