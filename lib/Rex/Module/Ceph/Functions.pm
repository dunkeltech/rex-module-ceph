package Rex::Module::Ceph::Functions;

use strict;
use warnings;
use Data::Dumper;

use Rex -base;
use Rex::Module::Ceph::ConfigReader;
use Rex::Module::Ceph::ConfigWriter;

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);
use Carp;

@EXPORT = qw(ceph_config);

sub ceph_config {
    my (%option) = @_;

    my $ceph_config = {};

    if ( is_file( $Rex::Module::Ceph::PARAMS->{config_file} ) ) {
        my $ceph_config_r = file_read $Rex::Module::Ceph::PARAMS->{config_file};
        $ceph_config = Rex::Module::Ceph::ConfigReader->read_handle($ceph_config_r->{fh}->{fh});
    }

    for my $key (keys %option) {
        my ($section, $varname) = split(/\//, $key, 2);
        $ceph_config->{$section}->{$varname} = $option{$key};
    }

    eval {
        my $ceph_config_w = file_write $Rex::Module::Ceph::PARAMS->{config_file} . ".tmp";
        Rex::Module::Ceph::ConfigWriter->write_handle($ceph_config, $ceph_config_w->{fh}->{fh});
        mv $Rex::Module::Ceph::PARAMS->{config_file} . ".tmp", $Rex::Module::Ceph::PARAMS->{config_file};
        1;
    } or do {
        rm $Rex::Module::Ceph::PARAMS->{config_file} . ".tmp";
        confess "Error generating ceph configuration.\n\n$@\n\n";
    };

}

1;