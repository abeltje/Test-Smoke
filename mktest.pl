#!/usr/bin/perl -w

# Smoke test for perl-current
# (c)'01 H.Merijn Brand [27 August 2001]
#    and Nicholas Clark
# 20020909: Abe Timmerman
# REVISION: 1.18 
# $Id$
use strict;

sub usage ()
{
    print STDERR "usage: mktest.pl [options] [<smoke.cfg>]\n";
    exit 1;
} # usage

@ARGV == 1 and $ARGV[0] eq "-?" || $ARGV[0] =~ m/^-+help$/ and usage;

use Config;
use Cwd;
use Getopt::Long;
use File::Find;
use Text::ParseWords;
use File::Spec;

use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use Test::Smoke::Util;
use Test::Smoke::Policy;

my $win32_cctype   = "MSVC60"; # 2.0 => MSVC20; 5.0 => MSVC; 6.0 => MSVC60
my $win32_maker    = $Config{make};
my $smoker         = $Config{cf_email};
my $fdir           = undef;
my $locale         = undef;
my $is56x          = undef;
my $force_c_locale = undef;

=head1 NAME

mktest.pl - Configure, build and test bleading edge perl

=head1 SYNOPSIS

    $ ./mktest.pl [options] smoke.cfg

=head1 OPTIONS

=over

=item * -n | --norun | --dry-run

=item * -v | --verbose [ level ]

=item * -m | --win32-maker <dmake | nmake>

=item * -c | --win32-cctype <BORLAND|GCC|MSVC20|MSVC|MSVC60>

=item * -s | --smoker <your-email-address>

=item * -f | --forest <basedir>

=item * -l | --locale <somelocale>

=item * --is56x

=item * --[no]force-c-locale

=back

All remaining arguments in C<@ARGV> are used for B<MSWin32> to
tweak values in Config.pm and should be C<< key=value >> pairs.

=head1 METHODS

=over

=cut

my $norun   = 0;
my $verbose = 0;
GetOptions (
    "n|norun|dry-run"  => \$norun,
    "v|verbose:i"      => \$verbose,	# NYI
    "m|win32-maker=s"  => \$win32_maker,
    "c|win32-cctype=s" => \$win32_cctype,
    "s|smoker=s"       => \$smoker,
    "f|forest=s"       => \$fdir,
    "l|locale=s"       => \$locale,
    "is56x"            => \$is56x,
    "force-c-locale!"  => \$force_c_locale,
) or usage;

$verbose and print "$0 running at verbose level $verbose\n";

my $config_file = shift;
# All remaining stuff in @ARGV is used by Configure_win32()
# They are appended to the CFG_VARS macro
# This is a way to cheat in Win32 and get the "right" stuff into Config.pm

open TTY,    ">&STDERR";	select ((select (TTY),    $| = 1)[0]);
open STDERR, ">&1";		select ((select (STDERR), $| = 1)[0]);
open OUT,    "> mktest.out";	select ((select (OUT),    $| = 1)[0]);
				select ((select (STDOUT), $| = 1)[0]);

# Do we need this for smoking from 5.8.0 under locale?
binmode( TTY ); binmode( STDERR ); binmode( OUT );

=item is_win32( )

C<is_win32()> returns true if  C<< $^O eq "MSWin32" >>.

=cut

sub is_win32() { $^O eq "MSWin32" }

=item run( $command[, $sub[, @args]] )

C<run()> returns C<< qx( $command ) >> unless C<$sub> is specified.
If C<$sub> is defined (and a coderef) C<< $sub->( $command, @args ) >> will 
be called.

=cut

sub run($;@) {
    my( $command, $sub, @args ) = @_;
    $norun and return print TTY "$command\n";

    defined $sub and return &$sub( $command, @args );

    return qx($command);
}

=item make( $command )

C<make()> calls C<< run( "make $command" ) >>, and does some extra
stuff to help MSWin32 (the right maker, the directory).

=cut

sub make($) {
    my $cmd = shift;

    is_win32 or return run "make $cmd";

    my $kill_err;
    # don't capture STDERR 
    # @ But why? and what if we do it DOSish? 2>NUL:

    $cmd =~ s{2\s*>\s*/dev/null\s*$}{} and $kill_err = 1;

    $cmd = "$win32_maker -f smoke.mk $cmd";
    chdir "win32" or die "unable to chdir () into 'win32'";
    run( $kill_err ? qq{$^X -e "close STDERR; system '$cmd'"} : $cmd );
    chdir ".." or die "unable to chdir() out of 'win32'";
}

=item ttylog( @message )

C<ttylog()> prints C<@message> to both STDOUT and the logfile.

