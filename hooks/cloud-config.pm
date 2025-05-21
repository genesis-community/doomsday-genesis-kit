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
			# For AWS deployments, use naming convention from aws-cloud-config.yml
			$self->network_definition(
				$self->iaas_is('aws') ?
					$self->env->lookup('params.network_name', 'ocfp-mgmt-us-east-1-doomsday') :
					'doomsday',
          strategy => 'ocfp',
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
						aws => {
							'subnet' => $self->network_reference('subnet_id'),
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
					# AWS VM configuration
					# Based on best practices for Doomsday deployments
					# t3.medium for dev environments (2 vCPU, 4 GiB RAM)
					# t3.large for prod environments (2 vCPU, 8 GiB RAM)
					aws => {
						'instance_type' => $self->for_scale({
							dev => 't3.medium',
							prod => 't3.large'
						}, 't3.medium'),
						'ephemeral_disk' => {
							'size' => 32, # in gigabytes
							'type' => 'gp3' # General Purpose SSD with good baseline performance
						},
					},
				},
			),
		],
		'disk_types' => [
			$self->disk_type_definition(
				$self->iaas_is('aws') ?
					$self->for_scale({
						dev => 'doomsday-dev',
						prod => 'doomsday-prod'
					}, 'doomsday-dev') :
					'doomsday',
				common => {
					disk_size => $self->for_scale({
						dev => gigabytes(16),  # 16GB (16384MB) for dev as per aws-cloud-config.yml
						prod => gigabytes(32)  # 32GB (32768MB) for prod as per aws-cloud-config.yml
					}, gigabytes(16)),
				},
				cloud_properties_for_iaas => {
					openstack => {
						'type' => 'storage_premium_perf6',
					},
					stackit => {
						'type' => 'storage_premium_perf6',
					},
					aws => {
						'encrypted' => $self->TRUE, # All disks are encrypted for security
						'type' => 'gp3',           # General Purpose SSD with good baseline performance
					},
				},
			),
		],
		# VM extensions for load balancing (from aws-cloud-config.yml)
		'vm_extensions' => [
			$self->iaas_is('aws') ?
				{
					'name' => 'doomsday-lb',
					'cloud_properties' => {
						'lb_target_groups' => [
							'ocfp-mgmt-doomsday-lb-tg'
						]
					}
				} : (),
		],
	});

	return $self->done($config);
}

1;
