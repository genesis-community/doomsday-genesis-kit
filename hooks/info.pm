package Genesis::Hook::Info::Doomsday;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/info bail run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Get Doomsday URL and credentials from exodus data
  my $doomsday_url = $self->env->exodus_lookup('url');
  bail("Doomsday URL not found in exodus data") unless $doomsday_url;

  my $username = $self->env->exodus_lookup('admin_username');
  bail("Doomsday username not found in exodus data") unless $username;

  my $password = $self->env->exodus_lookup('admin_password');
  bail("Doomsday password not found in exodus data") unless $password;

	my $out = $self->env->bosh(qw/env --tty/);

  # Display information
  info(
    "\n#B{Doomsday Information}\n\n".
    "BOSH environment:%s\n\n".
    "Doomsday Web UI:\n".
    "\t#C{%s}\n\n".
    "Credentials:\n".
    "\tusername: #M{%s}\n".
    "\tpassword: #G{%s}\n\n".
    "You can use the following addons:\n".
    "\t#G{%s do -- login} # Log into Doomsday\n".
    "\t#G{%s do -- open}  # Open Doomsday Web UI\n",
    join("\n  ", '', split("\n", $out)),
    $doomsday_url,
    $username,
    $password,
    scalar($self->env->get_call_path_with_env()),
    scalar($self->env->get_call_path_with_env())
  );

  return $self->done(1);
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
