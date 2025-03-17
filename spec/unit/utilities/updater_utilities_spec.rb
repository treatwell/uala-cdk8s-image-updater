require 'spec_helper'

RSpec.describe Utilities do
  let(:base_env) do
    {
      'GIT_SOURCE_REPO' => 'uala/test-app',
      'GIT_SOURCE_BRANCH' => 'main',
      'GIT_SOURCE_COMMIT_SHA' => '12345678'
    }
  end

  describe '.check_type' do
    # Holds the array where matched applications will be stored
    let(:applications_to_update) { [] }

    context 'with development deployment configuration' do
      describe 'matching applications by repo and branch' do
        # Given
        let(:config) do
          YAML.load_file('spec/fixtures/development/basic.yaml')
        end

        context 'when branch matches' do
          it 'finds the matching application' do
            # Given
            env_vars = base_env

            # When
            with_env(env_vars) do
              described_class.check_type(config, '', applications_to_update)
            end

            # Then
            expect(applications_to_update.size).to eq(1)
            expect(applications_to_update.first).to include(
              'name' => 'testApp',
              'git_repo' => 'uala/test-app'
            )
          end
        end

        context 'when branch differs' do
          it 'does not find any applications' do
            # Given
            env_vars = base_env.merge('GIT_SOURCE_BRANCH' => 'feature')

            # When
            with_env(env_vars) do
              described_class.check_type(config, '', applications_to_update)
            end

            # Then
            expect(applications_to_update).to be_empty
          end
        end
      end
    end

    context 'with production deployment configuration' do
      describe 'handling tag-based deployments' do
        # Given
        let(:config) do
          YAML.load_file('spec/fixtures/production/tag_based.yaml')
        end

        context 'when tag is present' do
          it 'finds the matching application' do
            # Given
            env_vars = base_env.merge('GIT_SOURCE_TAG' => 'v1.0.0')

            # When
            with_env(env_vars) do
              described_class.check_type(config, '', applications_to_update)
            end

            # Then
            expect(applications_to_update.size).to eq(1)
            expect(applications_to_update.first).to include(
              'name' => 'testApp',
              'only_tags' => true
            )
          end
        end

        context 'when no tag is present' do
          it 'does not find any applications' do
            # Given
            env_vars = base_env

            # When
            with_env(env_vars) do
              described_class.check_type(config, '', applications_to_update)
            end

            # Then
            expect(applications_to_update).to be_empty
          end
        end
      end
    end

    context 'with force update application' do
      describe 'handling forced application updates' do
        # Given
        let(:config) do
          YAML.load_file('spec/fixtures/development/multiple_apps.yaml')
        end

        context 'when FORCE_UPDATE_APP is set' do
          it 'only includes the forced application' do
            # Given
            env_vars = base_env.merge('FORCE_UPDATE_APP' => 'testApp')

            # When
            with_env(env_vars) do
              described_class.check_type(config, '', applications_to_update)
            end

            # Then
            expect(applications_to_update.size).to eq(1)
            expect(applications_to_update.first['name']).to eq('testApp')
          end
        end
      end
    end

    context 'with nested configuration structure' do
      describe 'traversing nested configurations' do
        # Given
        let(:config) do
          YAML.load_file('spec/fixtures/nested/services.yaml')
        end

        it 'finds applications in nested structures' do
          # Given
          env_vars = base_env

          # When
          with_env(env_vars) do
            described_class.check_type(config, '', applications_to_update)
          end

          # Then
          expect(applications_to_update.size).to eq(1)
          expect(applications_to_update.first['name']).to eq('testApp')
        end
      end
    end
  end
end
