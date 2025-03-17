require 'spec_helper'

RSpec.describe Utilities do
  before do
    stub_env(
      'GIT_SOURCE_REPO' => 'uala/test-app',
      'GIT_SOURCE_BRANCH' => 'main',
      'GIT_SOURCE_COMMIT_SHA' => '12345678'
    )
  end

  describe '.check_type' do
    # Holds the array where matched applications will be stored
    let(:applications_to_update) { [] }
    let(:config) { YAML.load_file(config_file_name) }

    describe 'matching applications by repo and branch' do
      # Given
      let(:config_file_name) { 'spec/fixtures/development/basic.yaml' }

      it 'finds the matching application when branch matches' do
        # When
        described_class.check_type(config, '', applications_to_update)

        # Then
        expect(applications_to_update.size).to eq(1)
        expect(applications_to_update.first).to include(
                                                  'name' => 'testApp',
                                                  'git_repo' => 'uala/test-app'
                                                )
      end

      it 'does not find any applications when branch differs' do
        # Given
        stub_env('GIT_SOURCE_BRANCH', 'feature')

        # When
        described_class.check_type(config, '', applications_to_update)

        # Then
        expect(applications_to_update).to be_empty
      end
    end

    describe 'handling tag-based deployments' do
      # Given
      let(:config_file_name) { 'spec/fixtures/production/tag_based.yaml' }

      it 'finds the matching application when tag is present' do
        # Given
        stub_env('GIT_SOURCE_TAG', 'v1.0.0')

        # When
        described_class.check_type(config, '', applications_to_update)

        # Then
        expect(applications_to_update.size).to eq(1)
        expect(applications_to_update.first).to include(
                                                  'name' => 'testApp',
                                                  'only_tags' => true
                                                )
      end

      it 'does not find any applications when no tag is present' do
        # When
        described_class.check_type(config, '', applications_to_update)

        # Then
        expect(applications_to_update).to be_empty
      end
    end

    describe 'handling forced application updates' do
      # Given
      let(:config_file_name) { 'spec/fixtures/development/multiple_apps.yaml' }

      it 'only includes the forced application when FORCE_UPDATE_APP is set' do
        # Given
        stub_env('FORCE_UPDATE_APP', 'testApp')

        # When
        described_class.check_type(config, '', applications_to_update)

        # Then
        expect(applications_to_update.size).to eq(1)
        expect(applications_to_update.first['name']).to eq('testApp')
      end
    end

    describe 'traversing nested configurations' do
      # Given
      let(:config_file_name) { 'spec/fixtures/nested/services.yaml' }

      it 'finds applications in nested structures' do
        # When
        described_class.check_type(config, '', applications_to_update)

        # Then
        expect(applications_to_update.size).to eq(1)
        expect(applications_to_update.first['name']).to eq('testApp')
      end
    end
  end
end
