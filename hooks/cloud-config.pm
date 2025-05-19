#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::CloudConfig::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

	my $network = 'default';
	my $vm_type = 'default';
	my $disk_type = 'default';

	if ($self->want_feature('ocfp')) {
		my $env_scale = $self->env->lookup('params.ocfp_env_scale', 'dev');
		$vm_type = "default-${env_scale}";
		$disk_type = "default-${env_scale}";
		$network = $self->env->name . "-doomsday";
	}

	# Use values from params if specified
	$network = $self->env->lookup('params.network', $network);
	$vm_type = $self->env->lookup('params.vm_type', $vm_type);
	$disk_type = $self->env->lookup('params.disk_type', $disk_type);

	my $config = $self->build_cloud_config({
		'networks' => [
			$self->network_definition('doomsday', strategy => 'ocfp',
				dynamic_subnets => {
					allocation => {
						size => 0,
						statics => 0,
					},
					cloud_properties_for_iaas => {
						openstack => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => ['default']
						},
						stackit => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => ['default']
						},
					},
				},
			)
		],
		'vm_types' => [
			$self->vm_type_definition('doomsday',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'm1.2',
							prod => 'm1.3'
						}, 'm1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 32 # in gigabytes
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 'm1.2',
							prod => 'm1.3'
						}, 'm1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 32 # in gigabytes
						},
					},
				},
			),
		],
		'disk_types' => [
			$self->disk_type_definition('doomsday',
				common => {
					disk_size => $self->for_scale({
						dev => gigabytes(64),
						prod => gigabytes(128)
					}, gigabytes(64)),
				},
				cloud_properties_for_iaas => {
					openstack => {
						'type' => 'storage_premium_perf6',
					},
					stackit => {
						'type' => 'storage_premium_perf6',
					},
				},
			),
		],
	});

	return $self->done($config);
}

1;