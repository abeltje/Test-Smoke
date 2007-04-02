package Test::Smoke::Reporter;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.027';

use Cwd;
use File::Spec::Functions;
require File::Path;
use Text::ParseWords;
require Test::Smoke;
use Test::Smoke::SysInfo;
use Test::Smoke::Util qw( grepccmsg get_smoked_Config
                          time_in_hhmm get_local_patches );

my %CONFIG = (
    df_ddir       => curdir(),
    df_outfile    => 'mktest.out',
    df_rptfile    => 'mktest.rpt',
    df_cfg        => undef,
    df_lfile      => undef,
    df_showcfg    => 0,

    df_locale     => undef,
    df_defaultenv => undef,
    df_is56x      => undef,

    df_v          => 0,
);

=head1 NAME

Test::Smoke::Reporter - OO interface for handling the testresults (mktest.out)

=head1 SYNOPSIS

    use Test::Smoke;
    use Test::Smoke::Reporter;

    my $reporter = Test::Smoke::Reporter->new( %args );
    $reporter->write_to_file;

=head1 DESCRIPTION

Handle the parsing of the F<mktest.out> file.

=head1 METHODS

=over 4

=cut

=item Test::Smoke::Reporter->new( %args )

[ Constructor | Public ]

Initialise a new object.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } keys %{ $class->config( 'all_defaults' ) };

    my $self = bless \%fields, $class;
    $self->read_parse(  );
}

=item Test::Smoke::Reporter->config( $key[, $value] )

[ Accessor | Public ]

C<config()> is an interface to the package lexical C<%CONFIG>, 
which holds all the default values for the C<new()> arguments.

With the special key B<all_defaults> this returns a reference
to a hash holding all the default values.

=cut

sub config {
    my $dummy = shift;

    my $key = lc shift;

    if ( $key eq 'all_defaults' ) {
        my %default = map {
            my( $pass_key ) = $_ =~ /^df_(.+)/;
            ( $pass_key => $CONFIG{ $_ } );
        } grep /^df_/ => keys %CONFIG;
        return \%default;
    }

    return undef unless exists $CONFIG{ "df_$key" };

    $CONFIG{ "df_$key" } = shift if @_;

    return $CONFIG{ "df_$key" };
}

=item $self->read_parse( [$result_file] )

C<read_parse()> reads the smokeresults file and parses it.

=cut

sub read_parse {
    my $self = shift;

    my $result_file = @_ ? $_[0] : $self->{outfile} 
        ? catfile( $self->{ddir}, $self->{outfile} )
        : "";
    if ( $result_file ) {
        $self->_read( $result_file );
        $self->_parse;
    }
    return $self;
}

=item $self->_read( $nameorref )

C<_read()> is a private method that handles the reading.

=over 8

=item B<Reference to a SCALAR> smokeresults are in C<$$nameorref>

=item B<Reference to an ARRAY> smokeresults are in C<@$nameorref>

=item B<Reference to a GLOB> smokeresults are read from the filehandle

=item B<Other values> are taken as the filename for the smokeresults

=back

=cut

sub _read {
    my $self = shift;
    my( $nameorref ) = @_;
    $nameorref = '' unless defined $nameorref;

    my $vmsg = "";
    local *SMOKERSLT;
    if ( ref $nameorref eq 'SCALAR' ) {
        $self->{_outfile} = $$nameorref;
        $vmsg = "from internal content";
    } elsif ( ref $nameorref eq 'ARRAY' ) {
        $self->{_outfile} = join "", @$nameorref;
        $vmsg = "from internal content";
    } elsif ( ref $nameorref eq 'GLOB' ) {
	*SMOKERSLT = *$nameorref;
        $self->{_outfile} = do { local $/; <SMOKERSLT> };
        $vmsg = "from anonymous filehandle";
    } else {
        if ( $nameorref ) {
            if ( open SMOKERSLT, "< $nameorref" ) {
                $self->{_outfile} = do { local $/; <SMOKERSLT> };
                close SMOKERSLT;
                $vmsg = "from $nameorref";
            } else {
                require Carp;
                Carp::carp( "Cannot read smokeresults ($nameorref): $!" );
                $self->{_outfile} = undef;
                $vmsg = "did fail";
            }
        } else { # Allow intentional default_buildcfg()
            $self->{_outfile} = undef;
            $vmsg = "did fail";
        } 
    }
    $self->{v} and print "Reading smokeresult $vmsg\n";
}

