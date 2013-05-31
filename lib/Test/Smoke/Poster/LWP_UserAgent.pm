package Test::Smoke::Poster::LWP_UserAgent;
use warnings;
use strict;

use base 'Test::Smoke::Poster::Base';

use JSON;

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

    require LWP::UserAgent;
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
