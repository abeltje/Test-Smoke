package Test::Smoke::Syncer::Git;
use warnings;
use strict;

our $VERSION = '0.029';

use base 'Test::Smoke::Syncer::Base';

=head1 Test::Smoke::Syncer::Git

This handles syncing with git repositories.

=cut


use Cwd;
use File::Spec::Functions;
use Test::Smoke::LogMixin;
use Test::Smoke::Util::Execute;
use File::Path;

=head2 Test::Smoke::Syncer::Git->new( %args )

Keys for C<%args>:

    * gitorigin
    * gitdir
    * gitbin
    * gitbranchfile
    * gitdfbranch

=cut

=head2 $syncer->sync()

Do the actual syncing.

=over

=item New clone
  git clone <gitorigin> <gitdir>
  git clone <gitdir> --reference <gitdir> <ddir>

=item Existing clone
  cd <ddir>
  git pull

=back

=cut

sub sync {
    my $self = shift;

    my $gitbin = Test::Smoke::Util::Execute->new(
        command => $self->{gitbin},
        verbose => $self->verbose,
    );
    use Carp;
    my $cwd = cwd();
    if ( ! -d $self->{gitdir} || ! -d catdir($self->{gitdir}, '.git') ) {
        my @clone_args = (
            'clone',
            $self->{gitorigin},
            $self->{gitdir},
            '2>&1'
        );
        my $cloneout = $gitbin->run(@clone_args);
        if ( my $gitexit = $gitbin->exitcode ) {
            croak("Cannot make inital clone: $self->{gitbin} exit $gitexit");
        }
        $self->log_debug($cloneout);
    }

    # gitdir typically is 'git-perl'
    chdir $self->{gitdir} or croak("Cannot chdir($self->{gitdir}): $!");

    my $gitout;
    $gitout = $gitbin->run(clean => '-dfx');
    $self->log_debug($gitout);

    $gitout = $gitbin->run(fetch => ('--prune', 'origin'));
    $self->log_debug($gitout);

    # We'll assume that 'blead' already exists, but we want it in sync with
    # origin
    $gitout = $gitbin->run(checkout => 'blead');
    $self->log_debug($gitout);

    $gitout = $gitbin->run(rebase => 'origin/blead');
    $self->log_debug($gitout);

    # get_git_branch() returns first line in file smokecurrent.gitbranch
    my $testingbranch = $self->get_git_branch;
    chomp($testingbranch);

    unless ($testingbranch eq 'blead') {

        # For smoke-testing, we (probably) always want to test a branch in its
        # current state out there on the origin.  We don't want to test any
        # previously created branch by that name in this repository.

        $gitout = $gitbin->run(branch => ('-D', $testingbranch));
        $self->log_debug($gitout);

        $gitout = $gitbin->run(checkout => ('-b', $testingbranch, "origin/$testingbranch"));
        $self->log_debug($gitout);
    }

    chdir $cwd or croak("Cannot chdir($cwd): $!");

    # Make the smoke clone.  Rather than trying to keep the repository in ddir
    # up-to-date with origin, we'll simply create it de novo from that in
    # gitdir.  So the branch we want to test will already be set.

    my $removed_count = File::Path::rmtree($self->{ddir})
        if (-d $self->{ddir});

    my $cloneout = $gitbin->run(
        clone         => $self->{gitdir},
        '--reference' => $self->{gitdir},
        $self->{ddir},
        '2>&1'
    );
    if ( my $gitexit = $gitbin->exitcode ) {
        croak("Cannot make smoke clone: $self->{gitbin} exit $gitexit");
    }
    $self->log_debug($cloneout);

    chdir $self->{ddir} or croak("Cannot chdir($self->{ddir}): $!");

    my $mk_dot_patch = Test::Smoke::Util::Execute->new(
        command => "$^X Porting/make_dot_patch.pl > .patch",
        verbose => $self->verbose,
    );
    my $perlout = $mk_dot_patch->run();
    $self->log_debug($perlout);

    chdir $cwd;

    return $self->check_dot_patch;
}

=head2 $git->get_git_branch()

Reads the first line of the file set in B<gitbranchfile> and returns its
value.

=cut

sub get_git_branch {
    my $self = shift;

    return $self->{gitdfbranch} if !$self->{gitbranchfile};
    return $self->{gitdfbranch} if ! -f $self->{gitbranchfile};

    if (open my $fh, '<', $self->{gitbranchfile}) {
        $self->log_debug("Reading branch to smoke from: '$self->{gitbranchfile}'");

        my $branch = <$fh>;
        close $fh;
        return $branch;
    }
    $self->log_warn("Error opening '$self->{gitbranchfile}': $!");
    return $self->{gitdfbranch};
}

1;

=head1 COPYRIGHT

(c) 2002-2013, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

  * <http://www.perl.com/perl/misc/Artistic.html>,
  * <http://www.gnu.org/copyleft/gpl.html>

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
