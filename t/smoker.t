#! /usr/bin/perl -w
use strict;
use Data::Dumper;

# $Id$
use File::Spec::Functions qw( :DEFAULT devnull abs2rel rel2abs );
use Cwd;

use Test::More tests => 4;
use_ok( 'Test::Smoke::Smoker' );

{
    my %config = (
        v => 0,
        ddir => 'perl-current',
        defaultenv => 1,
    );

    local *LOG;
    open LOG, "> " . devnull();

    my $smoker = Test::Smoke::Smoker->new( \*LOG, %config );
    isa_ok( $smoker, 'Test::Smoke::Smoker' );

    my $ref = mkargs( \%config, 
                      Test::Smoke::Smoker->config( 'all_defaults' ) );
    $ref->{logfh} = \*LOG;

    is_deeply( $smoker, $ref, "Check arguments" );   

    close LOG;
}

{
    my @nok = (
        '../ext/Cwd/t/Cwd.....................FAILED at test 10',
        'op/magic.............................FAILED at test 37',
        '../t/op/die..........................FAILED at test 22',
        'ext/IPC/SysV/t/ipcsysv...............FAILED at test 1',

    );
    local *LOG;
    open LOG, "> " . devnull();

    my $smoker = Test::Smoke::Smoker->new( \*LOG,
        v => 0,
        ddir => cwd(),
    );

    my %tests = $smoker->_transform_testnames( @nok );
    my %raw = (
        '../ext/Cwd/t/Cwd.t'          => 'FAILED at test 10',
        '../t/op/magic.t'             => 'FAILED at test 37',
        '../t/op/die.t'               => 'FAILED at test 22',
        '../ext/IPC/SysV/t/ipcsysv.t' => 'FAILED at test 1',
    );
    my %expect;
    my $test_base = catdir( cwd, 't' );
    foreach my $test ( keys %raw ) {
        my $test_name = rel2abs( $test, $test_base );

        my $test_path = abs2rel( $test_name, $test_base );
        $test_path =~ tr!\\!/! if $^O eq 'MSWin32';
        $expect{ $test_path } = $raw{ $test };
    }
    is_deeply \%tests, \%expect, "transform testnames" or diag Dumper \%tests;

    close LOG;
}

sub mkargs {
    my( $set, $default ) = @_;

    my %mkargs = map {

        my $value = exists $set->{ $_ } 
            ? $set->{ $_ } : Test::Smoke::Smoker->config( $_ );
        ( $_ => $value )
    } keys %$default;

    return \%mkargs;
}
