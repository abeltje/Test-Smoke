package Test::Smoke::SysInfo::Linux;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();
    $self->prepare_os();
    return if !$self->prepare_proc_cpuinfo();

    for ($self->get_cpu_type()) {
        /arm/   && do {$self->linux_arm(); last};
        /ppc/   && do {$self->linux_ppc(); last};
        /sparc/ && do {$self->linux_sparc(); last};
        # default
        $self->linux_generic();
    }
    return $self;
}

sub prepare_os {
    my $self = shift;

    my ($dist_file) = grep {
        -s $_ && !/\blsb-/
    } glob("/etc/*[-_][rRvV][eE][lLrR]*"), "/etc/issue";
    return if !$dist_file;

    my $os = $self->_os();
    (my $distro = $dist_file) =~ s{^/etc/}{};
    $distro =~ s{[-_](?:release|version)\b}{}i;
    if (open(my $fh, "< $dist_file")) {
        my @osi = <$fh>;
        close $fh;
        my %os = map { m/^\s*\U(\S+)\E\s*=\s*(.*)\s*$/ } @osi;
        s/^"\s*(.*?)\s*"$/$1/ for values %os;

        if ( $os{PRETTY_NAME} ) {
            $distro = $os{PRETTY_NAME};          # "openSUSE 12.1 (Asparagus) (x86_64)"
            $distro =~ s/\)\s+\(\w+\)\s*$/)/;    # remove architectural part
        }
        elsif ( $os{VERSION} && $os{NAME} ) {
            $distro = qq{$os{NAME} $os{VERSION}};
        }
        elsif ( $os{VERSION} && $os{CODENAME} ) {
            $distro .= qq{ $os{VERSION} "$os{CODENAME}"};
        }
        elsif ( @osi && $osi[0] =~ m{^\s*([-A-Za-z0-9. ""/]+)} ) {

            # /etc/issue:
            # Welcome to openSUSE 11.2 "Emerald" - Kernel \r (\l).
            # Welcome to openSUSE 11.3 "Teal" - Kernel \r (\l).
            # Welcome to openSUSE 11.4 "Celadon" - Kernel \r (\l).
            # Welcome to openSUSE 12.1 "Asparagus" - Kernel \r (\l).
            # Welcome to openSUSE 12.2 "Mantis" - Kernel \r (\l).
            # Welcome to openSUSE 12.3 "Dartmouth" - Kernel \r (\l).
            # Ubuntu 10.04.4 LTS \n \l
            # Debian GNU/Linux wheezy/sid \n \l
            # Debian GNU/Linux 6.0 \n \l
            # /etc/redhat-release:
            # CentOS release 5.7 (Final)
            # Red Hat Enterprise Linux ES release 4 (Nahant Update 2)
            # /etc/debian_version:
            # 6.0.4
            # wheezy/sid
            ( $distro = $1 ) =~ s/^Welcome\s+to\s+//i;
            $distro =~ s/\s+-\s+Kernel.*//i;
        }
    }
    if ($distro =~ s/^\s*(.*\S)\s*$/$1/) {
        $os .= " [$distro]";
    }
    $self->{__os} = $os;
}

sub linux_generic {
    my $self = shift;

    $self->{__cpu_count} = $self->count_in_cpuinfo(qr/^processor\s+:\s+/);

    my @parts = ( 'model name', 'vendor_id', 'cpu mhz' );
    my %info = map {
        ( $_ => $self->from_cpuinfo($_) );
    } @parts;
    $self->{__cpu} = sprintf "%s (%s %.0fMHz)", map $info{$_} => @parts;

    my $ncores = 0;
    for my $cores ( grep /cpu cores\s*:\s*\d+/ => $self->_proc_cpuinfo ) {
        $ncores += $cores =~ /(\d+)/ ? $1 : 0;
    }
    $self->{__cpu_count} .= " [$ncores cores]" if $ncores;

}

sub linux_arm {
    my $self = shift;

    $self->{__cpu_count} = $self->count_in_cpuinfo(qr/^processor\s+:\s+/i);

    my $cpu = $self->from_cpuinfo('Processor');
    my $bogo = $self->from_cpuinfo('BogoMIPS');
    my $mhz  = 100 * int(($bogo + 50)/100);
    $cpu =~ s/\s+/ /g;
    $cpu .= " ($mhz MHz)" if $mhz;
    $self->{__cpu} = $cpu;
}

sub linux_ppc {
    my $self = shift;

    $self->{__cpu_count} = $self->count_in_cpuinfo(qr/^processor\s+:\s+/);

    my @parts = qw( cpu machine clock );
    my %info = map {
        ( $_ => $self->from_cpuinfo($_) );
    } @parts;
    if ($info{detected} = $self->from_cpuinfo('detected as')){
        $info{detected} =~ s/.*(\b.+Mac G\d).*/$1/;
        $info{machine} = $info{detected};
    }
        
    $self->{__cpu} = sprintf "%s %s (%s)", map $info{ $_ } => @parts;
}

sub linux_sparc {
    my $self = shift;

    $self->{__cpu_count} = $self->from_cpuinfo('ncpus active');

    my @parts = qw( cpu Cpu0ClkTck );
    my %info = map {
        ( $_ => $self->from_cpuinfo($_) );
    } @parts;
    my $cpu = $info{cpu};
    if ($info{Cpu0ClkTck}) {
        $cpu .=  sprintf " (%.0fMHz)", hex( $info{Cpu0ClkTck} )/1_000_000;
    }
    $self->{__cpu} = $cpu;
}

sub prepare_proc_cpuinfo {
    my $self = shift;

    local *PCI;
    if (open PCI, "< /proc/cpuinfo") {
        chomp($self->{__proc_cpuinfo} = [<PCI>]);
        close PCI;
        return 1;
    }
}

sub count_in_cpuinfo {
    my $self = shift;
    my ($regex) = @_;

    return scalar grep /$regex/, $self->_proc_cpuinfo();
}

sub from_cpuinfo {
    my $self = shift;
    my ($key) = @_;

    my ($first) = grep /^\s*$key\s*[:=]\s*/i => $self->_proc_cpuinfo();
    defined $first or $first = "";
    $first =~ s/^\s*$key\s*[:=]\s*//i;
    $first =~ s/\s+/ /g;
    $first =~ s/\s+$//;
    return $first;
}

1;
