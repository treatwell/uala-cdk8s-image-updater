require 'simplecov'

# Configure and start SimpleCov first, before any code is loaded
SimpleCov.start do
  # Never merge results
  SimpleCov.use_merging false
  
  # Track branch coverage
  enable_coverage :branch
  primary_coverage :branch
  
  # Ignore specs in coverage
  add_filter '/spec/'
  
  # Force coverage directory
  coverage_dir 'coverage'
  
  # Clear results from previous runs
  SimpleCov.clear_result
end

# Require all dependencies first
require 'rspec'
require 'rspec/its'
require 'yaml'
require 'fileutils'
require 'timecop'

# Verify fixture files exist
required_fixtures = [
  'spec/fixtures/development/basic.yaml',
  'spec/fixtures/development/multiple_apps.yaml',
  'spec/fixtures/nested/services.yaml',
  'spec/fixtures/production/tag_based.yaml'
]

missing_fixtures = required_fixtures.reject { |f| File.exist?(f) }
if missing_fixtures.any?
  raise "Missing required fixture files: #{missing_fixtures.join(', ')}"
end

# Add app directory to load path
$LOAD_PATH.unshift File.expand_path('../app', __dir__)

# Require application files we're testing
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
  # Use fixed seed for deterministic ordering unless overridden
  config.order = :random
  # config.seed = ENV['RSPEC_SEED'] || 1234

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Enable the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset test-related ENV vars before each test
  config.before(:each) do
    ENV.delete_if { |key| key.start_with?('GIT_', 'GITHUB_', 'DEBUG', 'IAC_') }
  end

  # Clean up any temporary files and restore original dir after each test
  config.around(:each) do |example|
    original_dir = Dir.pwd
    begin
      FileUtils.rm_rf('iac-repo')
      example.run
    ensure
      Dir.chdir(original_dir)
      FileUtils.rm_rf('iac-repo')
    end
  end

  # Clean up temporary files after suite
  config.after(:suite) do
    FileUtils.rm_rf('iac-repo')
    FileUtils.rm_rf('deployer.yaml')
  end

  # Configure RSpec to allow message expectations on nil
  config.mock_with :rspec do |mocks|
    mocks.allow_message_expectations_on_nil = false
  end
end
