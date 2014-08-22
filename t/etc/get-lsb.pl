#!/pro/bin/perl

use strict;
use warnings;

foreach my $vf (glob ("/etc/*[-_][rRvV][eE][lLrR]*"), "/etc/issue",
             "/etc.defaults/VERSION", "/etc/VERSION", "/etc/release") {
    open my $fh, "<", $vf or next;
    (my $lf = $vf) =~ s{.*/}{};
    print "cat > $lf <<EOFV\n", <$fh>, "EOFV\n";
    }

