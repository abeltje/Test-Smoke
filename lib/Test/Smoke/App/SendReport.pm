package Test::Smoke::App::SendReport;
use warnings;
use strict;

use base 'Test::Smoke::App::Base';

use Test::Smoke::Mailer;
use Test::Smoke::Poster;
use Test::Smoke::Reporter;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    if ($self->option('mail')) {
        $self->{_mailer} = Test::Smoke::Poster->new(
            $self->option('poster'),
            $self->options
        );
    }
    $self->{_poster} = Test::Smoke::Mailer->new(
        $self->option('mail_type'),
        $self->options
    );
}

sub run {
    my $self = shift;

    $self->check_for_report_and_json;

    if ($self->option('mail')) {
        $self->mailer->send();
    }

    if ($self->option('smokedb_url')) {
        $self->poster->post();
    }
}

1;
