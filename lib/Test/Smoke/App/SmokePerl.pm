package Test::Smoke::App::SmokePerl;
use warnings;
use strict;

use base 'Test::Smoke::App::Base';

use Test::Smoke::App::Archiver;
use Test::Smoke::App::Reporter;
use Test::Smoke::App::RunSmoke;
use Test::Smoke::App::SendReport;
use Test::Smoke::App::SyncTree;

use Test::Smoke::App::Options;
my $opt = 'Test::Smoke::App::Options';

=head1 NAME

Test::Smoke::App::SmokePerl - The tssmokeperl.pl application.

=head1 DESCRIPTION

=head2 Test::Smoke::App::SmokePerl->new()

Return an instance.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    {
        local @ARGV = @{$self->ARGV};
        $self->{_synctree} = Test::Smoke::App::SyncTree->new(
            $opt->synctree_config()
        );
    }
    {
        local @ARGV = @{$self->ARGV};
        $self->{_runsmoke} = Test::Smoke::App::RunSmoke->new(
            $opt->runsmoke_config()
        );
    }
    {
        local @ARGV = @{$self->ARGV};
        $self->{_reporter} = Test::Smoke::App::Reporter->new(
            $opt->reporter_config()
        );
    }
    {
        local @ARGV = @{$self->ARGV};
        $self->{_sendreport} = Test::Smoke::App::SendReport->new(
            $opt->sendreport_config()
        );
    }
    {
        local @ARGV = @{$self->ARGV};
        $self->{_archiver} = Test::Smoke::App::Archiver->new(
            $opt->archiver_config()
        );
    }

    return $self;
}

=head2 $app->run();

Run all the parts:

=over

=item * synctree

=item * runsmoke

=item * report

=item * sendrpt

=item * archive

=back

=cut

sub run {
    my $self = shift;

    $self->synctree->run();
    $self->runsmoke->run();
    $self->reporter->run();
    $self->sendreport->run();
    $self->archiver->run();
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
