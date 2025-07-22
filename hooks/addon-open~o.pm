# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::Doomsday::Open;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub cmd_details {
	return
	"Open the Doomsday Web UI in your default browser (macOS & Linux only).\n";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Get URL from exodus data
	my $url = $env->exodus_lookup('url');
	bail("Could not retrieve Doomsday URL from exodus data") unless $url;

	# Determine open command based on OS
	my $uname = `uname`;
	chomp($uname);

	my $open_cmd;
	if ($uname eq "Darwin") {
		$open_cmd = "open";
	} elsif ($uname eq "Linux") {
		$open_cmd = "xdg-open";
	} else {
		bail("This addon only works on macOS and Linux");
	}

	# Get credentials
	my $username = $env->exodus_lookup('admin_username');
	my $password = $env->exodus_lookup('admin_password');

	bail("Could not retrieve Doomsday credentials from exodus data")
		unless $username && $password;

	# Show credentials
	info(
    "\nDoomsday Web UI Credentials:\n".
    "\tusername: #M{$username}\n".
    "\tpassword: #G{$password}\n\n".
    "Opening Doomsday Web UI at #C{https://$url} in your browser...\n"
  );

	# Check if command exists
	my ($out, $rc) = run("command -v $open_cmd >/dev/null 2>&1");
	if ($rc) {
		info("$open_cmd command not found, skipping system opening.") if $rc;
	} else {
		info("Opening browser...");
		system("$open_cmd https://$url >/dev/null 2>&1");
	}

  return $self->done();
}

1;
