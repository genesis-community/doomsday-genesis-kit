package Genesis::Hook::Blueprint::Doomsday v1.0.3;

use v5.20;
use warnings;    # Genesis min perl version is 5.20

# Only needed for development
BEGIN { push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME} . '/.genesis/lib' }
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error in_array mkdir_or_fail save_to_yaml_file/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');

	# Initialize OCFP processing state
	$obj->{ops_dir} = $ENV{PREVIOUS_ENV}
		? ".genesis/cached/$ENV{PREVIOUS_ENV}/ops"
		: "ops";

	# Automatically detect explicit vault prefixes (replaces sharded-vault feature)
	$obj->{vault_prefixes} = $obj->env->vault->get($obj->env->secrets_base . 'vault/prefixes') // {};
	$obj->_assess_child_environments();

	return $obj;
}

sub perform {
	my ($self) = @_;

	# Add the base files
	$self->add_files(qw(
		manifests/doomsday.yml
		manifests/releases/doomsday.yml
	));

	if ($self->want_feature('ocfp')) {
		$self->validate_ocfp_features();
		return $self->process_ocfp_features();
	} else {
		$self->validate_classic_features();
		return $self->process_classic_features();
	}
}

sub validate_ocfp_features {
	my ($self) = @_;

	$self->validate_features(
		valid_features => [qw(
			ocfp tls lb userpass sharded-vault-paths
		)]
	);
}


sub validate_classic_features {
	my ($self) = @_;

	$self->validate_features(
		valid_features => [qw(
			tls lb userpass sharded-vault-paths
		)]
	);
}

sub process_classic_features {
	my ($self) = @_;

	# Process addon features
	$self->add_files_if_wants('tls', 'manifests/addons/tls.yml');
	$self->add_files_if_wants('lb', 'manifests/addons/lb.yml');
	$self->add_files_if_wants('userpass', 'manifests/addons/userpass.yml');

	# Process ops files
	$self->_process_ops_files();

	return $self->done();
}

sub process_ocfp_features {
	my ($self) = @_;

	# Process addon features (same as classic - these work with OCFP)
	$self->add_files_if_wants('tls', 'manifests/addons/tls.yml');
	$self->add_files_if_wants('lb', 'manifests/addons/lb.yml');
	$self->add_files_if_wants('userpass', 'manifests/addons/userpass.yml');

	# OCFP-specific processing
	$self->add_files('ocfp/ocfp.yml');
	$self->_process_ocfp_templates();
	$self->_process_ops_files();

	return $self->done();
}

sub _process_ops_files {
	my ($self) = @_;

    for my $feature ($self->features) {
        my $ops_file = "$self->{ops_dir}/${feature}.yml";
        if (-f $self->env->path($ops_file)) {
            $self->add_files($self->env->path($ops_file));
        }
    }
}

