package Test::Smoke::SysInfo;
use strict;

# $Id$
use vars qw( $VERSION @EXPORT_OK );
$VERSION = '0.042';

use base 'Exporter';
@EXPORT_OK = qw( &sysinfo &tsuname );

=head1 NAME

Test::Smoke::SysInfo - OO interface to system specific information

=head1 SYNOPSIS

    use Test::Smoke::SysInfo;

    my $si = Test::Smoke::SysInfo->new;

    printf "Hostname: %s\n", $si->host;
    printf "Number of CPU's: %s\n", $si->ncpu;
    printf "Processor type: %s\n", $si->cpu_type;   # short
    printf "Processor description: %s\n", $si->cpu; # long
    printf "OS and version: %s\n", $si->os;

or

    use Test::Smoke::SysInfo qw( sysinfo );
    printf "[%s]\n", sysinfo();

or

    $ perl -MTest::Smoke::SysInfo=tsuname -le print+tsuname

=head1 DESCRIPTION

Sometimes one wants a more eleborate description of the system one is
smoking.

=head1 METHODS

=head2 Test::Smoke::SysInfo->new( )

Dispatch to one of the OS-specific subs.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my $chk_os;
    for $chk_os ( $^O ) {

        $chk_os =~ /aix/i        && return bless AIX(),     $class;

        $chk_os =~ /bsd/i        && return bless BSD(),     $class;

        $chk_os =~ /darwin/i     && return bless Darwin(),  $class;

        $chk_os =~ /hp-?ux/i     && return bless HPUX(),    $class;

        $chk_os =~ /linux/i      && return bless Linux(),   $class;

        $chk_os =~ /irix/i       && return bless IRIX(),    $class;

        $chk_os =~ /solaris|sunos|osf/i 
                                 && return bless Solaris(), $class;

        $chk_os =~ /cygwin|mswin32|windows/i
                                 && return bless Windows(), $class;

        $chk_os =~ /VMS/         && return bless VMS(),     $class;
    }
    return bless Generic(), $class;
}

my %info = map { ($_ => undef ) } qw( os ncpu cpu cpu_type host );

sub AUTOLOAD {
    my $self = shift;
    use vars qw( $AUTOLOAD );

    ( my $method = $AUTOLOAD ) =~ s/^.*::(.+)$/\L$1/;

    return $self->{ "_$method" } if exists $info{ "$method" };
}

=head2 __get_os( )

This is the short info string about the Operating System.

=cut

