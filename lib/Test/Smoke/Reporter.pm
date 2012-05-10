package Test::Smoke::Reporter;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.050';

require File::Path;
require Test::Smoke;
use Cwd;
use File::Spec::Functions;
use JSON;
use LWP::UserAgent;
use POSIX qw( strftime );
use Test::Smoke::SysInfo;
use Text::ParseWords;
use Test::Smoke::Util qw( grepccmsg get_smoked_Config
                          time_in_hhmm get_local_patches );

my %CONFIG = (
    df_ddir         => curdir(),
    df_outfile      => 'mktest.out',
    df_rptfile      => 'mktest.rpt',
    df_jsnfile      => 'mktest.jsn',
    df_cfg          => undef,
    df_lfile        => undef,
    df_showcfg      => 0,

    df_locale       => undef,
    df_defaultenv   => undef,
    df_is56x        => undef,
    df_skip_tests   => undef,

    df_harnessonly  => undef,
    df_harness3opts => undef,

    df_v            => 0,
    df_user_note    => '',
);

=head1 NAME

Test::Smoke::Reporter - OO interface for handling the testresults (mktest.out)

=head1 SYNOPSIS

    use Test::Smoke;
    use Test::Smoke::Reporter;

    my $reporter = Test::Smoke::Reporter->new( %args );
    $reporter->write_to_file;
    $reporter->transport( $url );

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

    $fields{_conf_args} = { %args_raw };
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

Interpret the contents of the outfile and prepare them for processing,
so report can be made.

=cut

