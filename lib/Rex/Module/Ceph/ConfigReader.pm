package Rex::Module::Ceph::ConfigReader;

use base qw(Config::INI::Reader);

sub can_ignore {
  my ($self, $line, $handle) = @_;
 
  # Skip comments and empty lines
  return $line =~ /\A\s*(?:[#;]|$)/ ? 1 : 0;
}

sub preprocess_line {
  my ($self, $line) = @_;
 
  # Remove inline comments
  ${$line} =~ s/\s+[#;].*$//g;
}

sub parse_value_assignment {
  my ($key, $value) = ($1, $2) if $_[1] =~ /^\s*([^=\s\pC][^=\pC]*?)\s*=\s*(.*?)\s*$/;

  $key =~ s/ /_/g;

  return ($key, $value) if ($key, $value);
  return;
}

1;