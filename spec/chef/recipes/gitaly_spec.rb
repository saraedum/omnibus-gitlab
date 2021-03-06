require 'chef_helper'

describe 'gitlab::gitaly' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }
  config_path = '/var/opt/gitlab/gitaly/config.toml'
  let(:gitaly_config) { chef_run.template(config_path) }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'by default' do
    it_behaves_like "enabled runit service", "gitaly", "root", "root"

    it 'creates expected directories with correct permissions' do
      expect(chef_run).to create_directory('/var/opt/gitlab/gitaly').with(user: 'git', mode: '0700')
      expect(chef_run).to create_directory('/var/log/gitlab/gitaly').with(user: 'git', mode: '0700')
      expect(chef_run).to create_directory('/opt/gitlab/etc/gitaly')
      expect(chef_run).to create_file('/opt/gitlab/etc/gitaly/PATH')
    end

    it 'populates gitaly config.toml with defaults' do
      expect(chef_run).to render_file(config_path)
        .with_content("socket_path = '/var/opt/gitlab/gitaly/gitaly.socket'")
      expect(chef_run).not_to render_file(config_path)
        .with_content("listen_addr = 'localhost:7777'")
      expect(chef_run).not_to render_file(config_path)
        .with_content("prometheus_listen_addr = 'localhost:9000'")
    end

    it 'populates gitaly config.toml with default storages' do
      expect(chef_run).to render_file(config_path)
        .with_content(%r{\[\[storage\]\]\s+name = 'default'\s+path = '/var/opt/gitlab/git-data/repositories'})
    end
  end

  context 'with user settings' do
    before do
      stub_gitlab_rb(
        gitaly: {
          socket_path: '/tmp/gitaly.socket',
          listen_addr: 'localhost:7777',
          prometheus_listen_addr: 'localhost:9000'
        }
      )
    end

    it 'populates gitaly config.toml with custom values' do
      expect(chef_run).to render_file(config_path)
        .with_content("socket_path = '/tmp/gitaly.socket'")
      expect(chef_run).to render_file(config_path)
        .with_content("listen_addr = 'localhost:7777'")
      expect(chef_run).to render_file(config_path)
        .with_content("prometheus_listen_addr = 'localhost:9000'")
    end

    context 'when using gitaly storage configuration' do
      before do
        stub_gitlab_rb(
          gitaly: {
            storage: [
              {
                'name' => 'default',
                'path' => '/tmp/path-1'
              },
              {
                'name' => 'nfs1',
                'path' => '/mnt/nfs1'
              }
            ]
          }
        )
      end

      it 'populates gitaly config.toml with custom storages' do
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'default'\s+path = '/tmp/path-1'})
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'nfs1'\s+path = '/mnt/nfs1'})
      end
    end

    context 'when using git_data_dirs storage configuration' do
      before do
        stub_gitlab_rb(
          {
            git_data_dirs:
             {
               'default' => { 'path' => '/tmp/default/git-data' },
               'nfs1' => { 'path' => '/mnt/nfs1' }
             }
          }
        )
      end

      it 'populates gitaly config.toml with custom storages' do
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'default'\s+path = '/tmp/default/git-data/repositories'})
        expect(chef_run).to render_file(config_path)
          .with_content(%r{\[\[storage\]\]\s+name = 'nfs1'\s+path = '/mnt/nfs1/repositories'})
        expect(chef_run).not_to render_file(config_path)
          .with_content('gitaly_address: "/var/opt/gitlab/gitaly/gitaly.socket"')
      end
    end
  end

  context 'when gitaly is disabled' do
    before do
      stub_gitlab_rb(gitaly: { enable: false })
    end

    it_behaves_like "disabled runit service", "gitaly"

    it 'does not create the gitaly directories' do
      expect(chef_run).not_to create_directory('/var/opt/gitlab/gitaly')
      expect(chef_run).not_to create_directory('/var/log/gitlab/gitaly')
      expect(chef_run).not_to create_directory('/opt/gitlab/etc/gitaly')
      expect(chef_run).not_to create_file('/var/opt/gitlab/gitaly/config.toml')
    end
  end
end