sub _parse {
    my $self = shift;

    $self->{_rpt}    = \my %rpt;
    $self->{_cache}  = {};
    $self->{_mani}   = [];
    $self->{configs} = \my @new;
    return $self unless defined $self->{_outfile};

    my ($cfgarg, $debug, $tstenv, $start, $statarg, $fcnt);
    $rpt{count} = 0;
    # reverse and use pop() instead of using unshift()
    my @lines           = reverse split m/\n+/, $self->{_outfile};
    my $previous        = "";
    my $previous_failed = "";

    while (defined (local $_ = pop @lines)) {
        m/^\s*$/ and next;
        m/^-+$/  and next;
        s/\s*$//;

        if (my ($status, $time) = /(Started|Stopped) smoke at (\d+)/) {
            if ($status eq "Started") {
                $start = $time;
                $rpt{started} ||= $time;
            }
            elsif (defined $start) {
                my $elapsed = $time - $start;
                $rpt{secs} += $elapsed;
                @new and $new[-1]{duration} = $elapsed;
            }
            next;
        }

        if (my ($patch) = m/^   \s*
                                Smoking\ patch\s*
                                ((?:[0-9a-f]+\s+\S+)|(?:\d+\S*))
                                /x )
        {
            my ($pl, $descr) = split ' ', $patch;
            $rpt{patchlevel} = $patch;
            $rpt{patch}      = $pl || $patch;
            $rpt{patchdescr} = $descr || $pl;
            next;
        }

        if (/^MANIFEST /) {
            push @{$self->{_mani}}, $_;
            next;
        }

        if (s/^\s*Configuration:\s*//) {

            # You might need to do something here with
            # the previous Configuration: $cfgarg
            $rpt{statcfg}{$statarg} = $fcnt if defined $statarg;
            $fcnt = 0;

            $rpt{count}++;
            s/-Dusedevel(\s+|$)//;
            s/\s*-des//;
            $statarg = $_;
            $debug = s/-D(DEBUGGING|usevmsdebug)\s*// ? "D" : "N";
            $debug eq 'D' and $rpt{dbughow} = "-D$1";
            s/\s+$//;

            $cfgarg = $_ || "";

            push(
                @new,
                {
                    arguments => $_,
                    debugging => $debug,
                    started   => __posixdate($start),
                    results   => [],
                }
            );
            push @{$rpt{cfglist}}, $_ unless $rpt{config}->{$cfgarg}++;
            $tstenv          = "";
            $previous_failed = "";
            next;
        }

        if (my ($cinfo) = /^Compiler info: (.+)$/) {
            $rpt{$cfgarg}->{cinfo} = $cinfo;
            $rpt{cinfo} ||= $cinfo;
            @{$new[-1]}{qw( cc ccversion )} = split m/ version / => $cinfo, 2;
            next;
        }

        if (m/(?:PERLIO|TSTENV)\s*=\s*([-\w:.]+)/) {
            $tstenv          = $1;
            $previous_failed = "";
            $rpt{$cfgarg}->{summary}{$debug}{$tstenv} ||= "?";
            my ($io_env, $locale) = split m/:/ => $tstenv,
                2;
            push(
                @{$new[-1]{results}},
                {
                    io_env        => $io_env,
                    locale        => $locale,
                    summary       => "?",
                    statistics    => undef,
                    stat_tests    => undef,
                    stat_cpu_time => undef,
                    failures      => [],
                }
            );

            # Deal with harness output
            s/^(?:PERLIO|TSTENV)\s*=\s+[-\w:.]+(?: :crlf)?\s*//;
        }

        if (m/\b(Files=[0-9]+,\s*Tests=([0-9]+),.*?=\s*([0-9.]+)\s*CPU)/) {
            $new[-1]{results}[-1]{statistics}    = $1;
            $new[-1]{results}[-1]{stat_tests}    = $2;
            $new[-1]{results}[-1]{stat_cpu_time} = $3;
        }
        elsif (
            m/\b(u=([0-9.]+)\s+
                    s=([0-9.]+)\s+
                    cu=([0-9.]+)\s+
                    cs=([0-9.]+)\s+
                    scripts=[0-9]+\s+
                    tests=([0-9]+))/xi
            )
        {
            $new[-1]{results}[-1]{statistics}    = $1;
            $new[-1]{results}[-1]{stat_tests}    = $6;
            $new[-1]{results}[-1]{stat_cpu_time} = $2 + $3 + $4 + $5;
        }

        if (m/^\s*All tests successful/) {
            $rpt{$cfgarg}->{summary}{$debug}{$tstenv} = "O";
            $new[-1]{results}[-1]{summary} = "O";
            next;
        }

        if (m/Inconsistent test ?results/) {
            ref $rpt{$cfgarg}->{$debug}{$tstenv}{failed}
                or $rpt{$cfgarg}->{$debug}{$tstenv}{failed} = [];

            if (not $rpt{$cfgarg}->{summary}{$debug}{$tstenv}
                or $rpt{$cfgarg}->{summary}{$debug}{$tstenv} ne "F")
            {
                $rpt{$cfgarg}->{summary}{$debug}{$tstenv} = "X";
                $new[-1]{results}[-1]{summary} = "X";
            }
            push @{$rpt{$cfgarg}->{$debug}{$tstenv}{failed}}, $_;
            push(
                @{$new[-1]{results}[-1]{failures}},
                m/^ \s* (\S+?) \.+ (\w+) \s* $/x
                    ? {
                        test   => $1,
                        status => $2,
                        extra  => []
                        }
                    : {
                        test   => "?",
                        status => "?",
                        extra  => []
                    }
            );
        }

        if (/^Finished smoking [\dA-Fa-f]+/) {
            $rpt{statcfg}{$statarg} = $fcnt;
            $rpt{finished} = "Finished";
            next;
        }

        if (my ($status, $mini) =
            m/^ \s* Unable\ to
                \ (?=([cbmt]))(?:build|configure|make|test)
                \ (anything\ but\ mini)?perl/x
                )
        {
            $mini and $status = uc $status;   # M for no perl but miniperl
                                              # $tstenv is only set *after* this
            $tstenv ||= $mini ? "minitest" : "stdio";
            $rpt{$cfgarg}->{summary}{$debug}{$tstenv} = $status;
            push(
                @{$new[-1]{results}},
                {
                    io_env        => $tstenv,
                    locale        => undef,
                    summary       => $status,
                    statistics    => undef,
                    stat_tests    => undef,
                    stat_cpu_time => undef,
                    failures      => [],
                }
            );
            $fcnt++;
            next;
        }

        if (m/FAILED/ || m/DIED/ || m/dubious$/ || m/\?\?\?\?\?\?$/) {
            ref $rpt{$cfgarg}->{$debug}{$tstenv}{failed}
                or $rpt{$cfgarg}->{$debug}{$tstenv}{failed} = [];

            if ($previous_failed ne $_) {
                if (not $rpt{$cfgarg}->{summary}{$debug}{$tstenv}
                    or $rpt{$cfgarg}->{summary}{$debug}{$tstenv} ne "X")
                {
                    $rpt{$cfgarg}->{summary}{$debug}{$tstenv} = "F";
                    $new[-1]{results}[-1]{summary} = "F";
                }
                push @{$rpt{$cfgarg}->{$debug}{$tstenv}{failed}}, $_;
                push(
                    @{$new[-1]{results}[-1]{failures}},
                    m/^ \s* (\S+?) \.+ (\w+) \s* $/x
                        ? {
                            test   => $1,
                            status => $2,
                            extra  => []
                            }
                        : {
                            test   => "?",
                            status => "?",
                            extra  => []
                        }
                );

                $fcnt++;
            }
            $previous_failed = $_;

            $previous = "failed";
            next;
        }

        if (m/PASSED/) {
            ref $rpt{$cfgarg}->{$debug}{$tstenv}{passed}
                or $rpt{$cfgarg}->{$debug}{$tstenv}{passed} = [];

            push @{$rpt{$cfgarg}->{$debug}{$tstenv}{passed}}, $_;
            push(
                @{$new[-1]{results}[-1]{failures}},
                m/^ \s* (\S+?) \.+ (\w+) \s* $/x
                    ? {
                        test   => $1,
                        status => $2,
                        extra  => []
                        }
                    : {
                        test   => "?",
                        status => "?",
                        extra  => []
                    }
            );
            $previous = "passed";
            next;
        }

        if (/^\s+(\d+(?:[-\s]+\d+)*)/) {
            if (ref $rpt{$cfgarg}->{$debug}{$tstenv}{$previous}) {
                push @{$rpt{$cfgarg}->{$debug}{$tstenv}{$previous}}, $_;
                push @{$new[-1]{results}[-1]{failures}[-1]{extra}}, $1;
            }
            next;
        }

        if (/^\s+(?:Bad plan)|(?:No plan found)|^\s+(?:Non-zero exit status)/) {
            if (ref $rpt{$cfgarg}->{$debug}{$tstenv}{failed}) {
                push @{$rpt{$cfgarg}->{$debug}{$tstenv}{failed}}, $_;
                s/^\s+//;
                push @{$new[-1]{results}[-1]{failures}[-1]{extra}}, $_;
            }
            next;
        }
        next;
    }

    $rpt{last_cfg} = $statarg;
    exists $rpt{statcfg}{$statarg} or $rpt{running} = $fcnt;
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

    unless (defined $self->{is56x}) {
        my %cfg = get_smoked_Config($self->{ddir}, "version");
        my $p_version = sprintf "%d.%03d%03d", split m/\./, $cfg{version};
        $self->{is56x} = $p_version < 5.007;
    }
    $self->{defaultenv} ||= $self->{is56x};

    my (%bldenv, %cfgargs);
    my $rpt = $self->{_rpt};
    foreach my $config (@{$rpt->{cfglist}}) {

        foreach my $buildenv (keys %{$rpt->{$config}{summary}{N}}) {
            $bldenv{$buildenv}++;
        }
        foreach my $buildenv (keys %{$rpt->{$config}{summary}{D}}) {
            $bldenv{$buildenv}++;
        }
        foreach my $ca (grep defined $_ => quotewords('\s+', 1, $config)) {
            $cfgargs{$ca}++;
        }
    }
    my %common_args =
        map { ($_ => 1) }
        grep $cfgargs{$_} == @{$rpt->{cfglist}}
        && !/^-[DU]use/ => keys %cfgargs;

    $rpt->{_common_args} = \%common_args;
    $rpt->{common_args} = join " ", sort keys %common_args;
    $rpt->{common_args} ||= 'none';

    $self->{_tstenv} = [reverse sort keys %bldenv];
    my %count = (
        O => 0,
        F => 0,
        X => 0,
        M => 0,
        m => 0,
        c => 0,
        o => 0,
        t => 0
    );
    my (%failures, %order);
    my $ord = 1;
    my (%todo_passed, %order2);
    my $ord2 = 1;
    my $debugging = $rpt->{dbughow} || '-DDEBUGGING';

    foreach my $config (@{$rpt->{cfglist}}) {
        foreach my $dbinfo (qw( N D )) {
            my $cfg = $config;
            ($cfg = $cfg ? "$debugging $cfg" : $debugging)
                if $dbinfo eq "D";
            $self->{v} and print "Processing [$cfg]\n";
            my $status = $self->{_rpt}{$config}{summary}{$dbinfo};
            foreach my $tstenv (reverse sort keys %bldenv) {
                next if $tstenv eq 'minitest' && !exists $status->{$tstenv};

                (my $showenv = $tstenv) =~ s/^locale://;
                if ($tstenv =~ /^locale:/) {
                    $self->{_locale_keys}{$showenv}++
                        or push @{$self->{_locale}}, $showenv;
                }
                $showenv = 'default'
                    if $self->{defaultenv} && $showenv eq 'stdio';

                $status->{$tstenv} ||= '-';

                my $status2 = $self->{_rpt}{$config}{$dbinfo};
                if (exists $status2->{$tstenv}{failed}) {
                    my $failed = join "\n", @{$status2->{$tstenv}{failed}};
                    if (   exists $failures{$failed}
                        && @{$failures{$failed}}
                        && $failures{$failed}->[-1]{cfg} eq $cfg)
                    {
                        push @{$failures{$failed}->[-1]{env}}, $showenv;
                    }
                    else {
                        push @{$failures{$failed}},
                            {
                            cfg => $cfg,
                            env => [$showenv]
                            };
                        $order{$failed} ||= $ord++;
                    }
                }
                if (exists $status2->{$tstenv}{passed}) {
                    my $passed = join "\n", @{$status2->{$tstenv}{passed}};
                    if (   exists $todo_passed{$passed}
                        && @{$todo_passed{$passed}}
                        && $todo_passed{$passed}->[-1]{cfg} eq $cfg)
                    {
                        push @{$todo_passed{$passed}->[-1]{env}}, $showenv;
                    }
                    else {
                        push(
                            @{$todo_passed{$passed}},
                            {
                                cfg => $cfg,
                                env => [$showenv]
                            }
                        );
                        $order2{$passed} ||= $ord2++;
                    }

                }

                $self->{v} > 1 and print "\t[$showenv]: $status->{$tstenv}\n";
                if ($tstenv eq 'minitest') {
                    $status->{stdio} = "M";
                    delete $status->{minitest};
                }
            }
            unless ($self->{defaultenv}) {
                exists $status->{perlio} or $status->{perlio} = '-';
                my @locales = split ' ', ($self->{locale} || '');
                for my $locale (@locales) {
                    exists $status->{"locale:$locale"}
                        or $status->{"locale:$locale"} = '-';
                }
            }

            $count{$_}++
                for map { m/[cmMtFXO]/ ? $_ : m/-/ ? 'O' : 'o' }
                map $status->{$_} => keys %$status;
        }
    }
    defined $self->{_locale} or $self->{_locale} = [];

    my @failures = map {
        {
            tests => $_,
            cfgs  => [
                map {
                    my $cfg_clean = __rm_common_args($_->{cfg}, \%common_args);
                    my $env = join "/", @{$_->{env}};
                    "[$env] $cfg_clean";
                } @{$failures{$_}}
            ],
        }
    } sort { $order{$a} <=> $order{$b} } keys %failures;
    $self->{_failures} = \@failures;

    my @todo_passed = map {
        {
            tests => $_,
            cfgs  => [
                map {
                    my $cfg_clean = __rm_common_args($_->{cfg}, \%common_args);
                    my $env = join "/", @{$_->{env}};
                    "[$env] $cfg_clean";
                } @{$todo_passed{$_}}
            ],
        }
    } sort { $order2{$a} <=> $order2{$b} } keys %todo_passed;
    $self->{_todo_passed} = \@todo_passed;

    $self->{_counters} = \%count;

    # Need to rebuild the test-environments as minitest changes into stdio
    my %bldenv2;
    foreach my $config (@{$rpt->{cfglist}}) {
        foreach my $buildenv (keys %{$rpt->{$config}{summary}{N}}) {
            $bldenv2{$buildenv}++;
        }
        foreach my $buildenv (keys %{$rpt->{$config}{summary}{D}}) {
            $bldenv2{$buildenv}++;
        }
    }
    $self->{_tstenvraw} = $self->{_tstenv};
    $self->{_tstenv}    = [reverse sort keys %bldenv2];
}

