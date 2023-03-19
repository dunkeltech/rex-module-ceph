package Rex::Module::Ceph::Provider::ceph_key::Debian;

use strict;
use warnings;

use Rex -base;
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
    my $name = $resource_config->{name};

    if ( !defined $params{secret} ) {
        die "You have to define a secret key. You can create it with `ceph-authtool --gen-print-key`";
    }

    my (@cluster_options, @cap_options) = ();

    if ( defined $params{cluster} ) {
        push @cluster_options, "--cluster", $params{cluster};
    }

    if ( defined $params{cap_mon} ) {
        push @cap_options, "--cap", "mon", $params{cap_mon}->@*;
    }

    if ( defined $params{cap_osd} ) {
        push @cap_options, "--cap", "osd", $params{cap_osd}->@*;
    }

    if ( defined $params{cap_mds} ) {
        push @cap_options, "--cap", "mds", $params{cap_mds}->@*;
    }

    if ( defined $params{cap_mgr} ) {
        push @cap_options, "--cap", "mgr", $params{cap_mgr}->@*;
    }

    if ( !is_file($params{keyring_path}) ) {
        file $params{keyring_path},
            ensure => "present",
            content => "",
            owner => $params{owner},
            group => $params{group},
            mode => $params{mode};
    }

    my $caps = join(" ", @cap_options);

    my $changed = 0;

    my $ret = run "ceph-key-${name}", 
        unless => <<EOF,
set -x
NEW_KEYRING=\$(mktemp)
ceph-authtool \$NEW_KEYRING --name '${name}' --add-key '$params{secret}' ${caps}
diff -N \$NEW_KEYRING $params{keyring_path}
rv=\$?
rm \$NEW_KEYRING
exit \$rv
EOF
        command => <<EOF,
set -ex
ceph-authtool $params{keyring_path} --name '${name}' --add-key '$params{secret}' ${caps}
EOF
        auto_die => true,
        timeout => $params{exec_timeout},
        on_change => sub { $changed = 1; };

    if ( defined $params{inject} ) {
        my @inject_options = ();

        if ( defined $params{inject_as_id} ) {
            push @inject_options, "--name", $params{inject_as_id};
        }

        if ( defined $params{inject_keyring} ) {
            push @inject_options, "--keyring", $params{inject_keyring};
        }

        my $cluster_option = join(" ", @cluster_options);
        my $inject_options_str = join(" ", @inject_options);

        my $ret_inject = run "ceph-injectkey-${name}", 
            unless => <<EOF,
set -x
OLD_KEYRING=\$(mktemp)
TMP_KEYRING=\$(mktemp)
cat $params{keyring_path} | sed -e 's/\\\\//g' > \$TMP_KEYRING
ceph ${cluster_option} ${inject_options_str} auth get ${name} -o \$OLD_KEYRING || true
diff -N \$OLD_KEYRING \$TMP_KEYRING
rv=\$?
rm \$OLD_KEYRING
rm \$TMP_KEYRING
exit \$rv
EOF
            command => <<EOF,
set -ex
ceph ${cluster_option} ${inject_options_str} auth import -i $params{keyring_path}
EOF
        auto_die => true,
        timeout => $params{exec_timeout},
        on_change => sub { $changed = 1; };


    }

    return $changed;
}

1;