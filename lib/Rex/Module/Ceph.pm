package Rex::Module::Ceph;

use strict;
use warnings;

use Rex -minimal;
use Rex::Resource::Common;
use Rex::Commands::Gather;

use Carp;
use boolean;


sub get_ceph_provider {
    my ($func) = @_;

    return {
        debian => "Rex::Module::Ceph::Provider::${func}::Debian",
        default => "Rex::Module::Ceph::Provider::${func}::Debian",
    };
}


our $PARAMS = {
    exec_timeout => 600,
    pkg_mds => ['ceph-mds'],
    fsid => undef,
};

resource "ceph", { export => 1 }, sub {
    my $rule_name = resource_name;

    my $resource_config = {
        fsid                          => param_lookup( "fsid", $rule_name ),
        ensure                        => param_lookup( "ensure",  "present" ),
        authentication_type           => param_lookup( "authentication_type", "cephx" ),
        keyring                       => param_lookup( "keyring", undef ),
        osd_journal_size              => param_lookup( "osd_journal_size", undef ),
        osd_max_object_name_len       => param_lookup( "osd_max_object_name_len", undef ),
        osd_max_object_namespace_len  => param_lookup( "osd_max_object_namespace_len", undef ),
        osd_pool_default_pg_num       => param_lookup( "osd_pool_default_pg_num", undef ),
        osd_pool_default_pgp_num      => param_lookup( "osd_pool_default_pgp_num", undef ),
        osd_pool_default_size         => param_lookup( "osd_pool_default_size", undef ),
        osd_pool_default_min_size     => param_lookup( "osd_pool_default_min_size", undef ),
        osd_pool_default_crush_rule   => param_lookup( "osd_pool_default_crush_rule", undef ),
        osd_crush_update_on_start     => param_lookup( "osd_crush_update_on_start", undef ),
        mon_osd_full_ratio            => param_lookup( "mon_osd_full_ratio", undef ),
        mon_osd_nearfull_ratio        => param_lookup( "mon_osd_nearfull_ratio", undef ),
        mon_initial_members           => param_lookup( "mon_initial_members", undef ),
        mon_host                      => param_lookup( "mon_host", undef ),
        ms_bind_ipv6                  => param_lookup( "ms_bind_ipv6", undef ),
        require_signatures            => param_lookup( "require_signatures", undef ),
        cluster_require_signatures    => param_lookup( "cluster_require_signatures", undef ),
        service_require_signatures    => param_lookup( "service_require_signatures", undef ),
        sign_messages                 => param_lookup( "sign_messages", undef ),
        cluster_network               => param_lookup( "cluster_network", undef ),
        public_network                => param_lookup( "public_network", undef ),
        public_addr                   => param_lookup( "public_addr", undef ),
        osd_max_backfills             => param_lookup( "osd_max_backfills", undef ),
        osd_recovery_max_active       => param_lookup( "osd_recovery_max_active", undef ),
        osd_recovery_op_priority      => param_lookup( "osd_recovery_op_priority", undef ),
        osd_recovery_max_single_start => param_lookup( "osd_recovery_max_single_start", undef ),
        osd_max_scrubs                => param_lookup( "osd_max_scrubs", undef ),
        osd_op_threads                => param_lookup( "osd_op_threads", undef ),
        rbd_default_features          => param_lookup( "rbd_default_features", undef ),
        
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
        rgw_socket_path => param_lookup( "rgw_socket_path", '/tmp/radosgw.sock' ),
        enable_sig      => param_lookup( "enable_sig", false ),
        release         => param_lookup( "release", 'nautilus' ),
        user_radosgw        => param_lookup( "user_radosgw", 'www-data' ),

        packages            => param_lookup( "packages", ['ceph']),
        pkg_radosgw         => param_lookup( "pkg_radosgw", ['radosgw'] ),
        pkg_fastcgi         => param_lookup( "pkg_fastcgi", ['libapache2-mod-fastcgi'] ),
        pkg_policycoreutils => param_lookup( "pkg_policycoreutils", ['policycoreutils'] ),
        pkg_mds             => param_lookup( "pkg_mds", ['ceph-mds'] ),

        config_file => param_lookup( "config_file", "/etc/ceph/ceph.conf" ),

        # DEPRECATED PARAMETERS
        set_osd_params                => param_lookup( "set_osd_params", false),
    };

    $PARAMS->{exec_timeout} = $resource_config->{exec_timeout};
    $PARAMS->{pkg_mds} = $resource_config->{pkg_mds};
    $PARAMS->{fsid} = $resource_config->{fsid};
    $PARAMS->{config_file} = $resource_config->{config_file} // "/etc/ceph/ceph.conf";

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph") ) );

    $provider->require;

    my $provider_o = $provider->new();

    # and execute the requested state.
    if ( $resource_config->{ensure} eq "present" ) {
        if ( $provider_o->present($resource_config) ) {
            emit created, "DunkelTech::Rex::Nomad::Resources::NomadJob resource created.";
        }
    }
    elsif ( $resource_config->{ensure} eq "absent" ) {
        if ( $provider_o->absent($resource_config) ) {
            emit removed, "DunkelTech::Rex::Nomad::Resources::NomadJob resource removed.";
        }
    }
    else {
        die "Error: $resource_config->{ensure} not a valid option for 'ensure'.";
    }
};

