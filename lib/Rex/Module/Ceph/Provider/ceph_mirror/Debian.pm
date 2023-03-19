package Rex::Module::Ceph::Provider::ceph_mirror::Debian;

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

# use Rex::Module::Ceph;

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

    $params{pkg_mirror} //= ["rbd-mirror"];
    $params{rbd_mirror_ensure} //= "started";

    pkg $params{pkg_mirror}, ensure => "present";

    my $service_name = "ceph-rbd-mirror\@${name}";

    service $service_name, ensure => $params{rbd_mirror_ensure};

    return $changed;
}

1;