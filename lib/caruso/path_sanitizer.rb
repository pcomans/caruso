# frozen_string_literal: true

require "pathname"

module Caruso
  # PathSanitizer provides utilities to validate and sanitize file paths
  # to prevent path traversal attacks and ensure paths stay within expected boundaries
  module PathSanitizer
    class PathTraversalError < StandardError; end

    # Validates that a path doesn't contain path traversal sequences
    # and stays within the expected base directory
    #
    # @param path [String] The path to validate
    # @param base_dir [String] Optional base directory to validate against
    # @return [String] The validated, normalized path
    # @raise [PathTraversalError] if path contains traversal sequences or escapes base_dir
    def self.sanitize_path(path, base_dir: nil)
      return nil if path.nil? || path.empty?

      # Normalize the path to resolve any . or .. components
      normalized_path = Pathname.new(path).expand_path

      # If base_dir is provided, ensure the path stays within it
      if base_dir
        normalized_base = Pathname.new(base_dir).expand_path

        # Check if path is within base using relative_path_from
        # This will raise ArgumentError if path is not within base
        begin
          relative = normalized_path.relative_path_from(normalized_base)
          # Check that the relative path doesn't start with ..
          if relative.to_s.start_with?("..")
            raise PathTraversalError, "Path escapes base directory: #{path}"
          end
        rescue ArgumentError
          # Paths on different drives/volumes
          raise PathTraversalError, "Path is not within base directory: #{path}"
        end
      end

      normalized_path.to_s
    end

    # Safely joins path components, ensuring no traversal attacks
    #
    # @param base [String] The base directory
    # @param *parts [String] Path components to join
    # @return [String] The sanitized joined path
    # @raise [PathTraversalError] if result would escape base directory
    def self.safe_join(base, *parts)
      # Join the parts
      joined = File.join(base, *parts)

      # Validate the result stays within base
      sanitize_path(joined, base_dir: base)
    end

    # Validates a relative path component (like a plugin source path)
    # Ensures it doesn't start with / or contain ..
    #
    # @param path [String] The relative path to validate
    # @return [String] The validated path
    # @raise [PathTraversalError] if path is invalid
    def self.validate_relative_path(path)
      return nil if path.nil? || path.empty?

      if path.start_with?("/")
        raise PathTraversalError, "Relative path cannot be absolute: #{path}"
      end

      if path.include?("..")
        raise PathTraversalError, "Relative path contains traversal sequence: #{path}"
      end

      path
    end
  end
end
