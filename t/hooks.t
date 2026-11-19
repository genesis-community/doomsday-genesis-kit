#!/usr/bin/env perl
# Tests for the hooks that use the Doomsday admin credentials.  Run with:
#   GENESIS_LIB=<genesis>/lib prove t/
use strict;
use warnings;
use v5.20;
use Test::More;
use File::Basename qw/dirname/;
use File::Spec;
use File::Temp qw/tempdir/;

BEGIN { unshift @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib' }

my $hooks = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'hooks'));

my $path       = '/secret/base/doomsday/users/admin';
my $vault_pw   = 'pw-from-vault';
my $exodus_pw  = 'stale-pw-from-exodus';

# A stand-in environment.  Its exodus data still holds the admin password,
# as an environment deployed before the kit stopped exporting it does, so a
# test fails if a hook uses that copy.
package FakeEnv {
	sub new {
		my ($class, %o) = @_;
		return bless {
			name   => 'base',
			exodus => {
				url            => 'https://doomsday.example.com',
				admin_username => 'admin',
				admin_password => $exodus_pw,
			},
			%o
		}, $class;
	}
	sub name         { $_[0]{name} }
	sub secrets_base { '/secret/base/doomsday/' }
	sub exodus_lookup {
		my ($self, $key, $default) = @_;
		return {%{$self->{exodus}}} if $key eq '.';
		return exists $self->{exodus}{$key} ? $self->{exodus}{$key} : $default;
	}
	sub secrets_store { FakeStore->new($_[0]{vault}) }
	sub bosh          { FakeBosh->new }
	sub get_call_path_with_env { 'genesis base' }
}

package FakeStore {
	sub new     { bless {vault => $_[1]}, $_[0] }
	sub service { $_[0]{vault} }
}

package FakeBosh {
	sub new     { bless {}, $_[0] }
	sub execute { ("Name  test-director", 0, '') }
}

package FakeVault {
	sub new { bless {data => $_[1], reads => []}, $_[0] }
	sub get {
		my ($self, $p, $key) = @_;
		push @{$self->{reads}}, "get $p:$key";
		return $self->{data}{"$p:$key"};
	}
	sub has {
		my ($self, $p, $key) = @_;
		push @{$self->{reads}}, "has $p:$key";
		return exists $self->{data}{"$p:$key"} ? 1 : 0;
	}
}

package main;

my $good_vault  = sub { FakeVault->new({"$path:password" => $vault_pw}) };
my $empty_vault = sub { FakeVault->new({}) };

# The shared helper
{
	require "$hooks/_admin.pm";
	my $admin = 'Genesis::Hook::Doomsday::Admin';

	my $env = FakeEnv->new;
	is_deeply([$admin->can('admin_password_secret')->($env)], [$path, 'password'],
		'the password is at users/admin:password under the secrets base');

	my $vault = $good_vault->();
	is($admin->can('admin_password')->($env, $vault), $vault_pw,
		'the password is read from the secrets store');
	is_deeply($vault->{reads}, ["get $path:password"], 'the secrets store is read at the userpass path');

	eval { $admin->can('admin_password')->($env, $empty_vault->()) };
	like($@, qr{\Q$path:password\E}, 'a missing password is refused with its path and key');
	unlike($@, qr/\Q$exodus_pw\E/, 'the refusal does not fall back to exodus');

	eval { $admin->can('check_admin_password')->($env, $empty_vault->()) };
	like($@, qr{\Q$path:password\E}, 'the presence check names the path and key');
	ok(eval { $admin->can('check_admin_password')->($env, $good_vault->()); 1 },
		'the presence check passes when the password is stored');
}

