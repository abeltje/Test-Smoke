package Test::Smoke::SysInfo;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.001';

=head1 NAME

Test::Smoke::SysInfo - OO interface to system specific information

=head1 SYNOPSIS

    use Test::Smoke::SysInfo;

    my $si = Test::Smoke::SysInfo->new;

    printf "Number of CPU's: %d\n", $si->ncpu;
    printf "Processor type: %s\n", $si->cpu_type;   # short
    printf "Processor description: %s\n", $si->cpu; # long

=head1 DESCRIPTION

Sometimes one wants a more eleborate description of the system one is smoking.

=head1 METHODS

=over 4

=cut

=item Test::Smoke::SysInfo->new( )

Dispatch to one of the OS-specific packages.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    CASE: {
        local $_ = $^O;

        /darwin|bsd/i && return Test::Smoke::SysInfo::BSD->new;

        /linux/i      && return Test::Smoke::SysInfo::Linux->new;

        /irix/i       && return Test::Smoke::SysInfo::IRIX->new;

        /solaris|sunos|osf/i 
                      && return Test::Smoke::SysInfo::Solaris->new;

        /cygwin|mswin32|windows/i
                      && return Test::Smoke::SysInfo::Windows->new;
    }
    return Test::Smoke::SysInfo::Generic->new;
}

my %info = map { ($_ => undef ) } qw( ncpu cpu cpu_type );

sub AUTOLOAD {
    my $self = shift;
    use vars qw( $AUTOLOAD );

    ( my $method = $AUTOLOAD ) =~ s/^.*::(.+)$/\L$1/;

    return $self->{ "_$method" } if exists $info{ "$method" };
}

1;

=back

=head1 PACKAGE

Test::Smoke::SysInfo::Generic - For systems that cannot fetch the info

=head1 METHODS

=over 4

=cut

package Test::Smoke::SysInfo::Generic;

@Test::Smoke::SysInfo::Generic::ISA = qw( Test::Smoke::SysInfo );

=item Test::Smoke::SysInfo::Generic->new( )

Try to get the information from C<POSIX::uname()>.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my $self = {
        _cpu_type => __get_cpu_type(),
        _cpu      => __get_cpu(),
        _ncpu     => __get_ncpu(),
    };

    return bless $self, $class;
}

=item __get_cpu_type( )

This is the short info string about the cpu-type. The L<POSIX> module
should provide one with C<POSIX::uname()>.

=cut

sub __get_cpu_type {
    require POSIX;
    return (POSIX::uname())[4];
}

=item __get_cpu( )

We do not have a specific way to get this information, so assign
C<_cpu_type> to it.

=cut

sub __get_cpu { return __get_cpu_type() }

sub __get_ncpu { return '?' }


=back

=head1 PACKAGE

Test::Smoke::SysInfo::BSD - SysInfo for BSD-type os

=head1 METHODS

=over 4

=cut

package Test::Smoke::SysInfo::BSD;

@Test::Smoke::SysInfo::BSD::ISA = qw( Test::Smoke::SysInfo );

=item Test::Smoke::SysInfo::BSD->new( )

Use the L<sysctl> program to find information.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my %sysctl;
    foreach my $name ( qw( model machine ncpu ) ) {
        chomp( $sysctl{ $name } = `sysctl hw.$name` );
        $sysctl{ $name } =~ s/^hw.$name = //;
    }

    my $self = {
        _cpu_type => $sysctl{model},
        _cpu      => $sysctl{machine},
        _ncpu     => $sysctl{ncpu},
    };
    return bless $self, $class;
}

=back

=head1 PACKAGE

Test::Smoke::SysInfo::IRIX - SysInfo for IRIX type os

=head1 METHODS

=over 4

=cut

package Test::Smoke::SysInfo::IRIX;

@Test::Smoke::SysInfo::IRIX::ISA = qw( Test::Smoke::SysInfo );

=item Test::Smoke::SysInfo::IRIX->new( )

