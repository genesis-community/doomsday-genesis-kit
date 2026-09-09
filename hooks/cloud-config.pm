package Genesis::Hook::CloudConfig::Doomsday v1.0.3;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw/bail/;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub perform {
	my ($self) = @_;
	return 1 if $self->completed;

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
							'security_groups' => ['default'],
						},
						stackit => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => $self->network_reference('sgs', 'get_sgs_by_names', 'ocfp', 'default'),
						},
						aws => {
							'subnet' => $self->subnet_reference('id'),
						},
						pve => {
							'bridge' => $self->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0'),
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
							prod => 'm1.2'
						}, 'm1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 16 # in gigabytes
						},
					},
					aws => {
						'instance_type' => $self->for_scale({
							dev => 't3.medium',
							prod => 'm6i.large'
						}, 't3.medium'),
						'ephemeral_disk' => {
							'encrypted' => $self->TRUE,
							'size' => $self->for_scale({
								dev => 4096,
								prod => 16384
							}, 4096),
							'type' => 'gp3'
						},
						'metadata_options' => {
							'http_tokens' => 'required'
						},
					},
					pve => {
						'cpu'            => scalar($self->env->lookup('bosh-configs.cpi.pve_doomsday_cpu', $self->for_scale({ dev => 2, prod => 4 }, 2))),
						'ram'            => scalar($self->env->lookup('bosh-configs.cpi.pve_doomsday_ram', $self->for_scale({ dev => 4096, prod => 8192 }, 4096))),
						'disk'           => scalar($self->env->lookup('bosh-configs.cpi.pve_doomsday_disk', $self->for_scale({ dev => 32768, prod => 65536 }, 32768))),
						'network_bridge' => $self->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0'),
					},
				},
			),
		],
		'disk_types' => [
			$self->disk_type_definition('doomsday',
				common => {
					disk_size => $self->for_scale({
						dev => gigabytes(16),
						prod => gigabytes(32)
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
						'encrypted' => $self->TRUE,
						'type' => 'gp3',
					},
					pve => {
						'storage'     => $self->_pve_cpi_setting('pve_disk_storage', 'disk_storage', 'local-lvm'),
						'disk_format' => scalar($self->env->lookup('bosh-configs.cpi.pve_disk_format', 'raw')),
					},
				},
			),
		],
                # VM extensions for load balancing (from aws-cloud-config.yml)
 		'vm_extensions' => [
			$self->vm_extension_definition('doomsday-lb' => {
					aws => {
						'lb_target_groups' => [
							'ocfp-mgmt-doomsday-lb-tg',
						],
					},
				},
			),
		],
	});

	$self->done($config);

	return 1;

}

sub get_sgs_by_names {
	my ($self, $subnet_data, $ref, @names) = @_;
	my @ids = map {$subnet_data->{$ref}{$_}{id}} @names;
	# TODO: Error checking
	return \@ids
}


# _pve_cpi_setting - resolve a PVE CPI setting from the env file, then the OCFP vault config, then a default {{{
sub _pve_cpi_setting {
	my ($self, $env_key, $vault_key, $default) = @_;
	my $value = scalar($self->env->lookup("bosh-configs.cpi.$env_key", undef));
	$value //= scalar($self->env->ocfp_config_lookup("cpi.pve.$vault_key", undef));
	$value //= $default;
	bail(
		"No PVE %s configured for %s: set #c{bosh-configs.cpi.%s} in the ".
		"environment file, or run #g{ocfp vault populate} so the OCFP config ".
		"provides #c{cpi/pve:%s}.",
		$vault_key, $self->env->name, $env_key, $vault_key
	) unless defined($value) && length($value);
	return $value;
}

# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