=item __posixdate($time)

Returns C<strftime("%F %T %z")>.

=cut

sub __posixdate {

    # Note that the format "%F %T %z" returns:
    #  Linux:  2012-04-02 10:57:58 +0200
    #  HP-UX:  April 08:53:32 METDST
    # ENOTPORTABLE!  %F is C99 only!
    my $stamp = shift || time;
    return POSIX::strftime("%Y-%m-%d %T %z", localtime $stamp);
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
    my( $name ) = shift || ( catfile $self->{ddir}, $self->{rptfile} );

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

=item $reporter->smokedb_data()

Transport the report to the gateway. The transported data will also be stored
locally in the file mktest.jsn

=cut

sub smokedb_data {
    my $self = shift;
    my %rpt  = map { $_ => $self->{$_} } keys %$self;
    $rpt{manifest_msgs}   = delete $rpt{_mani};
    $rpt{applied_patches} = [$self->registered_patches];
    $rpt{sysinfo}         = do {
        my %Conf = get_smoked_Config($self->{ddir} => qw( version lfile ));
        my $si = Test::Smoke::SysInfo->new;
        my ($osname, $osversion) = split m/ - / => $si->os, 2;
        (my $ncpu      = $si->ncpu          || "?") =~ s/^\s*(\d+)\s*/$1/;
        (my $user_note = $self->{user_note} || "")  =~ s/(\S)[\s\r\n]*\z/$1\n/;
        {
            architecture     => $si->cpu_type,
            config_count     => $self->{_rpt}{count},
            cpu_count        => $ncpu,
            cpu_description  => $si->cpu,
            duration         => $self->{_rpt}{secs},
            git_describe     => $self->{_rpt}{patchdescr},
            git_id           => $self->{_rpt}{patch},
            hostname         => $si->host,
            lang             => $ENV{LANG},
            lc_all           => $ENV{LC_ALL},
            osname           => $osname,
            osversion        => $osversion,
            perl_id          => $Conf{version},
            reporter         => $self->{_conf_args}{from},
            reporter_version => $VERSION,
            smoke_date       => __posixdate($self->{_rpt}{started}),
            smoke_revision   => $Test::Smoke::REVISION,
            smoker_version   => $Test::Smoke::Smoker::VERSION,
            smoke_version    => $Test::Smoke::VERSION,
            test_jobs        => $ENV{TEST_JOBS},
            username         => $ENV{LOGNAME} || getlogin || getpwuid($<) || "?",
            user_note        => $user_note,
            smoke_perl       => ($^V ? sprintf("%vd", $^V) : $]),
        };
    };
    $rpt{compiler_msgs} = [$self->ccmessages];
    $rpt{skipped_tests} = [$self->user_skipped_tests];
    $rpt{harness_only}  = delete $rpt{harnessonly};
    $rpt{summary}       = $self->summary;

    $rpt{log_file} = undef;
    my $rpt_fail = $rpt{summary} eq "PASS" ? 0 : 1;
    if (my $send_log = $rpt{_conf_args}{send_log}) {
        if (   ($send_log eq "always")
            or ($send_log eq "on_fail" && $rpt_fail))
        {
            local *FH;
            if (open FH, "<", $rpt{lfile}) {
                local $/;
                $rpt{log_file} = <FH>;
                close FH;
            }
        }
    }
    $rpt{out_file} = undef;
    if (my $send_out = $rpt{_conf_args}{send_out}) {
        if (   ($send_out eq "always")
            or ($send_out eq "on_fail" && $rpt_fail))
        {
            local *FH;
            if (open FH, "<", $rpt{outfile}) {
                local $/;
                $rpt{out_file} = <FH>;
                close FH;
            }
        }
    }
    delete $rpt{$_} for "user_note", grep m/^_/ => keys %rpt;

    my $json = JSON->new->utf8(1)->pretty(1)->encode(\%rpt);

    # write the json to file:
    local *JSN;
    if (open JSN, ">", catfile($self->{ddir}, $self->{jsnfile})) {
        binmode(JSN);
        print JSN $json;
        close JSN;
    }

    return $self->{_json} = $json;
}

