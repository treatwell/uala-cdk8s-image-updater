require 'spec_helper'
require_relative '../../../app/controllers/updater_controller'

RSpec.describe UpdaterController do
  let(:controller) { described_class.new }

  describe '#check_required_params' do
    # Given: Required environment variables are not set
    context 'when missing required environment variables' do
      before do
        # Clear all relevant env vars before each test
        ENV.delete('GIT_IAC_REPO')
        ENV.delete('GIT_IAC_TOKEN')
        ENV.delete('GIT_SOURCE_REPO')
        ENV.delete('GIT_SOURCE_COMMIT_SHA')
        ENV.delete('GIT_SOURCE_TAG')
        ENV.delete('GIT_SOURCE_BRANCH')
      end

      it 'exits with error when GIT_IAC_REPO is missing' do
        # When: Checking required params
        # Then: Should exit with error
        expect { controller.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when GIT_IAC_TOKEN is missing' do
        # Given: Only GIT_IAC_REPO is set
        ENV['GIT_IAC_REPO'] = 'some-repo'

        # When/Then: Should exit with error
        expect { controller.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when GIT_SOURCE_REPO is missing' do
        # Given: IAC variables are set
        ENV['GIT_IAC_REPO'] = 'some-repo'
        ENV['GIT_IAC_TOKEN'] = 'some-token'

        # When/Then: Should exit with error
        expect { controller.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when both GIT_SOURCE_COMMIT_SHA and GIT_SOURCE_TAG are missing' do
        # Given: Basic variables are set
        ENV['GIT_IAC_REPO'] = 'some-repo'
        ENV['GIT_IAC_TOKEN'] = 'some-token'
        ENV['GIT_SOURCE_REPO'] = 'source-repo'

        # When/Then: Should exit with error
        expect { controller.check_required_params }.to raise_error(SystemExit)
      end

      it 'exits with error when GIT_SOURCE_BRANCH is missing with commit SHA' do
        # Given: Commit SHA but no branch
        ENV['GIT_IAC_REPO'] = 'some-repo'
        ENV['GIT_IAC_TOKEN'] = 'some-token'
        ENV['GIT_SOURCE_REPO'] = 'source-repo'
        ENV['GIT_SOURCE_COMMIT_SHA'] = 'abc123'

        # When/Then: Should exit with error
        expect { controller.check_required_params }.to raise_error(SystemExit)
      end
    end

    # Given: All required environment variables are set
    context 'when all required variables are present' do
      before do
        ENV['GIT_IAC_REPO'] = 'some-repo'
        ENV['GIT_IAC_TOKEN'] = 'some-token'
        ENV['GIT_SOURCE_REPO'] = 'source-repo'
      end

      it 'succeeds with GIT_SOURCE_TAG' do
        # Given: Using tag-based deployment
        ENV['GIT_SOURCE_TAG'] = 'v1.0.0'

        # When/Then: Should not raise error
        expect { controller.check_required_params }.not_to raise_error
      end

      it 'succeeds with GIT_SOURCE_COMMIT_SHA and GIT_SOURCE_BRANCH' do
        # Given: Using commit-based deployment
        ENV['GIT_SOURCE_COMMIT_SHA'] = 'abc123'
        ENV['GIT_SOURCE_BRANCH'] = 'main'

        # When/Then: Should not raise error
        expect { controller.check_required_params }.not_to raise_error
      end
    end
  end

  describe '#get_applications_available' do
    let(:test_dir) { File.dirname(__FILE__) }

    before do
      # Given: Mock file system access for tests
      FileUtils.mkdir_p('iac-repo')
      ENV['DEBUG'] = 'false'
    end

    it 'loads and merges multiple YAML configurations' do
      # Given: Multiple YAML files with proper structure
      yaml1 = {
        'environments' => {
          'development' => {
            'applications' => {
              'app1' => { 'image' => 'org/app1:v1' }
            }
          }
        }
      }
      yaml2 = {
        'environments' => {
          'development' => {
            'applications' => {
              'app2' => { 'image' => 'org/app2:v1' }
            }
          }
        }
      }

      File.write('iac-repo/applications1.yaml', yaml1.to_yaml)
      File.write('iac-repo/applications2.yaml', yaml2.to_yaml)

      # When: Getting available applications
      controller.instance_variable_set(:@applications_conf, {})
      controller.get_applications_available

      # Then: Applications should be merged correctly
      apps_conf = controller.instance_variable_get(:@applications_conf)
      expect(apps_conf).to include('environments')
      expect(apps_conf['environments']).to include('development')
      expect(apps_conf['environments']['development']).to include('applications')
      expect(apps_conf['environments']['development']['applications']).to include('app1', 'app2')
    end

    it 'handles ERB templates in YAML files' do
      # Given: YAML with ERB template
      File.write('iac-repo/applications.yaml', <<~YAML)
        environments:
          production:
            applications:
              app1:
                image: "org/app:<%= ENV['GIT_SOURCE_TAG'] %>"
      YAML
      ENV['GIT_SOURCE_TAG'] = 'v1.0.0'

      # When: Getting available applications
      controller.instance_variable_set(:@applications_conf, {})
      controller.get_applications_available

      # Then: ERB should be evaluated
      apps_conf = controller.instance_variable_get(:@applications_conf)
      expect(apps_conf.dig('environments', 'production', 'applications', 'app1', 'image')).to eq('org/app:v1.0.0')
    end
  end

  describe '#update_images_tags' do
    let(:settings_path) { 'iac-repo/applications/development/applications_settings.yaml' }
    let(:app_settings) do
      {
        'myapp' => {
          'image' => 'org/myapp:old-tag'
        }
      }
    end

    before do
      FileUtils.mkdir_p('iac-repo/applications/development')
      ENV['DEBUG'] = 'false'
      File.write(settings_path, app_settings.to_yaml)
    end

    it 'updates image tags in application settings' do
      # Given: Application to update is configured
      controller.instance_variable_set(:@applications_to_update, [
        {
          'path' => 'development',
          'name' => 'myapp',
          'image' => 'org/myapp:new-tag'
        }
      ])

      # When: Updating image tags
      controller.update_images_tags

      # Then: File should be updated with new tag
      updated_content = YAML.load_file(settings_path)
      expect(updated_content['myapp']['image']).to eq('org/myapp:new-tag')
    end

    it 'handles missing applications gracefully' do
      # Given: Application that doesn't exist in settings
      controller.instance_variable_set(:@applications_to_update, [
        {
          'path' => 'development',
          'name' => 'non_existent_app',
          'image' => 'org/app:new-tag'
        }
      ])

      # When: Updating image tags
      # Then: Should not raise error
      expect { controller.update_images_tags }.not_to raise_error

      # And: Original settings should remain unchanged
      updated_content = YAML.load_file(settings_path)
      expect(updated_content).to eq(app_settings)
    end
  end

  describe '#update_iac_repo' do
    let(:mock_git) { double('Git::Base') }
    let(:fixed_time) { Time.utc(2024, 1, 1, 12, 0, 0) }
    let(:timestamp) { fixed_time.to_i.to_s }

    before(:each) do
      # Given: Git client mock setup
      allow(mock_git).to receive(:current_branch).and_return('main')
      controller.instance_variable_set(:@git_client, mock_git)
      
      # Common ENV setup
      ENV['GIT_SOURCE_REPO'] = 'test-repo'
      ENV['GIT_DRY_RUN'] = 'false'
    end

    around(:each) do |example|
      Timecop.freeze(fixed_time) do
        example.run
      end
    end

    context 'when creating PR' do
      before(:each) do
        # PR-specific setup
        ENV['GIT_SOURCE_TAG'] = 'v1.0.0'
        @expected_branch = "test-repo--v1.0.0-#{timestamp}"
      end

      it 'creates PR for tag deployment' do
        # Given: Git operations are mocked
        expect(mock_git).to receive(:branch).with(@expected_branch)
        expect(mock_git).to receive_message_chain(:branch, :checkout)
        expect(mock_git).to receive(:commit_all).with("[IMAGE_UPDATER] #{@expected_branch}")
        expect(mock_git).to receive(:push).with('origin', @expected_branch)
        expect(controller).to receive(:`).with(/^cd iac-repo && gh pr create.*/).and_return('PR created successfully')

        # When/Then: Should create PR
        expect { controller.update_iac_repo }.not_to raise_error
      end
    end

    context 'when direct push' do
      before(:each) do
        # Direct push setup
        ENV.delete('GIT_SOURCE_TAG')
        ENV['GIT_SOURCE_COMMIT_SHA'] = 'abc123'
        ENV['GIT_SOURCE_BRANCH'] = 'main'
        ENV['GIT_IAC_FORCE_PR'] = 'false'
      end

      it 'pushes directly for non-tag deployment' do
        # Given: Git operations are mocked
        expect(mock_git).to receive(:checkout).with('main')
        expect(mock_git).to receive(:commit_all)
        allow(::Retriable).to receive(:retriable).and_yield
        expect(mock_git).to receive(:pull).with('origin', 'main')
        expect(mock_git).to receive(:push).with('origin', 'main')

        # When/Then: Should push directly
        expect { controller.update_iac_repo }.not_to raise_error
      end
    
      describe '#prepare_local_environment' do
        before do
          ENV.delete('GITHUB_TOKEN')
          FileUtils.mkdir_p('iac-repo')
        end
    
        after do
          FileUtils.rm_rf('iac-repo')
        end
    
        it 'sets up required environment variables and cleans directories' do
          # Given: IAC token is set
          ENV['GIT_IAC_TOKEN'] = 'test-token'
    
          # When: Preparing environment
          controller.prepare_local_environment
    
          # Then: Should set GITHUB_TOKEN and clean directory
          expect(ENV['GITHUB_TOKEN']).to eq('test-token')
          expect(Dir.exist?('iac-repo')).to be_falsey
        end
      end
    
  describe '#clone_iac_repo' do
    let(:mock_git) { instance_double(Git::Base) }
    let(:mock_git_lib) { class_double(Git).as_stubbed_const }
    
    before do
      allow(mock_git_lib).to receive(:clone).and_return(mock_git)
      allow(mock_git).to receive(:current_branch).and_return('main')
    end

    it 'clones the repository with correct parameters' do
      # Given: Required environment variables
      ENV['GIT_IAC_TOKEN'] = 'test-token'
      ENV['GIT_IAC_REPO'] = 'github.com/org/repo'
      ENV['GIT_IAC_BRANCH'] = 'main'

      # When/Then: Should clone with correct parameters
      expect(mock_git_lib).to receive(:clone).with(
        'https://test-token@github.com/org/repo',
        'iac-repo',
        { branch: 'main' }
      )

      controller.clone_iac_repo
    end
  end
    
      describe '#find_involved_applications' do
        let(:utilities) { class_double(Utilities).as_stubbed_const }
        
        before do
          controller.instance_variable_set(:@applications_conf, { 'test' => 'config' })
          controller.instance_variable_set(:@applications_to_update, [])
        end
    
        context 'when matching applications are found' do
          before do
            ENV['GIT_SOURCE_REPO'] = 'test-app'
            ENV['GIT_SOURCE_BRANCH'] = 'main'
            ENV['GIT_SOURCE_TAG'] = ''
            ENV['DEBUG'] = 'false'
          end

          after do
            ENV.delete('GIT_SOURCE_REPO')
            ENV.delete('GIT_SOURCE_BRANCH')
            ENV.delete('GIT_SOURCE_TAG')
            ENV.delete('DEBUG')
          end

          it 'populates applications to update' do
            # Given: Applications configuration with matching git repo and branch
            test_config = {
              'environments' => {
                'development' => {
                  'applications' => {
                    'app1' => {
                      'name' => 'app1',
                      'git_repo' => 'test-app',
                      'branch' => 'main',
                      'image' => 'test/app1:latest'
                    }
                  }
                },
                'production' => {
                  'applications' => {
                    'app2' => {
                      'name' => 'app2',
                      'git_repo' => 'test-app',
                      'branch' => 'main',
                      'image' => 'test/app2:latest'
                    }
                  }
                }
              }
            }
            
            controller.instance_variable_set(:@applications_conf, test_config)

            # When/Then: Should find applications without raising error
            expect { controller.find_involved_applications }.not_to raise_error

            # And: Should have populated applications list with matched applications
            applications = controller.instance_variable_get(:@applications_to_update)
            expect(applications.length).to eq(2)
            expect(applications).to include(
              hash_including('name' => 'app1', 'git_repo' => 'test-app', 'branch' => 'main'),
              hash_including('name' => 'app2', 'git_repo' => 'test-app', 'branch' => 'main')
            )
          end

          it 'handles tag-based deployments correctly' do
            ENV['GIT_SOURCE_TAG'] = 'v1.0.0'
            ENV['GIT_SOURCE_BRANCH'] = ''

            # Given: Applications configuration with tag-only applications
            test_config = {
              'environments' => {
                'development' => {
                  'applications' => {
                    'app1' => {
                      'name' => 'app1',
                      'git_repo' => 'test-app',
                      'only_tags' => true,
                      'image' => 'test/app1:latest'
                    }
                  }
                }
              }
            }
            
            controller.instance_variable_set(:@applications_conf, test_config)

            # When/Then: Should find tag-based applications without raising error
            expect { controller.find_involved_applications }.not_to raise_error(SystemExit)

            # And: Should have correct applications
            applications = controller.instance_variable_get(:@applications_to_update)
            expect(applications.length).to eq(1)
            expect(applications).to include(
              hash_including('name' => 'app1', 'git_repo' => 'test-app', 'only_tags' => true)
            )
          end
        end
    
        context 'when no matching applications are found' do
          it 'exits cleanly' do
            # Given: Mock utilities to return no matches
            expect(utilities).to receive(:check_type)
              .with({ 'test' => 'config' }, '', [])
              .and_return([])
    
            # When/Then: Should exit with status 0
            expect { controller.find_involved_applications }.to raise_error(SystemExit)
          end
        end
      end
    
      describe '#generate_deployer_config' do
        context 'when IAC_DEPLOYER_FILE is not set' do
          it 'does nothing' do
            # Given: No deployer file configured
            ENV.delete('IAC_DEPLOYER_FILE')
    
            # When/Then: Should return early
            expect(controller.generate_deployer_config).to be_nil
          end
        end
    
        context 'when IAC_DEPLOYER_FILE is set' do
          let(:deployer_file) { 'deployer.yaml' }
          
          before do
            ENV['IAC_DEPLOYER_FILE'] = deployer_file
            controller.instance_variable_set(:@applications_to_update, [
              { 'path' => '/environments/test1', 'name' => 'app1' },
              { 'path' => '/environments/test1', 'name' => 'app2' },
              { 'path' => '/environments/test2', 'name' => 'app3' }
            ])
          end
    
          after do
            File.delete(deployer_file) if File.exist?(deployer_file)
          end
    
          it 'generates correct deployer configuration' do
            # When: Generating deployer config
            controller.generate_deployer_config
    
            # Then: Should create file with correct structure
            config = YAML.load_file(deployer_file)
            expect(config).to include('deploy_environments')
            expect(config['deploy_environments']).to include(
              { 'test1' => ['app1', 'app2'] },
              { 'test2' => ['app3'] }
            )
          end
        end
      end
    end
  end
end