# OCFP Template Processing Methods {{{
sub _process_ocfp_templates {
	my ($self) = @_;

	# Ensure dynamic directory exists
	my $dynamic_dir = $self->kit->path('dynamic');
	mkdir_or_fail($dynamic_dir) unless -d $dynamic_dir;

	# Process BOSH director envs (Credhub, FQDNs)
	for my $env_name ($self->{bosh_envs}->@*) {
		my $vault_prefix = $self->{vault_prefixes}{$env_name} // $self->env->secrets_mount;

		$self->add_dynamic_credhub_config($env_name);
		$self->add_dynamic_fqdns_config($env_name);
	}

	# BOSH-deployed Vault envs
	for my $env_name (@{$self->{vault_envs} // []}) {
		$self->add_dynamic_credhub_config($env_name)
	}

	# External Vault envs
	for my $env_name (keys %{$self->{vault_prefixes}//{}}) {
		$self->add_dynamic_external_vault_config($env_name);
	}
	return;
}

sub _assess_child_environments {
	my ($self) = @_;
	my @ocf_envs = ();

	$self->env->notify('assessing deployed environments...');
	push @{$self->{bosh_envs} //= []}, $self->env->name;

	# Get BOSH handle from environment
	my ($rows, $rc, $err) = $self->read_json_from_bosh('deployments');
	if ($rc) {
		info("[[ - >>#Yk{#E{warning} warning:} Could not determine child environments - only monitoring the current management environment");
	} else {
		for my $deployment (@$rows) {
			my $name = $deployment->{name};
			next unless $name;

			if ( $name =~ /^(.+)-bosh$/ ) {
				push @{$self->{bosh_envs}}, $1;
				info("[[  - >>including BOSH director environment '%s'", $1);

			}	elsif ( $name =~ /^(.+)-vault$/ ) {
				push @{$self->{vault_envs}}, $1;
				info("[[ - >>including vault environment '%s'", $1);
			}
		}
	}
	return @ocf_envs;
}

# External Vault Auto-Detection {{{
sub _get_external_vault_configs {
	my ($self) = @_;
	my @vault_configs = ();

	my $prefixes_path = $self->env->secrets_base . "/vault/prefixes";

	if ($self->env->vault->has($prefixes_path)) {
		my $prefixes = $self->env->vault->get($prefixes_path);

		for my $name (keys %$prefixes) {
			my $base_path = $prefixes->{$name};
			my $vault_path = $base_path . "/" . ($name =~ s/-/\//gr);

			info("OCFP:   -> adding external vault '%s' at '%s'", $name, $vault_path);

			push @vault_configs, {
				name => $name,
				base_path => $base_path,
				vault_path => $vault_path
			};
		}
	}

	return @vault_configs;
}
# }}}

sub ocfp_vault_path {
	my ($self, $env_name, $sub_path) = @_;
	my $vault_prefix = $self->{vault_prefixes}{$env_name} // $self->env->secrets_mount;
	$vault_prefix =~ s/\/+$//; # Remove trailing slash(es) if any
	my $ocfp_env_name = $env_name =~ s/-(mgmt|ocf)$//r;
	# FIXME: config should not be hardcoded
	return "${vault_prefix}/config/${ocfp_env_name}/${sub_path}";
}

sub exodus_vault_path {
	my ($self, $env_name, $sub_path) = @_;
	my $vault_prefix = $self->{vault_prefixes}{$env_name} // $self->env->secrets_mount;
	$vault_prefix =~ s/\/+$//; # Remove trailing slash(es) if any
	# FIXME: exodus should not be hardcoded
	return "${vault_prefix}/exodus/${env_name}/${sub_path}";
}

sub _vault_op {
	shift if ref($_[0]); # just in case it was called with $self->
	return '(( vault "'.$_[0].'" ))';
}

# Data Structure Creation Methods {{{
sub _create_credhub_content {
	my ($self, $env_name) = @_;

	return {
		instance_groups => [{
			name => 'doomsday',
			jobs => [{
				name => 'doomsday',
				properties => {
					backends => [
						'(( append ))', {
						type => 'credhub',
						name => "${env_name}-credhub",
						properties => {
							address  => $self->env->vault->get($self->exodus_vault_path($env_name,'bosh:credhub_url')),
							ca_certs => _vault_op($self->exodus_vault_path($env_name,'bosh:credhub_ca_cert')),
							insecure_skip_verify => $self->TRUE,
							auth => {
								grant_type    => 'client_credentials',
								client_id     => _vault_op($self->exodus_vault_path($env_name,'bosh:doomsday_client_id')),
								client_secret => _vault_op($self->exodus_vault_path($env_name,'bosh:doomsday_client_secret'))
							}
						}}]
				}
			}]
		}]
	};
}

sub _create_vault_content {
	my ($self, $env_name) = @_;

	my $env_path = $env_name =~ s{-}{/}gr;
	my $vault_prefix = $self->{vault_prefixes}{$env_name} // $self->env->secrets_mount;

	return {
		instance_groups => [{
			name => 'doomsday',
			jobs => [{
				name => 'doomsday',
				properties => {
					backends => [
						'(( append ))', {
						type => 'vault',
						name => "${env_name}-vault",
						refresh_interval => 60,
						properties => {
							base_path => "${vault_prefix}${env_path}",
							address => "(( vault meta.vault \"/vault:url\" ))",
							ca_certs => "(( vault meta.vault \"/vault:ca\" ))",
							namespace => "(( vault meta.vault \"/vault:namespace\" ))",
							insecure_skip_verify => $self->TRUE,
							trace => $self->TRUE,
							auth => {
								role_id => "(( vault meta.vault \"/vault:approle_id\" ))",
								secret_id => "(( vault meta.vault \"/vault:approle_secret\" ))"
							}
						}}]}}]}]
	};
}

sub _create_vault_ext_content {
	my ($self, $env_name) = @_;

	my $env_path = $env_name =~ s{-}{/}gr;
	my $vault_prefix = $self->{vault_prefixes}{$env_name} // $self->env->secrets_mount;

	return {
		instance_groups => [{
			name => 'doomsday',
			jobs => [{
				name => 'doomsday',
				properties => {
					backends => [
						'(( append ))', {
						type => 'vault',
						name => "${env_name}-vault",
						refresh_interval => 60,
						properties => {
							base_path => "${vault_prefix}/${env_path}",
							address => "(( vault meta.vault \"/vault:url\" ))",
							ca_certs => "(( vault meta.vault \"/vault:ca\" ))",
							namespace => "(( vault meta.vault \"/vault:namespace\" ))",
							insecure_skip_verify => $self->TRUE,
							trace => $self->TRUE,
							auth => {
								role_id => "(( vault meta.vault \"/vault:approle_id\" ))",
								secret_id => "(( vault meta.vault \"/vault:approle_secret\" ))"
							}
						}}]}}]}]
	};
}

sub _create_fqdns_content {
	my ($self, $env_name) = @_;

	# The fqdns records hold one hostname per service plus metadata such as
	# env_type, so only keep values that look like hostnames.
	my %fqdns = ();
	for my $type (qw/mgmt ocf/) {
		my $fqdn_data = $self->env->vault->get($self->ocfp_vault_path($env_name,"$type/fqdns"));
		next unless $fqdn_data;
		for my $key (keys %$fqdn_data) {
			my $value = $fqdn_data->{$key};
			next if $key eq 'env_type';
			next unless defined($value) && !ref($value) && $value =~ /^[a-z0-9_-]+(\.[a-z0-9_-]+)+$/i;
			$fqdns{$value} = 1;
		}
	}
	my @fqdns = sort keys %fqdns;

	return undef unless @fqdns;

	# Child directors in the same bloc resolve to the same fqdns records, so
	# skip a backend that would probe an identical host list.
	my $host_set = join(',', @fqdns);
	return undef if $self->{fqdn_host_sets}{$host_set}++;

	return {
		instance_groups => [{
			name => 'doomsday',
			jobs => [{
				name => 'doomsday',
				properties => {
					backends => [
						'(( append ))', {
						type => 'tlsclient',
						name => "${env_name}-fqdns",
						properties => {
							timeout => 20,
							hosts => \@fqdns
		}}]}}]}]
	};
}
# }}}

sub _add_dynamic_config {
  my ($self, $content, $env_name, $suffix) = @_;

	return unless $content;

	my $filename = "dynamic/$env_name";
	$filename .= "-$suffix" if $suffix;
	$filename .= ".yml" unless $filename =~ /\.yml$/;

	save_to_yaml_file($content, $self->kit->path($filename));
	$self->add_files($filename);
}

# Configuration Creation and Saving Methods {{{
sub add_dynamic_credhub_config {
	my ($self, $env_name) = @_;
	$self->_add_dynamic_config(
		$self->_create_credhub_content($env_name),
		$env_name,
		'credhub'
	);
}

sub add_dynamic_vault_config {
	my ($self, $env_name) = @_;

	$self->_add_dynamic_config(
		$self->_create_vault_content($env_name),
		$env_name,
		'vault'
	)
}

sub add_dynamic_external_vault_config {
	my ($self, $env_name) = @_;

	$self->_add_dynamic_config(
		$self->_create_vault_ext_content($env_name),
		$env_name,
		'vault-external'
	);
}

sub add_dynamic_fqdns_config {
	my ($self, $env_name) = @_;

	$self->_add_dynamic_config(
		$self->_create_fqdns_content($env_name),
		$env_name,
		'fqdn'
	);
}
# }}}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
