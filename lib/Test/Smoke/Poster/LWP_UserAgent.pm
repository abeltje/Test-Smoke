package Test::Smoke::Poster::LWP_UserAgent;
use warnings;
use strict;

use base 'Test::Smoke::Poster::Base';

use JSON;
use LWP::UserAgent;

=head1 NAME

Test::Smoke::Poster::LWP_UserAgent - Poster subclass using LWP::UserAgent.

=head1 DESCRIPTION

This is a subclass of L<Test::Smoke::Poster::Base>.

=head2 Test::Smoke::Poster::LWP_UserAgent->new(%arguments)

=head3 Extra Arguments

=over

=item ua_timeout => a timeout te feed to L<LWP::UserAgent>.

=back

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my %extra_args;
    if (defined $self->ua_timeout) {
        $extra_args{timeout} = $self->ua_timeout;
    }
    $self->{_ua} = LWP::UserAgent->new(
        agent => $self->agent_string(),
        %extra_args
    );

    return $self;
}

=head2 $poster->post()

Post the json to CoreSmokeDB.

=cut

sub post {
    my $self = shift;

    my $json = $self->get_json();

    my $response = $self->ua->post(
        $self->smokedb_url,
        { json => $json }
    );

    return decode_json($response->content)->{id};
}

1;
