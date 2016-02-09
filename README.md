# puppet-pgsqlcluster
Installs and configures PostgreSQL master/slave cluster

# Usage

## Master
```
  class { '::postgresql::server':
    listen_addresses        => $ipaddress,
    ip_mask_allow_all_users => '10.0.0.0/8',
  }

  class { '::pgsqlcluster':
    server_type => 'master', # Default value
    username    => 'replicator',
    password    => 'replicatorpassword',
    sibling_net => '10.0.0.1/8'
  }
```

## Slave
```
  class { '::postgresql::server':
    listen_addresses        => $ipaddress,
    ip_mask_allow_all_users => '192.168.0.0/24',
    manage_recovery_conf    => true,
    needs_initdb            => false,
  }

  class { '::pgsqlcluster':
    server_type => 'slave',
    username    => 'replicator',
    password    => 'replicatorpassword',
    sibling_net => '192.168.0.104/32' # IP of master
  }
```
