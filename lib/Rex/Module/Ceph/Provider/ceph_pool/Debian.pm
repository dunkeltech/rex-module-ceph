package Rex::Module::Ceph::Provider::ceph_pool::Debian;

use strict;
use warnings;

use Rex -base;
use Rex::Resource::Common;
use Rex::Logger;

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

    $params{ensure} //= "present";
    $params{exec_timeout} //= $DunkelTech::Rex::Ceph::PARAMS->{exec_timeout};
    $params{pg_num} //= 64;

    if ( $params{ensure} eq "present" ) {
        run "create-${name}",
            unless => <<EOF,
set -ex
ceph osd pool ls | grep -w '${name}'
EOF
            command => <<EOF,
set -ex
ceph osd pool create ${name} $params{pg_num}
EOF
            on_change => sub { $changed = 1; },
            timeout => $params{exec_timeout},
            auto_die => true;

        run "set-${name}-pg_num",
            unless => <<EOF,
set -ex
test \$(ceph osd pool get ${name} pg_num | sed 's/.*:\s*//g') -ge $params{pg_num}
EOF
            command => <<EOF,
set -ex
ceph osd pool set ${name} pg_num $params{pg_num}
EOF
            on_change => sub { $changed = 1; },
            timeout => $params{exec_timeout},
            auto_die => true;

        if ( $params{pgp_num} ) {
            run "set-${name}-pgp_num",
                unless => <<EOF,
set -ex
test \$(ceph osd pool get ${name} pgp_num | sed 's/.*:\s*//g') -ge $params{pgp_num}
EOF
                command => <<EOF,
set -ex
ceph osd pool set ${name} pgp_num $params{pgp_num}
EOF
            on_change => sub { $changed = 1; },
            timeout => $params{exec_timeout},
            auto_die => true;

        }

        if ( $params{size} ) {
            run "set-${name}-size",
                unless => <<EOF,
set -ex
test \$(ceph osd pool get ${name} size | sed 's/.*:\s*//g') -eq $params{size}
EOF
                command => <<EOF,
set -ex
ceph osd pool set ${name} size $params{size}
EOF
            on_change => sub { $changed = 1; },
            timeout => $params{exec_timeout},
            auto_die => true;
        }

        if ( $params{tag} ) {
            run "set-${name}-tag",
                unless => <<EOF,
set -ex
ceph osd pool application get ${name} $params{tag}
EOF
                command => <<EOF,
set -ex
ceph osd pool application enable ${name} $params{tag}
EOF
            on_change => sub { $changed = 1; },
            timeout => $params{exec_timeout},
            auto_die => true;
        }

    }

    elsif ( $params{ensure} eq "absent" ) {

        run "delete-${name}",
            only_if => <<EOF,
set -ex
ceph osd pool ls | grep -w '${name}'
EOF
            command => <<EOF,
set -ex
ceph osd pool delete ${name} ${name} --yes-i-really-really-mean-it
EOF
            on_change => sub { $changed = 1; },
            timeout => $params{exec_timeout},
            auto_die => true;

    }

    else {
        confess "'ensure' must be either present or absent.";
    }

    return $changed;

}

1;