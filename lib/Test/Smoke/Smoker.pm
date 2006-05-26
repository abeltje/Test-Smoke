package Test::Smoke::Smoker;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.029';

use Cwd;
use File::Spec::Functions qw( :DEFAULT abs2rel rel2abs );
use Config;
use Test::Smoke::Util qw( get_smoked_Config skip_filter );
BEGIN { eval q{ use Time::HiRes qw( time ) } }

my %CONFIG = (
    df_ddir           => curdir(),
    df_v              => 0,
    df_run            => 1,
    df_fdir           => undef,
    df_is56x          => 0,
    df_locale         => '',
    df_force_c_locale => 0,
    df_defaultenv     => 0,
    df_harness_destruct => 2,

    df_is_vms         => $^O eq 'VMS',
    df_vmsmake        => 'MMK',
    df_harnessonly    => scalar ($^O =~ /VMS/),

    df_is_win32       => $^O eq 'MSWin32',
    df_w32cc          => 'MSVC60',
    df_w32make        => 'nmake',
    df_w32args        => [ ],

    df_makeopt        => "",
    df_testmake       => undef,
);

# Define some constants that we can use for
# specifying how far "make" got.
sub BUILD_MINIPERL() { -1 } # but no perl
sub BUILD_PERL    () {  1 } # ok
sub BUILD_NOTHING () {  0 } # not ok

sub HARNESS_RE1 () {
     '(\S+\.t)(?:\s+[\d?]+){0,4}(?:\s+[\d?.]*%)?\s+([\d?]+(?:[-\s]+\d+-?)*)$'
}
sub HARNESS_RE2() { '^\s+(\d+(?:[-\s]+\d+)*-?)$' }

=head1 NAME

Test::Smoke::Smoker - OO interface to do one smoke cycle.

=head1 SYNOPSIS

    use Test::Smoke;
    use Test::Smoke::Smoker;

    open LOGFILE, "> mktest.out" or die "Cannot create 'mktest.out': $!";
    my $buildcfg = Test::SmokeBuildCFG->new( $conf->{cfg} );
    my $policy = Test::Smoke::Policy->new( '../', $conf->{v} );
    my $smoker = Test::Smoke::Smoker->new( \*LOGFILE, $conf );

    foreach my $config ( $buildcfg->configurations ) {
        $smoker->smoke( $config, $policy );
    }

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item Test::Smoke::Smoker->new( \*GLOB, %args )

C<new()> takes a mandatory (opened) filehandle and some other options:

    ddir            build directory
    fdir            The forest source
    v               verbose level: 0..2
    defaultenv      'make test' without $ENV{PERLIO}
    is56x           skip the PerlIO stuff?
    locale          do another testrun with $ENV{LC_ALL}
    force_c_locale  set $ENV{LC_ALL} = 'C' for all smoke runs

    is_win32        is this MSWin32?
    w32cc           the CCTYPE for MSWin32 (MSVCxx BORLAND GCC)
    w32make         the maker to use for CCTYPE

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $fh = shift;

    unless ( ref $fh eq 'GLOB' ) {
        require Carp;
        Carp::croak sprintf "Usage: %s->new( \\*FH, %%args )", __PACKAGE__;
    }

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } keys %{ Test::Smoke::Smoker->config( 'all_defaults' ) };

    $fields{logfh}  = $fh;
    select( ( select( $fh ), $|++ )[0] );
    $fields{defaultenv} = 1 if $fields{is56x};
    $^O =~ /VMS/i and $fields{is_vms} = 1;

    unless ( defined $fields{testmake} ) {
        $fields{testmake} = 'make';
        $fields{is_win32} and $fields{testmake} = $fields{w32make};
        $fields{is_vms}   and $fields{testmake} = $fields{vmsmake};
    }
    my $self = bless { %fields }, $class;

    return $self;
}

sub mark_in {
    my $self = shift;
    $self->log( sprintf "Started smoke at %d\n", time() );
}

sub mark_out {
    my $self = shift;
    $self->log( sprintf "Stopped smoke at %d\n", time() );
}

=item Test::Smoke::Smoker->config( $key[, $value] )

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

=item $smoker->tty( $message )

Prints a message to the default filehandle.

=cut

sub tty {
    my $self = shift;
    my $message = join "", @_;
    print $message;
}

=item $smoker->log( $message )

Prints a message to the logfile, filehandle.

=cut

