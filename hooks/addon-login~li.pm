#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Doomsday::Login v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run/;
use Genesis::UI qw/prompt_for_boolean/;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
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
	my $username = $env->exodus_lookup('username');
	my $password = $env->exodus_lookup('password');

	bail("Could not retrieve Doomsday URL or credentials from exodus data")
		unless $url && $username && $password;

	# Confirm before proceeding
	unless ($non_interactive) {
		info("\nAbout to log into Doomsday at #C{https://$url} as #M{$username}.\n");
		my $continue = prompt_for_boolean("Proceed? [y|n]", 1);
		return $self->done(0) unless $continue;
	}

	# Perform login
	my $auth_url = "https://$url/v1/auth";
	my $curl_cmd = "curl -s";
	$curl_cmd .= " -k" unless $validate_ssl;
	$curl_cmd .= " -X POST -H 'Content-Type: application/json'";
	$curl_cmd .= " -d '{\"username\":\"$username\",\"password\":\"$password\"}'";
	$curl_cmd .= " $auth_url";

	my ($token, $rc, $err) = run($curl_cmd);
	bail("Failed to log into Doomsday: $err") if $rc;

	# Parse and extract token
	my $json;
	eval { $json = JSON::PP::decode_json($token); };
	bail("Failed to parse login response: $@") if $@;

	my $jwt = $json->{token};
	bail("No token found in login response") unless $jwt;

	# Save token to environment
	$ENV{DOOMSDAY_TOKEN} = $jwt;

	info("\n#G{Successfully logged into Doomsday!}\n".
	     "Token saved to DOOMSDAY_TOKEN environment variable.\n".
	     "You can now use this token with the Doomsday API.\n");

	return $self->done(1);
}

1;
