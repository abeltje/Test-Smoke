package Test::Smoke;
use strict;

use vars qw( $VERSION $conf @EXPORT );
$VERSION = '1.17';

use base 'Exporter';
@EXPORT  = qw( $conf &read_config );

my $ConfigError;

=head1 NAME

Test::Smoke - The Perl core test smoke suite

=head1 SYNOPSIS

    use Test::Smoke;

    use vars qw( $VERSION );
    $VERSION = Test::Smoke->VERSION;

    read_config( $config_name ) or warn Test::Smoke->config_error; 
    

=head1 DESCRIPTION

C<Test::Smoke> exports C<$conf> and C<read_config()> by default.

=over 4

=item Test::Smoke::read_config( $config_name )

=cut

sub read_config {
    my( $config_name ) = @_;
    defined $config_name or $config_name = 'smokecurrent_config';

    eval { require $config_name };
    $ConfigError = $@ ? $@ : undef;

    return defined $ConfigError ? undef : 1;
}

=item Test::Smoke->config_error()

Return the value of C<$ConfigError>

=cut

sub config_error {
    return $ConfigError;
}

1;

=back

=head1 COPYRIGHT

(c) 2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

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
