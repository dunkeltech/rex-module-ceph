package Rex::Module::Ceph::Provider::ceph_mon::Debian;

use strict;
use warnings;

use Rex -base;
use Rex::Resource::Common;
use Rex::Logger;

use Rex::Module::Ceph::Functions;

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
    $params{mon_enable} //= true;
    $params{authentication_type} //= "cephx";
    $params{exec_timeout} //= $DunkelTech::Rex::Ceph::PARAMS->{exec_timeout};
    $params{cluster} //= "ceph";

    my $id = $name;

    my $cluster_option = "--cluster $params{cluster}";
    my $keyring_path;

    if ( $params{ensure} eq "present" ) {

        if ( $params{authentication_type} eq "cephx" ) {
            if ( ! $params{key} && ! $params{keyring} ) {
                die "authentication_type $params{authentication_type} requires either key or keyring to be set but both are undef";
            }

            if ( $params{key} && $params{keyring} ) {
                die "key (set to $params{key}) and keyring (set to $params{keyring}) are mutually exclusive";
            }

            if ( $params{key} ) {
                $keyring_path = "/tmp/ceph-mon-keyring-${id}";

                run "create-keyring-$id",
                    unless => <<EOF,
set -ex
mon_data=\$(ceph-mon ${cluster_option} --id ${id} --show-config-value mon_data) || exit 1
# if ceph-mon fails then the mon is probably not configured yet
test -e \$mon_data/done
EOF
                    command => <<EOF,
set -ex
cat > ${keyring_path} << EOS
[mon.]
    key = $params{key}
    caps mon = "allow *"
EOS
chmod 0444 ${keyring_path}
EOF
                    auto_die => true,
                    timeout => $params{exec_timeout},
                    on_change => sub { $changed = 1; };

            }
            else {
                $keyring_path = $params{keyring};
            }
        }
        else {
            $keyring_path = "/dev/null";
        }

        if ( defined $params{public_addr} ) {
            ceph_config
                "mon.${id}/public_addr" => $params{public_addr};
        }

        run "touch", ["/etc/ceph/$params{cluster}.client.admin.keyring"],
            creates => "/etc/ceph/$params{cluster}.client.admin.keyring";

        run "ceph-mkfs",
            unless => <<EOF,
set -ex
mon_data=\$(ceph-mon ${cluster_option} --id ${id} --show-config-value mon_data)
test -d  \$mon_data
EOF
            command => <<EOF,
set -ex
mon_data=\$(ceph-mon ${cluster_option} --id ${id} --show-config-value mon_data)
if [ ! -d \$mon_data ] ; then
    mkdir -p \$mon_data
    if getent passwd ceph >/dev/null 2>&1; then
        chown -h ceph:ceph \$mon_data
        if ceph-mon ${cluster_option} \\
              --setuser ceph --setgroup ceph \\
              --mkfs \\
              --id ${id} \\
              --keyring ${keyring_path} ; then
            touch \$mon_data/done \$mon_data/systemd \$mon_data/keyring
            chown -h ceph:ceph \$mon_data/done \$mon_data/systemd \$mon_data/keyring
        else
            rm -fr \$mon_data
        fi
    else
        if ceph-mon ${cluster_option} \\
              --mkfs \\
              --id ${id} \\
              --keyring ${keyring_path} ; then
            touch \$mon_data/done \$mon_data/systemd \$mon_data/keyring
        else
            rm -fr \$mon_data
        fi
    fi
fi
EOF
            auto_die => true,
            timeout => $params{exec_timeout},
            on_change => sub { $changed = 1; };

        if ( $params{authentication_type} eq "cephx" ) {
            if ( $params{key} ) {
                run "/bin/rm ${keyring_path}",
                    unless => "test ! -e ${keyring_path}";
            }
        }

        service "ceph-mon\@${id}", ensure => "started";
    }
    elsif ( $params{ensure} eq "absent" ) {
        service "ceph-mon\@${id}", ensure => "stopped";

        run "remove-mond-$id",
            unless => <<EOF,
set -ex
which ceph-mon || exit 0 # if ceph-mon is not available we already uninstalled ceph and there is nothing to do
mon_data=\$(ceph-mon ${cluster_option} --id ${id} --show-config-value mon_data)
test ! -d \$mon_data
EOF
            command => <<EOF,
set -ex
mon_data=\$(ceph-mon ${cluster_option} --id ${id} --show-config-value mon_data)
rm -fr \$mon_data
EOF
            auto_die => true,
            timeout => $params{exec_timeout},
            on_change => sub { $changed = 1; };

        ceph_config
            "mon.${id}/public_addr" => {ensure => "absent"};
    }
    else {
        confess "Ensure on MON must be either present or absent";
    }


    return $changed;
}

1;