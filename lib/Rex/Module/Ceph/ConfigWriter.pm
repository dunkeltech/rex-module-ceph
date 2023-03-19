package Rex::Module::Ceph::ConfigWriter;

use base qw(Config::INI::Writer);

sub is_valid_property_name {
    my ($self, $property) = @_;
    return $property !~ qr/(?:\n|\s;|^\s|=$)/;
}

sub stringify_value_assignment {
  my ($self, $name, $value) = @_;
 
  return '' unless defined $value;

  $name =~ s/_/ /g;
 
  return $name . ' = ' . $self->stringify_value($value) . "\n";
}

1;