=cut

sub ttylog(@) {
    print TTY @_;
    print OUT @_;
}

$config_file = get_cfg_filename( $config_file );
my @config = get_config( $config_file );

my $testdir = getcwd;

exists $Config{ldlibpthname} && $Config{ldlibpthname} and
    $ENV{$Config{ldlibpthname}} ||= '',
    substr ($ENV{$Config{ldlibpthname}}, 0, 0) = "$testdir$Config{path_sep}";

my $patch = get_patch();
print OUT "Smoking patch $patch\n\n";


my $MANIFEST = check_MANIFEST( $testdir );
foreach my $f (sort keys %$MANIFEST) {
    ttylog "MANIFEST ",
        ($MANIFEST->{ $f } ? "still has" : "did not declare"), " $f\n";
}

my $Policy = Test::Smoke::Policy->new( File::Spec->updir, $verbose );

my @p_conf = ("", "");

run_tests( \@p_conf, "-Dusedevel", [], @config );

close OUT;

sub run_tests {
    # policy.sh
    # configuration command line built up so far
    # hash of substitutions in Policy.sh (mostly cflags)
    # array of things still to test (in @_ ?)

    my ($p_conf, $old_config_args, $substs, $this_test, @tests) = @_;

    # $this_test is either
    # [ "", "-Dthing" ]
    # or
    # { policy_target => "-DDEBUGGING", args => [ "", "-DDEBUGGING" ] }

    my $policy_target;
    if (ref $this_test eq "HASH") {
	$policy_target = $this_test->{policy_target};
	$this_test     = $this_test->{args};
    }

    foreach my $conf (@$this_test) {
        my $config_args = $old_config_args;
        # Try not to add spurious spaces as it confuses mkovz.pl
        length $conf and $config_args .= " $conf";

        $Policy->reset_rules;
        $Policy->set_rules( $_ ) foreach @$substs;
        my @substs = @$substs;
        if ( defined $policy_target ) {
            # This set of permutations also need to subst inside Policy.sh
            # somewhere.
            push @substs, [ $policy_target, $conf ];
            $Policy->set_rules( $substs[-1] );
        }

        if ( @tests ) { # Another level of tests
            run_tests ($p_conf, $config_args, \@substs, @tests);
            next;
        }

        # No more levels to expand
        my $s_conf = join "\n" => "", "Configuration: $config_args",
                                  "-" x 78, "";

        # Skip officially unsupported combo's
        $config_args =~ m/-Uuseperlio/ && $config_args =~ m/-Dusei?threads/
            and next; # patch 17000

        ttylog $s_conf;

        # You can put some optimizations (skipping configurations) here
        if ( $^O =~ m/^(?: hpux | freebsd )$/x &&
             $config_args =~ m/longdouble|morebits/) {
            # longdouble is turned off in Configure for hpux, and since
            # morebits is the same as 64bitint + longdouble, these have
            # already been tested. FreeBSD does not support longdoubles
            # well enough for perl (eg no sqrtl)
            ttylog " Skipped this configuration for this OS " .
                   "(duplicate test)\n";
            next;
        }

        if ( is_win32 && $win32_cctype eq "BORLAND" &&
             $config_args =~ /-Duselargefiles/ ) {
            # MSWin32 + BORLAND doesn't support USE_LARGE_FILES
            # I send in a patch to unset USE_LARGE_FILES for BORLAND
#            ttylog " Skipped this configuration for this compiler " .
#                   "(not supported)\n";
            next;
        }

        print TTY "Make distclean ...";
        if ( $fdir ) {
            require Test::Smoke::Syncer;
            my $distclean = Test::Smoke::Syncer->new( 
                hardlink => { ddir => cwd(), v => 0, hdir => $fdir }
            );
            $distclean->clean_from_directory( $fdir, 'mktest.out' );
        } else {
            make "-i distclean 2>/dev/null";
        }

        unless ( is_win32 ) {
            print TTY "\nCopy Policy.sh ...";
            $verbose > 1 || $ norun and print $Policy->_do_subst;
            $Policy->write unless $norun;
        }

        print TTY "\nConfigure ...";
        # Configure_win32() uses MSVCxx as default, this could be not right
        $config_args .= " -DCCTYPE=$win32_cctype"
            if is_win32 && $config_args !~ /-DCCTYPE=\$win32_cctype/;

        my @configure_args;
        push @configure_args, \&Configure_win32, $win32_maker, @ARGV 
            if is_win32;
        run "./Configure $config_args -des", @configure_args;

        unless ($norun or (is_win32 ? -f "win32/smoke.mk"
                                    : -f "Makefile" && -s "config.sh")) {
            ttylog " Unable to configure perl in this configuration\n";
            next;
        }

        unless ( is_win32 || $fdir ) {
            print TTY "\nMake headers ...";
            make "regen_headers";
        }

        print TTY "\nMake ...";
        make " ";

	my $perl = "perl$Config{_exe}";
	unless ($norun or (-s $perl && -x _)) {
	    ttylog " Unable to make perl in this configuration\n";
	    next;
	}

	$norun or unlink "t/$perl";
	make "test-prep";
	unless ($norun or is_win32 ? -f "t/$perl" : -l "t/$perl") {
	    ttylog " Unable to test perl in this configuration\n";
	    next;
	}

	print TTY "\n Tests start here:\n";

        # No use testing different io layers without PerlIO
        # just output 'stdio' for mkovz.pl
        my @layers = ( ($config_args =~ /-Uuseperlio\b/) || $is56x )
            ? qw( stdio ) : qw( stdio perlio );

        if ( !($config_args =~ /-Uuseperlio\b/ || $is56x) && $locale ) {
            push @layers, 'locale';
        }

	foreach my $perlio ( @layers ) {
            my $had_LC_ALL = exists $ENV{LC_ALL};
            local( $ENV{PERLIO}, $ENV{LC_ALL}, $ENV{PERL_UNICODE} ) =
                 ( "", defined $ENV{LC_ALL} ? $ENV{LC_ALL} : "", "" );
            my $perlio_logmsg = $perlio;
            if ( $perlio ne 'locale' ) {
                $ENV{PERLIO} = $perlio;
                is_win32 and $ENV{PERLIO} .= " :crlf";
                $ENV{LC_ALL} = 'C' if $force_c_locale;
                $ENV{LC_ALL} or delete $ENV{LC_ALL};
                delete $ENV{PERL_UNICODE};
            } else {
                $ENV{PERL_UNICODE} = ""; # See -C in perlrun
                $ENV{LC_ALL} = $locale;
                $perlio_logmsg .= ":$locale";
            }
	    ttylog "PERLIO = $perlio_logmsg\t";

	    if ($norun) {
		ttylog "\n";
		next;
	    }

	    # MSWin32 builds from its own directory
	    if ( is_win32 ) {
		chdir "win32" or die "unable to chdir () into 'win32'";
		# Same as in make ()
		open TST, "$win32_maker -f smoke.mk test |";
		chdir ".." or die "unable to chdir () out of 'win32'";
	    } else {
		local $ENV{PERL} = "./perl";
		open TST, "make _test |";
	    }

	    my @nok = ();
	    select ((select (TST), $| = 1)[0]);
	    while (<TST>) {
		skip_filter( $_ ) and next;

		# make mkovz.pl's life easier
		s/(.)(PERLIO\s+=\s+\w+)/$1\n$2/;

		if (m/^u=.*tests=/) {
		    s/(\d\.\d*) /sprintf "%.2f ", $1/ge;
		    print OUT;
		} else {
		    push @nok, $_;
		}
		print;
	    }
	    print OUT map { "    $_" } @nok;
	    if (grep m/^All tests successful/, @nok) {
		print TTY "\nOK, archive results ...";
		$patch and $nok[0] =~ s/\./ for .patch = $patch./;
	    } else {
		my @harness;
		for (@nok) {
		    m|^(?:\.\.[\\/])?(\w+/[-\w/]+).*| or next;
		    # Remeber, we chdir into t, so -f is false for op/*.t etc
		    push @harness, (-f "$1.t") ? "../$1.t" : "$1.t";
		}
		if (@harness) {
		    local $ENV{PERL_SKIP_TTY_TEST} = 1;
		    print TTY "\nExtending failures with Harness\n";
		    my $harness = is_win32 ?
			join " ", map { s{^\.\.[/\\]}{};
					m/^(?:lib|ext)/ and $_ = "../$_";
					$_ } @harness :
			"@harness";
		    ttylog "\n",
			grep !m:\bFAILED tests\b: &&
			    !m:% okay$: => run "./perl t/harness $harness";
		}
	    }
	    print TTY "\n";
            $had_LC_ALL and exists $ENV{LC_ALL} and delete $ENV{LC_ALL};
	}
    }
} # run_tests

=back

=head1 SEE ALSO

L<Test::Smoke::Util>, L<mkovz.pl>.

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * H.Merijn Brand <h.m.brand@hccnet.nl>
  * Nicholas Clark <nick@unfortu.net>
  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * http://www.perl.com/perl/misc/Artistic.html

=item * http://www.gnu.org/copyleft/gpl.html

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