sub __get_os {
    require POSIX;
    my $os = join " - ", (POSIX::uname())[0,2];
    $os =~ s/(\S+)/\L$1/;
    my $chk_os;
    for $chk_os ( $^O ) {

        $chk_os =~ /aix/i && do {
            chomp( $os = `oslevel -r` );
            if ( $os =~ m/^(\d+)-(\d+)$/ ) {
                $os = ( join ".", split //, $1 ) . "/ML$2";
            } else {
                chomp( $os = `oslevel` );

                # And try figuring out at what maintainance level we are
                my $ml = "00";
                for ( grep m/ML\b/ => `instfix -i` ) {
                    if ( m/All filesets for (\S+) were found/ ) {
                        $ml = $1;
                        $ml =~ m/^\d+-(\d+)_AIX_ML/ and $ml = "ML$1";
                        next;
                    }
                    $ml =~ s/\+*$/+/;
                }
                $os .= "/$ml";
            }
            $os =~ s/^/AIX - /;
            last;
        };
        $chk_os =~ /irix/i && do {
            chomp( my $osvers = `uname -R` );
            my( $osn, $osv ) = split ' ', $os;
            $osvers =~ s/^$osv\s+(?=$osv)//;
            $os = "$osn - $osvers";
            last;
        };
        $chk_os =~ /linux/i && do {
            my $dist_re = '[-_](?:release|version)\b';
            my( $distro ) = grep /$dist_re/ && !/\blsb-/ => glob( '/etc/*' );
            last MOREOS unless $distro;
            $distro =~ s|^/etc/||;
            $distro =~ s/$dist_re//i;
            $os .= " [$distro]" if $distro;
            last;
        };
        $chk_os =~ /solaris|sunos|osf/i && do {
            my( $osn, $osv ) = (POSIX::uname())[0,2];
            $chk_os =~ /solaris|sunos/i && $osv > 5 and do {
                $osn = 'Solaris';
                $osv = '2.' . (split /\./, $osv, 2)[1];
            };
            $os = join " - ", $osn, $osv;
            last;
        };
        $chk_os =~ /windows|mswin32/i && do {
            eval { require Win32 };
            $@ and last MOREOS;
            $os = "$^O - " . join " ", Win32::GetOSName();
            $os =~ s/Service\s+Pack\s+/SP/;
            last;
        };
        $chk_os =~ /vms/i && do {
            $os = join " - ", (POSIX::uname())[0,3];
            $os =~ s/(\S+)/\L$1/;
        };
    }
    return $os;
}

=head2 __get_cpu_type( )

This is the short info string about the cpu-type. The L<POSIX> module
should provide one (portably) with C<POSIX::uname()>.

=cut

sub __get_cpu_type {
    require POSIX;
    return (POSIX::uname())[4];
}

=head2 __get_cpu( )

We do not have a portable way to get this information, so assign
C<_cpu_type> to it.

=cut

sub __get_cpu { return __get_cpu_type() }

=head2 __get_hostname( )

Get the hostname from C<POSIX::uname()>.

=cut

sub __get_hostname {
    require POSIX;
    return (POSIX::uname())[1];
}

sub __get_ncpu { return '' }

=head2 Generic( )

Get the information from C<POSIX::uname()>

=cut

sub Generic {

    return {
        _os       => __get_os(),
        _cpu_type => __get_cpu_type(),
        _cpu      => __get_cpu(),
        _ncpu     => __get_ncpu(),
        _host     => __get_hostname(),
    };

}

=head2 AIX( )

Use the L<lsdev> program to find information.

=cut

sub AIX {
    local $ENV{PATH} = "$ENV{PATH}:/usr/sbin";

    my @lsdev = grep /Available/ => `lsdev -C -c processor -S Available`;
    my( $info ) = grep /^\S+/ => @lsdev;
    ( $info ) = $info =~ /^(\S+)/;
    $info .= " -a 'state type'";
    my( $cpu ) = grep /\benable:[^:\s]+/ => `lsattr -E -O -l $info`;
    ( $cpu ) = $cpu =~ /\benable:([^:\s]+)/;
    $cpu =~ s/\bPowerPC(?=\b|_)/PPC/i;

    ( my $cpu_type = $cpu ) =~ s/_.*//;

    my $os = __get_os();
    if ( $> == 0 ) {
        chomp( my $k64 = `bootinfo -K 2>/dev/null` );
        $k64 and $os .= "/$k64";
	chomp( my $a64 = `bootinfo -y 2>/dev/null` );
	$a64 and $cpu_type .= "/$a64";
    }

    return {
        _os       => $os,
        _cpu_type => $cpu_type,
        _cpu      => $cpu,
        _ncpu     => scalar @lsdev,
        _host     => __get_hostname(),
    };
}

=head2 HPUX( )

Use the L<ioscan>, L<getconf> and L<machinfo> programs to find information.

This routine was contributed by Rich Rauenzahn.

=cut

sub HPUX {
    my $hpux = Generic();
    my $parisc = 0;

    $hpux->{_os} =~ s/hp-ux/HP-UX/;

    # ioscan is always available
    $hpux->{_ncpu} = grep /^processor/ => `/usr/sbin/ioscan -knfCprocessor`;

    chomp(my $k64 = `/usr/bin/getconf KERNEL_BITS 2>/dev/null`);
    $hpux->{_os} .= "/$k64" if(length $k64);

    # For now, unknown cpu_types are set as the Generic
    chomp(my $cv = `/usr/bin/getconf CPU_VERSION 2>/dev/null`);
    # see /usr/include/sys/unistd.h for hex values
    if($cv < 0x20B) {
#        $hpux->{_cpu_type} = sprintf("Unknown CPU_VERSION 0x%x", $cv);
    } elsif($cv >= 0x20C && $cv <= 0x20E) {
        $hpux->{_cpu_type} = "Motorola"; # You have an antique
    } elsif($cv <= 0x2FF) {
        $hpux->{_cpu_type} = "PA-RISC";
        $hpux->{_cpu_type} = "PA-RISC1.0" if $cv == 0x20B;
        $hpux->{_cpu_type} = "PA-RISC1.1" if $cv == 0x210;
        $hpux->{_cpu_type} = "PA-RISC1.2" if $cv == 0x211;
        $hpux->{_cpu_type} = "PA-RISC2.0" if $cv == 0x214;
        $parisc++;
    } elsif($cv == 0x300) {
#        $hpux->{_cpu_type} = "Itanium,archrev0";
        $hpux->{_cpu_type} = "ia64";
    } else {
#        $hpux->{_cpu_type} = sprintf("Unknown CPU_VERSION 0x%x", $cv);
    }

    if ( $parisc ) {
        my( @cpu, $lst );
        chomp( my $model = `model` );
        ( my $m = $model ) =~ s:.*/::;
        local *LST; my $f;
        foreach $f (qw( /usr/sam/lib/mo/sched.models
                        /opt/langtools/lib/sched.models )) {
            if ( open LST, "< $f" ) {
                @cpu = grep m/$m/i => <LST>;
                close LST;
                @cpu and last;
            }
        }
        if (@cpu == 0 && open my $lst,
                              "echo 'sc product cpu;il' | /usr/sbin/cstm |") {
            while (<$lst>) {
                s/^\s*(PA)\s*(\d+)\s+CPU Module.*/$m 1.1 $1$2/ or next;
                $2 =~ m/^8/ and s/ 1.1 / 2.0 /;
                push @cpu, $_;
            }
        }
        if (@cpu and $cpu[0] =~ m/^\S+\s+(\d+\.\d+[a-z]?)\s+(\S+)/) {
             my( $arch, $cpu ) = ( "PA-RISC$1", $2 );
             $hpux->{_cpu} = $cpu;
             chomp( my $hw3264 = 
                    `/usr/bin/getconf HW_32_64_CAPABLE 2>/dev/null` );
            (my $osvers = $hpux->{_os}) =~ s/.*[AB]\.//;
            $osvers =~ s{/.*}{};
            $osvers <= 10.20 and $hw3264 = 0;
            if ( $hw3264 == 1 ) {
                $hpux->{_cpu_type} = $arch . "/64";
            } elsif ( $hw3264 == 0 ) {
                $hpux->{_cpu_type} = $arch . "/32";
            }
        }
    } else {
        my $machinfo = `/usr/contrib/bin/machinfo`;
        if ( $machinfo =~ m/processor model:\s+(\d+)\s+(.*)/ ) {
            $hpux->{_cpu} = $2;
        } elsif ( $machinfo =~ m{\s*[0-9]+\s+(intel.r.*processor)\s*\(([0-9.]+)\s*([GM])Hz.*}mi) {
            my ($m, $s, $h) = ($1, $2, $3);
            $m =~ s: series processor::;
            $h eq "G" and $s = int ($s * 1024);
            $hpux->{_cpu} = "$m/$s";
        }
        if ( $machinfo =~ m/Clock\s+speed\s+=\s+(.*)/ ) {
            $hpux->{_cpu} .= "/$1";
        }
    }
    return $hpux;
}

=head2 BSD( )

Use the L<sysctl> program to find information.

=cut

sub BSD {
    my %sysctl;

    my $sysctl_cmd = -x '/sbin/sysctl' ? '/sbin/sysctl' : 'sysctl';

    my %extra = ( cpufrequency => undef, cpuspeed => undef );
    my @e_args = map {
        /^hw\.(\w+)\s*[:=]/; $1
    } grep /^hw\.(\w+)/ && exists $extra{ $1 } => `$sysctl_cmd -a hw`; 

    foreach my $name ( qw( model machine ncpu ), @e_args ) {
        chomp( $sysctl{ $name } = `$sysctl_cmd hw.$name` );
        $sysctl{ $name } =~ s/^hw\.$name\s*[:=]\s*//;
    }
    $sysctl{machine} and $sysctl{machine} =~ s/Power Macintosh/macppc/;

    my $cpu = $sysctl{model};

    if ( exists $sysctl{cpuspeed} ) {
        $cpu .= sprintf " (%.0f MHz)", $sysctl{cpuspeed};
    } elsif ( exists $sysctl{cpufrequency} ) {
        $cpu .= sprintf " (%.0f MHz)", $sysctl{cpufrequency}/1_000_000;
    }

    return {
        _cpu_type => ($sysctl{machine} || __get_cpu_type()),
        _cpu      => $cpu || __get_cpu,
        _ncpu     => $sysctl{ncpu},
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=head2 Darwin( )

If the L<system_profiler> program is accessible (meaning that this is
Mac OS X), use it to find information; otherwise treat as L</BSD>.

This sub was donated by Dominic Dunlup.

=cut

sub Darwin {
    my $system_profiler_output;
    {
        local $^W = 0;
	$system_profiler_output =
	    `/usr/sbin/system_profiler -detailLevel mini SPHardwareDataType`;
    }
    return BSD() unless $system_profiler_output;

    my %system_profiler;
    $system_profiler{$1} = $2
	while $system_profiler_output =~ m/^\s*([\w ]+):\s+(.+)$/gm;

    # convert newer output from Intel core duo
    my %keymap = (
        'Processor Name'       => 'CPU Type',
        'Processor Speed'      => 'CPU Speed',
        'Model Name'           => 'Machine Name',
        'Model Identifier'     => 'Machine Model',
        'Number Of Processors' => 'Number Of CPUs',
    );
    for my $newkey ( keys %keymap ) {
        my $oldkey = $keymap{ $newkey };
        exists $system_profiler{ $newkey} and
            $system_profiler{ $oldkey } = delete $system_profiler{ $newkey };
    }

    $system_profiler{'CPU Type'} =~ s/PowerPC\s*(\w+).*/macppc$1/;
    $system_profiler{'CPU Speed'} =~ 
	s/(0(?:\.\d+)?)\s*GHz/sprintf("%d MHz", $1 * 1000)/e;

    my $model = $system_profiler{'Machine Name'} ||
                $system_profiler{'Machine Model'};

    my $ncpu = $system_profiler{'Number Of CPUs'};
    $system_profiler{'Total Number Of Cores'} and
        $ncpu .= " [$system_profiler{'Total Number Of Cores'} cores]";
    return {
        _cpu_type => ($system_profiler{'CPU Type'} || __get_cpu_type()),
        _cpu      => ("$model ($system_profiler{'CPU Speed'})" || __get_cpu),
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os() . " (Mac OS X)",
    };
}

=head2 IRIX( )

Use the L<hinv> program to get the system information.

=cut

sub IRIX {
    chomp( my( $cpu ) = `hinv -t cpu` );
    $cpu =~ s/^CPU:\s+//;
    chomp( my @processor = `hinv -c processor` );
    my( $cpu_cnt ) = grep /\d+.+processors?$/i => @processor;
    my( $cpu_mhz ) = $cpu_cnt =~ /^\d+ (\d+ MHZ) /;
    my $ncpu = (split " ", $cpu_cnt)[0];
    my $type = (split " ", $cpu_cnt)[-2];

    return {
        _cpu_type => $type,
        _cpu      => $cpu . " ($cpu_mhz)",
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };

}

=head2 __from_proc_cpuinfo( $key, $lines )

Helper function to get information from F</proc/cpuinfo>

=cut

sub __from_proc_cpuinfo {
    my( $key, $lines ) = @_;
    my( $value ) = grep /^\s*$key\s*[:=]\s*/i => @$lines;
    defined $value or $value = "";
    $value =~ s/^\s*$key\s*[:=]\s*//i;
    return $value;
}

=head2 Linux( )

Use the C</proc/cpuinfo> pseudofile to get the system information.

=cut

sub Linux {
    my( $type, $cpu, $ncpu ) = ( __get_cpu_type() );
    ARCH: {

        $type =~ /sparc/ and return Linux_sparc( $type );
        $type =~ /ppc/i  and return Linux_ppc(   $type );

    }

    local *CPUINFO;
    if ( open CPUINFO, "< /proc/cpuinfo" ) {
        chomp( my @cpu_info = <CPUINFO> );
        close CPUINFO;

        $ncpu = grep /^processor\s+:\s+/ => @cpu_info;

        my @parts = ( 'model name', 'vendor_id', 'cpu mhz' );
        my %info = map {
            ( $_ => __from_proc_cpuinfo( $_, \@cpu_info ) );
        } @parts;
        $cpu = sprintf "%s (%s %.0fMHz)", map $info{ $_ } => @parts;

        my $ncores = 0;
        for my $cores ( grep /cpu cores\s*:\d+/ => @cpu_info ) {
            $ncores += $cores =~ /(\d+)/ ? $1 : 0;
        }
        $ncores and $ncpu .= " [$ncores cores]";
    } else {
        $cpu = __get_cpu();
    }
    $cpu =~ s/\s+/ /g;
    return {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=head2 Linux_sparc( )

Linux on sparc architecture seems too different from intel

=cut

sub Linux_sparc {
    my( $type, $cpu, $ncpu ) = @_;
    local *CPUINFO;
    if ( open CPUINFO, "< /proc/cpuinfo" ) {
        chomp( my @cpu_info = <CPUINFO> );
        close CPUINFO;

        $ncpu = __from_proc_cpuinfo( 'ncpus active', \@cpu_info );

        my @parts = qw( cpu Cpu0ClkTck );
        my %info = map {
            ( $_ => __from_proc_cpuinfo( $_, \@cpu_info ) );
        } @parts;
        $cpu = $info{cpu};
        $info{Cpu0ClkTck} and 
            $cpu .=  sprintf " (%.0fMHz)", hex( $info{Cpu0ClkTck} )/1_000_000;
    } else {
        $cpu = __get_cpu();
    }
    $cpu =~ s/\s+/ /g;
    return {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=head2 Linux_ppc( )

Linux on ppc architecture seems too different from intel

=cut

sub Linux_ppc {
    my( $type, $cpu, $ncpu ) = @_;
    local *CPUINFO;
    if ( open CPUINFO, "< /proc/cpuinfo" ) {
        chomp( my @cpu_info = <CPUINFO> );
        close CPUINFO;

        $ncpu =  grep /^processor\s+:\s+/ => @cpu_info;

        my @parts = qw( cpu machine clock );
        my %info = map {
            ( $_ => __from_proc_cpuinfo( $_, \@cpu_info ) );
        } @parts;
        if ($info{detected} = __from_proc_cpuinfo( 'detected as', \@cpu_info )){
            $info{detected} =~ s/.*(\b.+Mac G\d).*/$1/;
            $info{machine} = $info{detected};
        }
        
        $cpu = sprintf "%s %s (%s)", map $info{ $_ } => @parts;
    } else {
        $cpu = __get_cpu();
    }
    $cpu =~ s/\s+/ /g;
    return {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=head2 Solaris( )

Use the L<psrinfo> program to get the system information.
Used also in Tru64 (osf).

=cut

sub Solaris {

    local $ENV{PATH} = "/usr/sbin:$ENV{PATH}";

    my @psrinfo = `psrinfo -v`;
    my( $psrinfo ) = grep /the .* operates .* [gm]hz/ix => @psrinfo;
    my( $type, $speed, $magnitude ) =
        $psrinfo =~ /the (.+) processor.*at (.+?)\s*([GM]hz)/i;

    $type =~ s/(v9)$/ $1 ? "64" : ""/e;

    my $cpu = __get_cpu();
    if ( -d "/usr/platform" ) { # Solaris but not OSF/1.
        chomp( my $platform = `uname -i` );
        my $pfpath = "/usr/platform/$platform/sbin/prtdiag";
        if ( -x "$pfpath" ) { # Not on Solaris-x86
            my $prtdiag = `$pfpath`;
            ( $cpu ) = $prtdiag =~ /^System .+\(([^\s\)]+)/;
            unless ( $cpu ) {
                my($cpu_line) = grep /\s+on-?line\s+/i => split /\n/, $prtdiag;
                ( $cpu = ( split " ", $cpu_line )[4] ) =~ s/.*,//;
            }
            $cpu .= " ($speed$magnitude)";
        } else {
            $cpu .= " ($speed$magnitude)";
        }
    } elsif (-x "/usr/sbin/sizer") { # OSF/1.
        $cpu = $type;
        chomp( $type = `sizer -implver` );
    }

    my $ncpu = grep /on-?line/ => `psrinfo`;

    return {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=head2 Windows( )

Use the C<%ENV> hash to find information. Fall back on the *::Generic
values if these values have been unset or are unavailable (sorry I do
not have Win9[58]).

Use L<Win32::TieRegistry> if available to get better information.

=cut

sub Windows {
    my( $cpu_type, $cpu, $ncpu );

    eval { require Win32::TieRegistry };
    unless ( $@ ) {
        Win32::TieRegistry->import();
	my $Registry = $Win32::TieRegistry::Registry->Open(
          "",
          { Access => 0x2000000 }
        );
        my $basekey = join "\\",
            qw( LMachine HARDWARE DESCRIPTION System CentralProcessor );
        my $pnskey = "$basekey\\0\\ProcessorNameString";
        my $cpustr = $Registry->{ $pnskey };
        my $idkey = "$basekey\\0\\Identifier";
        $cpustr ||= $Registry->{ $idkey };
        $cpustr =~ tr/ / /sd;
        my $mhzkey = "$basekey\\0\\~MHz";
        $cpustr .= sprintf "(~%d MHz)", hex $Registry->{ $mhzkey };
        $cpu = $cpustr;
        $ncpu = keys %{ $Registry->{ $basekey } };
        ($cpu_type) = $Registry->{ $idkey } =~ /^(\S+)/;
    }

    return {
        _cpu_type => ( $cpu_type || $ENV{PROCESSOR_ARCHITECTURE} ),
        _cpu      => ( $cpu || $ENV{PROCESSOR_IDENTIFIER} ),
        _ncpu     => ( $ncpu || $ENV{NUMBER_OF_PROCESSORS} ),
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=head2 VMS()

Use some VMS specific stuff to get system information. These were
suggested by Craig Berry.

=cut

sub VMS {
    my $vms = Generic();

#    my $myname = $vms->{_host};
#    my @cpu_brief = `SHOW CPU/BRIEF`;
#    my( $sysline ) = grep /$myname,(?:\s+a)?\s+/i => @cpu_brief;
#    my( $cpu ) = $sysline =~ /$myname,(?:\s+a)?\s+(.+)/i;
#    my $ncpu = grep /^CPU \d+/ && /\bstate\b/i && /\bRUN\b/i => @cpu_brief;

    my %map = ( 
        cpu      => 'HW_NAME',
        cpu_type => 'ARCH_NAME',
        ncpu     => 'ACTIVECPU_CNT'
    );
    for my $key ( keys %map ) {
        my $cmd_out = `write sys\$output f\$getsyi("$map{$key}")`;
        chomp( $vms->{ "_$key" } = $cmd_out );
    }

    return $vms;
}

=head2 sysinfo( )

C<sysinfo()> returns a string with C<host>, C<os> and C<cpu_type>.

=cut

sub sysinfo {
    my $si = Test::Smoke::SysInfo->new;
    my @fields = $_[0]
        ? qw( host os cpu ncpu cpu_type )
        : qw( host os cpu_type );
    return join " ", @{ $si }{ map "_$_" => @fields };
}

=head2 tsuname( @args )

This class gathers most of the C<uname(1)> info, make a comparable
version. Takes almost the same arguments:

    a for all (can be omitted)
    n for nodename
    s for os name and version
    m for cpu name
    c for cpu count
    p for cpu_type

=cut

sub tsuname {
    my $si;
    ref $_[0] eq __PACKAGE__ and $si = shift;
    my @args = map split() => @_;

    my @sw = qw( n s m c p );
    my %sw = ( n => '_host', s => '_os',
               m => '_cpu', c => '_ncpu', p => '_cpu_type' );

    @args = grep exists $sw{ $_ } => @args;
    @args or @args = ( 'a' );
    grep( /a/ => @args ) and @args = @sw;
    my %show = map +( $_ => undef ) => grep exists $sw{ $_ } => @args;
    @args = grep exists $show{ $_ } => @sw;

    defined $si or $si = Test::Smoke::SysInfo->new;
    return join " ", @{ $si }{ @sw{ @args } };
}

1;

=head1 SEE ALSO

L<Test::Smoke::Smoker>, L<Test::Smoke::Reporter>

=head1 COPYRIGHT

(c) 2002-2006, Abe Timmerman <abeltje@cpan.org> All rights reserved.

With contributions from Jarkko Hietaniemi, Merijn Brand, Campo
Weijerman, Alan Burlison, Allen Smith, Alain Barbet, Dominic Dunlop,
Rich Rauenzahn, David Cantrell.

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
