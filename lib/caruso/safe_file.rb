# frozen_string_literal: true

require_relative "path_sanitizer"

module Caruso
  class SafeFile
    class Error < StandardError; end
    class NotFoundError < Error; end
    class SecurityError < Error; end

    # Safely reads a file from the filesystem
    #
    # @param path [String] The path to the file to read
    # @param base_dir [String] Optional base directory to restrict access to
    # @return [String] The file content
    # @raise [NotFoundError] if the file does not exist or is not a file
    # @raise [SecurityError] if the path is unsafe or outside base_dir
    def self.read(path, base_dir: nil)
      # 1. Sanitize and validate path
      begin
        safe_path = PathSanitizer.sanitize_path(path, base_dir: base_dir)
      rescue PathSanitizer::PathTraversalError => e
        raise SecurityError, "Invalid file path: #{e.message}"
      end

      # 2. Check existence and type
      unless File.exist?(safe_path)
        raise NotFoundError, "File not found: #{path}"
      end

      unless File.file?(safe_path)
        raise NotFoundError, "Path is not a regular file: #{path}"
      end

      # 3. Read content
      File.read(safe_path)
    end
  end
end
