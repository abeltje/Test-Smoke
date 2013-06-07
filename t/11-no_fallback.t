#! perl -w
use strict;

use Test::More 'no_plan';

use Config;
use File::Path qw/mkpath rmtree/;
use File::Spec::Functions;

{
    my ($base, @tree, @inc);
    BEGIN {
        @inc = @INC;
        $base = catdir('t', 'fallback');
        @tree = ($base);
        push @tree, catdir($base, $Config{archname}, 'auto');
        push @tree, catdir($base, $Config{archname});
        push @tree, catdir($base, $Config{version});
        push @tree, catdir($base, $Config{version}, $Config{archname});
        mkpath($_) for @tree;
    }
    use fallback 't/fallback';

    no fallback 't/fallback';
    is_deeply(\@INC, \@inc, "\@INC restored");

    rmtree($base);
}
#done_testing();

