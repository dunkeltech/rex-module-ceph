package Rex::Module::Ceph::Provider::ceph_osd::Debian;

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
    $params{fsid} //= $DunkelTech::Rex::Ceph::PARAMS->{fsid};
    $params{dmcrypt} //= false;
    $params{dmcrypt_key_dir} //= "/etc/ceph/dmcrypt-keys";
    $params{cluster} //= "ceph";

    my $data = $name;

    my $cluster_option = "--cluster $params{cluster}";

    my $osd_type = $params{store_type} || "";

    my (@wal_opts, @block_opts, @journal_opts, @dmcrypt_opts, @fsid_opts);

    if ( $params{bluestore_wal} || $params{bluestore_db} ) {
        if ( $params{bluestore_wal} ) {
            push @wal_opts, "--block.wal", $params{bluestore_wal};
        }
        if ( $params{bluestore_db} ) {
            push @block_opts, "--block.db", $params{bluestore_db};
        }

        push @journal_opts, @wal_opts, @block_opts;
    } elsif( $params{journal} ) {
        push @journal_opts, "--journal", $params{journal};
    }

    if ( $params{dmcrypt} ) {
        push @dmcrypt_opts, "--dmcrypt", "--dmcrypt-key-dir", $params{dmcrypt_key_dir};
    }

    my $dmcrypt_options = @dmcrypt_opts ? "'" . join("' '", @dmcrypt_opts) . "'" : "";
    my $journal_options = @journal_opts ? "'" . join("' '", @journal_opts) . "'" : "";

    if ( $params{ensure} eq "present" ) {
        if ( $params{fsid} ) {
            @fsid_opts = ("--cluster-fsid", $params{fsid});

            eval {
                run "ceph-osd-check-fsid-mismatch-${name}",
                    command => <<EOF,
set -ex
exit 1
EOF
                    unless => <<EOF,
set -ex
if [ -z \$(ceph-volume lvm list ${data} |grep 'cluster fsid' | awk -F'fsid' '{print \$2}'|tr -d  ' ') ]; then
    exit 0
fi
test $params{fsid} = \$(ceph-volume lvm list ${data} |grep 'cluster fsid' | awk -F'fsid' '{print \$2}'|tr -d  ' ')
EOF
                    auto_die => true,
                    timeout => $params{exec_timeout};
                1;
            } or do {
                confess "There is a mismatch in the fsid parameter.";
            };
        }

        my $fsid_option = @fsid_opts ? "'" . join("' '", @fsid_opts) . "'" : "";

        my $bootstrap_osd_keyring = "/var/lib/ceph/bootstrap-osd/$params{cluster}.keyring";
        run "ceph auth get client.bootstrap-osd > $bootstrap_osd_keyring", creates => $bootstrap_osd_keyring;

        run "ceph-osd-prepare-${name}",
            unless => <<EOF,
ceph-volume lvm list ${data}
EOF
            command => <<EOF,
set -ex
if [ \$(echo ${data}|cut -c 1) = '/' ]; then
    disk=${data}
else
    # If data is vg/lv, block device is /dev/vg/lv
    disk=/dev/${data}
fi
if ! test -b \$disk ; then
    # Since nautilus, only block devices or lvm logical volumes can be used for OSDs
    exit 1
fi
ceph-volume lvm prepare ${osd_type} ${cluster_option}${dmcrypt_options} ${fsid_option} --data ${data} ${journal_options}
EOF
            auto_die => true,
            timeout => $params{exec_timeout},
            on_change => sub { $changed = 1; };


        run "ceph-osd-activate-${name}",
            unless => <<EOF,
set -ex
id=\$(ceph-volume lvm list ${data} | grep 'osd id'|awk -F 'osd id' '{print \$2}'|tr -d ' ')
ps -fCceph-osd|grep \"\\--id \$id \"
EOF
            command => <<EOF,
set -ex
if [ \$(echo ${data}|cut -c 1) = '/' ]; then
    disk=${data}
else
    # If data is vg/lv, block device is /dev/vg/lv
    disk=/dev/${data}
fi
if ! test -b \$disk ; then
    # Since nautilus, only block devices or lvm logical volumes can be used for OSDs
    exit 1
fi
id=\$(ceph-volume lvm list ${data} | grep 'osd id'|awk -F 'osd id' '{print \$2}'|tr -d ' ')
fsid=\$(ceph-volume lvm list ${data} | grep 'osd fsid'|awk -F 'osd fsid' '{print \$2}'|tr -d ' ')
ceph-volume lvm activate \$id \$fsid
EOF
            auto_die => true,
            timeout => $params{exec_timeout},
            on_change => sub { $changed = 1; };

    } elsif( $params{ensure} eq "absent" ) {

        run "remove-osd-$params{name}",
            command => <<EOF,
set -ex
id=\$(ceph-volume lvm list ${data} | grep 'osd id'|awk -F 'osd id' '{print \$2}'|tr -d ' ')
if [ \"\$id\" ] ; then
  ceph ${cluster_option} osd out osd.\$id
  stop ceph-osd cluster=$params{cluster} id=\$id || true
  service ceph stop osd.\$id || true
  systemctl stop ceph-osd@\$id || true
  ceph ${cluster_option} osd crush remove osd.\$id
  ceph ${cluster_option} auth del osd.\$id
  ceph ${cluster_option} osd rm \$id
  rm -fr /var/lib/ceph/osd/$params{cluster}-\$id/*
  umount /var/lib/ceph/osd/$params{cluster}-\$id || true
  rm -fr /var/lib/ceph/osd/$params{cluster}-\$id
  ceph-volume lvm zap ${data}
fi
EOF
            unless => <<EOF;
set -x
ceph-volume lvm list ${data}
if [ \$? -eq 0 ]; then
    exit 1
else
    exit 0
fi
EOF

    } else {
        confess "Ensure on OSD must be either present or absent";
    }

    return $changed;
}

1;