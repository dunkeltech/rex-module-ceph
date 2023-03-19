package Rex::Module::Ceph::Provider::ceph_mgr::Debian;

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

use Rex::Module::Ceph;

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

    $params{ensure} //= "started";
    $params{cluster} //= "ceph";
    $params{authentication_type} //= "cephx";
    $params{inject_key} //= false;

    file "/var/lib/ceph/mgr",
        ensure => "directory",
        owner => "ceph",
        group => "ceph";
    
    file "/var/lib/ceph/mgr/$params{cluster}-${name}",
        ensure => "directory",
        owner => "ceph",
        group => "ceph";

    if ( $params{authentication_type} eq "cephx" ) {
        if ( !$params{key} ) {
            confess "cephx requires a specified key for the manager daemon";
        }

        ceph_key "mgr.${name}",
            secret       => $params{key},
            cluster      => $params{cluster},
            keyring_path => "/var/lib/ceph/mgr/$params{cluster}-${name}/keyring",
            cap_mon      => ['allow', 'profile', 'mgr'],
            cap_osd      => ['allow', '*'],
            cap_mds      => ['allow', '*'],
            user         => 'ceph',
            group        => 'ceph',
            inject       => $params{inject_key};
    }

    service "ceph-mgr\@${name}", ensure => $params{ensure};

    return $changed;
}

1;