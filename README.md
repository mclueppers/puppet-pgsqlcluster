# puppet-pgsqlcluster
Installs and configures PostgreSQL master/slave cluster

# Usage

## Master
```
  # Optional PostgreSQL class invocation
  class { '::postgresql::server':
    listen_addresses        => $ipaddress,
    ip_mask_allow_all_users => '10.0.0.0/8',
  }

  class { '::pgsqlcluster':
    server_type      => 'master',              # Default value
    username         => 'replicator',
    password         => 'replicatorpassword',
    sibling_net      => '10.0.0.1/8',
    listen_addresses => '*',                   # Used in case the module is declaring postgresql::server         
    manage_postgres  => false                  # Set to true in case you want the module to setup PostgreSQL
                                               # Then make sure you don't declare postgresql::server
  }
```

## Slave
```
  # Optional PostgreSQL class invocation
  class { '::postgresql::server':
    listen_addresses        => $ipaddress,
    ip_mask_allow_all_users => '192.168.0.0/24',
    manage_recovery_conf    => true,           # Required option
    needs_initdb            => false,          # Required option
  }

  class { '::pgsqlcluster':
    server_type      => 'slave',
    username         => 'replicator',
    password         => 'replicatorpassword',
    sibling_net      => '192.168.0.104/32'     # IP of master
    listen_addresses => '*',                   # Optional: See next option
    manage_postgres  => false                  # Shall postgresql::server be managed by this module
  }
```
