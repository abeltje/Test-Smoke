package Test::Smoke::SysInfo;
use strict;

# $Id$
use vars qw( $VERSION @EXPORT_OK );
$VERSION = '0.016';

use base 'Exporter';
@EXPORT_OK = qw( &sysinfo );

=head1 NAME

Test::Smoke::SysInfo - OO interface to system specific information

=head1 SYNOPSIS

    use Test::Smoke::SysInfo;

    my $si = Test::Smoke::SysInfo->new;

    printf "Hostname: %s\n, $si->host;
    printf "Number of CPU's: %s\n", $si->ncpu;
    printf "Processor type: %s\n", $si->cpu_type;   # short
    printf "Processor description: %s\n", $si->cpu; # long
    printf "OS and version: %s\n", $si->os;

or

    use Test::Smoke::SysInfo qw( sysinfo );
    prinft "[%s]\n", sysinfo();

=head1 DESCRIPTION

Sometimes one wants a more eleborate description of the system one is
smoking.

=head1 METHODS

=over 4

=item Test::Smoke::SysInfo->new( )

Dispatch to one of the OS-specific subs.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    CASE: {
        local $_ = $^O;

        /aix/i        && return bless AIX(),     $class;

        /darwin|bsd/i && return bless BSD(),     $class;

        /hp-?ux/i     && return bless HPUX(),    $class;

        /linux/i      && return bless Linux(),   $class;

        /irix/i       && return bless IRIX(),    $class;

        /solaris|sunos|osf/i 
                      && return bless Solaris(), $class;

        /cygwin|mswin32|windows/i
                      && return bless Windows(), $class;
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

=item __get_os( )

This is the short info string about the Operating System.

=cut

sub __get_os {
    require POSIX;
    my $os = join " - ", (POSIX::uname())[0,2];
    $os =~ s/(\S+)/\L$1/;
    MOREOS: {
        local $_ = $^O;

        /aix/i             && do {
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
            last MOREOS;
        };
        /irix/i            && do {
            chomp( my $osvers = `uname -R` );
            my( $osn, $osv ) = split ' ', $os;
            $osvers =~ s/^$osv\s+(?=$osv)//;
            $os = "$osn - $osvers";
            last MOREOS;
        };
        /linux/i           && do {
            my $dist_re = '[-_](?:release|version)\b';
            my( $distro ) = grep /$dist_re/ => glob( '/etc/*' );
            last MOREOS unless $distro;
            $distro =~ s|^/etc/||;
            $distro =~ s/$dist_re//i;
            $os .= " [$distro]" if $distro;
            last MOREOS;
        };
        /solaris|sunos/i   && do {
            require Config;
            $os = join " - ", $Config::Config{osname},
                              $Config::Config{osvers};
        };
        /windows|mswin32/i && do {
            eval { require Win32 };
            $@ and last MOREOS;
            $os = "$^O - " . join " ", Win32::GetOSName();
            $os =~ s/Service\s+Pack\s+/SP/;
            last MOREOS;
        };
    }
    return $os;
}

=item __get_cpu_type( )

This is the short info string about the cpu-type. The L<POSIX> module
should provide one (portably) with C<POSIX::uname()>.

=cut

sub __get_cpu_type {
    require POSIX;
    return (POSIX::uname())[4];
}

=item __get_cpu( )

We do not have a portable way to get this information, so assign
C<_cpu_type> to it.

=cut

sub __get_cpu { return __get_cpu_type() }

=item __get_hostname( )

Get the hostname from C<POSIX::uname()>.

=cut

sub __get_hostname {
    require POSIX;
    return (POSIX::uname())[1];
}

sub __get_ncpu { return '' }

=item Generic( )

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

=item AIX( )

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

=item HPUX( )

Use the L<ioscan> program to find information.

=cut

sub HPUX {
    my $hpux = Generic();
    local $ENV{PATH} = "/etc:$ENV{PATH}";
    my $ncpu = grep /^processor/ => `ioscan -fnkC processor`;
    unless ( $ncpu ) {	# not root?
        local *SYSLOG;
        if ( open SYSLOG, "< /var/adm/syslog/syslog.log" ) {
            while ( <SYSLOG> ) {
                m/\bprocessor$/ and $ncpu++;
            }
        }
    }
    $hpux->{_ncpu} = $ncpu;
    # http://wtec.cup.hp.com/~cpuhw/hppa/hversions.html
    my( @cpu, $lst );
    chomp( my $model = `model` );
    ( my $m = $model ) =~ s:.*/::;
    local *LST;
    open LST, "< /usr/sam/lib/mo/sched.models" and
	@cpu = grep m/$m/i, <LST>;
    close LST;

    @cpu == 0 && open LST, "< /opt/langtools/lib/sched.models" and
	@cpu = grep m/$m/i, <LST>;
    close LST;

    if (@cpu == 0 && open LST, "echo 'sc product cpu;il' | /usr/sbin/cstm |") {
        while (<$lst>) {
            s/^\s*(PA)\s*(\d+)\s+CPU Module.*/$m 1.1 $1$2/ or next;
            $2 =~ m/^8/ and s/ 1.1 / 2.0 /;
            push @cpu, $_;
        }
    }
    $hpux->{_os} =~ s/ B\.(\d+)/ $1/;
    my $os_r = $1;

    if ($os_r >= 11) {
       chomp( my $k64 = `getconf KERNEL_BITS` );
       $k64 and $hpux->{_os} .= "/$k64";
    }

    if ($cpu[0] =~ m/^\S+\s+(\d+\.\d+)\s+(\S+)/) {
        my( $arch, $cpu ) = ("PA-$1", $2);
        $hpux->{_cpu} = $cpu;
        $hpux->{_cpu_type} = $os_r >= 11 && `getconf HW_32_64_CAPABLE` =~ m/^1/
            ? "$arch/64" : "$arch/32";
    }
    return $hpux;
}

=item BSD( )

Use the L<sysctl> program to find information.

=cut

sub BSD {
    my %sysctl;

    my $sysctl_cmd = -x '/sbin/sysctl' ? '/sbin/sysctl' : 'sysctl';

    my %extra = ( cpufrequency => undef );
    my @e_args = map {
        /^hw\.(\w+)\s*[:=]/; $1
    } grep /^hw\.(\w+)/ && exists $extra{ $1 } => `$sysctl_cmd -a hw`; 

    foreach my $name ( qw( model machine ncpu ), @e_args ) {
        chomp( $sysctl{ $name } = `$sysctl_cmd hw.$name` );
        $sysctl{ $name } =~ s/^hw\.$name\s*[:=]\s*//;
    }
    $sysctl{machine} and $sysctl{machine} =~ s/Power Macintosh/ppc/;

    my $cpu = $sysctl{model};
    exists $sysctl{cpufrequency}
        and $cpu .= sprintf " (%.0f MHz)", $sysctl{cpufrequency}/1_000_000;

    return {
        _cpu_type => $sysctl{machine} || __get_cpu_type(),
        _cpu      => $cpu || __get_cpu,
        _ncpu     => $sysctl{ncpu},
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=item IRIX( )

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

=item __from_proc_cpuinfo( $key, $lines )

Helper function to get information from F</proc/cpuinfo>

=cut

sub __from_proc_cpuinfo {
    my( $key, $lines ) = @_;
    my( $value ) = grep /^\s*$key\s*[:=]\s*/i => @$lines;
    defined $value or $value = "";
    $value =~ s/^\s*$key\s*[:=]\s*//i;
    return $value;
}

=item Linux( )

Use the C</proc/cpuinfo> preudofile to get the system information.

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

=item Linux_sparc( )

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

=item Linux_ppc( )

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

=item Solaris( )

Use the L<psrinfo> program to get the system information.

=cut

sub Solaris {

    local $ENV{PATH} = "/usr/sbin:$ENV{PATH}";

    my( $psrinfo ) = grep /the .* operates .* mhz/ix => `psrinfo -v`;
    my( $type, $speed ) = $psrinfo =~ /the (\w+) processor.*at (\d+) mhz/i;
    $type =~ s/(v9)$/ $1 ? "-LP64" : "-LP32"/e;
    my( $cpu_line ) = grep /\s+$speed\s+MHz\s+/i => `prtdiag`;
    ( my $cpu = ( split " ", $cpu_line )[4] ) =~ s/.*,//;
    $cpu .= " (${speed}MHz)";
    my $ncpu = grep /on-line/ => `psrinfo`;

    return {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=item Windows( )

Use the C<%ENV> hash to find information. Fall back on the *::Generic
values if these values have been unset or are unavailable (sorry I do
not have Win9[58]).

Use L<Win32::TieRegistry> if available to get better information.

=cut

sub Windows {

    my $cpu_type = $ENV{PROCESSOR_ARCHITECTURE};
    my $cpu      = $ENV{PROCESSOR_IDENTIFIER};
    my $ncpu     = $ENV{NUMBER_OF_PROCESSORS};
    eval { require Win32::TieRegistry };
    unless ( $@ ) {
        Win32::TieRegistry->import();
        my $basekey = join "\\",
            qw( LMachine HARDWARE DESCRIPTION System CentralProcessor );
        my $pnskey = "$basekey\\0\\ProcessorNameString";
        my $cpustr = $Win32::TieRegistry::Registry->{ $pnskey };
        my $idkey = "$basekey\\0\\Identifier";
        $cpustr ||= $Win32::TieRegistry::Registry->{ $idkey };
        $cpustr =~ tr/ / /sd;
        my $mhzkey = "$basekey\\0\\~MHz";
        $cpustr .= sprintf "(~%d MHz)",
            hex $Win32::TieRegistry::Registry->{ $mhzkey };
        $cpu = $cpustr;
        $ncpu = keys %{ $Win32::TieRegistry::Registry->{ $basekey } };
        ($cpu_type) = $Win32::TieRegistry::Registry->{ $idkey } =~ /^(\S+)/;
    }

    return {
        _cpu_type => $cpu_type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
        _host     => __get_hostname(),
        _os       => __get_os(),
    };
}

=item sysinfo( )

C<sysinfo()> returns a string with C<host>, C<os> and C<cpu_type>.

=cut

sub sysinfo {
    my $si = Test::Smoke::SysInfo->new;
    my @fields = $_[0]
        ? qw( host os cpu ncpu cpu_type )
        : qw( host os cpu_type );
    return join " ", @{ $si }{ map "_$_" => @fields };
}

1;

=back

=head1 SEE ALSO

L<Test::Smoke::Smoker>, L<Test::Smoke::Reporter>

=head1 COPYRIGHT

(c) 2002-2003, Abe Timmerman <abeltje@cpan.org> All rights reserved.

With contributions from Jarkko Hietaniemi, Merijn Brand, Campo
Weijerman, Alan Burlison, Allen Smith, Alain Barbet.

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
