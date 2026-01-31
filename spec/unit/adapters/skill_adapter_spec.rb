# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "caruso/adapters/skill_adapter"

RSpec.describe Caruso::Adapters::SkillAdapter do
  let(:target_dir) { Dir.mktmpdir }
  let(:source_dir) { Dir.mktmpdir }
  let(:marketplace_name) { "test-market" }
  let(:plugin_name) { "test-plugin" }

  after do
    FileUtils.rm_rf(target_dir)
    FileUtils.rm_rf(source_dir)
  end

  def create_file(path, content)
    full_path = File.join(source_dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  describe "#adapt" do
    it "processes SKILL.md and scripts correctly" do
      # Setup skill files
      skill_md = create_file("skills/my-skill/SKILL.md", "---\ndescription: My Skill\n---\n# Content")
      script_sh = create_file("skills/my-skill/scripts/run.sh", "#!/bin/bash\necho hello")
      asset_txt = create_file("skills/my-skill/reference/docs.txt", "some info")

      files = [skill_md, script_sh, asset_txt]

      adapter = described_class.new(
        files,
        target_dir: File.join(target_dir, ".cursor/rules"), # simulates real CLI target
        marketplace_name: marketplace_name,
        plugin_name: plugin_name,
        agent: :cursor
      )

      adapter.adapt

      # Verify Rule creation
      rule_path = File.join(target_dir, ".cursor/rules/caruso", marketplace_name, plugin_name, "skills", "my-skill.mdc")
      expect(File.exist?(rule_path)).to be true

      rule_content = File.read(rule_path)
      # Check header modification with nested structure
      # Path should include the skill name before remaining subpath: .../my-skill/
      expected_hint_path = ".cursor/scripts/caruso/#{marketplace_name}/#{plugin_name}/my-skill/"
      expect(rule_content).to include("Scripts located at: #{expected_hint_path}")

      # Verify Script creation
      # Structure: .cursor/scripts/caruso/<market>/<plugin>/<skill>/scripts/run.sh
      script_target_path = File.join(target_dir, ".cursor/scripts/caruso", marketplace_name, plugin_name, "my-skill", "scripts", "run.sh")

      expect(File.exist?(script_target_path)).to be true
      expect(File.executable?(script_target_path)).to be true
      expect(File.read(script_target_path)).to include("echo hello")

      # Verify Asset creation (e.g. reference files)
      # Structure: .cursor/scripts/caruso/<market>/<plugin>/<skill>/reference/docs.txt
      asset_target_path = File.join(target_dir, ".cursor/scripts/caruso", marketplace_name, plugin_name, "my-skill", "reference", "docs.txt")
      expect(File.exist?(asset_target_path)).to be true
      expect(File.read(asset_target_path)).to include("some info")
    end
  end
end
