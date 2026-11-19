# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Doomsday::Admin v1.0.0;

# Shared lookups for the Doomsday admin credentials.  This is a helper, not
# a hook, so the hooks load it with require.
#
# The admin password is never in exodus.  It lives in the environment's
# secrets, where the kit generated it and where manifests/addons/userpass.yml
# reads it from.  An environment deployed before the kit stopped exporting
# it still has a copy in exodus until it is redeployed, and these lookups
# never use that copy.

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

use Genesis qw/bail/;

# admin_password_secret - where the admin password is stored {{{
# Returns the secrets path and key of the admin password, as (path, key).
sub admin_password_secret {
	my ($env) = @_;
	return ($env->secrets_base . 'users/admin', 'password');
}

# }}}
# admin_password - read the admin password from the secrets store {{{
# Takes the environment and the secrets store, and returns the password.
# Refuses, naming the path and key, when it is not there.
sub admin_password {
	my ($env, $vault) = @_;
	my ($path, $key) = admin_password_secret($env);
	my $password = $vault->get($path, $key);
	_missing($path, $key) unless defined($password) && $password ne '';
	return $password;
}

# }}}
# check_admin_password - confirm the admin password is stored, without reading it {{{
# For hooks that only tell the operator where the password is.  Returns the
# path and key, and refuses, naming them, when the password is not there.
sub check_admin_password {
	my ($env, $vault) = @_;
	my ($path, $key) = admin_password_secret($env);
	_missing($path, $key) unless $vault->has($path, $key);
	return ($path, $key);
}

# }}}
# _missing - refuse because the admin password is not in the secrets store {{{
sub _missing {
	my ($path, $key) = @_;
	bail(
		"Cannot find the Doomsday admin password in the secrets store at #C{%s:%s}.  ".
		"Check that the userpass feature is enabled and that the environment's ".
		"secrets have been added.", $path, $key
	);
}

# }}}

1;
