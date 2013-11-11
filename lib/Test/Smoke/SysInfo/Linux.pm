package Test::Smoke::SysInfo::Linux;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

=head1 NAME

Test::Smoke::SysInfo::Linux - Object for specific Linux info.

=head1 DESCRIPTION

=head2 $si->prepare_sysinfo()

Use os-specific tools to find out more about the system.

=cut

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

=head2 $si->prepare_os()

Use os-specific tools to find out more about the operating system.

=cut

sub prepare_os {
    my $self = shift;

    my ($dist_file) = grep {
        -s $_ && !/\blsb-/
    } glob("/etc/*[-_][rRvV][eE][lLrR]*"), "/etc/issue",
	"/etc.defaults/VERSION", "/etc/VERSION";
    return if !$dist_file;

    my $os = $self->_os();
    (my $distro = $dist_file) =~ s{^/etc(?:\.defaults)?/}{}i;
    $distro =~ s{[-_]?(?:release|version)\b}{}i;
    if (open(my $fh, "< $dist_file")) {
        my @osi = grep m/\S/ => <$fh>;
        close $fh;
        my %os = map { m/^\s*(\S+)\s*=\s*(.*)\s*$/; ( uc $1 => $2 ) } @osi;
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
        elsif ( $os{MAJORVERSION} && $os{MINORVERSION} ) {
            -d "/usr/syno" and $distro .= "DSM";
            $distro .= qq{ $os{MAJORVERSION}.$os{MINORVERSION}};
            $os{BUILDNUMBER}    and $distro .= qq{-$os{BUILDNUMBER}};
            $os{SMALLFIXNUMBER} and $distro .= qq{-$os{SMALLFIXNUMBER}};
        }
        elsif ( @osi && $osi[0] =~ m{^\s*([-A-Za-z0-9. ""/]+)} ) {

	    # /etc/issue:
	    #  Welcome to openSUSE 11.1 - Kernel \r (\l).
	    #  Welcome to openSUSE 11.2 "Emerald" - Kernel \r (\l).
	    #  Welcome to openSUSE 11.3 "Teal" - Kernel \r (\l).
	    #  Welcome to openSUSE 11.4 "Celadon" - Kernel \r (\l).
	    #  Welcome to openSUSE 12.1 "Asparagus" - Kernel \r (\l).
	    #  Welcome to openSUSE 12.2 "Mantis" - Kernel \r (\l).
	    #  Welcome to openSUSE 12.3 "Dartmouth" - Kernel \r (\l).
	    #  Welcome to SUSE Linux Enterprise Server 11 SP1 for VMware  (x86_64) - Kernel \r (\l).
	    #  Ubuntu 10.04.4 LTS \n \l
	    #  Debian GNU/Linux wheezy/sid \n \l
	    #  Debian GNU/Linux 6.0 \n \l
	    #  CentOS release 6.4 (Final)
	    # /etc/redhat-release:
	    #  CentOS release 5.7 (Final)
	    #  CentOS release 6.4 (Final)
	    #  Red Hat Enterprise Linux ES release 4 (Nahant Update 2)
	    # /etc/debian_version:
	    #  6.0.4
	    #  wheezy/sid
	    #  squeeze/sid
            ( $distro = $1 ) =~ s/^Welcome\s+to\s+//i;
            $distro =~ s/\s+-\s+Kernel.*//i;
            $distro =~ s/\s*\\[rln].*//;
        }
    }
    if ($distro =~ s/^\s*(.*\S)\s*$/$1/) {
        $os .= " [$distro]";
    }
    $self->{__os} = $os;
}

=head2 $si->linux_generic

Check C</proc/cpuinfo> for these keys:

=over

=item 'processor'  (count occurrence for __cpu_count)

=item 'model name' (part of __cpu)

=item 'vendor_id'  (part of __cpu)

=item 'cpu mhz'    (part of __cpu)

=item 'cpu cores'  (add values to add to __cpu_count)

=back

=cut

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

=head2 $si->linux_arm

Check C</proc/cpuinfo> for these keys:

=over

=item 'processor'  (count occurrence for __cpu_count)

=item 'Processor' (part of __cpu)

=item 'BogoMIPS'  (part of __cpu)

=back

=cut

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

=head2 $si->linux_ppc

Check C</proc/cpuinfo> for these keys:

=over

=item 'processor'  (count occurrence for __cpu_count)

=item 'cpu'     (part of __cpu)

=item 'machine' (part of __cpu)

=item 'clock'   (part of __cpu)

=item 'detected' (alters machine if present)

=back

=cut

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

=head2 $si->linux_sparc

Check C</proc/cpuinfo> for these keys:

=over

=item 'processor'  (count occurrence for __cpu_count)

=item 'cpu'        (part of __cpu)

=item 'Cpu0ClkTck' (part of __cpu)

=back

=cut

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

=head2 $si->prepare_proc_cpuinfo

Read the complete C<< /proc/cpuinfo >>.

=cut

sub prepare_proc_cpuinfo {
    my $self = shift;

    if (open my $pci, "< /proc/cpuinfo") {
        chomp($self->{__proc_cpuinfo} = [<$pci>]);
        close $pci;
        return 1;
    }
}

=head2 $si->count_in_cpuinfo($regex)

Returns the number of lines $regex matches for.

=cut

sub count_in_cpuinfo {
    my $self = shift;
    my ($regex) = @_;

    return scalar grep /$regex/, $self->_proc_cpuinfo();
}

=head2 $si->from_cpuinfo($key)

Returns the first value of that key in C<< /proc/cpuinfo >>.

=cut

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

=head1 COPYRIGHT

(c) 2002-2013, Abe Timmerman <abeltje@cpan.org> All rights reserved.

With contributions from Jarkko Hietaniemi, Merijn Brand, Campo
Weijerman, Alan Burlison, Allen Smith, Alain Barbet, Dominic Dunlop,
Rich Rauenzahn, David Cantrell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * L<http://www.perl.com/perl/misc/Artistic.html>

=item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
