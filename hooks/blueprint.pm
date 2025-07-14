package Genesis::Hook::Blueprint::Doomsday;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error in_array mkdir_or_fail/;

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
		));
		$blueprint->_process_ocfp_templates();
	}

	return $blueprint->done();
}

# OCFP Template Processing Methods {{{
sub _process_ocfp_templates {
	my ($self) = @_;
	
	# Get management environment and OCF environments from BOSH deployments
	my $mgmt_env = $self->env->name;
	my @ocf_envs = $self->_get_ocf_environments();
	
	# Process templates for each environment
	for my $env_name ($mgmt_env, @ocf_envs) {
		my $env_path = $env_name =~ s/-/\//gr;
		my $vault_prefix = $self->_get_vault_prefix($env_name);
		
		# Render templates for this environment
		my @rendered_files = ();
		
		# Always render vault template
		push @rendered_files, $self->_render_ocfp_template('vault', $env_name, $env_path, $vault_prefix);
		
		# Render credhub template
		push @rendered_files, $self->_render_ocfp_template('credhub', $env_name, $env_path, $vault_prefix);
		
		# Render FQDNs template if FQDNs exist
		my $fqdns_file = $self->_render_fqdns_template($env_name, $env_path, $vault_prefix);
		push @rendered_files, $fqdns_file if $fqdns_file;
		
		# Add all rendered files to the blueprint
		$self->add_files(@rendered_files);
	}
}

sub _get_ocf_environments {
	my ($self) = @_;
	my @ocf_envs = ();
	
	# Get BOSH handle from environment
	eval {
		my $bosh = $self->env->bosh;
		
		# Execute bosh deployments command
		my ($out, $rc, $err) = $bosh->execute('deployments', '--json');
		
		if ($rc == 0 && $out) {
			# Parse JSON output to extract OCF environment names
			require JSON;
			my $data = JSON::decode_json($out);
			
			# BOSH deployments --json returns an array of deployment objects
			if ($data && ref($data) eq 'ARRAY') {
				for my $deployment (@$data) {
					if ($deployment->{name} && $deployment->{name} =~ /^(.+)-bosh$/) {
						push @ocf_envs, $1;
					}
				}
			}
		}
	};
	if ($@) {
		warning("Failed to get BOSH deployments: $@");
		info("Only monitoring the current management environment");
	}
	
	return @ocf_envs;
}

sub _get_vault_prefix {
	my ($self, $env_name) = @_;
	
	if ($self->want_feature('sharded-vault-paths')) {
		# Not recommended, but supported for backward compatibility
		my $path = sprintf("%s/doomsday/vault/prefixes",
			$self->env->name =~ s/-/\//gr
		);
		
		# Get vault handle and retrieve the prefix
		my $vault = $self->env->vault;
		my $prefix = $vault->get("$path:$env_name");
		
		if ($prefix) {
			return $prefix;
		}
	}
	
	# Return empty string since Genesis handles the vault mount/prefix
	return "";
}

sub _render_ocfp_template {
	my ($self, $template_name, $env_name, $env_path, $vault_prefix) = @_;
	
	my $srcdir = 'ocfp/templates';
	my $dstdir = 'dynamic';
	my $src = "$srcdir/${template_name}.yml";
	my $dst = "$dstdir/${env_name}-${template_name}.yml";
	
	# Ensure dynamic directory exists in kit's working directory
	my $kit_dynamic_dir = $self->kit->path($dstdir);
	mkdir_or_fail($kit_dynamic_dir) unless -d $kit_dynamic_dir;
	
	# Read template and substitute variables
	my $src_path = $self->kit->path($src);
	my $dst_path = $self->kit->path($dst);  # Changed from $self->env->path
	
	open my $src_fh, '<', $src_path or bail("Cannot open template $src: $!");
	open my $dst_fh, '>', $dst_path or bail("Cannot open output file $dst: $!");
	
	while (my $line = <$src_fh>) {
		$line =~ s/\{\{OCFP_ENV_NAME\}\}/$env_name/g;
		$line =~ s/\{\{OCFP_ENV_PATH\}\}/$env_path/g;
		$line =~ s/\{\{OCFP_VAULT_PREFIX\}\}/$vault_prefix/g;
		print $dst_fh $line;
	}
	
	close $src_fh;
	close $dst_fh;
	
	return $dst;
}

sub _render_fqdns_template {
	my ($self, $env_name, $env_path, $vault_prefix) = @_;
	
	# Get FQDNs from vault for both OCF and management environments
	my @fqdns = ();
	my $vault = $self->env->vault;
	
	for my $env_type ('ocf', 'mgmt') {
		my $path = "tf/${env_path}/${env_type}/fqdns";
		
		# Check if path exists first
		if ($vault->has($path)) {
			my $data = $vault->get($path);
			
			# Handle different data formats
			if ($data) {
				if (ref($data) eq 'HASH') {
					# If it's a hash, get all values
					push @fqdns, values %$data;
				} elsif (!ref($data)) {
					# If it's a scalar, add it directly
					push @fqdns, $data;
				}
			}
		}
	}
	
	# Only render template if we found FQDNs
	return unless @fqdns;
	
	# Render the base template
	my $dst = $self->_render_ocfp_template('fqdns', $env_name, $env_path, $vault_prefix);
	
	# Append the FQDNs to the rendered file
	open my $fh, '>>', $self->kit->path($dst) or bail("Cannot append to $dst: $!");
	for my $fqdn (@fqdns) {
		print $fh "                  - $fqdn\n";
	}
	close $fh;
	
	return $dst;
}
# }}}

sub addon_feature {
  return $_addon_features->{$_[0]};
}

sub virtual_feature {
  return $_virtual_features->{$_[0]} || $_[0] =~ /^\+/;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