=item $self->_parse( )

Interpret the contents of the logfile and prepare them for processing,
so report can be made.

=cut

sub _parse {
    my $self = shift;
    $self->{_rpt} = { }; $self->{_cache} = { }; $self->{_mani} = [ ];
    return $self unless defined $self->{_outfile};

    my( %rpt, $cfgarg, $debug, $tstenv, $start, $statarg, $fcnt );
    $rpt{count} = 0;
    # reverse and use pop() instead of using unshift()
    my @lines = reverse split /\n+/, $self->{_outfile};
    while ( defined( local $_ = pop @lines ) ) {
        m/^\s*$/ and next;
        m/^-+$/  and next;
        s/\s*$//;

        if ( my( $status, $time ) = /(Started|Stopped) smoke at (\d+)/ ) {
            if ( $status eq "Started" ) {
                $start = $time;
                $rpt{started} ||= $time;
            } else {
                $rpt{secs} += ($time - $start) if defined $start;
            }
            next;
        }

        if  ( my( $patch ) = /^\s*Smoking patch\s* (\d+\S*)/ ) {
            $rpt{patch} = $patch;
            next;
        }

        if ( my( $cinfo ) = /^Compiler info: (.+)$/ ) {
            $rpt{cinfo} = $cinfo unless $rpt{cinfo};
            next;
        }

        if ( /^MANIFEST / ) {
            push @{ $self->{_mani} }, $_;
            next;
        }

        if ( s/^\s*Configuration:\s*// ) {
            # You might need to do something here with 
            # the previous Configuration: $cfgarg
            $rpt{statcfg}{ $statarg } = $fcnt if defined $statarg;
            $fcnt = 0;

            $rpt{count}++;
            s/-Dusedevel(\s+|$)//;
            s/\s*-des//;
            $statarg = $_;
            $debug = s/-D(DEBUGGING|usevmsdebug)\s*// ? "D" : "N";
            $debug eq 'D' and $rpt{dbughow} = "-D$1";
            s/\s+$//;

            $cfgarg = $_ || "";

            push @{ $rpt{cfglist} }, $_ unless $rpt{config}->{ $cfgarg }++;
            $tstenv = "";
            next;
        }

        if ( m/(?:PERLIO|TSTENV)\s*=\s*([-\w:.]+)/ ) {
            $tstenv = $1;
            $rpt{$cfgarg}->{$debug}{$tstenv} ||= "?";
            # Deal with harness output
            s/^(?:PERLIO|TSTENV)\s*=\s+[-\w:.]+(?: :crlf)?\s*//;
        }

        if ( m/^\s*All tests successful/ ) {
            $rpt{$cfgarg}->{$debug}{$tstenv} = "O";
            next;
        }

        if ( m/Inconsistent test ?results/ ) {
            ref $rpt{$cfgarg}->{$debug}{$tstenv} or
                $rpt{$cfgarg}->{$debug}{$tstenv} = [ ];
            push @{ $rpt{$cfgarg}->{$debug}{$tstenv} }, $_;
        }

        if ( /^Finished smoking \d+/ ) {
            $rpt{statcfg}{ $statarg } = $fcnt;
            $rpt{finished} = "Finished";
            next;
        }

        if ( my( $status, $mini ) =
             m/^\s*Unable\ to
               \ (?=([cbmt]))(?:build|configure|make|test)
               \ (anything\ but\ mini)?perl/x) {
            $mini and $status = uc $status; # M for no perl but miniperl
            # $tstenv is only set *after* this
            $tstenv = $mini ? 'minitest' : 'stdio' unless $tstenv;
            $rpt{$cfgarg}->{$debug}{$tstenv} = $status;
            $fcnt++;
            next;
        }

        if ( m/FAILED/ || m/DIED/ || m/dubious$/) {
            ref $rpt{$cfgarg}->{$debug}{$tstenv} or
                $rpt{$cfgarg}->{$debug}{$tstenv} = [ ];
            push @{ $rpt{$cfgarg}->{$debug}{$tstenv} }, $_;
            $fcnt++;
            next;
        }
        if ( /^\s+\d+(?:[-\s]+\d+)*/ ) {
            push @{ $rpt{$cfgarg}->{$debug}{$tstenv} }, $_
                if ref $rpt{$cfgarg}->{$debug}{$tstenv};
            next;
        }
        next;
    }

    $rpt{last_cfg} = $statarg;
    exists $rpt{statcfg}{ $statarg } or $rpt{running} = $fcnt;
    $rpt{avg} = $rpt{secs} / $rpt{count};
    $self->{_rpt} = \%rpt;
    $self->_post_process;
}

