#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More tests => 44;
my $verbose = 0;

use_ok "Test::Smoke::BuildCFG";

{ # Start with a basic configuration
    my $dft_cfg = <<__EOCFG__;

-Uuseperlio
=

-Duseithreads
=
/-DDEBUGGING/

-DDEBUGGING
__EOCFG__

    my $dft_sect = [
        [ '', '-Uuseperlio' ],
        [ '', '-Duseithreads' ],
        { policy_target => '-DDEBUGGING', args => [ '', '-DDEBUGGING'] },
    ];

    my $bcfg = Test::Smoke::BuildCFG->new( \$dft_cfg => { v => $verbose } );
    isa_ok $bcfg, "Test::Smoke::BuildCFG";

    is_deeply $bcfg->{_sections}, $dft_sect, "Parse a configuration";

}

{ # Check that order within sections is honored
    my $dft_cfg = <<__EOCFG__;

-Duseithreads
=
-Uuseperlio

-Duse64bitint
=
/-DDEBUGGING/

-DDEBUGGING
__EOCFG__

    my $dft_sect = [
        [ '', '-Duseithreads' ],
        [ '-Uuseperlio', '', '-Duse64bitint' ],
        { policy_target => '-DDEBUGGING', args => [ '', '-DDEBUGGING'] },
    ];

    my $bcfg = Test::Smoke::BuildCFG->new( \$dft_cfg => { v => $verbose } );

    is_deeply $bcfg->{_sections}, $dft_sect, "Section-order kept";

    my $first = ( $bcfg->configurations )[0];
    isa_ok( $first, 'Test::Smoke::BuildCFG::Config');
    is( "$first", $first->[0], "as_string: $first->[0]" );
    foreach my $config ( $bcfg->configurations ) {
        if ( ($config->policy)[0]->[1] ) {
            ok( $config->has_arg( '-DDEBUGGING' ), "has_arg(-DDEBUGGING)" );
            like( "$config", '/-DDEBUGGING/', 
                  "'$config' has -DDEBUGGING" );
        } else {
            ok( !$config->has_arg( '-DDEBUGGING' ), "! has_arg(-DDEBUGGING)" );
            unlike( "$config", '/-DDEBUGGING/', 
                    "'$config' has no -DDEBUGGING" );
        }
        ok( $config->args_eq( "$config" ), "Stringyfied: args_eq($config)" );
    }
}

{ # Check that empty sections are skipped
    my $dft_cfg = <<__EOCFG__;
# This is an empty section

# It really is, although it's got an empty (non comment) line
=

-Duseithreads
==
-Uuseperlio

-Duse64bitint
=
/-DDEBUGGING/

-DDEBUGGING
__EOCFG__

    my $dft_sect = [
        [ '', '-Duseithreads' ],
        [ '-Uuseperlio', '', '-Duse64bitint' ],
        { policy_target => '-DDEBUGGING', args => [ '', '-DDEBUGGING'] },
    ];

    my $bcfg = Test::Smoke::BuildCFG->new( \$dft_cfg => { v => $verbose } );

    is_deeply $bcfg->{_sections}, $dft_sect, "Empty sections are skipped";

}

{ # This is to test the default configuration
    my $dft_sect = [
        [ '', '-Duseithreads'],
        [ '-Uuseperlio', '', qw(-Duse64bitint -Duselongdouble -Dusemorebits) ],
        { policy_target => '-DDEBUGGING', args => [ '', '-DDEBUGGING'] },
    ];

    my $bcfg = Test::Smoke::BuildCFG->new( undef,  { v => $verbose } );

    is_deeply $bcfg->{_sections}, $dft_sect, "Default configuration";
}

package CatchOut;

sub TIEHANDLE { bless \(my $self), shift }
sub PRINT { my $self = shift; $$self .= shift }
sub PRINTF { my $self = shift; my $fmt =shift; $$self .= sprintf $fmt, @_ }
sub CLOSE {}
