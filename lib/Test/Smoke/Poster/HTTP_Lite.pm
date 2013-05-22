package Test::Smoke::Poster::HTTP_Lite;
use warnings;
use strict;
use Carp;

use base 'Test::Smoke::Poster::Base';

use HTTP::Lite;
use JSON;

=head1 NAME

Test::Smoke::Poster::HTTP_Lite - Poster subclass using HTTP::Lite.

=head1 DESCRIPTION

This is a subclass of L<Test::Smoke::Poster::Base>.

=head2 Test::Smoke::Poster::HTTP::Lite->new(%arguments)

=head3 Extra Arguments

None.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{_ua} = HTTP::Lite->new();

    return $self;
}

=head2 $poster->post()

Post the json to CoreSmokeDB.

=cut

sub post {
    my $self = shift;

    $self->ua->prepare_post({ json => $self->get_json });
    $self->ua->add_req_header('User-Agent', $self->agent_string);
    $self->ua->request($self->smokedb_url) or croak("CoreSmokeDB: $!");

    my $body = decode_json($self->ua->body);
    if (exists $body->{error}) {
        $self->log_info("CoreSmokeDB: %s", $body->{error});
        return;
    }
    return $body->{id};
}

1;