=item $self->_post_process( )

C<_post_process()> sets up the report for easy printing. It needs to
sort the buildenvironments, statusletters and test failures.

=cut

sub _post_process {
    my $self = shift;

    unless ( defined $self->{is56x} ) {
        my %cfg = get_smoked_Config( $self->{ddir}, 'version' );
        my $p_version = sprintf "%d.%03d%03d", split /\./, $cfg{version};
        $self->{is56x} = $p_version < 5.007;
    }
    $self->{defaultenv} ||= $self->{is56x};

    my( %bldenv, %cfgargs );
    my $rpt = $self->{_rpt};
    foreach my $config ( @{ $rpt->{cfglist} } ) {
        foreach my $buildenv ( keys %{ $rpt->{ $config }{N} } ) {
            $bldenv{ $buildenv }++;
        }
        foreach my $buildenv ( keys %{ $rpt->{ $config }{D} } ) {
            $bldenv{ $buildenv }++;
        }
        $cfgargs{$_}++ for grep defined $_ => quotewords( '\s+', 1, $config );
    }
    my %common_args = map {
        ( $_ => 1)
    } grep $cfgargs{ $_ } == @{ $rpt->{cfglist} } && ! /^-[DU]use/
        => keys %cfgargs;

    $rpt->{_common_args} = \%common_args;
    $rpt->{common_args} = join " ", sort keys %common_args;
    $rpt->{common_args} ||= 'none';

    $self->{_tstenv} = [ reverse sort keys %bldenv ];
    my %count = ( O => 0, F => 0, X => 0, M => 0, 
                  m => 0, c => 0, o => 0, t => 0 );
    my( %failures, %order ); my $ord = 1;
    my $debugging = $rpt->{dbughow} || '-DDEBUGGING';
    foreach my $config ( @{ $rpt->{cfglist} } ) {
        foreach my $dbinfo (qw( N D )) {
            my $cfg = $config;
            ( $cfg =  $cfg ? "$debugging $cfg" : $debugging )
                if $dbinfo eq "D";
            $self->{v} and print "Processing [$cfg]\n";
            my $status = $self->{_rpt}{ $config }{ $dbinfo };
            foreach my $tstenv ( reverse sort keys %bldenv ) {
                next if $tstenv eq 'minitest' && ! exists $status->{ $tstenv };

                ( my $showenv = $tstenv ) =~ s/^locale://;
                $self->{_locale} ||= $showenv if $tstenv =~ /^locale:/;
                $showenv = 'default' 
                    if $self->{defaultenv} && $showenv eq 'stdio';

                $status->{ $tstenv } ||= '-';
                if ( ref $status->{ $tstenv } eq "ARRAY" ) {
                    my $failed = join "\n", @{ $status->{ $tstenv } };
                    if ( exists $failures{ $failed } &&
                         @{ $failures{ $failed } } && 
                         $failures{ $failed }->[-1]{cfg} eq $cfg ) {
                        push @{ $failures{ $failed }->[-1]{env} }, $showenv;
                    } else {
                        push @{ $failures{ $failed } }, 
                             { cfg => $cfg, env => [ $showenv ] };
                        $order{ $failed } ||= $ord++;
                    }
                    $status->{ $tstenv } = $failed =~ /^Inconsistent/
                        ? "X" : "F";
                }
                $self->{v} > 1 and print "\t[$showenv]: $status->{$tstenv}\n";
                if ( $tstenv eq 'minitest' ) {
                    $status->{stdio} = "M";
                    delete $status->{minitest};
                }
            }
            unless ( $self->{defaultenv} ) {
                exists $status->{perlio} or $status->{perlio} = '-';
                exists $status->{ "locale:$self->{locale}" } or 
                    $status->{ "locale:$self->{locale}" } = '-'
                        if $self->{locale};
            }

            $count{ $_ }++ for map {
                m/[cmMtFXO]/ ? $_ : m/-/ ? 'O' : 'o' 
            } map $status->{ $_ } => keys %$status;
        }
    }
    my @failures = map {
        { tests => $_,
          cfgs  => [ map {
              my $cfg_clean = __rm_common_args( $_->{cfg}, \%common_args );
              my $env = join "/", @{ $_->{env} };
              "[$env] $cfg_clean";
        } @{ $failures{ $_ } }],
      }
    } sort { $order{$a} <=> $order{ $b} } keys %failures;
    $self->{_failures} = \@failures;

    $self->{_counters} = \%count;
    # Need to rebuild the test-environments as minitest changes into stdio
    my %bldenv2;
    foreach my $config ( @{ $rpt->{cfglist} } ) {
        foreach my $buildenv ( keys %{ $rpt->{ $config }{N} } ) {
            $bldenv2{ $buildenv }++;
        }
        foreach my $buildenv ( keys %{ $rpt->{ $config }{D} } ) {
            $bldenv2{ $buildenv }++;
        }
    }
    $self->{_tstenvraw} = $self->{_tstenv};
    $self->{_tstenv} = [ reverse sort keys %bldenv2 ];
}

