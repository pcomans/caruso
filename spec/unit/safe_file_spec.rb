# frozen_string_literal: true

require "spec_helper"
require "caruso/safe_file"

RSpec.describe Caruso::SafeFile do
  let(:temp_dir) { Dir.mktmpdir }
  let(:valid_file) { File.join(temp_dir, "test.txt") }
  let(:content) { "Hello World" }

  before do
    File.write(valid_file, content)
  end

  after do
    FileUtils.remove_entry(temp_dir)
  end

  describe ".read" do
    it "reads a valid file" do
      expect(described_class.read(valid_file)).to eq(content)
    end

    it "raises NotFoundError if file does not exist" do
      expect do
        described_class.read(File.join(temp_dir, "missing.txt"))
      end.to raise_error(Caruso::SafeFile::NotFoundError)
    end

    it "raises NotFoundError if path is a directory" do
      expect do
        described_class.read(temp_dir)
      end.to raise_error(Caruso::SafeFile::NotFoundError)
    end

    context "with base_dir" do
      it "reads file within base_dir" do
        expect(described_class.read(valid_file, base_dir: temp_dir)).to eq(content)
      end

      it "raises SecurityError if path is outside base_dir" do
        outside_file = File.join(Dir.tmpdir, "outside.txt")
        File.write(outside_file, "outside")

        begin
          expect do
            described_class.read(outside_file, base_dir: temp_dir)
          end.to raise_error(Caruso::SafeFile::SecurityError)
        ensure
          FileUtils.rm_f(outside_file)
        end
      end
    end

    it "raises SecurityError for traversal attempts" do
      # This depends on PathSanitizer implementation, but good to verify integration
      expect do
        described_class.read("../../../etc/passwd", base_dir: temp_dir)
      end.to raise_error(Caruso::SafeFile::SecurityError)
    end
  end
end
