package Rex::Module::Ceph::Provider::ceph::Debian;

use strict;
use warnings;

use Rex -base;
use Rex::Resource::Common;
use Rex::Logger;

use Data::Dumper;
use Carp;
use JSON::XS;
use boolean;

use Rex::Module::Ceph::Functions;

sub new {
    my $that  = shift;
    my $proto = ref($that) || $that;
    my $self  = {@_};

    bless( $self, $proto );

    return $self;
}

# the ensure methods
sub present {
    my ( $self, $resource_config ) = @_;

    my $changed = 0;
    my $resource_name = resource_name;

    pkg $resource_config->{packages}, ensure => "present";
    pkg "libdigest-md5-perl", ensure => "present";

    ceph_config
        'global/fsid' => $resource_config->{fsid},
        'global/keyring' => $resource_config->{keyring},
        'global/osd_max_object_name_len' => $resource_config->{osd_max_object_name_len},
        'global/osd_max_object_namespace_len' => $resource_config->{osd_max_object_namespace_len},
        'global/osd_pool_default_pg_num' => $resource_config->{osd_pool_default_pg_num},
        'global/osd_pool_default_pgp_num' => $resource_config->{osd_pool_default_pgp_num},
        'global/osd_pool_default_size' => $resource_config->{osd_pool_default_size},
        'global/osd_pool_default_min_size' => $resource_config->{osd_pool_default_min_size},
        'global/osd_pool_default_crush_rule' => $resource_config->{osd_pool_default_crush_rule},
        'global/osd_crush_update_on_start' => $resource_config->{osd_crush_update_on_start},
        'global/mon_osd_full_ratio' => $resource_config->{mon_osd_full_ratio},
        'global/mon_osd_nearfull_ratio' => $resource_config->{mon_osd_nearfull_ratio},
        'global/mon_initial_members' => $resource_config->{mon_initial_members},
        'global/mon_host' => $resource_config->{mon_host},
        'global/ms_bind_ipv6' => $resource_config->{ms_bind_ipv6},
        'global/require_signatures' => $resource_config->{require_signatures},
        'global/cluster_require_signatures' => $resource_config->{cluster_require_signatures},
        'global/service_require_signatures' => $resource_config->{service_require_signatures},
        'global/sign_messages' => $resource_config->{sign_messages},
        'global/cluster_network' => $resource_config->{cluster_network},
        'global/public_network' => $resource_config->{public_network},
        'global/public_addr' => $resource_config->{public_addr},
        'osd/osd_journal_size' => $resource_config->{osd_journal_size},
        'client/rbd_default_features' => $resource_config->{rbd_default_features};

    if ( $resource_config->{authentication_type} eq "cephx" ) {
        ceph_config
            'global/auth_cluster_required' => 'cephx',
            'global/auth_service_required' => 'cephx',
            'global/auth_client_required' => 'cephx',
            'global/auth_supported' => 'cephx';
    }
    else {
        ceph_config
            'global/auth_cluster_required' => 'none',
            'global/auth_service_required' => 'none',
            'global/auth_client_required' => 'none',
            'global/auth_supported' => 'none';
    }

    # This section will be moved up with the rest of the non-auth settings in the next release and the set_osd_params flag will be removed
    if ( $resource_config->{set_osd_params} ) {
        ceph_config
            'osd/osd_max_backfills' => $resource_config->{osd_max_backfills},
            'osd/osd_recovery_max_active' => $resource_config->{osd_recovery_max_active},
            'osd/osd_recovery_op_priority' => $resource_config->{osd_recovery_op_priority},
            'osd/osd_recovery_max_single_start' => $resource_config->{osd_recovery_max_single_start},
            'osd/osd_max_scrubs' => $resource_config->{osd_max_scrubs},
            'osd/osd_op_threads' => $resource_config->{osd_op_threads};
    }

    return $changed;
}

sub absent {
    my ( $self, $resource_config ) = @_;

    my $changed = 0;

    return $changed;
}

1;