require 'spec_helper'
require_relative '../../../app/controllers/updater_controller'

RSpec.describe UpdaterController do
  describe 'Environment Configuration' do
    context 'when validating required environment variables' do
      it 'exits with error when GIT_IAC_REPO is missing' do
        # Given: No environment variables are set

        # When: Running environment validation
        # Then: System should exit with error
        expect { subject.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when GIT_IAC_TOKEN is missing' do
        # Given: Only GIT_IAC_REPO is set
        stub_env('GIT_IAC_REPO', 'github.com/org/repo')

        # When: Running environment validation
        # Then: System should exit with error
        expect { subject.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when GIT_SOURCE_REPO is missing' do
        # Given: IAC-related variables are set
        stub_env('GIT_IAC_REPO', 'github.com/org/repo')
        stub_env('GIT_IAC_TOKEN', 'token123')

        # When: Running environment validation
        # Then: System should exit with error
        expect { subject.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when both GIT_SOURCE_COMMIT_SHA and GIT_SOURCE_TAG are missing' do
        # Given: Basic repository variables are set
        stub_env('GIT_IAC_REPO', 'github.com/org/repo')
        stub_env('GIT_IAC_TOKEN', 'token123')
        stub_env('GIT_SOURCE_REPO', 'github.com/org/source')

        # When: Running environment validation
        # Then: System should exit with error
        expect { subject.check_required_params }.to raise_error(SystemExit)
      end

      it 'succeeds with all required variables for tag-based deployment' do
        # Given: All required variables including GIT_SOURCE_TAG are set
        stub_env('GIT_IAC_REPO', 'github.com/org/repo')
        stub_env('GIT_IAC_TOKEN', 'token123')
        stub_env('GIT_SOURCE_REPO', 'github.com/org/source')
        stub_env('GIT_SOURCE_TAG', 'v1.0.0')

        # When: Running environment validation
        # Then: System should not exit with error
        expect { subject.check_required_params }.not_to raise_error
      end

      it 'succeeds with all required variables for commit-based deployment' do
        # Given: All required variables including commit SHA and branch are set
        stub_env('GIT_IAC_REPO', 'github.com/org/repo')
        stub_env('GIT_IAC_TOKEN', 'token123')
        stub_env('GIT_SOURCE_REPO', 'github.com/org/source')
        stub_env('GIT_SOURCE_COMMIT_SHA', 'abc123')
        stub_env('GIT_SOURCE_BRANCH', 'main')

        # When: Running environment validation
        # Then: System should not exit with error
        expect { subject.check_required_params }.not_to raise_error
      end
    end
  end

  describe 'Repository Management' do
    let(:mock_git) { instance_double(Git::Base) }

    before do
      allow(Git).to receive(:clone).and_return(mock_git)
      allow(mock_git).to receive(:current_branch).and_return('main')
    end

    it 'clones the repository with correct authentication and branch' do
      # Given: Required environment variables for repository cloning
      stub_env('GIT_IAC_TOKEN', 'token123')
      stub_env('GIT_IAC_REPO', 'github.com/org/repo')
      stub_env('GIT_IAC_BRANCH', 'main')

      # When: Cloning the repository
      # Then: Git clone should be called with correct parameters
      expect(Git).to receive(:clone).with(
        'https://token123@github.com/org/repo',
        'iac-repo',
        { branch: 'main' }
      )
      
      subject.clone_iac_repo
    end
  end

  describe 'Configuration Loading' do
    before do
      FileUtils.mkdir_p('iac-repo')
    end

    after do
      FileUtils.rm_rf('iac-repo')
    end

    it 'loads and merges multiple YAML configurations with literal values' do
      # Given: Multiple YAML configurations exist
      File.write('iac-repo/applications1.yaml', {
        'environments' => {
          'development' => {
            'applications' => {
              'app1' => {
                'name' => 'app1',
                'image' => 'org/app1:latest'
              }
            }
          }
        }
      }.to_yaml)

      File.write('iac-repo/applications2.yaml', {
        'environments' => {
          'development' => {
            'applications' => {
              'app2' => {
                'name' => 'app2',
                'image' => 'org/app2:latest'
              }
            }
          }
        }
      }.to_yaml)

      # When: Loading configurations
      apps_conf = subject.available_applications

      # Then: Configurations should be merged correctly
      expect(apps_conf.dig('environments', 'development', 'applications')).to include('app1', 'app2')
    end

    it 'loads configurations with ERB interpolation' do
      # Given: Configuration with ERB interpolation
      File.write('iac-repo/applications.yaml', {
        'environments' => {
          'development' => {
            'applications' => {
              'app1' => {
                'name' => 'app1',
                'image' => '<%= ENV["TEST_IMAGE"] %>'
              }
            }
          }
        }
      }.to_yaml)

      # And: Environment variable for interpolation
      stub_env('TEST_IMAGE', 'org/app1:latest')

      # When: Loading configurations
      apps_conf = subject.available_applications

      # Then: Configuration should be loaded with interpolated values
      expect(apps_conf.dig('environments', 'development', 'applications', 'app1', 'image')).to eq('org/app1:latest')
    end
  end

  describe 'Image Updates' do
    let(:settings_path) { 'iac-repo/applications/development/applications_settings.yaml' }
    
    before do
      FileUtils.mkdir_p(File.dirname(settings_path))
    end

    after do
      FileUtils.rm_rf('iac-repo')
    end

    it 'updates application image tags in settings file' do
      # Given: An existing application settings file
      File.write(settings_path, {
        'myapp' => {
          'name' => 'myapp',
          'image' => 'org/myapp:old-tag'
        }
      }.to_yaml)

      # And: Application is configured for update
      stub_env('GIT_SOURCE_TAG', 'v1.0.0')
      apps_to_update = [{
        'path' => 'development',
        'name' => 'myapp',
        'image' => 'org/myapp:new-tag'
      }]
      allow(subject).to receive(:involved_applications).and_return(apps_to_update)

      # When: Updating image tags
      subject.update_images_tags

      # Then: Settings file should contain updated image tag
      updated_settings = YAML.load_file(settings_path)
      expect(updated_settings.dig('myapp', 'image')).to eq('org/myapp:new-tag')
    end

    it 'preserves other application settings when updating image tags' do
      # Given: Settings file with multiple applications
      File.write(settings_path, {
        'app1' => {
          'name' => 'app1',
          'image' => 'org/app1:old-tag',
          'config' => { 'key' => 'value' }
        },
        'app2' => {
          'name' => 'app2',
          'image' => 'org/app2:old-tag',
          'config' => { 'other' => 'setting' }
        }
      }.to_yaml)

      # And: Only one application is configured for update
      apps_to_update = [{
        'path' => 'development',
        'name' => 'app1',
        'image' => 'org/app1:new-tag'
      }]
      allow(subject).to receive(:involved_applications).and_return(apps_to_update)

      # When: Updating image tags
      subject.update_images_tags

      # Then: Only specified application should be updated
      updated_settings = YAML.load_file(settings_path)
      expect(updated_settings['app1']['image']).to eq('org/app1:new-tag')
      expect(updated_settings['app1']['config']).to eq({ 'key' => 'value' })
      expect(updated_settings['app2']).to eq({
        'name' => 'app2',
        'image' => 'org/app2:old-tag',
        'config' => { 'other' => 'setting' }
      })
    end
  end

  describe 'Deployer Configuration' do
    let(:deployer_file) { 'deployer.yaml' }

    before do
      stub_env('IAC_DEPLOYER_FILE', deployer_file)
    end

    after do
      File.delete(deployer_file) if File.exist?(deployer_file)
    end

    it 'generates deployer configuration from updated applications' do
      # Given: Applications configured for update across environments
      apps_to_update = [
        { 'path' => 'development', 'name' => 'app1' },
        { 'path' => 'development', 'name' => 'app2' },
        { 'path' => 'production', 'name' => 'app3' }
      ]

      allow(subject).to receive(:involved_applications).and_return(apps_to_update)

      # When: Generating deployer configuration
      subject.generate_deployer_config

      # Then: Deployer file should contain correct environment mappings
      config = YAML.load_file(deployer_file)
      expect(config['deploy_environments']).to contain_exactly(
        { 'development' => ['app1', 'app2'] },
        { 'production' => ['app3'] }
      )
    end

    it 'skips deployer configuration when IAC_DEPLOYER_FILE is not set' do
      # Given: IAC_DEPLOYER_FILE is not set
      stub_env('IAC_DEPLOYER_FILE', nil)

      # When: Attempting to generate deployer configuration
      subject.generate_deployer_config

      # Then: No deployer file should be created
      expect(File.exist?(deployer_file)).to be false
    end
  end

  describe 'Finding Applications' do
    before do
      FileUtils.mkdir_p('iac-repo')
    end

    after do
      FileUtils.rm_rf('iac-repo')
    end

    it 'exits cleanly when no matching applications are found' do
      # Given: Configuration with no matching applications
      File.write('iac-repo/applications.yaml', {
        'environments' => {
          'development' => {
            'applications' => {
              'app1' => {
                'name' => 'app1',
                'git_repo' => 'different-repo',
                'branch' => 'main'
              }
            }
          }
        }
      }.to_yaml)

      # And: Source repository configuration
      stub_env('GIT_SOURCE_REPO', 'test-repo')
      stub_env('GIT_SOURCE_BRANCH', 'main')

      # When: Finding involved applications
      # Then: Should exit with status 0
      expect { subject.involved_applications }.to raise_error(SystemExit)
    end
  end

  describe 'Git Repository Updates' do
    let(:mock_git) { instance_double(Git::Base) }
    let(:fixed_time) { Time.utc(2024, 1, 1, 12, 0, 0) }
    
    before do
      allow(Git).to receive(:clone).and_return(mock_git)
      allow(mock_git).to receive(:current_branch).and_return('main')
      stub_env('GIT_SOURCE_REPO', 'test-repo')
      stub_env('GIT_DRY_RUN', 'false')

      # Freeze time for predictable branch names
      allow(DateTime).to receive(:now).and_return(fixed_time)
    end

    context 'when creating pull requests' do
      before do
        stub_env('GIT_SOURCE_TAG', 'v1.0.0')
        stub_env('GIT_SOURCE_BRANCH', 'main')
        allow(mock_git).to receive(:branch).and_return(instance_double(Git::Branch))
        allow(mock_git).to receive_message_chain(:branch, :checkout)
        allow(mock_git).to receive(:commit_all)
        allow(mock_git).to receive(:push)

        subject.clone_iac_repo
      end

      it 'creates a pull request for tag-based deployments' do
        # Given: Tag-based deployment configuration
        expected_branch = "test-repo-main-v1.0.0-#{fixed_time.to_i}"

        # When: Updating the repository
        # Then: Should create and push to new branch
        expect(mock_git).to receive(:branch).with(expected_branch)
        expect(mock_git).to receive(:commit_all).with("[IMAGE_UPDATER] #{expected_branch}")
        expect(mock_git).to receive(:push).with('origin', expected_branch)
        
        # And: Should create pull request
        expect(subject).to receive(:`).with(/^cd iac-repo && gh pr create.*#{expected_branch}.*/)
        
        subject.update_iac_repo
      end
    end

    context 'when pushing directly' do
      before do
        stub_env('GIT_SOURCE_COMMIT_SHA', 'abc123')
        stub_env('GIT_SOURCE_BRANCH', 'main')
        stub_env('GIT_IAC_FORCE_PR', 'false')

        allow(mock_git).to receive(:checkout)
        allow(mock_git).to receive(:commit_all)
        allow(mock_git).to receive(:pull)
        allow(mock_git).to receive(:push)

        subject.clone_iac_repo
      end

      it 'pushes directly to branch for commit-based updates' do
        # Given: Commit-based deployment configuration
        expected_branch = "test-repo-main-abc123-#{fixed_time.to_i}"
        
        # When: Updating the repository
        # Then: Should commit and push to current branch
        expect(mock_git).to receive(:checkout).with('main')
        expect(mock_git).to receive(:commit_all).with("[IMAGE_UPDATER] #{expected_branch}")
        expect(mock_git).to receive(:pull).with('origin', 'main')
        expect(mock_git).to receive(:push).with('origin', 'main')
        
        subject.update_iac_repo
      end
    end
  end

  describe 'Full Workflow' do
    let(:mock_git) { instance_double(Git::Base) }
    let(:production_env_path) { 'iac-repo/applications/environments/production' }
    let(:application_settings_path) { "#{production_env_path}/applications_settings.yaml" }
    
    before do
      # Setup environment
      stub_env('GIT_IAC_REPO', 'github.com/org/repo')
      stub_env('GIT_IAC_TOKEN', 'token123')
      stub_env('GIT_SOURCE_REPO', 'uala/test-app')
      stub_env('GIT_SOURCE_TAG', 'v1.0.0')
      stub_env('IAC_DEPLOYER_FILE', 'deployer.yaml')
      
      # Setup mocks
      allow(Git).to receive(:clone).with(anything, 'iac-repo', anything) do#.and_return(mock_git)
        path = FileUtils.mkdir_p(production_env_path).first
        File.write(application_settings_path, {
          'testApp' => {
            'name' => 'test-app',
            'image' => 'org/test-app:old-tag'
          }
        }.to_yaml)
        mock_git
      end
      allow(mock_git).to receive(:current_branch).and_return('main')
      allow(mock_git).to receive(:branch)
      
      mock_branch = instance_double(Git::Branch)
      allow(mock_git).to receive(:branch).and_return(mock_branch)
      allow(mock_branch).to receive(:checkout)
      
      allow(mock_git).to receive(:commit_all)
      allow(mock_git).to receive(:push)
      allow(subject).to receive(:`)

      fixture_path = File.absolute_path('spec/fixtures/production/with_erb_interpolation.yaml')
      allow(Dir).to receive(:glob).with('iac-repo/applications*.yaml').and_return([fixture_path])
    end

    after do
      FileUtils.rm_rf('iac-repo')
      File.delete('deployer.yaml') if File.exist?('deployer.yaml')
    end

    it 'executes the complete update workflow' do
      # When: Running the complete workflow
      expect { subject.run }.not_to raise_error(SystemExit)

      # Then: Should generate deployer configuration
      expect(File.exist?('deployer.yaml')).to be true
      config = YAML.load_file('deployer.yaml')

      expect(config['deploy_environments']).to contain_exactly(
        { 'production' => ['testApp'] }
      )

      # And: Should update application image tags
      updated_settings = YAML.load_file(application_settings_path)
      expect(updated_settings.dig('testApp', 'image')).to eq('org/test-app:v1.0.0')
    end
  end
end
