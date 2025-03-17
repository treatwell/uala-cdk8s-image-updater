require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  enable_coverage :branch
  primary_coverage :branch
end

require 'rspec'
require 'rspec/its'
require 'faker'
require 'yaml'
require 'fileutils'

# Add the app directory to the load path
$LOAD_PATH.unshift File.expand_path('../app', __dir__)

# Require the files we need for testing
require 'utilities/updater_utilities'
require 'controllers/updater_controller'

# Helper to set environment variables for tests
def with_env(env_vars)
  original = {}
  env_vars.each do |key, value|
    original[key] = ENV[key]
    ENV[key] = value
  end

  yield
ensure
  original.each do |key, value|
    ENV[key] = value
  end
end

# Helper to create a temporary YAML file
def create_temp_yaml(content, path)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, YAML.dump(content))
  yield if block_given?
ensure
  FileUtils.rm_f(path)
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Enable the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean up any temporary files after each test
  config.after(:each) do
    FileUtils.rm_rf('iac-repo')
  end
end
