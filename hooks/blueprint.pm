#!/usr/bin/env perl
package Genesis::Hook::Blueprint::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error in_array/;

my $_addon_features = {
	map {($_,1)} qw(tls lb userpass)
};

my $_virtual_features = {
	map {($_,1)} qw(ocfp sharded-vault-paths)
};

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($blueprint) = @_; # $blueprint is '$self'

	$blueprint->add_files(qw(
		manifests/doomsday.yml
		manifests/releases/doomsday.yml
	));

	# Features pre-check and validation
	my (@features, $abort, $warn) = ();
	for my $feature ($blueprint->features) {
		if (in_array($feature, qw(ocfp sharded-vault-paths))) {
			# Virtual features that don't directly add files
			push @features, $feature;
		} elsif (in_array($feature, qw(tls lb userpass))) {
			# Standard addon features
			push @features, $feature;
		} elsif ($feature =~ /^\+/) {
			# Virtual feature dynamically created based on other features/params
			push @features, $feature;
		} elsif (-f $blueprint->env->path("ops/${feature}.yml")) {
			# Custom ops files from environment
			push @features, $feature;
		} else {
			$abort = 1;
			error(
				"The #c{%s} feature is invalid. Valid features are: ocfp, ".
				"sharded-vault-paths, tls, lb, userpass, or a custom ops file in your ".
				"environment's ops/ directory.",
				$feature
			);
		}
	}

	bail(
		"#R{Cannot continue} - fix your #C{%s} file to resolve these issues.",
		$blueprint->relative_env_path,
	) if $abort;

	info(
		"Update your #C{%s} file to remove these warnings.\n",
		$blueprint->relative_env_path
	) if $warn;

	# Replace given features with the curated list
	$blueprint->set_features(@features);

	# Process features and add corresponding files
	for my $feature ($blueprint->features) {
		if (addon_feature($feature)) {
			$blueprint->add_files("manifests/addons/${feature}.yml");
		} elsif (virtual_feature($feature)) {
			# Virtual features - handled separately
		} elsif (-f $blueprint->env->path("ops/${feature}.yml")) {
			# Custom ops files - already validated above
		} else {
			# This shouldn't happen due to validation above
			$blueprint->kit->kit_bug(
				"Feature '%s' passed validation but has no handler",
				$feature
			);
		}
	}

	# Handle OCFP feature
	if ($blueprint->want_feature('ocfp')) {
		$blueprint->add_files(qw(
			ocfp/ocfp.yml
			ocfp/templates/fqdns.yml
			ocfp/templates/credhub.yml
			ocfp/templates/vault.yml
		));
	}

	return $blueprint->done();
}

sub addon_feature {
  return $_addon_features->{$_[0]};
}

sub virtual_feature {
  return $_virtual_features->{$_[0]} || $_[0] =~ /^\+/;
}

1;