sub log {
    my $self = shift;
    my $message = join "", @_;
    print { $self->{logfh} } $message;
}

=item $smoker->ttylog( $message )

Prints a message to both the default and the logfile filehandles.

=cut

sub ttylog {
    my $self = shift;
    $self->log( @_ );
    $self->tty( @_ );
}

=item $smoker->smoke( $config[, $policy] )

C<smoke()> takes a B<Test::Smoke::BuildCFG::Config> object and runs all 
the basic steps as (private) object methods.

=cut

sub smoke {
    my( $self, $config, $policy ) = @_;

    $self->{is_vms} and $self->_vms_rooted_logical;

    $self->make_distclean;

    $self->{v} > 1 and $self->extra_manicheck;

    $self->handle_policy( $policy, $config->policy );

    my $c_result = $self->Configure( $config );
    # Log the compiler info now, the last config could fail
    { # can we config.sh without Configure success?
        my %cinfo = get_smoked_Config( $self->{ddir} => qw(
            cc ccversion gccversion 
        ));
        my $version = $cinfo{gccversion} || $cinfo{ccversion};
        $self->log( "\nCompiler info: $cinfo{cc} version $version\n" )
            if $cinfo{cc};
    }

    $c_result or do {
        $self->ttylog( "Unable to configure perl in this configuration\n" );
        return 0;
    };

    my %sconf = get_smoked_Config( $self->{ddir} => 'ldlibpthname' );
    exists $sconf{ldlibpthname} or $sconf{ldlibpthname} = "";
    $sconf{ldlibpthname} and 
        local $ENV{ $sconf{ldlibpthname} } = $ENV{ $sconf{ldlibpthname} } || '',
        substr( $ENV{ $sconf{ldlibpthname} }, 0, 0) =
            "$self->{ddir}$Config{path_sep}";

    my $build_stat = $self->make_( $config );
  
    $build_stat == BUILD_MINIPERL and do {
        $self->ttylog( "Unable to make anything but miniperl",
                       " in this configuration\n" );
        return $self->make_minitest( "$config" );
    };
       
    $build_stat == BUILD_NOTHING and do {
        $self->ttylog( "Unable to make perl in this configuration\n" );
        return 0;
    };

    $self->make_test_prep or do {
        $self->ttylog( "Unable to test perl in this configuration\n" );
        return 0;
    };

    $self->make_test( $config );

#    $self->{is_vms} and $self->_unset_rooted_logical;
    return 1;
}

=item $smoker->make_distclean( )

C<make_distclean()> runs C<< make -i distclean 2>/dev/null >>

=cut

sub make_distclean {
    my $self = shift;
    
    $self->tty( "make distclean ..." );
    if ( $self->{fdir} && -d $self->{fdir} ) {
        require Test::Smoke::Syncer;
        my %options = (
            hdir => $self->{fdir},
            ddir => cwd(),
            v    => 0,
        );
        my $distclean = Test::Smoke::Syncer->new( hardlink => %options );
        $distclean->clean_from_directory( $self->{fdir}, 'mktest.out' );
    } else {
        my $target = $self->{is_vms} ? 'realclean' : '-i distclean';
        $self->_make( "$target 2>/dev/null" );
    }
}

=item $smoker->extra_manicheck( )

C<extra_manicheck()> will only work for C<< $self->{v} > 1 >> and does
an extra integrity check comparing F<MANIFEST> and the
source-tree. Output is send to the tty.

=cut

sub extra_manicheck {
    my $self = shift;
    $self->{v} > 1 or return;

    require Test::Smoke::SourceTree;
    Test::Smoke::SourceTree->import( qw( :mani_const ) );
    my $tree = Test::Smoke::SourceTree->new( $self->{ddir} );
    my $mani_check = $tree->check_MANIFEST(qw( mktest.out mktest.rpt ));
    foreach my $file ( sort keys %$mani_check ) {
        if ( $mani_check->{ $file } == ST_MISSING() ) {
            $self->tty( "manicheck: missing '$file' (not in source-tree)\n" );
        } elsif ( $mani_check->{ $file } == ST_UNDECLARED() ) {
            $self->tty( "manicheck: extra '$file' (not in MANIFEST)\n" );
        }
    }
}

=item $smoker->handle_policy( $policy, @substs );

C<handle_policy()> will try to apply the substition rules and then 
write the file F<Policy.sh>.

=cut

