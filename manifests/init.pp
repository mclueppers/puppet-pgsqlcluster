# == Class: pgsqlcluster
#
# Full description of class pgsqlcluster here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'pgsqlcluster':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2016 Your name here, unless otherwise noted.
#
# lint:ignore:autoloader_layout lint:ignore:80chars

class pgsqlcluster (
  $server_type = 'master',
  $username    = undef,
  $password    = undef,
  $sibling_net = undef,
) {
  # Validations
  validate_re($server_type, 'master|slave')
  validate_string($username, $password)

  if $server_type == 'master' {
    validate_ip_address($sibling_net)
  }
  
  if $sibling_net =~ /^(\d+\.\d+\.\d+\.\d+)\/\d+$/ {
    $master_ip = $1
  } else {
    $master_ip = $sibling_net
  }

  case $server_type {
    'master': {}
    'slave': {
      file { 'Add .pgpass to /var/lib/pgsql':
        ensure  => 'file',
        path    => '/var/lib/pgsql/.pgpass',
        owner   => 'postgres',
        group   => 'postgres',
        mode    => '0400',
        content => "${master_ip}:5432:replication:${username}:${password}"
      }

      exec { 'empty pgsql data folder':
        cwd         => '/var/lib/pgsql/data/',
        path        => '/bin:/sbin:/usr/sbin:/usr/bin',
        command     => 'rm -rf /var/lib/pgsql/data/*',
        refreshonly => true,
        subscribe   => File['Add .pgpass to /var/lib/pgsql'],
        before      => Class['Postgresql::Server::Reload']
      }

      exec { 'Run pg_basebackup on slave server':
        cwd         => '/',
        path        => '/bin:/sbin:/usr/sbin:/usr/bin',
        command     => "pg_basebackup -h ${master_ip} -D /var/lib/pgsql/data/ -U ${username}",
        user        => 'postgres',
        subscribe   => Exec['empty pgsql data folder'],
        refreshonly => true,
        notify      => Postgresql::Server::Pg_hba_rule["allow slave server at ${sibling_net} to access master"]
      }

      postgresql::server::config_entry { 'hot_standby':
        value   => 'on'
      }

      postgresql::server::recovery { "Create recovery.conf for slave at ${::fqdn}":
        standby_mode     => 'on',
        primary_conninfo => "host=${master_ip} port=5432 user=${username} password=${password} sslmode=require",
        trigger_file     => '/tmp/postgresql.trigger',
        require          => Exec['empty pgsql data folder'],
        before           => Class['Postgresql::Server::Reload']
      }
    }
    default: { fail ("Server mode ${server_type} is not supported by module ${module_name}") }
  }

  file { '/var/lib/pgsql/data/server.crt':
    ensure  => 'present',
    source  => "file:///var/lib/puppet/ssl/certs/${::fqdn}.pem",
    mode    => '0400',
    owner   => 'postgres',
    group   => 'postgres',
    require => Postgresql::Server::Role[$username]
  } ->
  file { '/var/lib/pgsql/data/server.key':
    ensure => 'present',
    source => "file:///var/lib/puppet/ssl/private_keys/${::fqdn}.pem",
    mode   => '0400',
    owner  => 'postgres',
    group  => 'postgres'
  } ->
  file { '/var/lib/pgsql/data/root.crt':
    ensure => 'present',
    source => 'file:///var/lib/puppet/ssl/certs/ca.pem',
    mode   => '0400',
    owner  => 'postgres',
    group  => 'postgres'
  }

  postgresql::server::config_entry { 'wal_level':
    value => 'hot_standby'
  } ->
  postgresql::server::config_entry { 'max_wal_senders':
    value => 3
  } ->
  postgresql::server::config_entry { 'checkpoint_segments':
    value => 8
  } ->
  postgresql::server::config_entry { 'wal_keep_segments':
    value => 8
  } ->
  postgresql::server::config_entry { 'ssl':
    value => 'on'
  }

  postgresql::server::pg_hba_rule { "allow slave server at ${sibling_net} to access master":
    description => "Open up PostgreSQL for access from ${sibling_net}",
    type        => 'hostssl',
    database    => 'replication',
    user        => $username,
    address     => $sibling_net,
    auth_method => 'md5',
  } ->
  postgresql::server::role { $username:
    password_hash => postgresql_password($username, $password),
    replication   => true,
    require       => Class['::postgresql::server']
  }
}
# lint:endignore