# login sends the password on stdin, never on the command line
{
	require "$hooks/addon-login~li.pm";
	my $class = 'Genesis::Hook::Addon::Doomsday::Login';
	my (@runs, @shown);
	no warnings qw(redefine once);
	local *Genesis::Hook::Addon::Doomsday::Login::run = sub {
		my @a = @_;
		my $opts = ref($a[0]) eq 'HASH' ? shift @a : {};
		push @runs, {opts => $opts, args => [@a]};
		return ("{\"token\":\"jwt-token\"}\n200", 0, '');
	};
	local *Genesis::Hook::Addon::Doomsday::Login::curl = sub {
		die "login must not use Genesis::curl, which puts the body on the command line\n";
	};
	local *Genesis::Hook::Addon::Doomsday::Login::info    = sub { push @shown, join(' ', map {$_ // ''} @_) };
	local *Genesis::Hook::Addon::Doomsday::Login::success = sub { push @shown, join(' ', map {$_ // ''} @_) };
	local $ENV{HOME} = tempdir(CLEANUP => 1);

	my $self = bless {env => FakeEnv->new, args => [], vault => $good_vault->()}, $class;
	my $ok = eval { $self->perform; 1 };
	ok($ok, 'login completes') or diag $@;
	is(scalar(@runs), 1, 'login runs one command');
	my $cmdline = join(' ', @{$runs[0]{args} // []});
	unlike($cmdline, qr/\Q$vault_pw\E/, 'the password is on no command line');
	unlike($cmdline, qr/\Q$exodus_pw\E/, 'the exodus copy is on no command line');
	like($cmdline, qr{https://doomsday\.example\.com/v1/auth}, 'login posts to the auth endpoint');
	like($runs[0]{opts}{stdin} // '', qr/"password":"\Q$vault_pw\E"/, 'the password from the secrets store goes on stdin');
	unlike(join("\n", @shown), qr/\Q$vault_pw\E|\Q$exodus_pw\E/, 'the password is not shown');
	ok(-f "$ENV{HOME}/.dday", 'the token is saved to ~/.dday');

	@runs = ();
	$self = bless {env => FakeEnv->new, args => [], vault => $empty_vault->()}, $class;
	eval { $self->perform };
	like($@, qr{\Q$path:password\E}, 'login without a stored password is refused with its path and key');
	is(scalar(@runs), 0, 'login does not contact Doomsday without the password');
}

# open names where the password is, and does not show it
{
	require "$hooks/addon-open~o.pm";
	my $class = 'Genesis::Hook::Addon::Doomsday::Open';
	my @shown;
	no warnings qw(redefine once);
	local *Genesis::Hook::Addon::Doomsday::Open::info = sub {
		my ($fmt, @args) = @_;
		push @shown, sprintf($fmt, map {$_ // ''} @args);
	};
	# report the browser command as missing, so nothing is opened
	local *Genesis::Hook::Addon::Doomsday::Open::run = sub { return ('', 1) };

	my $vault = $good_vault->();
	my $self  = bless {env => FakeEnv->new, args => [], vault => $vault}, $class;
	my $ok = eval { $self->perform; 1 };
	ok($ok, 'open completes') or diag $@;
	my $shown = join("\n", @shown);
	unlike($shown, qr/\Q$vault_pw\E|\Q$exodus_pw\E/, 'open does not show the password');
	like($shown, qr{\Q$path:password\E}, 'open names the path and key of the password');
	ok(!grep({/^get /} @{$vault->{reads}}), 'open does not read the password value');

	$self = bless {env => FakeEnv->new, args => [], vault => $empty_vault->()}, $class;
	eval { $self->perform };
	like($@, qr{\Q$path:password\E}, 'open without a stored password is refused with its path and key');
}

# info names where the password is, and does not show it
{
	require "$hooks/info.pm";
	my $class = 'Genesis::Hook::Info::Doomsday';
	my @shown;
	no warnings qw(redefine once);
	local *Genesis::Hook::Info::Doomsday::info = sub {
		my ($fmt, @args) = @_;
		push @shown, sprintf($fmt, map {$_ // ''} @args);
	};

	my $vault = $good_vault->();
	my $self  = bless {env => FakeEnv->new(vault => $vault)}, $class;
	my $ok = eval { $self->perform; 1 };
	ok($ok, 'info completes') or diag $@;
	my $shown = join("\n", @shown);
	unlike($shown, qr/\Q$vault_pw\E|\Q$exodus_pw\E/, 'info does not show the password');
	like($shown, qr{\Q$path:password\E}, 'info names the path and key of the password');
	like($shown, qr/admin/, 'info shows the username');
	ok(!grep({/^get /} @{$vault->{reads}}), 'info does not read the password value');

	$self = bless {env => FakeEnv->new(vault => $empty_vault->())}, $class;
	eval { $self->perform };
	like($@, qr{\Q$path:password\E}, 'info without a stored password is refused with its path and key');
}

done_testing;