=item $reporter->report( )

Return a string with the full report

=cut

sub report {
    my $self = shift;
    return unless defined $self->{_outfile};

    my $report = $self->preamble;

    $report .= "Summary: ".$self->summary."\n\n";
    $report .= $self->letter_legend . "\n";
    $report .= $self->smoke_matrix . $self->bldenv_legend;

    $report .= $self->registered_patches;

    $report .= $self->harness3_options;

    $report .= $self->user_skipped_tests;

    $report .= "\nFailures: (common-args) $self->{_rpt}{common_args}\n"
            .  $self->failures if $self->has_test_failures;
    $report .= "\n" . $self->mani_fail           if $self->has_mani_failures;

    $report .= "\nPassed Todo tests: (common-args) $self->{_rpt}{common_args}\n"
            .  $self->todo_passed if $self->has_todo_passed;

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

    my @lpatches = get_local_patches($self->{ddir}, $self->{v});
    @lpatches && $lpatches[0] eq "uncommitted-changes" and shift @lpatches;
    wantarray and return @lpatches;

    @lpatches or return "";

    my $list = join "\n", map "    $_" => @lpatches;
    return "\nLocally applied patches:\n$list\n";
}

=item $reporter->harness3_options

Show indication of the options used for C<HARNESS_OPTIONS>.

