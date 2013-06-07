package Test::Smoke::Poster::Curl;
use warnings;
use strict;

use base 'Test::Smoke::Poster::Base';

use fallback 'inc';

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

=head1 COPYRIGHT

(c) 2002-2013, Abe Timmerman <abeltje@cpan.org> All rights reserved.

With contributions from Jarkko Hietaniemi, Merijn Brand, Campo
Weijerman, Alan Burlison, Allen Smith, Alain Barbet, Dominic Dunlop,
Rich Rauenzahn, David Cantrell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * L<http://www.perl.com/perl/misc/Artistic.html>

=item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
