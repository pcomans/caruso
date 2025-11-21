# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--tag ~live"
end

RSpec::Core::RakeTask.new("spec:live") do |t|
  ENV["RUN_LIVE_TESTS"] = "true"
  t.rspec_opts = "--tag live"
end

RSpec::Core::RakeTask.new("spec:all") do |t|
  ENV["RUN_LIVE_TESTS"] = "true"
end

task default: :spec

desc "Run all tests including live tests"
task :test_all => "spec:all"

desc "Run only live tests (requires network)"
task :test_live => "spec:live"

namespace :bump do
  def bump_version(type)
    version_file = "lib/caruso/version.rb"
    content = File.read(version_file)
    
    unless content =~ /VERSION = "(\d+)\.(\d+)\.(\d+)"/
      raise "Could not find version in #{version_file}"
    end
    
    major, minor, patch = $1.to_i, $2.to_i, $3.to_i
    
    case type
    when :major
      major += 1
      minor = 0
      patch = 0
    when :minor
      minor += 1
      patch = 0
    when :patch
      patch += 1
    end
    
    new_version = "#{major}.#{minor}.#{patch}"
    new_content = content.sub(/VERSION = ".*"/, "VERSION = \"#{new_version}\"")
    
    File.write(version_file, new_content)
    puts "Bumped version to #{new_version}"
  end

  desc "Bump patch version"
  task :patch do
    bump_version(:patch)
  end

  desc "Bump minor version"
  task :minor do
    bump_version(:minor)
  end
  
  desc "Bump major version"
  task :major do
    bump_version(:major)
  end
end
