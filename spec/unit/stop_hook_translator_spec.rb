# frozen_string_literal: true

require "spec_helper"
require "caruso/stop_hook_translator"

RSpec.describe Caruso::StopHookTranslator do
  describe ".translate" do
    context "when CC hook exits 2 with stderr reason" do
      it "translates to Cursor followup_message" do
        result = described_class.translate(stdout: "", stderr: "Tests failing, keep going", exit_code: 2)

        expect(result[:exit_code]).to eq(0)
        parsed = JSON.parse(result[:stdout])
        expect(parsed["followup_message"]).to eq("Tests failing, keep going")
      end

      it "returns empty output when stderr is empty" do
        result = described_class.translate(stdout: "", stderr: "", exit_code: 2)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("")
      end
    end

    context "when CC hook exits 0 with decision=block JSON" do
      it "translates to Cursor followup_message" do
        cc_output = JSON.generate("decision" => "block", "reason" => "Not done yet")
        result = described_class.translate(stdout: cc_output, stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        parsed = JSON.parse(result[:stdout])
        expect(parsed["followup_message"]).to eq("Not done yet")
      end

      it "returns empty output when reason is missing" do
        cc_output = JSON.generate("decision" => "block")
        result = described_class.translate(stdout: cc_output, stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("")
      end

      it "returns empty output when reason is empty string" do
        cc_output = JSON.generate("decision" => "block", "reason" => "")
        result = described_class.translate(stdout: cc_output, stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("")
      end
    end

    context "when CC hook exits 0 with no blocking decision" do
      it "passes through stdout unchanged" do
        result = described_class.translate(stdout: "all good", stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("all good")
      end

      it "passes through empty output" do
        result = described_class.translate(stdout: "", stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("")
      end

      it "passes through JSON with decision=allow" do
        cc_output = JSON.generate("decision" => "allow")
        result = described_class.translate(stdout: cc_output, stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq(cc_output)
      end

      it "passes through non-JSON text" do
        result = described_class.translate(stdout: "some plain text", stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("some plain text")
      end
    end

    context "when CC hook exits with other codes" do
      it "passes through exit code 1" do
        result = described_class.translate(stdout: "error output", stderr: "some error", exit_code: 1)

        expect(result[:exit_code]).to eq(1)
        expect(result[:stdout]).to eq("error output")
      end

      it "passes through exit code 127" do
        result = described_class.translate(stdout: "", stderr: "command not found", exit_code: 127)

        expect(result[:exit_code]).to eq(127)
        expect(result[:stdout]).to eq("")
      end
    end

    context "edge cases" do
      it "handles nil stdout" do
        result = described_class.translate(stdout: nil, stderr: nil, exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("")
      end

      it "handles whitespace-only stdout" do
        result = described_class.translate(stdout: "  \n  ", stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("")
      end

      it "strips whitespace from decision JSON" do
        cc_output = "  #{JSON.generate('decision' => 'block', 'reason' => 'keep working')}  \n"
        result = described_class.translate(stdout: cc_output, stderr: "", exit_code: 0)

        parsed = JSON.parse(result[:stdout])
        expect(parsed["followup_message"]).to eq("keep working")
      end

      it "handles malformed JSON gracefully" do
        result = described_class.translate(stdout: "{broken json", stderr: "", exit_code: 0)

        expect(result[:exit_code]).to eq(0)
        expect(result[:stdout]).to eq("{broken json")
      end
    end
  end
end
