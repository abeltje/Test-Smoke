package Test::Smoke::SysInfo::AIX;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();

    local $ENV{PATH} = "$ENV{PATH}:/usr/sbin";
    $self->prepare_os();

    my @lsdev = grep /Available/ => `lsdev -C -c processor -S Available`;
    $self->{__cpu_count} = scalar @lsdev;

    my ($info) = grep /^\S+/ => @lsdev;
    ($info) = $info =~ /^(\S+)/;
    $info .= " -a 'state type'";

    my ($cpu) = grep /\benable:[^:\s]+/ => `lsattr -E -O -l $info`;
    ($cpu) = $cpu =~ /\benable:([^:\s]+)/;
    $cpu =~ s/\bPowerPC(?=\b|_)/PPC/i;

    (my $cpu_type = $cpu) =~ s/_.*//;
    $self->{__cpu} = $cpu;
    $self->{__cpu_type} = $cpu_type;

    my $os = $self->_os();
    if ( $> == 0 ) {
        chomp( my $k64 = `bootinfo -K 2>/dev/null` );
        $k64 and $os .= "/$k64";
        chomp( my $a64 = `bootinfo -y 2>/dev/null` );
        $a64 and $cpu_type .= "/$a64";
    }
    $self->{__os} = $os;
}

sub prepare_os {
    my $self = shift;

    my $os = $self->_os;
    chomp( $os = `oslevel -r` );
    if ( $os =~ m/^(\d+)-(\d+)$/ ) {
        $os = join(".", split //, $1) . "/ML$2";
    }
    else {
        chomp( $os = `oslevel` );

        # And try figuring out at what maintainance level we are
        my $ml = "00";
        for ( grep m/ML\b/ => `instfix -i` ) {
            if (m/All filesets for (\S+) were found/) {
                $ml = $1;
                $ml =~ m/^\d+-(\d+)_AIX_ML/ and $ml = "ML$1";
                next;
            }
            $ml =~ s/\+*$/+/;
        }
        $os .= "/$ml";
    }
    $os =~ s/^/AIX - /;
    $self->{__os} = $os;
}

1;
