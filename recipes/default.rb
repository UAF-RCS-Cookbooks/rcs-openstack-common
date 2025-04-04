#
# Cookbook:: openstack-common
# library:: default
#
# Copyright:: 2012-2021, AT&T Services, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

platform_options = node['openstack']['common']['platform']
case node['platform_family']
when 'debian'
  if node['openstack']['apt']['update_apt_cache']
    # update the apt cache before installing anything
    apt_update 'default' do
      action :update
    end
  end

  # populate the necessary apt options
  # by default, do not overwrite existing configuration files
  # this alleviates the need to populate package_overrides in every cookbook
  file '/etc/apt/apt.conf.d/confdef' do
    owner 'root'
    group 'root'
    mode '644'
    content 'Dpkg::Options {
      "--force-confdef";
      "--force-confold";
      }'
    action :create
  end

  package 'ubuntu-cloud-keyring' do
    options platform_options['package_overrides']
    action :upgrade
  end

  if node['openstack']['apt']['live_updates_enabled']
    apt_components = node['openstack']['apt']['components']
    apt_repository 'openstack-ppa' do
      uri node['openstack']['apt']['uri']
      distribution "#{node['lsb']['codename']}-updates/#{node['openstack']['release']}"
      components apt_components
      cache_rebuild true # update the cache after a new repo is added
    end

    # add in the proposed repo, but only if we're in development
    proposed_action = if node['openstack']['is_release']
                        :remove
                      else
                        :add
                      end

    apt_repository 'openstack-ppa-proposed' do
      uri node['openstack']['apt']['uri']
      distribution "#{node['lsb']['codename']}-proposed/#{node['openstack']['release']}"
      components apt_components
      action proposed_action
      cache_rebuild true # update the cache after a new repo is added
    end
  end

when 'rhel'
  case node['platform_version'].to_i
  when 7
    # TODO(ramereth): These packages conflict with the RDO repo for Train
    node.default['yum']['epel']['exclude'] = 'python2-qpid-proton python2-pyngus qpid-proton-c'
  when 8
    # Need PowerTools repo for some of the python deps
    node.default['yum']['powertools']['enabled'] = true
    node.default['yum']['powertools']['managed'] = true
    # Need to use RabbitMQ repo on EL8
    node.default['yum']['centos-rabbitmq']['enabled'] = true
    node.default['yum']['centos-rabbitmq']['managed'] = true

    include_recipe 'yum-centos'
  when 9    
    bash 'Setup CRB Repo' do # FIXME! This can't stay here
      user 'root'
      cwd '/tmp'
      code <<-EOH
        dnf config-manager --enable crb
      EOH
    end
  end

  include_recipe 'yum-epel'

  repo_action = if node['openstack']['yum']['rdo_enabled']
                  :add
                elsif FileTest.exist? "/etc/yum.repos.d/RDO-#{node['openstack']['release']}.repo"
                  :remove
                else
                  :nothing
                end

  yum_repository "RDO-#{node['openstack']['release']}" do
    description "OpenStack RDO repo for #{node['openstack']['release']}"
    gpgkey node['openstack']['yum']['repo-key']
    metalink node['openstack']['yum']['uri']
    gpgcheck node['openstack']['yum']['gpgcheck']
    enabled true
    action repo_action
  end

  # add in the RDO deps, but only if we're in development
  deps_action = if node['openstack']['is_release']
                  :remove
                else
                  :add
                end

  yum_repository "RDO-#{node['openstack']['release']}-deps" do
    description "OpenStack RDO deps repo for #{node['openstack']['release']}"
    baseurl "https://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-#{node['openstack']['release']}"
    gpgcheck false
    enabled true
    action deps_action
  end

  package 'centos-release-qemu-ev' do
    action :upgrade
  end if node['platform_version'].to_i < 8
end

# install a python
package node['openstack']['common']['platform']['python_packages'] do
  options platform_options['package_overrides']
  action :upgrade
end

if node['openstack']['databag_type'] == 'vault'
  chef_gem 'chef-vault' do
    version node['openstack']['vault_gem_version']
  end
end
