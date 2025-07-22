# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::Doomsday::Login;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run curl read_json_from mkfile_or_fail/;
use Genesis::UI qw/prompt_for_boolean/;
use JSON::PP qw/encode_json/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub cmd_details {
	return
	"Log into the Doomsday instance using the API.\n".
	"Supports the following options:\n".
	"[[  #y{--yes, -y}          >>Skip all confirmations, useful for non-interactive environments\n".
	"[[  #y{--validate-ssl}     >>Enforce SSL validation when connecting to Doomsday";
}

sub perform {
	my ($self) = @_;
	my $env = $self->env;

	# Parse options
	my %options = $self->parse_options([
		'yes|y',           # Skip confirmation prompts
		'validate-ssl',    # Enforce SSL validation
	]);

	my $non_interactive = $options{'yes'} ? 1 : 0;
	my $validate_ssl = $options{'validate-ssl'} ? 1 : 0;

	# Get Doomsday credentials
	my $url = $env->exodus_lookup('url');
	my $username = $env->exodus_lookup('admin_username');
	my $password = $env->exodus_lookup('admin_password');

	bail("Could not retrieve Doomsday URL or credentials from exodus data")
		unless $url && $username && $password;

	# Confirm before proceeding
	unless ($non_interactive) {
		info("\nAbout to log into Doomsday at #C{https://$url} as #M{$username}.\n");
		my $continue = prompt_for_boolean("Proceed? [y|n]", 1);
		return $self->done(0) unless $continue;
	}

	my ($json, $rc, $err) = read_json_from(curl(
		{
			method  => 'POST',
			headers => {
				'Content-Type' => 'application/json'
			},
			skip_verify => 1,
			data => encode_json(
				{
					username => $username,
					password => $password,
				}
			)
		},
		"$url/v1/auth"
	));

	bail("Failed to log into Doomsday: $err") if $rc;

	my $jwt = $json->{token};
	bail("No token found in login response") unless $jwt;

	# Save token to environment
	mkfile_or_fail(
		"$ENV{HOME}/.doomsday_token",
		"export DOOMSDAY_TOKEN=\"$jwt\"\n"
	);

	info(
		"\n#G{Successfully logged into Doomsday!}\n".
		"\`source ~/.doomsday_token\` then you can use the doomsday cli.\n"
	);

  return $self->done($jwt);
}

1;
