# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::Doomsday::Login;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/
	bail info success
	struct_set_value struct_lookup
	curl load_yaml_file save_to_yaml_file
/;
use JSON::PP qw/encode_json decode_json/;

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
	my $env_name = $self->env->name;

	# Parse options
	my %options = $self->parse_options([
		'yes|y',           # Skip confirmation prompts
		'validate-ssl',    # Enforce SSL validation
	]);

	my $non_interactive = $options{'yes'} ? 1 : 0;
	my $validate_ssl = $options{'validate-ssl'} ? 1 : 0;

	# Get Doomsday credentials
	my ($url, $username, $password) = $self->exodus_data(qw(url admin_username admin_password));
	bail("Could not retrieve Doomsday URL or credentials from exodus data")
		unless $url && $username && $password;

	info("\nLogging into Doomsday at #C{$url} as #M{$username}...\n");

	my ($status, $code, $data) = curl(
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
	);

	bail("Failed to log into Doomsday:\n\n$data\n") if $status > 399;

	my $json = eval { decode_json($data) };
	bail("Failed to decode json token: $@\ndata:\n\n$data\n") if ($@);

	my $jwt = $json->{token};
	bail("No token found in login response") unless $jwt;

	# Get the  users .dday file if it exists
	my $dday_file = "$ENV{HOME}/.dday";
	my $dday_data = {};
	my $action = undef;
	if (-e $dday_file) {
		$dday_data = load_yaml_file($dday_file);
	} else {
		$action = sprintf('created ~/.dday file with %s target', $env_name);
	}

	struct_set_value($dday_data, 'current', $env_name);
	struct_set_value($dday_data, 'targets', []) unless exists $dday_data->{targets};
	my $env_target_key = "targets.name=$env_name";
	my $content = {
		name        => $env_name,
		address     => $url,
		token       => $jwt,
		skip_verify => $validate_ssl ? JSON::PP::false : JSON::PP::true,
	};

	$action //= struct_set_value($dday_data, $env_target_key, $content)
	? sprintf('updated %s target in ~/.dday file', $env_name)
	:	sprintf('added %s target to ~/.dday file', $env_name);

	save_to_yaml_file($dday_data, $dday_file);

	success(
		"\n#g{Successfully logged into Doomsday!}\n".
		"[[  - >>%s, and set it as current target.\n\n".
		" Use #G{doomsday dashboard} to see current status of expiring certificates\n\n",
		$action
	);

  return $self->done($jwt);
}

1;