=item __rm_common_args( $cfg, \%common )

Removes the the arguments stored as keys in C<%common> from C<$cfg>.

=cut

sub __rm_common_args {
    my( $cfg, $common ) = @_;

    require Test::Smoke::BuildCFG;
    my $bcfg = Test::Smoke::BuildCFG::new_configuration( $cfg );

    return $bcfg->rm_arg( keys %$common );
}

=item $reporter->write_to_file( [$name] )

Write the C<< $self->report >> to file. If name is ommitted it will
use C<< catfile( $self->{ddir}, $self->{rptfile} ) >>.

=cut

sub write_to_file {
    my $self = shift;
    return unless defined $self->{_outfile};
    my( $name ) = @_ || ( catfile $self->{ddir}, $self->{rptfile} );

    $self->{v} and print "Writing report to '$name':";
    local *RPT;
    open RPT, "> $name" or do {
        require Carp;
        Carp::carp( "Error creating '$name': $!" );
        return;
    };
    print RPT $self->report;
    close RPT or do {
        require Carp;
        Carp::carp( "Error writing to '$name': $!" );
        return;
    };
    $self->{v} and print " OK\n";
    return 1;
}

=item $reporter->report( )

Return a string with the full report

=cut

sub report {
    my $self = shift;
    return unless defined $self->{_outfile};

    my $report = $self->preamble;

    $report .= $self->summary . "\n";
    $report .= $self->letter_legend . "\n";
    $report .= $self->smoke_matrix . $self->bldenv_legend;

    $report .= $self->registered_patches;

    $report .= "\nFailures: (common-args) $self->{_rpt}{common_args}\n"
            .  $self->failures if $self->has_test_failures;
    $report .= "\n" . $self->mani_fail           if $self->has_mani_failures;

    $report .= $self->ccmessages;

    if ( $self->{showcfg} && $self->{cfg} && $self->has_test_failures ) {
        require Test::Smoke::BuildCFG;
        my $bcfg = Test::Smoke::BuildCFG->new( $self->{cfg} );
        $report .= "\nBuild configurations:\n" . $bcfg->as_string ."=\n";
    }

    $report .= $self->signature;
    return $report;
}

