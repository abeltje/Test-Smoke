#! /usr/bin/perl -w
use strict;

# Stolen from the Module::Signature distribution, thanks Autrijus
# $Id$

use Test::More;
plan exists $ENV{SMOKE_DO_SIGTEST} && $ENV{SMOKE_DO_SIGTEST}
    ? ( tests => 1 )
    :( skip_all => "Set SMOKE_DO_SIGTEST=1 to run this test." );

my $key_server = 'pgp.mit.edu';

SKIP: {
    if (!eval { require Module::Signature; 1 }) {
        skip( "Next time around, consider installing Module::Signature, ".
              "so you can verify the integrity of this distribution.", 1 );
    }
    elsif (!eval { require Socket; Socket::inet_aton( $key_server ) }) {
        skip( "Cannot connect to the keyserver ($key_server)", 1 );
    }
    else {
        ok( Module::Signature::verify() == Module::Signature::SIGNATURE_OK(),
            "Valid signature" );
    }
}
