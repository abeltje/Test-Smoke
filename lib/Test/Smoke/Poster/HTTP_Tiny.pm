package Test::Smoke::Poster::HTTP_Tiny;
use warnings;
use strict;
use Carp;

use base 'Test::Smoke::Poster::Base';

use HTTP::Tiny;
use JSON;

=head1 NAME

Test::Smoke::Poster::HTTP_Tiny - Poster subclass using HTTP::Tiny.

=head1 DESCRIPTION

This is a subclass of L<Test::Smoke::Poster::Base>.

=head2 Test::Smoke::Poster::HTTP_Tiny->new(%arguments)

=head3 Extra Arguments

None.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{_ua} = HTTP::Tiny->new(
        agent => $self->agent_string()
    );

    return $self;
}

=head2 $poster->post()

Post the json to CoreSmokeDB.

=cut

sub post {
    my $self = shift;

    my $response = $self->ua->post_form(
        $self->smokedb_url,
        { json => $self->get_json() },
    );

    if (!$response->{success}) {
        $self->log_info(
            "POST failed: %s %s",
            $response->{status},
            $response->{reason}
        );
        return;
    }
    my $body = decode_json($response->{content});
    if (exists $body->{error}) {
        $self->log_info("CoreSmokeDB: %s", $body->{error});
        return;
    }
    return $body->{id};
}

1;
