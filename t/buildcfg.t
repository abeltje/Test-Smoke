#! /usr/bin/perl -w
use strict;
use Data::Dumper;

use Test::More 'no_plan';
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
            like( "$config", '/-DDEBUGGING/', "'$config' has -DDEBUGGING" );
        } else {
            ok( !$config->has_arg( '-DDEBUGGING' ), "! has_arg(-DDEBUGGING)" );
            unlike( "$config", '/-DDEBUGGING/', "'$config' has no -DDEBUGGING" );
        }
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

    my $bcfg = Test::Smoke::BuildCFG->new( \$dft_cfg => { v => 0 } );

    is_deeply $bcfg->{_sections}, $dft_sect, "Empty sections are skipped";

}


package CatchOut;

sub TIEHANDLE { bless \(my $self), shift }
sub PRINT { my $self = shift; $$self .= shift }
sub PRINTF { my $self = shift; my $fmt =shift; $$self .= sprintf $fmt, @_ }
sub CLOSE {}
