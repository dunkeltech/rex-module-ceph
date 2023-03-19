package Rex::Module::Ceph::Provider::ceph_mds::Debian;

use strict;
use warnings;

use Rex -base;
use Rex::Resource::Common;
use Rex::Logger;
use Rex::Module::ShellExec;

use Data::Dumper;
use Carp;
use JSON::XS;
use boolean;

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
    my %params = $resource_config->%*;
    my $name = $resource_config->{name};
    my $changed = 0;

    my %sys_info = Rex::Helper::System::info();

    $params{pkg_mds} //= $DunkelTech::Rex::Ceph::PARAMS->{pkg_mds};
    $params{pkg_mds_ensure} //= "present";
    $params{mds_activate} //= true;
    $params{mds_ensure} //= "started";
    $params{mds_id} //= $sys_info{Host}->{hostname};
    $params{cluster} //= "ceph";

    $params{mds_data} //= "/var/lib/ceph/mds/$params{cluster}-$params{mds_id}";
    $params{keyring} //= "$params{mds_data}/keyring";

    pkg $params{pkg_mds}, ensure => $params{pkg_mds_ensure};

    file $params{mds_data},
        ensure => "directory",
        owner => "ceph",
        group => "ceph",
        mode => "0750",
        on_change => sub { $changed = 1; };
    
    my $mds_service_name = "ceph-mds\@$params{mds_id}";

    service $mds_service_name,
        ensure => $params{mds_ensure},
        on_change => sub { $changed = 1; };

    if ( defined $params{mds_activate} ) {
        ceph_config
            'mds/mds_data' => $params{mds_data},
            'mds/keyring' => $params{keyring};

        if ( defined $params{public_addr} ) {
            ceph_config
                "mds.$params{mds_id}/public_addr" => $params{public_addr};
        }
    }
    else {
        ceph_config
            'mds/mds_data' => {ensure => "absent"},
            'mds/keyring' =>  {ensure => "absent"};
    }

    return $changed;
}

1;