Use the L<hinv> program to get the system information.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    chomp( my $cpu = `hinv -t cpu` );
    $cpu =~ s/^CPU:\s+//;
    chomp( my @processor = `hinv -c processor` );
    my $cpu_cnt = (grep /^\d+\s+.+processors?$/ => @processor)[0];
    my $ncpu = (split " ", $cpu_cnt)[0];
    my $type = (split " ", $cpu_cnt)[-2];

    my $self = {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
    };
    return bless $self, $class;
}

=back

=head1 PACKAGE

Test::Smoke::SysInfo::Linux - SysInfo for Linux type os

=head1 METHODS

=over 4

=cut

package Test::Smoke::SysInfo::Linux;

@Test::Smoke::SysInfo::Linux::ISA = qw( Test::Smoke::SysInfo );

=item Test::Smoke::SysInfo::Linux->new( )

Use the C</proc/cpuinfo> preudofile to get the system information.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    local *CPUINFO;
    my( $type, $cpu, $ncpu ) = 
        ( Test::Smoke::SysInfo::Generic::__get_cpu_type() );

    if ( open CPUINFO, "< /proc/cpuinfo" ) {
        chomp( my @cpu_info = <CPUINFO> );
        close CPUINFO;
        # every processor has its own 'block', so count the blocks
        $ncpu = grep /^processor\s+:\s+/ => @cpu_info;
        my %info;
        my @parts = $type =~ /sparc/
            ? ('cpu')
            : ('model name', 'vendor_id', 'cpu mhz' );
        foreach my $part ( @parts ) {

            ($info{ $part } = (grep /^$part\s+:/i => @cpu_info)[0]) 
                =~ s/^$part\s+:\s+//i;
        }
        $cpu = $type =~ /sparc/
            ? $info{cpu}
            : sprintf "%s (%s %sMHz)", map $info{ $_ } => @parts
    } else {
    }
    my $self = {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
    };
    return bless $self, $class;
}

=back

=head1 PACKAGE

Test::Smoke::SysInfo::Solaris - SysInfo for Solaris type os

=head1 METHODS

=over 4

=cut

package Test::Smoke::SysInfo::Solaris;

@Test::Smoke::SysInfo::Solaris::ISA = qw( Test::Smoke::SysInfo );

=item Test::Smoke::SysInfo::Solaris->new( )

Use the L<psrinfo> program to get the system information.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my( $psrinfo ) = grep /the .* operates .* mhz/ix => `psrinfo -v`;
    my $type = Test::Smoke::SysInfo::Generic::__get_cpu_type();
    my( $cpu, $speed ) = $psrinfo =~ /the (\w+) processor.*(\d+) mhz/i;
    $cpu .= " (${speed}MHz)";
    my $ncpu = grep /on-line/ => `psrinfo`;

    my $self = {
        _cpu_type => $type,
        _cpu      => $cpu,
        _ncpu     => $ncpu,
    };
    return bless $self, $class;
}

=back

=head1 PACKAGE

Test::Smoke::SysInfo::Windows - SysInfo for Windows and CygWin

=head1 METHODS

=over 4

=cut

package Test::Smoke::SysInfo::Windows;

@Test::Smoke::SysInfo::Windows::ISA = qw( Test::Smoke::SysInfo );

=item Test::Smoke::SysInfo::Windows->new( )

Use the C<%ENV> hash to find information. Fall back on the *::Generic
values if these values have been unset or are unavailable (sorry I do
not have Win9[58]).

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my $self = {
        _cpu_type => $ENV{PROCESSOR_ARCHITECTURE} ||
                     Test::Smoke::SysInfo::Generic::__get_cpu_type(),
        _cpu      => $ENV{PROCESSOR_IDENTIFIER} ||
                     Test::Smoke::SysInfo::Generic::__get_cpu(),
        _ncpu     => $ENV{NUMBER_OF_PROCESSORS} ||
                     Test::Smoke::SysInfo::Generic::__get_ncpu(),
    };
    return bless $self, $class;
}

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
