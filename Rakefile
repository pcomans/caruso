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
