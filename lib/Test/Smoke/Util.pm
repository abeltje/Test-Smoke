package Test::Smoke::Util;
use strict;

# $Id$
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = '0.30';

use base 'Exporter';
@EXPORT = qw( 
    &Configure_win32
    &get_cfg_filename &get_config
    &get_patch
    &skip_config &skip_filter
);

@EXPORT_OK = qw( 
    &get_ncpu &get_smoked_Config &parse_report_Config 
    &get_regen_headers &run_regen_headers
    &calc_timeout &time_in_hhmm
    &do_pod2usage
    &set_vms_rooted_logical
);

use Text::ParseWords;
use File::Spec;
use File::Find;
use Cwd;

=head1 NAME

Test::Smoke::Util - Take out some of the functions of the smoke suite.

=head1 FUNCTIONS

I've taken out some of the general stuff and put it here.
Now I can write some tests!

=over

=item Configure_win32( $command[, $win32_maker[, @args]] )

C<Configure_win32()> alters the settings of the makefile for MSWin32.

C<$command> is in the form of './Configure -des -Dusedevel ...'

C<$win32_maker> should either be C<nmake> or C<dmake>, the default 
is C<nmake>.

C<@args> is a list of C<< option=value >> pairs that will (eventually)
be passed to L<Config.pm>.

PLEASE read README.win32 and study the comments in the makefile.

It supports these options:

=over 4

=item * B<-Duseperlio>

set USE_PERLIO = define (default) [should be depricated]

=item * B<-Dusethreads>

set USE_ITHREADS = define (also sets USE_MULTI and USE_IMP_SYS)

=item * B<-Duseithreads>

set USE_ITHREADS = define (also sets USE_MULTI and USE_IMP_SYS)

=item * B<-Dusemultiplicity>

sets USE_MULTI = define (also sets USE_ITHREADS and USE_IMP_SYS)

=item * B<-Duseimpsys>

sets USE_IMP_SYS = define (also sets USE_ITHREADS and USE_MULTI)

=item * B<-Dusemymalloc>

set PERL_MALLOC = define

=item * B<-Duselargefiles>

set USE_LARGE_FILES = define

=item * B<-Dbccold>

set BCCOLD = define (this is for bcc32 <= 5.4)

=item * B<-Dgcc_v3_2>

set USE_GCC_V3_2 = define (this is for gcc >= 3.2)

=item * B<-DDEBUGGING>

sets CFG = Debug

=item * B<-DINST_DRV=...>

sets INST_DRV to a new value (default is "c:")

=item * B<-DINST_TOP=...>

sets INST_DRV to a new value (default is "$(INST_DRV)\perl"), this is 
where perl will be installed when C<< [nd]make install >> is run.

=item * B<-DINST_VER=...>

sets INST_VER to a new value (default is forced not set), this is also used
as part of the installation path to get a more unixy installation.
Without C<INST_VER> and C<INST_ARCH> you get an ActiveState like 
installation.

=item * B<-DINST_ARCH=...>

sets INST_ARCH to a new value (default is forced not set), this is also used
as part of the installation path to get a more unixy  installation.
Without C<INST_VER> and C<INST_ARCH> you get an ActiveState like 
installation.

=item * B<-DCCHOME=...>

Set the base directory for the C compiler.
B<$(CCHOME)\bin> still needs to be in the path!

=item * B<-DIS_WIN95>

sets IS_WIN95 to 'define' to indicate this is Win9[58]

=item * B<-DCRYPT_SRC=...>

The file to use as source for des_fcrypt()

=item * B<-DCRYPT_LIB=...>

The library to use for des_fcrypt()

=item * B<-Dcf_email=...>

Set the cf_email option (Config.pm)

=item * B<-Accflags=...>

Adds the option to BUILDOPT. This is implemented differently for 
B<nmake> and B<dmake>.
Returns the name of the outputfile.

=back

=cut

my %win32_makefile_map = (
    nmake => "Makefile",
    dmake => "makefile.mk",
);