=cut

sub harness3_options {
    my $self = shift;

    $self->{harnessonly} or return "";

    my $msg = "\nTestsuite was run only with 'harness'";
    $self->{harness3opts} or return $msg . "\n";

    return  $msg . " and HARNESS_OPTIONS=$self->{harness3opts}\n";
}

=item $reporter->user_skipped_tests( )

Show indication for the fact that the user requested to skip some tests.

=cut

sub user_skipped_tests {
    my $self = shift;

    my @skipped;
    if ($self->{skip_tests} && -f $self->{skip_tests} and open my $fh,
        "<", $self->{skip_tests})
    {
        @skipped = map { chomp; "    $_" } <$fh>;
        close $fh;
    }
    wantarray and return @skipped;

    my $skipped = join "\n", @skipped or return "";

    return "\nTests skipped on user request:\n$skipped";
}

=item $reporter->ccmessages( )

Use a port of Jarkko's F<grepccerr> script to report the compiler messages.

=cut

sub ccmessages {
    my $self = shift;
    my $ccinfo = $self->{_rpt}{cinfo} || $self->{_ccinfo} || "cc";
    $ccinfo =~ s/^(.+)\s+version\s+.+/$1/;

    $^O =~ /^(?:linux|.*bsd.*|darwin)/ and $ccinfo = 'gcc';
    my $cc = $ccinfo =~ /(gcc|bcc32)/ ? $1 : $^O;

    $self->{v} and print "Looking for cc messages: '$cc'\n";
    my $errors = grepccmsg($cc, $self->{lfile}, $self->{v}) || [];

    local $" = "\n";
    return @$errors ? wantarray ? @$errors : <<EOERRORS : "";

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
 
    (my $ncpu = $si->ncpu || "") =~ s/^(\d+)\s*/$1 cpu/;
    $archname .= "/$ncpu";

    my $cpu = $si->cpu;

    my $this_host = $si->host;
    my $time_msg  = time_in_hhmm( $self->{_rpt}{secs} );
    my $savg_msg  = time_in_hhmm( $self->{_rpt}{avg}  );

    my $cinfo = $self->ccinfo;

    my $os = $si->os;

    return <<__EOH__;
Automated smoke report for $Config{version} patch $self->{_rpt}{patchlevel}
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
    my $pad = " " x int( (11 - length( $rpt->{patchdescr} ))/2 );
    my $patch = $pad . $rpt->{patchdescr};
    my $report = sprintf "%-11s  Configuration (common) %s\n", 
                         $patch, $rpt->{common_args};
    $report .= ("-" x 11) . " " . ("-" x 57) . "\n";

    foreach my $config ( @{ $rpt->{cfglist} } ) {
        my $letters = "";
        foreach my $dbinfo (qw( N D )) {
            foreach my $tstenv ( @{ $self->{_tstenv} } ) {
                $letters .= "$rpt->{$config}{summary}{$dbinfo}{$tstenv} ";
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
    my $self         = shift;
    my $count        = $self->{_counters};
    my @rpt_sum_stat = grep $count->{$_} > 0 => qw( X F M m c t );
    my $rpt_summary  = "";
    if (@rpt_sum_stat) {
        $rpt_summary = "FAIL(" . join("", @rpt_sum_stat) . ")";
    }
    else {
        $rpt_summary = $count->{o} == 0 ? "PASS" : "PASS-so-far";
    }

    return $rpt_summary;
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

=item $repoarter->has_todo_passed( )

Returns true if C<< @{ $reporter->{_todo_pasesd} >>.

=cut

sub has_todo_passed { exists $_[0]->{_todo_passed} && @{ $_[0]->{_todo_passed} } }

=item $reporter->todo_passed( )

report the todo that passed (grouped by configurations).

=cut

sub todo_passed {
    my $self = shift;

    return join "\n", map {
         join "\n", @{ $_->{cfgs} }, $_->{tests}, ""
    } @{ $self->{_todo_passed} };
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
    $self->{defaultenv} = ( @{ $self->{_tstenv} } == 1 )
        unless defined $self->{defaultenv};
    my $debugging = $self->{_rpt}{dbughow} || '-DDEBUGGING';

    if ( $self->{_locale} && @{ $self->{_locale} } ) {
        my @locale = ( @{ $self->{_locale} }, @{ $self->{_locale} } );
        my $lcnt = @locale;
        my $half = int(( 4 +  $lcnt ) / 2 );
        my $cnt = 2 * $half;

        my $line = '';
        for my $i ( 0 .. $cnt-1 ) {
            $line .= '| ' x ( $cnt - 1 - $i );
            $line .= '+';
            $line .= '-' x (2 * $i);
            $line .= '- ';

            if ( ($i % $half) < ($lcnt / 2) ) {
                my $locale = shift @locale;     # XXX: perhaps pop()
                $line .= "LC_ALL = $locale"
            } else {
                $line .= ( (($i - @{$self->{_locale}}) % $half) % 2 == 0 )
                    ? "PERLIO = perlio"
                    : "PERLIO = stdio ";
            }
            $i < $half and $line .= " $debugging";
            $line .= "\n";
        }
        return $line;
    }

    my $locale = ''; # XXX
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
    my $self = shift;
    my $this_pver = $^V ? sprintf "%vd", $^V : $];
    my $build_info = "$Test::Smoke::VERSION build $Test::Smoke::REVISION";
    (my $user_note = $self->{user_note} || "") =~ s/(\S)[\s\r\n]*\z/$1\n/;
    return <<__EOS__
$user_note
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

(c) 2002-2012, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>
  * H.Merijn Brand <hmbrand@cpan.org>

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
