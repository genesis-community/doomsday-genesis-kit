package Genesis::Hook::Addon::Doomsday::SetupApprole;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use Genesis::UI qw/prompt_for_boolean/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return
  "\nCreate the necessary Vault AppRole and policy for Genesis Doomsday deployments.\n".
  "Unlike other addons, this can and should be run before deployment.\n".
  "\n".
  "This will setup up the app roles and policies for doomsday.\n".
  "The doomsday app role will provide doomsday access to vault paths for reading\n".
  "to check certificates.\n"
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  info(
    "\nThis will setup up the app roles and policies for doomsday and".
    "\ngenesis-pipelines. The doomsday app role will provide doomsday access to".
    "\nvault paths to read and examine certificates.\n"
  );

  # Check if AppRole is enabled
  info("Ensuring Vault AppRole is enabled...");
  my $result = $self->vault->query("vault","auth","enable","approle");

  my @roles = ();
  if ($result =~ /(Success\! Enabled approle auth method)/) {
    info("#G{[ok - successfully enabled approle]}");
  } elsif ($result =~ /(path is already in use)/) {
    info("#G{[ok - approle already enabled]}");
    info("Checking for existing roles...");
    my $roles_output = $self->vault->query("ls","auth/approle/role","-1");
    @roles = split(/\n/, $roles_output);
    info("#G{[ok - " . scalar(@roles) . " role(s) found]}");
  } else {
    bail("#R{[error]}\nFailed to enable app role on your targeted Vault:\n$result\n");
  }

  # Setup doomsday approle
  my $create_doomsday = prompt_for_boolean("Do you want to install the #C{doomsday} app role? [Y/N]", 0);
  if ($create_doomsday) {
    $self->_setup_doomsday_approle(\@roles);
  }

  return $self->done();
}

sub _setup_doomsday_approle {
  my ($self, $roles_ref) = @_;
  my $approle = 'doomsday';

  # Check if role already exists
  if (grep { $_ eq $approle } @$roles_ref) {
    info("#y{[WARNING]} App role #C{$approle} already exists. This action will overwrite it...");
    my $continue = "";
    prompt_for_boolean( "Continue?", 0);
    return 0 if $continue ;
  }

  info("Creating #C{doomsday} policy...");
  my $policy = "";
  $policy .= "# List, create, update, and delete key/value secrets for Doomsday\n";
  my $capabilities = ' { capabilities = [ "read", "list" ] }';

  my $sec_info = $self->_match_mount($ENV{GENESIS_SECRETS_MOUNT});
  if (!$sec_info) {
    bail("#R{[error]}\nCannot find mount for secrets path of '$ENV{GENESIS_SECRETS_MOUNT}'");
  }
  my ($sec_mnt, $sec_path, $sec_ver) = @$sec_info;

  my $exo_info = $self->_match_mount($ENV{GENESIS_EXODUS_MOUNT});
  if (!$exo_info) {
    bail("#R{[error]}\nCannot find mount for exodus path of '$ENV{GENESIS_EXODUS_MOUNT}'");
  }
  my ($exo_mnt, $exo_path, $exo_ver) = @$exo_info;

  my $mount_type = $sec_ver == 1 ? "kv_v1" : "kv_v2";
  if ($mount_type eq "kv_v1") {
    $policy .= "path \"$sec_mnt*\"$capabilities\n";
    $policy .= "path \"$exo_mnt*\"$capabilities\n";
  } else {
		# Secrets
    $policy .= "path \"${sec_mnt}data/*\"$capabilities\n";
    $policy .= "path \"${sec_mnt}metadata/*\"$capabilities\n";
		# Exodus
    $policy .= "path \"${exo_mnt}data/*\"$capabilities\n";
    $policy .= "path \"${exo_mnt}metadata/*\"$capabilities\n";
  }

	info("#Y{Policy file being applied to Doomsday}\n\n%s\n\n", $policy);

	# Write policy to file
  open(my $fh, '>', '/tmp/policy.hcl') or bail("#R{[error]}\nFailed to write policy to /tmp/policy.hcl: $!");
  print $fh $policy;
  close($fh);

  my $rc = $self->vault->query("vault","policy","write","doomsday","/tmp/policy.hcl");
	info("Output: %s", $rc);
	bail("#R{[error]}\nFailed to save #C{doomsday} policy.") unless $rc =~ /Success/x;

  info("#G{[ok]}");
  info("#wui{Policy for $approle}\n#K{$policy}\n");

  # Create app role
  info("Creating and configuring app role #C{$approle}...");
  $self->vault->query("vault","delete","auth/approle/role/$approle");

  $rc = $self->vault->set(
    "auth/approle/role/$approle",
    "secret_id_ttl", "0",
    "token_num_uses", "0",
    "token_period", "3600",
    "token_ttl", "3600",
    "token_max_ttl", "0",
    "secret_id_num_uses", "0",
    "policies", "doomsday"
  );

  if ($rc != 0) {
    bail("#R{[error]}\nFailed to create #C{$approle} approle.");
  }
  info("#G{[ok]}");

  # Generate credentials
  info("Generating and storing authentication credentials...");
  my $role_id = $self->vault->get("auth/approle/role/$approle/role-id:role_id");
  my $approle_secret = $self->vault->query("vault","write","-field=secret_id","-f","auth/approle/role/$approle/secret-id");

  # Store credentials
	my $env_path = $self->env->secrets_base;
  my $doomsday_approle_path = "${env_path}/vault";
  $self->vault->set("${doomsday_approle_path}", "approle_id", "$role_id");
  $self->vault->set("${doomsday_approle_path}", "approle_secret", "$approle_secret");

  info("#G{[ok]} Access credentials written to #M{$doomsday_approle_path}");
  info("#G{[DONE]} App role #C{$approle} created.");

  return 1;
}

sub _match_mount {
  my ($self, $path) = @_;
  my $output = $self->vault->query("vault","secrets","list","--detailed");

  # Get all kv mounts with versions
  my @mounts = ();
  my @lines = split(/\n/, $output);
  for my $line (@lines) {
    if ($line =~ /^(\/?)([^\/].*\/)  *kv  *.*map\[version:([12])\]/) {
      push @mounts, [ "/$2", $3 ];
    }
  }

  # Find best match
  for my $mount_info (@mounts) {
    my ($mount, $version) = @$mount_info;
    if ($path =~ /^$mount(.*)/) {
      my $subpath = $1 || "";
      $subpath =~ s/^\///;
      return [ $mount, $subpath, $version ];
    }
  }

  return undef;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