sub Configure_win32 {
    my($command, $win32_maker, @args ) = @_;
    $win32_maker ||= 'nmake'; $win32_maker = lc $win32_maker;
    my $is_dmake = $win32_maker eq 'dmake';
    my $is_nmake = $win32_maker eq 'nmake';

    local $_;
    my %opt_map = (
	"-Dusethreads"		=> "USE_ITHREADS",
	"-Duseithreads"		=> "USE_ITHREADS",
	"-Duseperlio"		=> "USE_PERLIO",
	"-Dusemultiplicity"	=> "USE_MULTI",
	"-Duseimpsys"		=> "USE_IMP_SYS",
        "-Dusemymalloc"         => "PERL_MALLOC",
        "-Duselargefiles"       => "USE_LARGE_FILES",
	"-DDEBUGGING"		=> "USE_DEBUGGING",
        "-DINST_DRV"            => "INST_DRV",
        "-DINST_TOP"            => "INST_TOP",
        "-DINST_VER"            => "INST_VER",
        "-DINST_ARCH"           => "INST_ARCH",
        "-Dcf_email"            => "EMAIL",
        "-DCCTYPE"              => "CCTYPE",
        "-Dgcc_v3_2"            => "USE_GCC_V3_2",
        "-Dbccold"              => "BCCOLD",
        "-DCCHOME"              => "CCHOME",
        "-DIS_WIN95"            => "IS_WIN95",
        "-DCRYPT_SRC"           => "CRYPT_SRC",
        "-DCRYPT_LIB"           => "CRYPT_LIB",
    );
# %opts hash-values:
# undef  => leave option as-is when no override (makefile default)
# 0      => disable option when no override  (forced default)
# (true) => enable option when no override (change value, unless
#           $key =~ /^(?:PERL|USE)_/) (forced default)
    my %opts = (
	USE_MULTI	=> 0,
	USE_ITHREADS	=> 0,
	USE_IMP_SYS	=> 0,
	USE_PERLIO	=> 1, # useperlio should be the default!
        PERL_MALLOC     => 0,
        USE_LARGE_FILES => 0,
	USE_DEBUGGING	=> 0,
        INST_DRV        => undef,
        INST_TOP        => undef,
        INST_VER        => '',
        INST_ARCH       => '',
        EMAIL           => undef,  # used to be $smoker,
        CCTYPE          => undef,  # used to be $win32_cctype,
        USE_GCC_V3_2    => 0,
        BCCOLD          => 0,
        CCHOME          => undef,
        IS_WIN95        => 0,
        CRYPT_SRC       => undef,
        CRYPT_LIB       => undef,
    );
#    my $def_re = qr/((?:(?:PERL|USE|IS)_\w+)|BCCOLD)/;
    my $def_re = '((?:(?:PERL|USE|IS)_\w+)|BCCOLD)';
    my @w32_opts = grep ! /^$def_re/, keys %opts;
    my $config_args = join " ", 
        grep /^-D[a-z_]+/, quotewords( '\s+', 1, $command );
    push @args, "config_args=$config_args";

    my @buildopt;
    $command =~ m{^\s*\./Configure\s+(.*)} or die "unable to parse command";
    foreach ( quotewords( '\s+', 1, $1) ) {
	m/^-[des]{1,3}$/ and next;
	m/^-Dusedevel$/  and next;
        if ( /^-Accflags=(['"]?)(.+)\1/ ) { #emacs' syntaxhighlite
           push @buildopt, $2;
           next;
        }
        my( $option, $value ) = /^(-D\w+)(?:=(.+))?$/;
	die "invalid option '$_'" unless exists $opt_map{$option};
	$opts{$opt_map{$option}} = $value ? $value : 1;
    }

    # If you set one, we do all, so you can have fork()
    if ( $opts{USE_MULTI} || $opts{USE_ITHREADS} || $opts{USE_IMP_SYS} ) {
        $opts{USE_MULTI} = $opts{USE_ITHREADS} = $opts{USE_IMP_SYS} = 1;
    }

    # If you -Dgcc_v3_2 you 'll *want* CCTYPE = GCC
    $opts{CCTYPE} = "GCC" if $opts{USE_GCC_V3_2};

    # If you -Dbccold you 'll *want* CCTYPE = BORLAND
    $opts{CCTYPE} = "BORLAND" if $opts{BCCOLD};

    local (*ORG, *NEW);
    my $in =  "win32/$win32_makefile_map{ $win32_maker }";
    my $out = "win32/smoke.mk";

    open ORG, "< $in"  or die "unable to open '$in': $!";
    open NEW, "> $out" or die "unable to open '$out': $!";
    binmode NEW;
    my $donot_change = 0;
    while (<ORG>) {
        if ( $donot_change ) {
            # need to help the Win95 build
            $is_dmake and s/\b$win32_makefile_map{ $win32_maker }\b/smoke.mk/;
            if (m/^\s*CFG_VARS\s*=/) {
                my( $extra_char, $quote ) = $is_nmake
                    ? ( "\t", '"' ) : ("~", "" );
                $_ .= join "", map "\t\t$quote$_$quote\t${extra_char}\t\\\n", 
                                   grep /\w+=/, @args;
            }
            print NEW $_;
            next;
        } else {
            if ( $donot_change = /^#+ CHANGE THESE ONLY IF YOU MUST #+$/ ) {
                # We will now insert the BULDOPT lines
                my $bo_tmpl = $win32_maker eq 'nmake'
                    ? "BUILDOPT\t= \$(BUILDOPT) %s" : "BUILDOPT\t+= %s";
                my $buildopt = join "\n", 
                                    map sprintf( $bo_tmpl, $_ ) => @buildopt;
                $buildopt and $_ = "$buildopt\n$_\n"
            };
        }

        # Only change config stuff _above_ that line!
        if ( m/^\s*#?\s*$def_re(\s*\*?=\s*define)$/ ) {
            $_ = ($opts{$1} ? "" : "#") . $1 . $2 . "\n";
        } elsif (m/^\s*#?\s*(CFG\s*\*?=\s*Debug)$/) {
            $_ = ($opts{USE_DEBUGGING} ? "" : "#") . $1 . "\n";
        } else {
            foreach my $cfg_var ( grep defined $opts{ $_ }, @w32_opts ) {
                if (  m/^\s*#?\s*($cfg_var\s*\*?=)\s*(.*)$/ ) {
                    $_ =  $opts{ $cfg_var } ?
                        "$1 $opts{ $cfg_var }\n":
                        "#$1 $2\n";
                    last;
                }
            }
        }
	print NEW $_;
    }
    close ORG;
    close NEW;
    return $out;
} # Configure_win32

=item set_vms_rooted_logical( $logical, $dir )

This will set a VMS rooted logical like:

    define/translation=concealed $logical $dir

=cut

sub set_vms_rooted_logical {
    my( $logical, $dir ) = @_;
    return unless $^O eq 'VMS';

    my $cwd = cwd();
    $dir ||= $cwd;

    chdir $dir or die "Cannot chdir($dir): $!";

    # On older systems we might exceed the 8-level directory depth limit
    # imposed by RMS.  We get around this with a rooted logical, but we
    # can't create logical names with attributes in Perl, so we do it
    # in a DCL subprocess and put it in the job table so the parent sees it.

    open TSBRL, '> tsbuildrl.com' or die "Error creating DCL-file; $!";

    print TSBRL <<COMMAND;
\$ $logical = F\$PARSE("SYS\$DISK:[]",,,,"NO_CONCEAL")-".][000000"-"]["-"].;"+".]"
\$ DEFINE/JOB/NOLOG/TRANSLATION=CONCEALED $logical '$logical'
COMMAND
    close TSBRL;

    my $result = system '@tsbuildrl.com';
    1 while unlink 'tsbuildrl.com';
    chdir $cwd;
    return $result == 0;
}

=item get_cfg_filename( )

C<get_cfg_filename()> tries to find a B<cfg file> and returns it.

=cut

sub get_cfg_filename {
    my( $cfg_name ) = @_;
    return $cfg_name if defined $cfg_name && -f $cfg_name;

    my( $base_dir ) = ( $0 =~ m|^(.*)/| ) || File::Spec->curdir;
    $cfg_name = File::Spec->catfile( $base_dir, 'smoke.cfg' );
    return $cfg_name  if -f $cfg_name && -s _;

    $base_dir = File::Spec->curdir;
    $cfg_name = File::Spec->catfile( $base_dir, 'smoke.cfg' );
    return $cfg_name if -f $cfg_name && -s _;

    return undef;
}

=item get_config( $filename )

Read and parse the configuration from file, or return the default
config.

=cut

sub get_config {
    my( $config_file ) = @_;

    return (
        [ "",
          "-Dusethreads -Duseithreads"
        ],
        [ "",
          "-Duse64bitint",
          "-Duse64bitall",
          "-Duselongdouble",
          "-Dusemorebits",
          "-Duse64bitall -Duselongdouble"
        ],
        { policy_target =>       "-DDEBUGGING",
          args          => [ "", "-DDEBUGGING" ]
        },
    ) unless defined $config_file;

    open CONF, "< $config_file" or do {
        warn "Can't open '$config_file': $!\nUsing standard configuration";
        return get_config( undef );
    };
    my( @conf, @cnf_stack, @target );

    # Cheat. Force a break marker as a line after the last line.
    foreach (<CONF>, "=") {
        m/^#/ and next;
        s/\s+$// if m/\s/;	# Blanks, new-lines and carriage returns. M$
        if (m:^/:) {
      	    m:^/(.*)/$:;
            defined $1 or die "Policy target line didn't end with '/': '$_'";
            push @target, $1;
            next;
        }

        if (!m/^=/) {
            # Not a break marker
            push @conf, $_;
            next;
        }

        # Break marker, so process the lines we have.
        if (@target > 1) {
            warn "Multiple policy target lines " .
       	         join (", ", map {"'$_'"} @target) . " - will use first";
        }
        my %conf = map { $_ => 1 } @conf;
        if (keys %conf == 1 and exists $conf{""} and !@target) {
            # There are only blank lines - treat it as if there were no lines
            # (Lets people have blank sections in configuration files without
            #  warnings.)
            # Unless there is a policy target.  (substituting ''  in place of
            # target is a valid thing to do.)
            @conf = ();
        }

        unless (@conf) {
            # They have no target lines
            @target and
                warn "Policy target '$target[0]' has no configuration lines, ".
                     "so it will not be used";
            @target = ();
            next;
        }

        while (my ($key, $val) = each %conf) {
            $val > 1 and 
                warn "Configuration line '$key' duplicated $val times";
        }
        my $args = [@conf];
        @conf = ();
        if (@target) {
            push @cnf_stack, { policy_target => $target[0], args => $args };
            @target = ();
            next;
        }

        push @cnf_stack, $args;
    }
    close CONF;
    return @cnf_stack;
}

=item get_patch( [$ddir] )

Try to find the patchlevel, look for B<.patch> or try to get it from
B<patchlevel.h> as a fallback.

=cut

sub get_patch {
    my( $ddir ) = @_;
    $ddir ||= File::Spec->curdir;

    my $dot_patch = File::Spec->catfile( $ddir, '.patch' );
    local *DOTPATCH;
    my $patch_level = '?????';
    if ( open DOTPATCH, "< $dot_patch" ) {
        chomp( $patch_level = <DOTPATCH> );
        close DOTPATCH;
        return $patch_level if $patch_level =~ /-RC\d+$/;
        $patch_level =~ tr/0-9//cd;
        return $1 if $patch_level =~/^([0-9]+)$/;
    }

    # There does not seem to be a '.patch', try 'patchlevel.h'
    local *PATCHLEVEL_H;
    my $patchlevel_h = File::Spec->catfile( $ddir, 'patchlevel.h' );
    if ( open PATCHLEVEL_H, "< $patchlevel_h" ) {
        my $declaration_seen = 0;
        while ( <PATCHLEVEL_H> ) {
            $declaration_seen ||= /local_patches\[\]/;
            $declaration_seen && /^\s+,"(?:DEVEL|MAINT)(\d+)|(RC\d+)"/ or next;
            $patch_level = $1 || $2 || '?????';
            if ( $patch_level =~ /^RC/ ) {
                $patch_level = version_from_patchlevel_h( $ddir ) .
                               "-$patch_level";
            } else {
                $patch_level .= '(+)';
            }
        }
    }
    return $patch_level;
}

=item version_from_patchlevel_h( $ddir )

C<version_from_patchlevel_h()> returns a "dotted" version as derived 
from the F<patchlevel.h> file in the distribution.

=cut

sub version_from_patchlevel_h {
    my( $ddir ) = @_;
    $ddir ||= File::Spec->curdir;
    my $file = File::Spec->catfile( $ddir, 'patchlevel.h' );

    my( $revision, $version, $subversion ) = qw( 5 ? ? );
    local *PATCHLEVEL;
    if ( open PATCHLEVEL, "< $file" ) {
        my $patchlevel = do { local $/; <PATCHLEVEL> };
        close PATCHLEVEL;
        $revision   = $patchlevel =~ /^#define PERL_REVISION\s+(\d+)/m 
                    ? $1 : '?';
        $version    = $patchlevel =~ /^#define PERL_VERSION\s+(\d+)/m
                    ? $1 : '?';
        $subversion = $patchlevel =~ /^#define PERL_SUBVERSION\s+(\d+)/m 
                    ? $1 : '?';
    }
    return "$revision.$version.$subversion";
}
 
=item get_ncpu( $osname )

C<get_ncpu()> returns the number of available (online/active/enabled) CPUs.

It does this by using some operating system specific trick (usually
by running some external command and parsing the output).

If it cannot recognize your operating system an empty string is returned.
If it can recognize it but the external command failed, C<"? cpus"> 
is returned.

In the first case (where we really have no idea how to proceed),
also a warning (C<get_ncpu: unknown operating system>) is sent to STDERR.

=item B<WARNINGS>

If you get the warning C<get_ncpu: unknown operating system>, you will
need to help us-- how does one tell the number of available CPUs in
your operating system?  Sometimes there are several different ways:
please try to find the fastest one, and a one that does not require
superuser (administrator) rights.

Thanks to Jarkko Hietaniemi for donating this!

=cut

sub get_ncpu {
    # Only *nixy osses need this, so use ':'
    local $ENV{PATH} = "$ENV{PATH}:/usr/sbin";

    my $cpus = "?";
    OS_CHECK: {
        local $_ = shift or return "";

        /aix/i && do {
            my @output = `lsdev -C -c processor -S Available`;
            $cpus = scalar @output;
            last OS_CHECK;
        };

        /(?:darwin|.*bsd)/i && do {
            chomp( my @output = `sysctl -n hw.ncpu` );
            $cpus = $output[0];
            last OS_CHECK;
        };

        /hp-?ux/i && do {
            my @output = grep /^processor/ => `ioscan -fnkC processor`;
            $cpus = scalar @output;
            last OS_CHECK;
	};

        /irix/i && do {
            my @output = grep /\s+processors?$/i => `hinv -c processor`;
            $cpus = (split " ", $output[0])[0];
            last OS_CHECK;
        };

        /linux/i && do {
            my @output; local *PROC;
            if ( open PROC, "< /proc/cpuinfo" ) {
                @output = grep /^processor/ => <PROC>;
                close PROC;
            }
            $cpus = @output ? scalar @output : '';
            last OS_CHECK;
	};

        /solaris|sunos|osf/i && do {
            my @output = grep /on-line/ => `psrinfo`;
            $cpus =  scalar @output;
            last OS_CHECK;
        };

        /mswin32|cygwin/i && do {
            $cpus = exists $ENV{NUMBER_OF_PROCESSORS} 
                ? $ENV{NUMBER_OF_PROCESSORS} : '';
            last OS_CHECK;
        };

        /vms/i && do {
            my @output = grep /CPU \d+ is in RUN state/ => `show cpu/active`;
            $cpus = @output ? scalar @output : '';
            last OS_CHECK;
        };

        $cpus = "";
        require Carp;
        Carp::carp "get_ncpu: unknown operationg system";
    }

    return $cpus ? sprintf( "%s cpu%s", $cpus, $cpus ne "1" ? 's' : '' ) : "";
}

=item get_smoked_Config( $dir, @keys )

C<get_smoked_Config()> returns a hash (a listified hash) with the
specified keys. It will try to find F<lib/Config.pm> to get those
values, if that cannot be found (make error?) we can try F<config.sh>
which is used to build F<lib/Config.pm>. 
If F<config.sh> is not there (./Configure error?) we try to get some
fallback information from C<POSIX::uname()> and F<patchlevel.h>.

=cut

sub get_smoked_Config {
    my( $dir, @fields ) = @_;
    my %Config = map { ( lc $_ => undef ) } @fields;

    my $perl_Config_pm = File::Spec->catfile ($dir, "lib", "Config.pm");
    my $perl_config_sh = File::Spec->catfile( $dir, 'config.sh' );
    local *CONF;
    if ( open CONF, "< $perl_Config_pm" ) {

        while (<CONF>) {
            if ( m/^(?:
                       (?:our|my)\ \$[cC]onfig_[sS][hH].*
                    |
                       \$_
                    )\ =\ <<'!END!';/x..m/^!END!/){
                m/!END!(?:';)?$/      and next;
                m/^([^=]+)='([^']*)'/ or next;
                exists $Config{lc $1} and $Config{lc $1} = $2;
            }
        }
        close CONF;
    }
    my %conf2 = map {
        ( $_ => undef )
    } grep !defined $Config{ $_ } => keys %Config;
    if ( open CONF, "< $perl_config_sh" ) {
        while ( <CONF> ) {
            m/^([^=]+)='([^']*)'/ or next; # '
            exists $conf2{ $1} and $Config{ lc $1 } = $2;
        }
        close CONF;
    }
    %conf2 = map {
        ( $_ => undef )
    } grep !defined $Config{ $_ } => keys %Config;
    if ( keys %conf2 ) { 
        # Fall-back values from POSIX::uname() (not reliable)
        require POSIX;
        my( $osname, undef, $osvers, undef, $arch) = POSIX::uname();
        $Config{osname}   = lc $osname if exists $conf2{osname};
        $Config{osvers}   = lc $osvers if exists $conf2{osvers};
        $Config{archname} = lc $arch   if exists $conf2{archname};
        $Config{version}  = version_from_patchlevel_h( $dir )
            if exists $conf2{version};
    }

    # There should be no under-bars in perl versions!
    exists $Config{version} and $Config{version} =~ s/_/./g;
    return %Config;
}

