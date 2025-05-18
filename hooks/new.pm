#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/run bail/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Create the environment file
	my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
	open my $fh, '>', $env_file or bail("Cannot open $env_file for writing: $!");

	print $fh "kit:\n";
	print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
	print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
	print $fh "  features:\n";
	print $fh "    - (( replace ))\n\n";

	# Get the genesis_config_block
	my ($out, $rc) = run('genesis_config_block');
	bail("Failed to generate genesis_config_block") if $rc;
	print $fh $out;

	print $fh "params: {}\n";

	close $fh;

	# Offer environment editor
	run({ interactive => 1 }, 'offer_environment_editor true');

	return $self->done(1);
}

1;
