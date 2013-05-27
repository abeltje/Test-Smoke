package Test::Smoke::App::Archiver;
use warnings;
use strict;

use base 'Test::Smoke::App::Base';

use Test::Smoke::Archiver;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{_archiver} = Test::Smoke::Archiver->new(
        $self->options,
        v => $self->option('verbose'),
    );

    return $self;
}

sub run {
    my $self = shift;

    $self->archiver->archive_files();
}

1;
