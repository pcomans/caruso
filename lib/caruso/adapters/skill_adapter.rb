# frozen_string_literal: true

require_relative "base"

module Caruso
  module Adapters
    class SkillAdapter < Base
      def adapt
        created_files = []
        
        # Separate SKILL.md from other files (scripts, etc.)
        skill_file = files.find { |f| File.basename(f).casecmp("skill.md").zero? }
        other_files = files - [skill_file]

        if skill_file
          skill_root = File.dirname(skill_file)
          skill_name = File.basename(skill_root)
          
          # Inject script location hint
          # Targeted script location: .cursor/scripts/caruso/<market>/<plugin>/<skill_name>/
          script_location = ".cursor/scripts/caruso/#{marketplace_name}/#{plugin_name}/#{skill_name}/"
          
          content = SafeFile.read(skill_file)
          adapted_content = inject_skill_metadata(content, skill_file, script_location)
          
          # Save as Rule (.mdc)
          extension = agent == :cursor ? ".mdc" : ".md"
          created_file = save_file(skill_file, adapted_content, extension: extension)
          created_files << created_file
          
          # Process Scripts/Assets -> .cursor/scripts/...
          other_files.each do |file_path|
            # Calculate path relative to the skill root
            # e.g. source: .../skills/auth/scripts/login.sh
            #      root:   .../skills/auth
            #      rel:    scripts/login.sh
            relative_path_from_root = file_path.sub(skill_root + "/", "")
            
            created_script = save_script(file_path, skill_name, relative_path_from_root)
            created_files << created_script
          end
        end

        created_files
      end

      private

      def inject_skill_metadata(content, file_path, script_location)
        # Inject script location into description
        hint = "Scripts located at: #{script_location}"
        
        if content.match?(/\A---\s*\n.*?\n---\s*\n/m)
          # Update existing frontmatter
          content.sub!(/^description: (.*)$/, "description: \\1. #{hint}")
          ensure_cursor_globs(content)
        else
          # Create new frontmatter with hint
          create_skill_frontmatter(file_path, hint) + content
        end
      end

      def create_skill_frontmatter(file_path, hint)
        filename = File.basename(file_path)
        <<~YAML
          ---
          description: Imported skill from #{filename}. #{hint}
          globs: []
          alwaysApply: false
          ---
        YAML
      end

      def save_script(source_path, skill_name, relative_sub_path)
        # Construct target path in .cursor/scripts
        # .cursor/scripts/caruso/<marketplace>/<plugin>/<skill_name>/<relative_sub_path>
        
        scripts_root = File.join(target_dir, "..", "scripts", "caruso", marketplace_name, plugin_name, skill_name)
        # Note: target_dir passed to adapter is usually .cursor/rules.
        # So .. -> .cursor -> scripts
        
        target_path = File.join(scripts_root, relative_sub_path)
        output_dir = File.dirname(target_path)
        
        FileUtils.mkdir_p(output_dir)
        FileUtils.cp(source_path, target_path)
        
        # Make executable
        File.chmod(0755, target_path)
        
        puts "Saved script: #{target_path}"
        
        # Return relative path for tracking/reporting
        # We start from .cursor (parent of target_dir) ideally?
        # Or just return the absolute path for now?
        target_path
      end
    end
  end
end
