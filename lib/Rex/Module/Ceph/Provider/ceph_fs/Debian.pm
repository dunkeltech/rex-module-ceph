package Rex::Module::Ceph::Provider::ceph_fs::Debian;

use strict;
use warnings;

use Rex -minimal;
use Rex::Resource::Common;
use Rex::Logger;

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

    $params{name} //= "cephfs";
    $params{exec_timeout} //= $Rex::Module::Ceph::PARAMS->{exec_timeout};

    my $changed = 0;

    run "create-fs-$params{name}",
        command => <<EOF,
set -ex
ceph fs new $params{name} $params{metadata_pool} $params{data_pool}
EOF
        unless => <<EOF,
set -ex
ceph fs ls | grep 'name: $params{name},'
EOF
        auto_die => true,
        timeout => $params{exec_timeout},
        on_change => sub { $changed = 1; };

    return $changed;
}

1;