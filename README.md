# Ceph Rex Module

Manage your Ceph deployment with Rex.

Ceph is an open source software-defined storage solution designed to address the block, file and object storage needs.

This module is heavly based on openstack puppet ceph module.

## Disclaimer

This module is currently WORK-IN-PROGRESS. So it might fail.

## OS Requirements

This module is currently only tested with debian. But it might run on other distros as well.

## Example

### Deploy a test system

This is only for testing purpose. Authentication is disabled and all services are running on the same host. 
You need a free logical volume to run this example.

After deployment, you can see the status with `ceph -s`.

```perl
use Rex -feature => ['1.4'];

use Rex::Module::Ceph;
use Rex::Module::Ceph::Functions;

report -on => "YAML";


group ceph_mon => "192.168.1.10";

task "deploy_ceph" => group => ['ceph_mon'], sub {
    # atm, only works with debian 
    ceph_repo "ceph-repo", ensure => "present";

    ceph "e764faff-b5f1-4228-93ad-7a3780173f87",
        ensure => "present",
        mon_host => "192.168.1.10",
        authentication_type => 'none',
        osd_pool_default_size => 1,
        osd_pool_default_min_size => 1;

    ceph_config
        'global/osd_journal_size' => 100;

    ceph_mon "a",
        ensure => "present",
        public_addr => "192.168.1.10",
        authentication_type => "none";

    # replace `vg1/osd` with your volume
    ceph_osd "vg1/osd",
        ensure => "present";

    ceph_mgr "mgr",
        ensure => "running",
        authentication_type => "none";

};

1;
```