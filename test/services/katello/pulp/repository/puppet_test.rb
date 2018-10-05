require 'katello_test_helper'

module Katello
  module Service
    class Repository
      class PuppetBaseTest < ::ActiveSupport::TestCase
        include VCR::TestCase
        include RepositorySupport

        def setup
          @master = FactoryBot.create(:smart_proxy, :default_smart_proxy)
          @mirror = FactoryBot.build(:smart_proxy, :pulp_mirror)

          @repo = katello_repositories(:p_forge)

          Cert::Certs.stubs(:ueber_cert).returns({})
        end

        def delete_repo(repo)
          ::ForemanTasks.sync_task(::Actions::Pulp::Repository::Destroy, :pulp_id => repo.pulp_id) rescue ''
        end
      end

      class PuppetVcrTest < PuppetBaseTest
        def setup
          super
          delete_repo(@repo)
        end

        def test_create
          @repo.root.mirror_on_sync = true

          repo = Katello::Pulp::Repository::Puppet.new(@repo, @master)

          response = repo.create
          assert_equal @repo.pulp_id, response['id']

          importer = repo.backend_data['importers'][0]['config']
          assert_equal importer['remove_missing'], true

          distributor = repo.backend_data['distributors'].find { |dist| dist['distributor_type_id'] == 'puppet_install_distributor' }
          assert_equal repo.puppet_install_distributor_path, distributor['config']['install_path']
          assert_equal 2, repo.backend_data['distributors'].count
        ensure
          delete_repo(@repo)
        end

        def test_create_puppet_environment_archive
          cvpe = katello_content_view_puppet_environments(:archive_view_puppet_environment)
          delete_repo(cvpe)

          repo = Katello::Pulp::Repository::Puppet.new(cvpe.nonpersisted_repository, @master)
          response = repo.create

          assert_equal cvpe.pulp_id, response['id']
        ensure
          delete_repo(cvpe)
        end
      end
    end
  end
end
