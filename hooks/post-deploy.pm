#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::PostDeploy);

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

	# Extract data from pre-deploy hook if available
	my $pre_deploy_data = $self->{data} || {};
	my $vault_prefix = $pre_deploy_data->{vault_prefix} || $self->env->secrets_base;

	# Check if deployment was successful
	if ($self->deploy_successful) {
		# Calculate deployment duration if start_time was provided
		my $duration_msg = "";
		if ($pre_deploy_data->{start_time}) {
			my $duration = gettimeofday - $pre_deploy_data->{start_time};
			$duration_msg = sprintf(" (deployed in %.1f seconds)", $duration);
		}

		# Display success message with helpful information
		info("\n#M{%s} Doomsday deployed successfully!%s\n\n".
			 "For details about the deployment, run:\n\n".
			 "  #G{%s info}\n\n".
			 "Available commands:\n\n".
			 "  #G{%s do -- login}      # Log into Doomsday\n".
			 "  #G{%s do -- open}       # Open the Doomsday web UI\n\n",
			 $self->env->name,
			 $duration_msg,
			 $self->command(),
			 $self->command(),
			 $self->command());
	} else {
		info("\n#R{Deployment failed!} Please check the logs for more information.\n");
	}

	# Call parent class perform if it exists
	$self->SUPER::perform() if $self->can('SUPER::perform');

	return $self->done(1);
}

1;
