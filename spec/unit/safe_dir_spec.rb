# frozen_string_literal: true

require "spec_helper"
require "caruso/safe_dir"

RSpec.describe Caruso::SafeDir do
  let(:temp_dir) { Dir.mktmpdir }
  let(:subdir) { File.join(temp_dir, "subdir") }

  before do
    FileUtils.mkdir_p(subdir)
    File.write(File.join(subdir, "test.md"), "content")
  end

  after do
    FileUtils.remove_entry(temp_dir)
  end

  describe ".exist?" do
    it "returns true for existing directory" do
      expect(described_class.exist?(subdir)).to be true
    end

    it "returns false for non-existent directory" do
      expect(described_class.exist?(File.join(temp_dir, "missing"))).to be false
    end

    it "returns false for unsafe paths" do
      # Should return false instead of raising error for exist? check
      expect(described_class.exist?("../../../etc", base_dir: temp_dir)).to be false
    end

    it "validates against base_dir" do
      expect(described_class.exist?(subdir, base_dir: temp_dir)).to be true
    end
  end

  describe ".glob" do
    it "finds files matching pattern" do
      pattern = File.join(subdir, "*.md")
      results = described_class.glob(pattern)
      expect(results).to include(File.join(subdir, "test.md"))
    end

    it "filters out results outside base_dir" do
      # Create a symlink pointing outside if possible, or just test logic
      # Simpler: pass a pattern that finds things outside, and ensure they are filtered
      
      # We'll mock Dir.glob to return an unsafe path
      allow(Dir).to receive(:glob).and_return(["/etc/passwd", File.join(subdir, "test.md")])
      
      results = described_class.glob("*", base_dir: temp_dir)
      expect(results).to include(File.join(subdir, "test.md"))
      expect(results).not_to include("/etc/passwd")
    end
  end
end
