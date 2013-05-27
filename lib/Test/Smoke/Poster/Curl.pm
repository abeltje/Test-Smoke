package Test::Smoke::Poster::Curl;
use warnings;
use strict;

use base 'Test::Smoke::Poster::Base';

use CGI::Util 'escape';
use JSON;
use Test::Smoke::Util::Execute;

=head1 NAME

Test::Smoke::Poster::Curl - Poster subclass using curl.

=head1 DESCRIPTION

This is a subclass of L<Test::Smoke::Poster::Base>.

=head2 Test::Smoke::Poster::Curl->new(%arguments)

=head3 Extra Arguments

=over

=item curlbin => $fq_path_to_curl

=back

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{_curl} = Test::Smoke::Util::Execute->new(
        command => ($self->curlbin || 'curl'),
        verbose => $self->v
    );

    return $self;
}

=head2 $poster->post()

Post the json to CoreSmokeDB.

=cut

sub post {
    my $self = shift;

    my $json = escape($self->get_json);
    my $response = $self->curl->run(
        ($self->v ? () : '--silent'),
        '-A' => $self->agent_string(),
        '-d' => "json=$json",
        $self->smokedb_url,
    );

    $self->log_info("curl-response: %s", $response);
    my $body = decode_json($response);
    if (exists $body->{error}) {
        $self->log_info("CoreSmokeDB: %s", $body->{error});
        return;
    }
    return $body->{id};
}

1;