resource "ceph_fs", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name            => $resource_name,
        metadata_pool   => param_lookup( "metadata_pool", undef ),
        data_pool       => param_lookup( "data_pool", undef ),
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    unless ( $resource_config->{metadata_pool} ) {
        confess "You have to set metadata_pool";
    }
    unless ( $resource_config->{data_pool} ) {
        confess "You have to set data_pool";
    }

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_fs: $resource_name created.";
    }
};


resource "ceph_key", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name => $resource_name,
        secret => param_lookup( "secret" ),
        cluster => param_lookup( "cluster", undef ),
        keyring_path => param_lookup( "keyring_path", "/etc/ceph/ceph.${resource_name}.keyring" ),
        cap_mon => param_lookup( "cap_mon", undef ),
        cap_osd => param_lookup( "cap_osd", undef ),
        cap_mds => param_lookup( "cap_mds", undef ),
        cap_mgr => param_lookup( "cap_mgr", undef ),
        user => param_lookup( "user", "root" ),
        group => param_lookup( "group", "root" ),
        mode => param_lookup( "mode", "0600" ),
        inject => param_lookup( "inject", false ),
        inject_as_id => param_lookup( "inject_as_id", undef ),
        inject_keyring => param_lookup( "inject_keyring", undef ),
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    unless ( $resource_config->{secret} ) {
        confess "You have to define a secret key. You can create it with `ceph-authtool --gen-print-key`";
    }

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_key") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_key: $resource_name created.";
    }
};

resource "ceph_mds", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name => $resource_name,
        public_addr => param_lookup( "public_addr", undef ),
        pkg_mds => param_lookup( "pkg_mds", $PARAMS->{pkg_mds} ),
        pkg_mds_ensure => param_lookup( "pkg_mds_ensure", "present" ),
        mds_activate => param_lookup( "mds_activate", true ),
        mds_data => param_lookup( "mds_data", undef ),
        mds_enable => param_lookup( "mds_enable", true ),
        mds_ensure => param_lookup( "mds_ensure", 'running' ),
        mds_id => param_lookup( "mds_id", $::hostname ),
        keyring => param_lookup( "keyring", undef ),
        cluster => param_lookup( "cluster", 'ceph' ),
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_mds") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_mds: $resource_name created.";
    }
};

resource "ceph_mgr", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name                => $resource_name,
        ensure              => param_lookup( 'ensure', 'started' ),
        cluster             => param_lookup( 'cluster', 'ceph' ),
        authentication_type => param_lookup( 'authentication_type', 'cephx' ),
        key                 => param_lookup( 'key', undef ),
        inject_key          => param_lookup( 'inject_key', false ),
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_mgr") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_mgr: $resource_name created.";
    }
};

resource "ceph_mirror", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name                => $resource_name,
        ensure              => param_lookup( 'ensure', 'present' ),
        pkg_mirror          => param_lookup( 'pkg_mirror', ['rbd-mirror'] ),
        rbd_mirror_ensure   => param_lookup( 'rbd_mirror_ensure', 'started' ),
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_mirror") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_mirror: $resource_name created.";
    }
};

resource "ceph_mon", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name                => $resource_name,
        ensure              => param_lookup( 'ensure', 'present' ),
        mon_enable          => param_lookup( 'mon_enable', true ),
        public_addr         => param_lookup( 'public_addr', undef ),
        cluster             => param_lookup( 'cluster', undef ),
        authentication_type => param_lookup( 'authentication_type', 'cephx' ),
        key                 => param_lookup( 'key', undef ),
        keyring             => param_lookup( 'keyring', undef ),
        exec_timeout        => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_mon") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_mon: $resource_name created.";
    }
};

resource "ceph_osd", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name                => $resource_name,
        ensure              => param_lookup( 'ensure', 'present' ),
        mon_enable          => param_lookup( 'mon_enable', true ),
        public_addr         => param_lookup( 'public_addr', undef ),
        cluster             => param_lookup( 'cluster', undef ),
        authentication_type => param_lookup( 'authentication_type', 'cephx' ),
        key                 => param_lookup( 'key', undef ),
        keyring             => param_lookup( 'keyring', undef ),
        exec_timeout        => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_osd") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_osd: $resource_name created.";
    }
};

resource "ceph_pool", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name            => $resource_name,
        ensure          => param_lookup( "ensure", "present"),
        pg_num          => param_lookup( "pg_num", 64),
        pgp_num         => param_lookup( "pgp_num", undef),
        size            => param_lookup( "size", undef),
        tag             => param_lookup( "tag", undef),
        exec_timeout    => param_lookup( "exec_timeout", $PARAMS->{exec_timeout} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_pool") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_pool: $resource_name created.";
    }
};

resource "ceph_repo", { export => 1 }, sub {
    my $resource_name = resource_name;

    my $resource_config = {
        name                => $resource_name,
        ensure              => param_lookup( 'ensure', 'present' ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), get_ceph_provider("ceph_repo") ) );

    $provider->require;

    my $provider_o = $provider->new();

    my $changed = $provider_o->present($resource_config);

    if ($changed) {
        emit created, "ceph_repo: $resource_name created.";
    }
};


1;