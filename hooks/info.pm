package Genesis::Hook::Info::Doomsday v1.0.4;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/info bail run/;

BEGIN {
  require File::Basename;
  require File::Spec;
  require(File::Spec->rel2abs(File::Spec->catfile(File::Basename::dirname(__FILE__), '_admin.pm')));
}

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Get the Doomsday URL and username from exodus data.  The password stays
  # in the secrets store, and only its path and key are shown.
  my $doomsday_url = $self->env->exodus_lookup('url');
  bail("Doomsday URL not found in exodus data") unless $doomsday_url;

  my $username = $self->env->exodus_lookup('admin_username');
  bail("Doomsday username not found in exodus data") unless $username;

  my ($path, $key) = Genesis::Hook::Doomsday::Admin::check_admin_password(
    $self->env, $self->env->secrets_store->service
  );

	my ($out,$rc,$err) = $self->env->bosh->execute(qw/env --tty/);

  # Display information
  info(
    "\n#B{Doomsday Information}\n\n".
    "BOSH environment:\n%s\n\n".
    "Doomsday Web UI:\n".
    "\t#C{%s}\n\n".
    "Credentials:\n".
    "\tusername: #M{%s}\n".
    "\tpassword: stored in the secrets store at #C{%s:%s}\n\n".
    "You can use the following addons:\n".
    "\t#G{%s do -- login} # Log into Doomsday\n".
    "\t#G{%s do -- open}  # Open Doomsday Web UI\n",
    join("\n  ", '', split("\n", $out)),
    $doomsday_url,
    $username,
    $path, $key,
    scalar($self->env->get_call_path_with_env()),
    scalar($self->env->get_call_path_with_env())
  );

  return $self->done(1);
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
