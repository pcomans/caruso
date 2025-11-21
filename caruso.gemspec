# frozen_string_literal: true

require_relative "lib/caruso/version"

Gem::Specification.new do |spec|
  spec.name = "caruso"
  spec.version = Caruso::VERSION
  spec.authors = ["Philipp Comans"]
  spec.email = ["philipp.comans@gmail.com"]

  spec.summary = "Sync steering docs from Claude Marketplaces to other agents."
  spec.description = "A tool to fetch Claude Code plugins and adapt them into Cursor Rules or other agent contexts."
  spec.homepage = "https://github.com/pcomans/caruso"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/pcomans/caruso"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["caruso"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.3" # For CLI
  spec.add_dependency "faraday", "~> 2.0" # For HTTP requests
  spec.add_dependency "git", "~> 1.19" # For cloning repos

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "aruba", "~> 2.1"
  spec.add_development_dependency "rubocop", "~> 1.60"
end
