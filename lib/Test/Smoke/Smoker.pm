package Test::Smoke::Smoker;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.003';

use Cwd;
use File::Spec;
use Config;
use Test::Smoke::Util;
BEGIN { eval q{ use Time::HiRes qw( time ) } }

my %CONFIG = (
    df_ddir           => File::Spec->curdir(),
    df_v              => 0,
    df_run            => 1,
    df_fdir           => undef,
    df_is56x          => 0,
    df_locale         => '',
    df_force_c_locale => 0,
    df_defaultenv     => 0,

    df_is_win32       => $^O eq 'MSWin32',
    df_w32cc          => 'MSVC60',
    df_w32make        => 'nmake',
    df_w32args        => [ ],
);

# Define some constants that we can use for
# specifying how far "make" got.
sub BUILD_MINIPERL() { -1 } # but no perl
sub BUILD_PERL    () {  1 } # ok
sub BUILD_NOTHING () {  0 } # not ok

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

    bless { %fields }, $class;
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

    $self->make_distclean;

    $self->handle_policy( $policy, $config->policy );

    $self->Configure( $config ) or do {
        $self->ttylog( "Unable to configure perl in this configuration\n" );
        return 0;
    };

    my $build_stat = $self->make_;
  
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

    $self->make_test( "$config" );

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
        $self->_make( "-i distclean 2>/dev/null" );
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
        $makefile = $self->_run( "./Configure $config", 
                                 \&Test::Smoke::Util::Configure_win32,
                                 $self->{w32make}, @w32args  );
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

    $self->tty( "\nmake ..." );
    $self->_make( "" );

    my $exe_ext  = $Config{_exe} || $Config{exe_ext};
    my $miniperl = "miniperl$exe_ext";
    my $perl     = "perl$exe_ext";
    -x $miniperl or return BUILD_NOTHING;
    return -x $perl ? BUILD_PERL : BUILD_MINIPERL;
}

=item make_test_prep( )

Run C<< I<make test-perp> >> and check if F<t/perl> exists.

=cut

sub make_test_prep {
    my $self = shift;

    my $exe_ext = $Config{_exe} || $Config{exe_ext};
    my $perl = File::Spec->catfile( "t", "perl$exe_ext" );

    $self->{run} and unlink $perl;
    $self->_make( "test-prep" );

    return $self->{is_win32} ? -f $perl : -l $perl;
}

=item $smoker->make_test( )

=cut

sub make_test {
    my $self = shift;
    my( $config_args ) = @_;

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
        $self->ttylog( "PERLIO = $perlio_logmsg\t" );

        unless ( $self->{run} ) {
            $self->ttylog( "bailing out ...\n" );
            next;
	}

        my $test_target = $self->{is56x} ? 'test' : '_test';
        local *TST;
        # MSWin32 builds from its own directory
        if ( $self->{is_win32} ) {
            chdir "win32" or die "unable to chdir () into 'win32'";
            # Same as in make ()
            open TST, "$self->{w32make} -f smoke.mk $test_target |";
            chdir ".." or die "unable to chdir () out of 'win32'";
        } else {
            local $ENV{PERL} = "./perl";
            open TST, "make $test_target |" or do {
                use Carp;
                Carp::carp "Cannot fork 'make _test': $!";
                next;
            };
        }

        my @nok = ();
        select ((select (TST), $| = 1)[0]);
        while (<TST>) {
            $self->{v} > 2 and $self->tty( $_ );
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
            my $error = $! || ( $? >> 8);
            require Carp;
            Carp::carp "\nError while reading test-results: $error";
        };
#        $self->log( map { "    $_" } @nok );
        if (grep m/^All tests successful/, @nok) {
            $self->log( "All tests successful\n" );
            $self->tty( "\nOK, archive results ..." );
            $self->{patch} and $nok[0] =~ s/\./ for .patch = $self->{patch}./;
        } else {
            $self->extend_with_harness( @nok );
        }
        $self->tty( "\n" );
        !$had_LC_ALL && exists $ENV{LC_ALL} and delete $ENV{LC_ALL};
    }

    return 1;
}

