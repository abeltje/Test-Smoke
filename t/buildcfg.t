#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More tests => 61;
my $verbose = 0;

use FindBin;
use lib $FindBin::Bin;
use TestLib;

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

{ # Check that empty lines at the end of sections are honored
    my $dft_cfg = <<__EOCFG__;
-Duseithreads

=
/-DDEBUGGING/

-DDEBUGGING
__EOCFG__

    my $dft_sect = [
        [ '-Duseithreads', '' ],
        { policy_target => '-DDEBUGGING', args => [ '', '-DDEBUGGING'] },
    ];

    my $bcfg = Test::Smoke::BuildCFG->new( \$dft_cfg => { v => $verbose } );

    is_deeply $bcfg->{_sections}, $dft_sect, 
              "Empty lines at end of section kept";

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

# Now we need to test the C<continue()> constructor
{
    my $dft_cfg = <<EOCFG;

-Dusethreads
=
/-DDEBUGGING/

-DDEBUGGING
EOCFG

    my $mktest_out = <<OUT;
Smoking patch 20000

Configuration: -Dusedevel
----------------------------------------------------------------------
PERLIO=stdio	All tests successful.

PERLIO=perlio	All tests successful.

Configuration: -Dusedevel -DDEBUGGING
----------------------------------------------------------------------
PERLIO=stdio	All tests successful.

PERLIO=perlio	All tests successful.

Configuration: -Dusedevel -Dusethreads
----------------------------------------------------------------------
PERLIO=stdio	
OUT

    put_file( $mktest_out, 'mktest.out' );
    my $bcfg = Test::Smoke::BuildCFG->continue( 'mktest.out', \$dft_cfg );
    isa_ok( $bcfg, 'Test::Smoke::BuildCFG' );

    my @not_seen;
    push @not_seen, "$_" for $bcfg->configurations;

    is_deeply( \@not_seen, ["-Dusedevel -Dusethreads", 
                            "-Dusedevel -Dusethreads -DDEBUGGING" ],
               "The right configs are left for continue" );
    1 while unlink 'mktest.out';
}


package Test::BCFGTester;
use strict;

use Test::Builder;
use base 'Exporter';

use vars qw( $VERSION @EXPORT );
$VERSION = '0.001';
@EXPORT = qw( &config_ok );
