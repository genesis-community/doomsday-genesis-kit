# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Check::Doomsday;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Check);

use Genesis qw/info/;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->{ok} = 1; # Start assuming all checks will pass
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

sub perform {
	my ($self) = @_;

	# Removed cloud config checking code as it's now handled separately

	# TODO: Add any customized checks for the Doomsday deployment, if any...

	# Return the final result
	if ($self->{ok}) {
		info("\n#G{All checks passed successfully!}\n");
		$self->env->notify(success => "environment files [#G{OK}]");
	} else {
		$self->env->notify(error => "environment files [#R{FAILED}]");
	}

	return $self->done($self->{ok});
}

1;
