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
    let(:applications_to_update) { [] }

    context 'with development deployment configuration' do
      let(:config) do
        {
          'environments' => [
            {
              'develop' => [
                {
                  'name' => 'testApp',
                  'git_repo' => 'uala/test-app',
                  'branch' => 'main',
                  'image' => 'org/test-app:main-12345678'
                }
              ]
            }
          ]
        }
      end

      it 'finds matching applications by repo and branch' do
        with_env(base_env) do
          described_class.check_type(config, '', applications_to_update)
          expect(applications_to_update.size).to eq(1)
          expect(applications_to_update.first).to include(
            'name' => 'testApp',
            'git_repo' => 'uala/test-app'
          )
        end
      end

      it 'does not match when branch differs' do
        with_env(base_env.merge('GIT_SOURCE_BRANCH' => 'feature')) do
          described_class.check_type(config, '', applications_to_update)
          expect(applications_to_update).to be_empty
        end
      end
    end

    context 'with production deployment configuration' do
      let(:config) do
        {
          'environments' => [
            {
              'production' => [
                {
                  'name' => 'testApp',
                  'git_repo' => 'uala/test-app',
                  'branch' => 'main',
                  'only_tags' => true,
                  'image' => 'org/test-app:v1.0.0'
                }
              ]
            }
          ]
        }
      end

      it 'finds matching applications when tag is present' do
        with_env(base_env.merge('GIT_SOURCE_TAG' => 'v1.0.0')) do
          described_class.check_type(config, '', applications_to_update)
          expect(applications_to_update.size).to eq(1)
          expect(applications_to_update.first).to include(
            'name' => 'testApp',
            'only_tags' => true
          )
        end
      end

      it 'does not match when only_tags is true but no tag is present' do
        with_env(base_env) do
          described_class.check_type(config, '', applications_to_update)
          expect(applications_to_update).to be_empty
        end
      end
    end

    context 'with force update application' do
      let(:config) do
        {
          'environments' => [
            {
              'develop' => [
                {
                  'name' => 'testApp',
                  'git_repo' => 'uala/test-app',
                  'branch' => 'main'
                },
                {
                  'name' => 'otherApp',
                  'git_repo' => 'uala/test-app',
                  'branch' => 'main'
                }
              ]
            }
          ]
        }
      end

      it 'only includes forced application when FORCE_UPDATE_APP is set' do
        with_env(base_env.merge('FORCE_UPDATE_APP' => 'testApp')) do
          described_class.check_type(config, '', applications_to_update)
          expect(applications_to_update.size).to eq(1)
          expect(applications_to_update.first['name']).to eq('testApp')
        end
      end
    end

    context 'with nested configuration structure' do
      let(:config) do
        {
          'environments' => [
            {
              'develop' => [
                {
                  'services' => [
                    {
                      'name' => 'testApp',
                      'git_repo' => 'uala/test-app',
                      'branch' => 'main'
                    }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'traverses nested structures to find applications' do
        with_env(base_env) do
          described_class.check_type(config, '', applications_to_update)
          expect(applications_to_update.size).to eq(1)
          expect(applications_to_update.first['name']).to eq('testApp')
        end
      end
    end
  end
end