=item $reporter->ccinfo( )

Return the string containing the C-compiler info.

=cut

sub ccinfo {
    my $self = shift;
    my $cinfo = $self->{_rpt}{cinfo};
    unless ( $cinfo ) { # Old .out file?
        my %Config = get_smoked_Config( $self->{ddir} => qw( 
            cc ccversion gccversion
        ));
        $cinfo = "? ";
        my $ccvers = $Config{gccversion} || $Config{ccversion} || '';
        $cinfo .= ( $Config{cc} || 'unknown cc' ) . " version $ccvers";
        $self->{_ccinfo} = ($Config{cc} || 'cc') . " version $ccvers";
    }
    return $cinfo;
}

=item $reporter->registered_patches()

Return a section with the locally applied patches (from patchlevel.h).

=cut

sub registered_patches {
    my $self = shift;

    my @lpatches = get_local_patches( $self->{ddir}, $self->{v} );
    @lpatches or return "";

    my $list = join "\n", map "    $_" => @lpatches;
    return "Locally applied patches:\n$list\n";
}

=item $reporter->ccmessages( )

Use a port of Jarkko's F<grepccerr> script to report the compiler messages.

=cut

sub ccmessages {
    my $self = shift;
    my $ccinfo = $self->{_rpt}{cinfo} || $self->{_ccinfo};
    $ccinfo =~ s/^(.+)\s+version\s+.+/$1/;

    $^O =~ /^(?:linux|.*bsd.*|darwin)/ and $ccinfo = 'gcc';
    my $cc = $ccinfo =~ /(gcc|bcc32)/ ? $1 : $^O;

    $self->{v} and print "Looking for cc messages: '$cc'\n";
    my $errors = grepccmsg( $cc, $self->{lfile}, $self->{v} ) || [ ];

    local $" = "\n";
    return @$errors ? <<EOERRORS : "";

Compiler messages($cc):
@$errors
EOERRORS
}

=item $reporter->preamble( )

Returns the header of the report.

=cut

sub preamble {
    my $self = shift;

    my %Config = get_smoked_Config( $self->{ddir} => qw( 
        version libc gnulibc_version
    ));
    my $si = Test::Smoke::SysInfo->new;
    my $archname  = $si->cpu_type;
    $archname .= sprintf "/%s cpu", $si->ncpu if $si->ncpu;
    my $cpu = $si->cpu;

    my $this_host = $si->host;
    my $time_msg  = time_in_hhmm( $self->{_rpt}{secs} );
    my $savg_msg  = time_in_hhmm( $self->{_rpt}{avg}  );

    my $cinfo = $self->ccinfo;

    my $os = $si->os;

    return <<__EOH__;
Automated smoke report for $Config{version} patch $self->{_rpt}{patch}
$this_host: $cpu ($archname)
    on        $os
    using     $cinfo
    smoketime $time_msg (average $savg_msg)

__EOH__
}

=item $reporter->smoke_matrix( )

C<smoke_matrix()> returns a string with the result-letters and their
configs.

=cut

sub smoke_matrix {
    my $self = shift;
    my $rpt  = $self->{_rpt};

    # Maximum of 6 letters => 11 positions
    my $pad = " " x int( (11 - length( $rpt->{patch} ))/2 );
    my $patch = $pad . $rpt->{patch};
    my $report = sprintf "%-11s  Configuration (common) %s\n", 
                         $patch, $rpt->{common_args};
    $report .= ("-" x 11) . " " . ("-" x 57) . "\n";

    foreach my $config ( @{ $rpt->{cfglist} } ) {
        my $letters = "";
        foreach my $dbinfo (qw( N D )) {
            foreach my $tstenv ( @{ $self->{_tstenv} } ) {
                $letters .= "$rpt->{$config}{$dbinfo}{$tstenv} ";
            }
        }
        my $cfg = join " ", grep ! exists $rpt->{_common_args}{ $_ }
            => quotewords( '\s+', 1, $config );
        $report .= sprintf "%-12s%s\n", $letters, $cfg;
    }

    return $report;
}

