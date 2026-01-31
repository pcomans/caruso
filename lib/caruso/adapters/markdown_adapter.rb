# frozen_string_literal: true

require_relative "base"

module Caruso
  module Adapters
    class MarkdownAdapter < Base
      def adapt
        created_files = []
        files.each do |file_path|
          content = SafeFile.read(file_path)
          adapted_content = inject_metadata(content, file_path)

          extension = agent == :cursor ? ".mdc" : ".md"
          created_file = save_file(file_path, adapted_content, extension: extension)

          created_files << created_file
        end
        created_files
      end
    end
  end
end