=item $self->extend_with_harness( @nok )

=cut

sub extend_with_harness {
    my( $self, @nok ) = @_;
    my @harness;
    for ( @nok ) {
        m!^(?:\.\.[\\/])?(\w+/[-\w/]+).*! or next;
        # Remeber, we chdir into t, so -f is false for op/*.t etc
        my $test_name = "$1.t";
        push @harness, (-f $test_name) 
            ? File::Spec->catdir( File::Spec->updir, $test_name )
            : $test_name;
    }
    if ( @harness ) {
        local $ENV{PERL_SKIP_TTY_TEST} = 1;
	        $self->tty( "\nExtending failures with Harness\n" );
        my $harness = $self->{is_win32} ?
        join " ", map { 
            s{^\.\.[/\\]}{};
	            m/^(?:lib|ext)/ and $_ = "../$_";
            $_;
        } @harness : "@harness";
        my $changed_dir;
        chdir 't' and $changed_dir = 1;
        my $harness_out = join "", map {
            my( $name, $fail ) = 
                m/(\S+\.t)\s+.+[?%]\s+(\d+(?:[-\s]+\d+)*)/;
            my $dots = '.' x (40 - length $name );
            "$name${dots}FAILED $fail\n";
        } grep m/\S+\.t\s+.+?\d+(?:[-\s+]\d+)*/ =>
            $self->_run( "./perl harness $harness" );
        $harness_out =~ s/^\s*$//;
        $harness_out ||= join "", map "    $_" => @nok;
        $self->ttylog("\n", $harness_out );
        $changed_dir and chdir File::Spec->updir;
    }
}

=item $self->make_minitest( $cfgargs )

C<make> was unable to build a I<perl> executable, but managed to build
I<miniperl>, so we do C<< S<make minitest> >>.

=cut

sub make_minitest {
    my $self = shift;

    $self->ttylog( "PERLIO = minitest\t" );
    local *TST;
    # MSWin32 builds from its own directory
    if ( $self->{is_win32} ) {
        chdir "win32" or die "unable to chdir () into 'win32'";
        # Same as in make ()
        open TST, "$self->{w32make} -f smoke.mk minitest |";
        chdir ".." or die "unable to chdir () out of 'win32'";
    } else {
        local $ENV{PERL} = "./perl";
        open TST, "make minitest |" or do {
            use Carp;
            Carp::carp "Cannot fork 'make _test': $!";
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

=item $self->_run( $command[, $sub[, @args]] )

C<run()> returns C<< qx( $command ) >> unless C<$sub> is specified.
If C<$sub> is defined (and a coderef) C<< $sub->( $command, @args ) >> will
be called.

=cut

sub _run {
    my $self = shift;
    my( $command, $sub, @args ) = @_;

    defined $sub and return &$sub( $command, @args );

    return qx( $command );
}

=item $self->_make( $command )

C<_make()> calls C<< run( "make $command" ) >>, and does some extra
stuff to help MSWin32 (the right maker, the directory).

=cut

sub _make {
    my $self = shift;
    my $cmd = shift;

    $self->{is_win32} or return $self->_run( "make $cmd" );

    my $kill_err;
    # don't capture STDERR
    # @ But why? and what if we do it DOSish? 2>NUL:

    my $win32_maker = $self->{w32make};
    $cmd =~ s|2\s*>\s*/dev/null\s*$|| and $kill_err = 1;

    $cmd = "$win32_maker -f smoke.mk $cmd";
    chdir "win32" or die "unable to chdir () into 'win32'";
    $self->_run( $kill_err ? qq{$^X -e "close STDERR; system '$cmd'"} : $cmd );
    chdir ".." or die "unable to chdir() out of 'win32'";
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
