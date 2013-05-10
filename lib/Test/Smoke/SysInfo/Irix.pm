package Test::Smoke::SysInfo::Irix;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinofo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();
    $self->prepare_os();

    chomp( my( $cpu ) = `hinv -t cpu` );
    $cpu =~ s/^CPU:\s+//;

    chomp( my @processor = `hinv -c processor` );
    my ($cpu_cnt) = grep /\d+.+processors?$/i => @processor;
    my ($cpu_mhz) = $cpu_cnt =~ /^\d+ (\d+ MHZ) /;
    my $ncpu = (split " ", $cpu_cnt)[0];
    my $type = (split " ", $cpu_cnt)[-2];

    $self->{__cpu_type}  = $type;
    $self->{__cpu}       = $cpu . " ($cpu_mhz)";
    $self->{__cpu_count} = $ncpu;

    return $self;
}

sub prepare_os {
    my $self = shift;

    chomp( my $osvers = `uname -R` );
    my ($osn, $osv) = ($self->_osname, $self->_osvers);
    $osvers =~ s/^$osv\s+(?=$osv)//;
    $self->{__os} = "$osn - $osvers";
}

1;
