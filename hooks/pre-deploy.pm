#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/info/;
use Time::HiRes qw/gettimeofday/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Prepare for deployment
	info("\n#M{Preparing to deploy Doomsday...}\n");

	# Check if we have the necessary credentials in Vault
	my $vault_prefix = $self->env->secrets_base;
	my $start = gettimeofday;

	info({pending => 1}, "Validating secrets in vault...");
	my @required_creds = qw(username password);
	my $missing = 0;

	foreach my $cred (@required_creds) {
		unless ($self->vault->has("$vault_prefix$cred")) {
			$missing = 1;
			info("\n  - Missing required credential: #R{$cred}");
		}
	}

	if ($missing) {
		info("#R{failed}" . pretty_duration(gettimeofday - $start));
		return $self->done({
			error => "Missing required credentials in Vault",
			output => "Please run 'genesis add-secrets' to generate missing credentials"
		});
	}

	info("#G{done}" . pretty_duration(gettimeofday - $start));

	# Return success with data for post-deploy hook
	return $self->done({
		start_time => gettimeofday,
		vault_prefix => $vault_prefix
	});
}

1;
