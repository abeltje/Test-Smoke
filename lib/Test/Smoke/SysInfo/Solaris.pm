package Test::Smoke::SysInfo::Solaris;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();

    local $ENV{PATH} = "/usr/sbin:$ENV{PATH}";

    my @psrinfo = `psrinfo -v`;
    my( $psrinfo ) = grep /the .* operates .* [gm]hz/ix => @psrinfo;
    my( $type, $speed, $magnitude ) =
        $psrinfo =~ /the (.+) processor.*at (.+?)\s*([GM]hz)/i;

    $type =~ s/(v9)$/ $1 ? "64" : ""/e;

    my $cpu = $self->_get_cpu();

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
        }
        else {
            $cpu .= " ($speed$magnitude)";
        }
    }
    elsif (-x "/usr/sbin/sizer") { # OSF/1.
        $cpu = $type;
        chomp( $type = `sizer -implver` );
    }

    my $ncpu = grep /on-?line/ => `psrinfo`;

    $self->{__cpu_type}  = $type;
    $self->{__cpu}       = $cpu;
    $self->{__cpu_count} = $ncpu;
    return $self;
}

sub prepare_os {
    my $self = shift;

    my ($osn, $osv) = ($self->_osname, $self->_osvers);
    if ($^O =~ /solaris|sunos/i && $osv > 5) {
        $osn = 'Solaris';
        $osv = '2.' . ( split /\./, $osv, 2 )[1];
    };
    $self->{__os} = join " - ", $osn, $osv;
}
1;