=item parse_report_Config( $report )

C<parse_report_Config()> returns a list attributes from a smoke report.

    my( $version, $plevel, $os, $osvers, $archname, $summary ) = 
        parse_report_Config( $rpt );

=cut

sub parse_report_Config {
    my( $report ) = @_;

    my $version  = $report =~ /^Automated.*for (.+) patch/ ? $1 : '';
    my $plevel   = $report =~ /^Automated.*patch (\d+(?:\.\d+\.\d+-RC\d+)?)/
        ? $1 : '';
    my $osname   = $report =~ /\bon\s+(.*) - / ? $1 : '';
    my $osvers   = $report =~ /\bon\s+.* - (.*)/? $1 : '';
    $osvers =~ s/\s+\(.*//;
    my $archname = $report =~ /:.* \((.*)\)/ ? $1 : '';
    my $summary  = $report =~ /^Summary: (.*)/m ? $1 : '';

    return ( $version, $plevel, $osname, $osvers, $archname, $summary );
}

=item get_regen_headers( $ddir )

C<get_regen_headers()> looks in C<$ddir> to find either 
F<regen_headers.pl> or F<regen.pl> (change 18851).

Returns undef if not found or a string like C<< $^X "$regen_headers_pl" >>

=cut

sub get_regen_headers {
    my( $ddir ) = @_;

    $ddir ||= File::Spec->curdir; # Don't smoke in a dir "0"!

    my $regen_headers_pl = File::Spec->catfile( $ddir, "regen_headers.pl" );

    -f $regen_headers_pl and return qq[$^X "$regen_headers_pl"];

    $regen_headers_pl = File::Spec->catfile( $ddir, "regen.pl" );
    -f $regen_headers_pl and return qq[$^X "$regen_headers_pl"];

    return; # Should this be "make regen_headers"?
}

=item run_regen_headers( $ddir, $verbose );

C<run_regen_headers()> gets its executable from C<get_regen_headers()>
and opens a pipe from it. warn()s on error.

=cut

sub run_regen_headers {
    my( $ddir, $verbose ) = @_;

    my $regen_headers = get_regen_headers( $ddir );

    defined $regen_headers or do {
        warn "Cannot find a regen_headers script\n";
        return;
    };

    $verbose and print "Running [$regen_headers]\n";
    local *REGENH;
    if ( open REGENH, "$regen_headers |" ) {
        while ( <REGENH> ) { $verbose > 1 and print }
        close REGENH or do {
            warn "Error in pipe [$regen_headers]\n";
            return;
        }
    } else {
        warn "Cannot fork [$regen_headers]\n";
        return;
    }
    return 1;
}

=item calc_timeout( $killtime[, $from] )

C<calc_timeout()> calculates the timeout in seconds. 
C<$killtime> can be one of two formats:

=over 8

=item B<+hh:mm>

This format represents a duration and is the easy format as we only need
to translate that to seconds.

=item B<hh:mm>

This format represents a clock time (localtime).  Calculate minutes
from midnight for both C<$killtime> and C<localtime($from)>, and get
the difference. If C<$from> is omitted, C<time()> is used.

If C<$killtime> is the actual time, the timeout will be 24 hours!

=back

=cut

sub calc_timeout {
    my( $killtime, $from ) = @_;
    my $timeout = 0;
    if ( $killtime =~ /^\+(\d+):([0-5]?[0-9])$/ ) {
        $timeout = 60 * (60 * $1 + $2 );
    } elsif ( $killtime =~ /^((?:[0-1]?[0-9])|(?:2[0-3])):([0-5]?[0-9])$/ ) {
        defined $from or $from = time;
        my $time_min = 60 * $1 + $2;
        my( $now_m, $now_h ) = (localtime $from)[1, 2];
        my $now_min = 60 * $now_h + $now_m;
        my $kill_min = $time_min - $now_min;
        $kill_min += 60 * 24 if $kill_min <= 0;
        $timeout = 60 * $kill_min;
    }
    return $timeout;
}

=item time_in_hhmm( $diff )

Create a string telling elapsed time in days, hours, minutes, seconds
from the number of seconds.

=cut

sub time_in_hhmm {
    my $diff = shift;

    # Only show decimal point for diffs < 5 minutes
    my $digits = $diff =~ /\./ ? $diff < 5*60 ? 3 : 0 : 0;
    my $days = int( $diff / (24*60*60) );
    $diff -= 24*60*60 * $days;
    my $hour = int( $diff / (60*60) );
    $diff -= 60*60 * $hour;
    my $mins = int( $diff / 60 );
    $diff -=  60 * $mins;
    $diff = sprintf "%.${digits}f", $diff;

    my @parts;
    $days and push @parts, sprintf "%d day%s",   $days, $days == 1 ? "" : 's';
    $hour and push @parts, sprintf "%d hour%s",  $hour, $hour == 1 ? "" : 's';
    $mins and push @parts, sprintf "%d minute%s",$mins, $mins == 1 ? "" : 's';
    $diff && !$days && !$hour and push @parts, "$diff seconds";

    return join " ", @parts;
}

=item do_pod2man( %pod2usage_options )

If L<Pod::Usage> is there then call its C<pod2usage()>.
In the other case, print the general message passed with the C<myusage> key.

=cut

sub do_pod2usage {
    my %p2u_opt = @_;
    eval { require Pod::Usage };
    if ( $@ ) {
        my $usage = $p2u_opt{myusage} || <<__EO_USAGE__;
Usage: $0 [options]
__EO_USAGE__
        print <<EO_MSG;
$usage

Use 'perldoc $0' for the documentation.
Please install 'Pod::Usage' for easy access to the docs.

EO_MSG
        exit( exists $p2u_opt{exitval} ? $p2u_opt{exitval} : 1 );
    } else {
        exists $p2u_opt{myusage} and delete $p2u_opt{myusage};
        Pod::Usage::pod2usage( @_ );
    }
}

=item skip_config( $config ) 

Returns true if this config should be skipped.
C<$config> should be a B<Test::Smoke::BuildCFG::Config> object.

=cut

sub skip_config {
    my( $config ) = @_;

    my $skip = $config->has_arg(qw( -Uuseperlio -Dusethreads )) ||
               $config->has_arg(qw( -Uuseperlio -Duseithreads ));
    return $skip;
}

=item skip_filter( $line )

C<skip_filter()> returns true if the filter rules apply to C<$line>.

=cut

sub skip_filter {
    local( $_ ) = @_;
    # Still to be extended
    return m,^ *$, ||
    m,^	AutoSplitting, ||
    m,^\./miniperl , ||
    m,^\s*autosplit_lib, ||
    m,^\s*PATH=\S+\s+./miniperl, ||
    m,^	Making , ||
    m,^make\[[12], ||
    m,make( TEST_ARGS=)? (_test|TESTFILE=|lib/\w+.pm), ||
    m,^make:.*Error\s+\d, ||
    m,^\s+make\s+lib/, ||
    m,^ *cd t &&, ||
    m,^if \(true, ||
    m,^else \\, ||
    m,^fi$, ||
    m,^lib/ftmp-security....File::Temp::_gettemp: Parent directory \((\.|/tmp/)\) is not safe, ||
    m,^File::Temp::_gettemp: Parent directory \((\.|/tmp/)\) is not safe, ||
    m,^ok$, ||
    m,^[-a-zA-Z0-9_/]+\.*(ok|skipping test on this platform)$, ||
    m,^(xlc|cc_r) -c , ||
#    m,^\s+$testdir/, ||
    m,^sh mv-if-diff\b, ||
    m,File \S+ not changed, ||
    m,^(not\s+)?ok\s+\d+\s+[-#]\s+(?i:skip\S*[: ]),i ||
    # cygwin
    m,^dllwrap: no export definition file provided, ||
    m,^dllwrap: creating one. but that may not be what you want, ||
    m,^(GNUm|M)akefile:\d+: warning: overriding commands for target `perlmain.o', ||
    m,^(GNUm|M)akefile:\d+: warning: ignoring old commands for target `perlmain.o', ||
    m,^\s+CCCMD\s+=\s+, ||
    # Don't know why BSD's make does this
    m,^Extracting .*with variable substitutions, ||
    # Or these
    m,cc\s+-o\s+perl.*perlmain.o\s+lib/auto/DynaLoader/DynaLoader\.a\s+libperl\.a, ||
    m,^\S+ is up to date, ||
    m,^(   )?### , ||
    # Clean up Win32's output
    m,^(?:\.\.[/\\])?[\w/\\-]+\.*ok$, ||
    m,^(?:\.\.[/\\])?[\w/\\-]+\.*ok\,\s+\d+/\d+\s+skipped:, ||
    m,^(?:\.\.[/\\])?[\w/\\-]+\.*skipped[: ], ||
    m,^\t?x?copy , ||
    m,\d+\s+[Ff]ile\(s\) copied, ||
    m,[/\\](?:mini)?perl\.exe ,||
    m,^\t?cd , ||
    m,^\b[nd]make\b, ||
    m,dmake\.exe:?\s+-S, ||
    m,^\s+\d+/\d+ skipped: , ||
    m,^\s+all skipped: , ||
    m,\.+skipped$, ||
    m,^\s*pl2bat\.bat [\w\\]+, ||
    m,^Making , ||
    m,^Skip , ||
    m,^Creating library file: libExtTest\.dll\.a,
}

1;

=back

=head1 COPYRIGHT

(c) 2001-2003, All rights reserved.

  * H. Merijn Brand <h.m.brand@hccnet.nl>
  * Nicholas Clark <nick@unfortu.net>
  * Jarkko Hietaniemi <jhi@iki.fi>
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
