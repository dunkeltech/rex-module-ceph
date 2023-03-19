package Rex::Module::Ceph::Provider::ceph_repo::Debian;

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

    $params{ensure} //= "present";

    if ( $params{ensure} eq "present" ) {
        run "lsb_release";
        eval { update_package_db; };
        if ( $? != 0 ) {
            pkg ["lsb-release"], ensure => "present";
        }
        run "wget";
        if ( $? != 0 ) {
            pkg ["wget"], ensure => "present";
        }
        run "gpg --version";
        if ( $? != 0 ) {
            pkg ["gnupg2"], ensure => "present";
        }

        my $debian_release = [run "lsb_release -sc"]->[0];
        if ( $debian_release ) {
            run "add-ceph-key",
                command => "wget -q -O- 'https://download.ceph.com/keys/release.asc' | apt-key add -";

            file "/etc/apt/sources.list.d/ceph.list",
                content => "deb https://download.ceph.com/debian-quincy/ $debian_release main",
                mode => "0644",
                owner => "root",
                group => "root",
                on_change => sub { $changed = 1; };

            update_package_db;
        }
        else {
            confess "Debian version not found.";
        }
    }
    elsif ( $params{ensure} eq "absent" ) {
            file "/etc/apt/sources.list.d/ceph.list",
                ensure => "absent",
                on_change => sub { $changed = 1; };

            update_package_db;
    }

    return $changed;
}

1;