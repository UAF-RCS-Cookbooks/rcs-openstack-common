name             'rcs-openstack-common'
maintainer       'UAF RCS'
maintainer_email 'chef@rcs.alaska.edu'
license          'Apache-2.0'
description      'Common OpenStack attributes, libraries and recipes.'
version          '21.0.5'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'etcd', '~> 7.0'
depends 'mariadb', '~> 5.0'
depends 'memcached', '~> 7.0'
depends 'selinux'
depends 'yum-centos', '>= 3.2.0'
depends 'yum-epel'

chef_version '>= 16.0'
