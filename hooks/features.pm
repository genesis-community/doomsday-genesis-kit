#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Process each requested feature
	foreach my $feature (@{$self->{features}}) {
		if ($feature eq 'ocfp') {
			# Add the OCFP feature
			$self->add_feature($feature);

			# Add default features for OCFP Reference Architecture
			foreach my $f (qw(userpass tls lb)) {
				$self->add_feature($f) unless $self->has_feature($f);
			}
		} else {
			# Add all other features as-is
			$self->add_feature($feature);
		}
	}

	# Build and return the features list
	return $self->done($self->build_features_list());
}

1;
