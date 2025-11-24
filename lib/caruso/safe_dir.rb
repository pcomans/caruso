# frozen_string_literal: true

require_relative "path_sanitizer"

module Caruso
  class SafeDir
    class Error < StandardError; end
    class SecurityError < Error; end

    # Safely checks if a directory exists
    #
    # @param path [String] The path to check
    # @param base_dir [String] Optional base directory to restrict access to
    # @return [Boolean] true if directory exists and is safe
    def self.exist?(path, base_dir: nil)
      safe_path = sanitize(path, base_dir)
      Dir.exist?(safe_path)
    rescue SecurityError
      false
    end

    # Safely globs files
    #
    # @param pattern [String] The glob pattern
    # @param base_dir [String] Optional base directory to restrict access to
    # @return [Array<String>] Matching file paths
    def self.glob(pattern, base_dir: nil)
      # For glob, we need to be careful. Ideally we validate the base of the pattern.
      # If pattern contains wildcards, we can't easily sanitize the whole string as a path.
      # So we rely on the caller to have constructed the pattern safely (e.g. using safe_join).
      # But we can still check if the resolved paths are safe if base_dir is provided.

      Dir.glob(pattern).select do |path|
        if base_dir
          begin
            PathSanitizer.sanitize_path(path, base_dir: base_dir)
            true
          rescue PathSanitizer::PathTraversalError
            false
          end
        else
          true
        end
      end
    end

    def self.sanitize(path, base_dir)
      PathSanitizer.sanitize_path(path, base_dir: base_dir)
    rescue PathSanitizer::PathTraversalError => e
      raise SecurityError, "Invalid directory path: #{e.message}"
    end
    private_class_method :sanitize
  end
end
