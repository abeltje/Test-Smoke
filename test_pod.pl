#! /usr/bin/perl
use warnings FATAL => 'all';
use strict;
use File::Spec;

my @test_files;
BEGIN {
    @test_files = qw(
        synctree.pl patchtree.pl mktest.pl mkovz.pl mailrpt.pl
        smokeperl.pl configsmoke.pl README ReleaseNotes FAQ.pod
    );
    push @test_files, map File::Spec->catfile( 'lib', 'Test', 'Smoke', $_ )
        => qw( Syncer.pm SourceTree.pm Policy.pm Util.pm 
               Patcher.pm Mailer.pm );
    push @test_files, map File::Spec->catfile( 'lib', 'Test', $_ )
        => qw( Smoke.pm );
}
use Test::Pod tests => scalar @test_files;

pod_ok( $_ ) for @test_files;
