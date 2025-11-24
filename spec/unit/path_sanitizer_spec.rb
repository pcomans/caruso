# frozen_string_literal: true

require "spec_helper"
require "caruso/path_sanitizer"
require "tmpdir"

RSpec.describe Caruso::PathSanitizer do
  let(:temp_dir) { Dir.mktmpdir }
  let(:safe_subdir) { File.join(temp_dir, "subdir") }

  before do
    FileUtils.mkdir_p(safe_subdir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".sanitize_path" do
    context "without base_dir" do
      it "returns normalized path for valid input" do
        path = "/some/valid/path"
        result = described_class.sanitize_path(path)
        expect(result).to eq(path)
      end

      it "normalizes paths with ." do
        path = "/some/./path"
        result = described_class.sanitize_path(path)
        expect(result).to eq("/some/path")
      end

      it "returns nil for nil input" do
        expect(described_class.sanitize_path(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.sanitize_path("")).to be_nil
      end
    end

    context "with base_dir" do
      it "allows paths within base directory" do
        safe_path = File.join(temp_dir, "file.txt")
        result = described_class.sanitize_path(safe_path, base_dir: temp_dir)
        expect(result).to eq(safe_path)
      end

      it "allows subdirectories within base" do
        result = described_class.sanitize_path(safe_subdir, base_dir: temp_dir)
        expect(result).to eq(safe_subdir)
      end

      it "allows the base directory itself" do
        result = described_class.sanitize_path(temp_dir, base_dir: temp_dir)
        expect(result).to eq(temp_dir)
      end

      it "rejects path traversal attempts with .." do
        bad_path = File.join(temp_dir, "..", "etc", "passwd")
        expect do
          described_class.sanitize_path(bad_path, base_dir: temp_dir)
        end.to raise_error(Caruso::PathSanitizer::PathTraversalError, /escapes base directory/)
      end

      it "rejects paths outside base directory" do
        outside_path = "/etc/passwd"
        expect do
          described_class.sanitize_path(outside_path, base_dir: temp_dir)
        end.to raise_error(Caruso::PathSanitizer::PathTraversalError)
      end

      it "rejects sneaky traversal with extra slashes" do
        bad_path = File.join(temp_dir, "..", "..", "etc", "passwd")
        expect do
          described_class.sanitize_path(bad_path, base_dir: temp_dir)
        end.to raise_error(Caruso::PathSanitizer::PathTraversalError)
      end

      it "handles paths with trailing slashes" do
        path_with_slash = "#{safe_subdir}/"
        result = described_class.sanitize_path(path_with_slash, base_dir: temp_dir)
        expect(result).to eq(safe_subdir)
      end

      it "handles relative paths when given with base_dir" do
        # When providing a relative path with base_dir, expand it first
        relative_path = "subdir/file.txt"
        full_path = File.expand_path(relative_path, temp_dir)
        result = described_class.sanitize_path(full_path, base_dir: temp_dir)
        expect(result).to eq(full_path)
      end

      it "normalizes paths before validation" do
        # Path that looks suspicious but normalizes to safe location
        safe_normalized = File.join(safe_subdir, "file.txt")
        wonky_path = File.join(safe_subdir, "..", "subdir", "file.txt")
        result = described_class.sanitize_path(wonky_path, base_dir: temp_dir)
        expect(result).to eq(safe_normalized)
      end
    end
  end

  describe ".safe_join" do
    it "safely joins path components" do
      result = described_class.safe_join(temp_dir, "subdir", "file.txt")
      expected = File.join(temp_dir, "subdir", "file.txt")
      expect(result).to eq(expected)
    end

    it "rejects traversal attempts in components" do
      expect do
        described_class.safe_join(temp_dir, "..", "etc", "passwd")
      end.to raise_error(Caruso::PathSanitizer::PathTraversalError)
    end

    it "handles components with leading slash (File.join strips them)" do
      # File.join strips leading / from non-first components
      # So "/etc/passwd" becomes "etc/passwd" when joined
      result = described_class.safe_join(temp_dir, "/etc/passwd")
      expected = File.join(temp_dir, "etc", "passwd")
      expect(result).to eq(expected)
    end

    it "handles multiple components safely" do
      result = described_class.safe_join(temp_dir, "a", "b", "c", "file.txt")
      expected = File.join(temp_dir, "a", "b", "c", "file.txt")
      expect(result).to eq(expected)
    end

    it "normalizes paths before checking" do
      # This should be safe after normalization
      result = described_class.safe_join(temp_dir, "subdir", ".", "file.txt")
      expected = File.join(temp_dir, "subdir", "file.txt")
      expect(result).to eq(expected)
    end
  end

  describe "edge cases" do
    it "handles Unicode characters in paths" do
      unicode_path = File.join(temp_dir, "文件.txt")
      result = described_class.sanitize_path(unicode_path, base_dir: temp_dir)
      expect(result).to eq(unicode_path)
    end

    it "handles spaces in paths" do
      spaced_path = File.join(temp_dir, "my file.txt")
      result = described_class.sanitize_path(spaced_path, base_dir: temp_dir)
      expect(result).to eq(spaced_path)
    end

    it "handles very long paths" do
      long_component = "a" * 200
      long_path = File.join(temp_dir, long_component)
      result = described_class.sanitize_path(long_path, base_dir: temp_dir)
      expect(result).to eq(long_path)
    end
  end

  describe "real-world attack scenarios" do
    it "blocks classic path traversal" do
      expect do
        described_class.safe_join(temp_dir, "../../../etc/passwd")
      end.to raise_error(Caruso::PathSanitizer::PathTraversalError)
    end
  end
end
