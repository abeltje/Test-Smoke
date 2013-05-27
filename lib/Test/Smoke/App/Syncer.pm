package Test::Smoke::App::Syncer;
use warnings;
use strict;

use base 'Test::Smoke::App::Base';

use Test::Smoke::Syncer;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{_syncer} = Test::Smoke::Syncer->new(
        $self->option('syncer'),
        $self->options,
        v => $self->option('verbose'),
    );

    return $self;
}

sub run {
    my $self = shift;

    my $patchlevel = $self->syncer->sync();
    $self->log_info(
        "%s is now up to patchlevel %s",
        $self->option('ddir'),
        $patchlevel
    );
}

1;