sub handle_policy {
    my $self = shift;
    my( $policy, @substs ) = @_;

    return unless UNIVERSAL::isa( $policy, 'Test::Smoke::Policy' );

    $self->tty( "\nCopy Policy.sh ..." );
    $policy->reset_rules;
    if ( @substs ) {
        $policy->set_rules( $_ ) foreach @substs;
    }
    $policy->write;
}

=item $smoker->Configure( $config )

C<Configure()> sorts out the MSWin32 mess and calls F<./Configure>

returns true if a makefile was created

=cut

sub Configure {
    my $self = shift;
    my( $config, $policy ) = @_;

    $self->tty( "\nConfigure ..." );
    my $makefile = '';
    if ( $self->{is_win32} ) {
        my @w32args = @{ $self->{w32args} };
        @w32args = @w32args[ 4 .. $#w32args ];
        my $w32_cfg = "$config" =~ /-DCCTYPE=/
            ? "$config" : "$config -DCCTYPE=$self->{w32cc}";

        $makefile = $self->_run( "./Configure $w32_cfg", 
                                 \&Test::Smoke::Util::Configure_win32,
                                 $self->{w32make}, @w32args  );
    } elsif ( $self->{is_vms} ) {
        my $vms_cfg = $config->vms;
        $self->_run( qq/\@configure -"des" $vms_cfg/ );
        $makefile = 'DESCRIP.MMS';
    } else {
        $self->_run( "./Configure -des $config" );
        $makefile = 'Makefile';
    }
    return -f $makefile;
}

=item $smoker->make_( )

C<make_()> will run make.

returns true if a perl executable is found

=cut

sub make_ {
    my $self = shift;
    my $config = shift;

    $self->tty( "\nmake ..." );
    my $make_args = "";
    $self->{is_vms} && $config->has_arg( '-Dusevmsdebug' ) and
        $make_args = qq[/macro=("__DEBUG__=1")];
    my $make_output = $self->_make( $make_args );

    if ( $self->{is_win32} ) { # Win32 creates config.sh during make
        my %cinfo = get_smoked_Config( $self->{ddir} => qw(
            cc ccversion gccversion
        ));
        my $version = $cinfo{gccversion} || $cinfo{ccversion};
        $self->log( "\nCompiler info: $cinfo{cc} version $version\n" )
            if $cinfo{cc};

        $self->{w32cc} =~ /MSVC|BORLAND/ and $self->tty( "\n$make_output\n" );
    }

    my $exe_ext  = $Config{_exe} || $Config{exe_ext};
    my $miniperl = "miniperl$exe_ext";
    my $perl     = "perl$exe_ext";
    $perl = "ndbg$perl" if $self->{is_vms} && $config->has_arg('-Dusevmsdebug');
    -x $miniperl or return BUILD_NOTHING;
    return -x $perl 
        ? $self->{_run_exit} ? BUILD_MINIPERL : BUILD_PERL
        : BUILD_MINIPERL;
}

=item make_test_prep( )

Run C<< I<make test-perp> >> and check if F<t/perl> exists.

=cut

sub make_test_prep {
    my $self = shift;
    $self->{harnessonly} and return 1; # no test-prep target

    my $exe_ext = $Config{_exe} || $Config{exe_ext};
    my $perl = catfile( "t", "perl$exe_ext" );

    $self->{run} and unlink $perl;
    $self->_make( "test-prep" );

    return $self->{is_win32} ? -f $perl : -l $perl;
}

=item $smoker->make_test( )

=cut

sub make_test {
    my $self = shift;
    my( $config ) = @_;
    my $config_args = "$config";

    $self->tty( "\n Tests start here:\n" );

    # No use testing different io layers without PerlIO
    # just output 'stdio' for mkovz.pl
    my @layers = ( ($config_args =~ /-Uuseperlio\b/) || $self->{defaultenv} )
               ? qw( stdio ) : qw( stdio perlio );

    if ( !($config_args =~ /-Uuseperlio\b/ || $self->{defaultenv}) && 
         $self->{locale} ) {
        push @layers, 'locale';
    }

    foreach my $perlio ( @layers ) {
        my $had_LC_ALL = exists $ENV{LC_ALL};
        local( $ENV{PERLIO}, $ENV{LC_ALL}, $ENV{PERL_UNICODE} ) =
             ( "", defined $ENV{LC_ALL} ? $ENV{LC_ALL} : "", "" );
        my $perlio_logmsg = $perlio;
        if ( $perlio ne 'locale' ) {
            $ENV{PERLIO} = $perlio;
            $self->{is_win32} and $ENV{PERLIO} .= " :crlf";
            $ENV{LC_ALL} = 'C' if $self->{force_c_locale};
            $ENV{LC_ALL} or delete $ENV{LC_ALL};
            delete $ENV{PERL_UNICODE};
            # make default 'make test' runs possible
            delete $ENV{PERLIO} if $self->{defaultenv};
        } else {
            $ENV{PERL_UNICODE} = ""; # See -C in perlrun
            $ENV{LC_ALL} = $self->{locale};
            $perlio_logmsg .= ":$self->{locale}";
        }
        $self->ttylog( "TSTENV = $perlio_logmsg\t" );

        unless ( $self->{run} ) {
            $self->ttylog( "bailing out (--norun)...\n" );
            next;
	}

        my $test_target = $self->{is_vms}
            ? 'test' : $self->{is56x} ? 'test-notty' : '_test';
        local *TST;
        # MSWin32 builds from its own directory
        if ( $self->{is_win32} ) {
            chdir "win32" or die "unable to chdir () into 'win32'";
            # Same as in make ()
            open TST, "$self->{w32make} -f smoke.mk $test_target |";
            chdir ".." or die "unable to chdir () out of 'win32'";
        } elsif ( !$self->{harnessonly} ) {
            local $ENV{PERL} = "./perl";
            open TST, "$self->{testmake} $test_target |" or do {
                use Carp;
                Carp::carp "Cannot fork '$self->{testmake} $test_target': $!";
                next;
            };
        }

        my @nok = ();
        unless ( $self->{harnessonly} ) {
            select ((select (TST), $| = 1)[0]);
            while (<TST>) {
                $self->{v} > 1 and $self->tty( $_ );
                skip_filter( $_ ) and next;
    
                # make mkovz.pl's life easier
                s/(.)(TSTENV\s+=\s+\w+)/$1\n$2/;
    
                if (m/^u=.*tests=/) {
                    s/(\d\.\d*) /sprintf "%.2f ", $1/ge;
                    $self->log( $_ );
                } else {
                    push @nok, $_;
                }
                $self->tty( $_ );
            }
            close TST or do {
                my $error = $! || ( $? >> 8);
                require Carp;
                Carp::carp "\nError while reading test-results: $error";
            };
#            $self->log( map { "    $_" } @nok );
            if (grep m/^All tests successful/, @nok) {
                $self->log( "All tests successful.\n" );
                $self->tty( "\nOK, archive results ..." );
                $self->{patch} and
                    $nok[0] =~ s/\./ for .patch = $self->{patch}./;
            } else {
                $self->extend_with_harness( @nok );
            }
            $self->tty( "\n" );
        } else {
            @nok = $self->mmk_test_harness( $config );
        }
        !$had_LC_ALL && exists $ENV{LC_ALL} and delete $ENV{LC_ALL};
    }

    return 1;
}

=item $self->extend_with_harness( @nok )

=cut

sub extend_with_harness {
    my $self = shift;
    my %inconsistent = $self->_transform_testnames( @_ );
    my @harness = sort keys %inconsistent;
    my $harness_re1 = HARNESS_RE1();
    my $harness_re2 = HARNESS_RE2();
    if ( @harness ) {

        # @20051016 By request of Nicholas Clark
        local $ENV{PERL_DESTRUCT_LEVEL} = $self->{harness_destruct};
        local $ENV{PERL_SKIP_TTY_TEST} = 1;

        # I'm not happy with this PERLSHR approach for VMS
        local $ENV{PERLSHR} = $ENV{PERLSHR} || "";
        $self->{is_vms} and
             $ENV{PERLSHR} = catfile( $self->{ddir},
                                      'PERLSHR' . $Config{_exe} );
        my $harness = join " ", @harness;
        $self->tty( "\nExtending failures with harness:\n\t$harness\n" );
        my $changed_dir;
        chdir 't' and $changed_dir = 1;
        my $all_ok = 0;
        my $tst_perl = catfile( curdir(), 'perl' );
        my $verbose = $self->{v} > 1 ? "-v" : "";
        my @run_harness = $self->_run( "$tst_perl harness $verbose $harness" );
        my $harness_out = $self->_parse_harness( \%inconsistent, $all_ok,
                                                 @run_harness );

        # safeguard against empty results
        $inconsistent{ $_ } ||= 'FAILED' for keys %inconsistent;
        $harness_out =~ s/^\s*$//;
        if ( $all_ok ) {
            $harness_out .= scalar keys %inconsistent
                ? "Inconsistent test results (between TEST and harness):\n" . 
                  join "", map {
                      my $dots = '.' x (40 - length $_ );
                      "    $_${dots}$inconsistent{ $_ }\n";
                  } keys %inconsistent
                : $harness_out ? "" : "All tests successful.";
        } else {
            $harness_out .= scalar keys %inconsistent
                ? "Inconsistent test results (between TEST and harness):\n" . 
                  join "", map {
                      my $dots = '.' x (40 - length $_ );
                      "    $_${dots}$inconsistent{ $_ }\n";
                  } keys %inconsistent
                : "";
        }
        $self->ttylog("\n", $harness_out, "\n" );
        $changed_dir and chdir updir();
    }
}

=item $self->mmk_test_harness

The VMS test-output is different from other platforms, but
Test::Harness knows how to deal with it. On VMS we only run C<mmk
test_harness> and take the summary.

This might be useful for all platforms...

=cut

sub mmk_test_harness {
    my $self = shift;
    my( $config ) = @_;

    my $debugging = $self->{is_vms} && $config->has_arg( '-Dusevmsdebug' )
        ? qq[/macro=("__DEBUG__=1")] : "";

    my $seenheader = 0;
    my @failed = ( );

    my $cmd = "$self->{testmake}$debugging test_harness";
        
    local *TST;
    open TST, "$cmd |" or die "Cannot spawn($cmd): $!";
    
    while ( <TST> ) {
        $self->{v} > 1 and $self->tty( $_ );

        /All tests successful/ and push( @failed, $_ ), last;

        /Failed Test\s+Stat/ and $seenheader = 1, next;
        $seenheader or next;
    
        my( $name, $fail ) = m/(\S+\.t)\s+.+%\s+([\d?]+(?:[-\s]+\d+)*)/;
        if ( $name ) {
            my $dots = '.' x (40 - length $name );
            push @failed, "    $name${dots}FAILED $fail\n";
        } else {
            ( $fail ) = m/^\s+(\d+(?:[-\s]+\d+)*)/;
            next unless $fail;
            push @failed, " " x 51 . "$fail\n";
        }
    
    }
    $self->ttylog( "\n", join( "", @failed ), "\n" );
    close TST or do {
        my $error = $! || ( $? >> 8);
        require Carp;
        Carp::carp "\nError while reading test_harness-results: $error";
    };
}

=item $self->make_minitest( $cfgargs )

C<make> was unable to build a I<perl> executable, but managed to build
I<miniperl>, so we do C<< S<make minitest> >>.

=cut

sub make_minitest {
    my $self = shift;

    $self->ttylog( "TSTENV = minitest\t" );
    local *TST;
    # MSWin32 builds from its own directory
    if ( $self->{is_win32} ) {
        chdir "win32" or die "unable to chdir () into 'win32'";
        # Same as in make ()
        open TST, "$self->{w32make} -f smoke.mk minitest |";
        chdir ".." or die "unable to chdir () out of 'win32'";
    } elsif ( $self->{is_vms} ) {
        open TST, "$self->{vmsmaker} minitest |" or do {
            use Carp;
            Carp::carp "Cannot fork '$self->{vmsmaker} minitest': $!";
            return 0;
        };
    } else {
        local $ENV{PERL} = "./perl";
        open TST, "make minitest |" or do {
            use Carp;
            Carp::carp "Cannot fork 'make minitest': $!";
            return 0;
        };
    }

    my @nok = ();
    select ((select (TST), $| = 1)[0]);
    while (<TST>) {
        $self->{v} >= 2 and $self->tty( $_ );
        skip_filter( $_ ) and next;
        # make mkovz.pl's life easier
        s/(.)(PERLIO\s+=\s+\w+)/$1\n$2/;

        if (m/^u=.*tests=/) {
            s/(\d\.\d*) /sprintf "%.2f ", $1/ge;
            $self->log( $_ );
        } else {
            push @nok, $_;
        }
        $self->tty( $_ );
    }
    close TST or do {
        require Carp;
        Carp::carp "Error while reading pipe: $!";
    };
    $self->ttylog( map { "    $_" } @nok );

    $self->tty( "\nOK, archive results ..." );
    $self->tty( "\n" );
    return 1;
}

=item $self->_parse_harness_output( $\%notok, $all_ok, @lines )

Fator out the parsing of the Test::Harness output, as it seems subject
to change.

=cut

sub _parse_harness {
    my( $self, $notok, $all_ok, @lines ) = @_;
    my $harness_re1 = HARNESS_RE1();
    my $harness_re2 = HARNESS_RE2();

    my $output = join "", map {
        my( $name, $fail ) = m/$harness_re1/;
        if ( $name ) {
            delete $notok->{ $name };
            my $dots = '.' x (40 - length $name );
            "    $name${dots}FAILED $fail\n";
        } else {
            ( $fail ) = m/$harness_re2/;
            " " x 51 . "$fail\n";
        }
    } grep m/$harness_re2/ || m/$harness_re1/ => map {
        /All tests successful/ && $all_ok++;
        $self->{v} and $self->tty( $_ );
        $_;
    } @lines;

    $_[2] = $all_ok;
    return $output;
}

=item $self->_trasnaform_testnames( @notok )

C<_transform_testnames()> takes a list of testnames, as found by
C<TEST> (testname without C<.t> suffix followed by dots and a reason)
and returns a hash with the filenames relative to the C<t/> directory
as keys and the reason as value.

=cut

sub _transform_testnames {
    my( $self, @notok ) = @_;
    my %inconsistent;
    for my $nok ( @notok ) {
        $nok =~ m!^(?:\.\.[\\/])?(\w+[\\/][-\w/\\]+)\.*(.*)! or next;
        my( $test_name, $status ) = ( $1, $2 );
        $test_name .= '.t';

        $test_name = $test_name =~ /^(?:ext|lib|t)\b/
            ? catfile( updir(), $test_name )
            : catfile( updir(), 't', $test_name );

        my $test_base = catdir( $self->{ddir}, 't' );
        $test_name = rel2abs( $test_name, $test_base );

        my $test_path = abs2rel( $test_name, $test_base );
        $test_path =~ tr!\\!/! if $self->{is_win32};
        $inconsistent{ $test_path } ||= $status;
    }
    return %inconsistent;
}

=item $self->_run( $command[, $sub[, @args]] )

C<_run()> returns C<< qx( $command ) >> unless C<$sub> is specified.
If C<$sub> is defined (and a coderef) C<< $sub->( $command, @args ) >> will
be called.

=cut

sub _run {
    my $self = shift;
    my( $command, $sub, @args ) = @_;

    $self->{v} > 1 and print "[$command]\n";
    defined $sub and return &$sub( $command, @args );

    my @output = qx( $command );
    $self->{_run_exit} = $? >> 8;
    return wantarray ? @output : join " ", @output;
}

=item $self->_make( $command )

C<_make()> calls C<< run( "make $command" ) >>, and does some extra
stuff to help MSWin32 (the right maker, the directory).

=cut

sub _make {
    my $self = shift;
    my $cmd = shift;
    $self->{makeopt} and $cmd = "$self->{makeopt} $cmd";

    $self->{is_win32} || $self->{is_vms} or return $self->_run( "make $cmd" );

    my $kill_err;
    # don't capture STDERR
    # @ But why? and what if we do it DOSish? 2>NUL:

    my $maker = $self->{is_vms} ? $self->{vmsmake} : $self->{w32make};
    $cmd =~ s|2\s*>\s*/dev/null\s*$|| and $kill_err = 1;

    if ( $self->{is_win32} ) {
        $cmd = "$maker -f smoke.mk $cmd";
        chdir "win32" or die "unable to chdir () into 'win32'";
    } else {
        $cmd = "$maker $cmd";
    }
    my @output = $self->_run( 
        $kill_err ? qq{$^X -e "close STDERR; system '$cmd'"} : $cmd
    );
    if ( $self->{is_win32} ) {
        chdir ".." or die "unable to chdir() out of 'win32'";
    }
    return wantarray ? @output : join "", @output;
}

=item $smoker->_vms__rooted_logical

This code sets up a rooted logical C<TSP5SRC> and changes the {ddir}
to that root.

=cut

sub _vms_rooted_logical {
    my $self = shift;
    return unless $^O eq 'VMS';

    Test::Smoke::Util::set_vms_rooted_logical( TSP5SRC => $self->{ddir} );
    $self->{vms_ddir} = $self->{ddir};
    $self->{ddir} = 'TSP5SRC:[000000]';

}

1;

=back

=head1 SEE ALSO

L<Test::Smoke>

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