=item $reporter->summary( )

Return the B<PASS> or B<FAIL(x)> string.

=cut

sub summary {
    my $self = shift;
    my $count = $self->{_counters};
    my @rpt_sum_stat = grep $count->{ $_ } > 0 => qw( X F M m c t );
    my $rpt_summary = '';
    if ( @rpt_sum_stat ) {
        $rpt_summary = "FAIL(" . join( "", @rpt_sum_stat ) . ")";
    } else {
        $rpt_summary = $count->{o} == 0 ? 'PASS' : 'PASS-so-far';
    }

    return "Summary: $rpt_summary\n";
}

=item $repoarter->has_test_failures( )

Returns true if C<< @{ $reporter->{_failures} >>.

=cut

sub has_test_failures { exists $_[0]->{_failures} && @{ $_[0]->{_failures} } }

=item $reporter->failures( )

report the failures (grouped by configurations).

=cut

sub failures {
    my $self = shift;

    return join "\n", map {
         join "\n", @{ $_->{cfgs} }, $_->{tests}, ""
    } @{ $self->{_failures} };
}

=item $repoarter->has_mani_failures( )

Returns true if C<< @{ $reporter->{_mani} >>.

=cut

sub has_mani_failures { exists $_[0]->{_mani} && @{ $_[0]->{_mani} } }

=item $reporter->mani_fail( )

report the MANIFEST failures.

=cut

sub mani_fail {
    my $self = shift;

    return join "\n", @{ $self->{_mani} }, "";
}

=item $reporter->bldenv_legend( )

Returns a string with the legend for build-environments

=cut

sub bldenv_legend {
    my $self = shift;
    my $locale = $self->{_locale};
    $self->{defaultenv} = ( @{ $self->{_tstenv} } == 1 )
        unless defined $self->{defaultenv};
    my $debugging = $self->{_rpt}{dbughow} || '-DDEBUGGING';

    return  $locale ? <<EOL : $self->{defaultenv} ? <<EOS : <<EOE;
| | | | | +- LC_ALL = $locale $debugging
| | | | +--- PERLIO = perlio $debugging
| | | +----- PERLIO = stdio  $debugging
| | +------- LC_ALL = $locale
| +--------- PERLIO = perlio
+----------- PERLIO = stdio

EOL
| +--------- $debugging
+----------- no debugging

EOS
| | | +----- PERLIO = perlio $debugging
| | +------- PERLIO = stdio  $debugging
| +--------- PERLIO = perlio
+----------- PERLIO = stdio

EOE
}

=item $reporter->letter_legend( )

Returns a string with the legend for the letters in the matrix.

=cut

sub letter_legend {
    require Test::Smoke::Smoker;
    return <<__EOL__
O = OK  F = Failure(s), extended report at the bottom
X = Failure(s) under TEST but not under harness
? = still running or test results not (yet) available
Build failures during:       - = unknown or N/A
c = Configure, m = make, M = make (after miniperl), t = make test-prep
__EOL__
}

sub signature {
    my $this_pver = $^V ? sprintf "%vd", $^V : $];
    my $build_info = "$Test::Smoke::VERSION build $Test::Smoke::REVISION";
    return <<__EOS__

-- 
Report by Test::Smoke v$build_info running on perl $this_pver
(Reporter v$VERSION / Smoker v$Test::Smoke::Smoker::VERSION)
__EOS__
}

1;

=back

=head1 SEE ALSO

L<Test::Smoke::Smoker>

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

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
