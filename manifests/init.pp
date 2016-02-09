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
) inherits ::pgsqlcluster::params { # lint:ignore:class_inherits_from_params_class
  # Validations
  validate_re($server_type, 'master|slave')
  validate_string($username, $password)

  if $server_type == 'master' {
    validate_ip_address($sibling_net)
  }
  
  case $server_type {
    'master': {}
    'slave': {
      postgresql::server::config_entry { 'hot_standby':
        value   => 'on'
      } ->
      postgresql::server::recovery { "Create recovery.conf for slave at ${::fqdn}":
        standby_mode     => 'on',
        primary_conninfo => "host=${sibling_net} port=5432 user=${username} password=${password} sslmode=require",
        trigger_file     => '/tmp/postgresql.trigger',
        require          => Class['::postgresql::server']
      }
    }
    default: { fail ("Server mode ${server_type} is not supported by module ${module_name}") }
  }

  file { '/var/lib/pgsql/data/server.crt':
    ensure => 'present',
    source => "file:///var/lib/puppet/ssl/certs/${::fqdn}.pem",
    mode   => '0400',
    owner  => 'postgres',
    group  => 'postgres'
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
  } ->
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
    database    => 'all',
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
