#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Blueprint::Doomsday v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($blueprint) = @_; # $blueprint is '$self'

  # Add base manifests
  $blueprint->add_files(qw(
    manifests/doomsday.yml
    manifests/releases/doomsday.yml
    ));

  # Create dynamic directory if needed
  mkdir "dynamic" unless -d "dynamic";

  # Process features
  foreach my $feature ($blueprint->features) {
    if ($feature eq 'ocfp' || $feature eq 'sharded-vault-paths') {
      # These features don't add files directly
    } elsif ($feature eq 'tls' || $feature eq 'lb' || $feature eq 'userpass') {
      $blueprint->add_files("manifests/addons/${feature}.yml");
    } elsif (-f $blueprint->env->path("ops/${feature}.yml")) {
      $blueprint->add_files($blueprint->env->path("ops/${feature}.yml"));
    } else {
      bail(
        "Feature not found: '%s'",
        $feature
      );
    }
  }

  # Handle OCFP feature
  if ($blueprint->want_feature('ocfp')) {
    $blueprint->add_files("ocfp/ocfp.yml");

    # Get environment names
    my $mgmt_env = $blueprint->env->name;
    my @ocf_envs = ();

    my ($out, $rc) = run('bosh deps --json | jq -r \'.Tables[0].Rows[].name\'');
    @ocf_envs = grep { /-bosh$/ } split /\n/, $out;
    @ocf_envs = map { s/-bosh$//r } @ocf_envs;

    # Process each environment
    foreach my $env_name ($mgmt_env, @ocf_envs) {
      my $env_path = $env_name;
      $env_path =~ s/-/\//g;

      my $vault_prefix = "secret";
      if ($blueprint->want_feature('sharded-vault-paths')) {
        $vault_prefix = $blueprint->vault->get(
          $blueprint->env->secrets_mount . "/" .
          $blueprint->env->name =~ s/-/\//gr .
          "/doomsday/vault/prefixes:${env_name}"
        );
      }

      # Generate dynamic files
      $blueprint->render_template_env_fqdns($env_name, $env_path, $vault_prefix);
      $blueprint->render_template_bosh_credhub($env_name, $env_path, $vault_prefix);
      $blueprint->render_template_env_vault($env_name, $env_path, $vault_prefix);
    }
  }

  return $blueprint->done();
}

sub render_template_env_fqdns {
  my ($self, $env_name, $env_path, $vault_prefix) = @_;

  my $template = "ocfp/templates/fqdns.yml";
  my $outfile = "dynamic/${env_name}-bosh-fqdns.yml";

  # Get FQDNs from vault
  my @fqdns = ();
  # TODO: Handle if vault get fails
  my $ocf_fqdns = $self->vault->get("${vault_prefix}/tf/${env_path}/ocf/fqdns");
  my $mgmt_fqdns = $self->vault->get("${vault_prefix}/tf/${env_path}/mgmt/fqdns");

  # Extract FQDNs from the output
  if ($ocf_fqdns) {
    push @fqdns, map { (split /:\s+/)[1] } split /\n/, $ocf_fqdns;
  }
  if ($mgmt_fqdns) {
    push @fqdns, map { (split /:\s+/)[1] } split /\n/, $mgmt_fqdns;
  }

  return unless @fqdns; # Skip if no FQDNs found

  # Render template
  $self->render_template($template, $outfile, {
      'OCFP_ENV_NAME' => $env_name,
      'OCFP_ENV_PATH' => $env_path,
      'OCFP_VAULT_PREFIX' => $vault_prefix
    });

  # Append FQDNs to the file
  open my $fh, '>>', $outfile or bail("Cannot open $outfile for appending: $!");
  foreach my $fqdn (@fqdns) {
    print $fh "                  - ${fqdn}\n";
  }
  close $fh;

  $self->add_files($outfile);
}

sub render_template_bosh_credhub {
  my ($self, $env_name, $env_path, $vault_prefix) = @_;

  my $template = "ocfp/templates/credhub.yml";
  my $outfile = "dynamic/${env_name}-bosh-credhub.yml";

  $self->render_template($template, $outfile, {
      'OCFP_ENV_NAME' => $env_name,
      'OCFP_ENV_PATH' => $env_path,
      'OCFP_VAULT_PREFIX' => $vault_prefix
    });

  $self->add_files($outfile);
}

sub render_template_env_vault {
  my ($self, $env_name, $env_path, $vault_prefix) = @_;

  my $template = "ocfp/templates/vault.yml";
  my $outfile = "dynamic/${env_name}-vault.yml";

  $self->render_template($template, $outfile, {
      'OCFP_ENV_NAME' => $env_name,
      'OCFP_ENV_PATH' => $env_path,
      'OCFP_VAULT_PREFIX' => $vault_prefix
    });

  $self->add_files($outfile);
}

sub render_template {
  my ($self, $template, $outfile, $vars) = @_;

  # Read template
  open my $in, '<', $template or bail("Cannot open $template for reading: $!");
  my $content = do { local $/; <$in> };
  close $in;

  # Replace variables
  foreach my $key (keys %$vars) {
    my $value = $vars->{$key};
    $content =~ s/\{\{$key\}\}/$value/g;
  }

  # Write output
  open my $out, '>', $outfile or bail("Cannot open $outfile for writing: $!");
  print $out $content;
  close $out;
}

1;

