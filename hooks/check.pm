#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Check::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook);

use Genesis qw/info/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->{ok} = 1; # Start assuming all checks will pass
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Removed cloud config checking code as it's now handled separately

	# TODO: Add any customized checks for the Doomsday deployment, if any...

	# Return the final result
	if ($self->{ok}) {
		info("\n#G{All checks passed successfully!}\n");
		$self->env->notify(success => "environment files [#G{OK}]");
	} else {
		$self->env->notify(error => "environment files [#R{FAILED}]");
	}

	return $self->done($self->{ok});
}

1;
