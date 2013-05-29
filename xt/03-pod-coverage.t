#! perl -w
use strict;

use Test::Pod::Coverage;

my @options = sort {
    length($b) <=> length($a) ||
    $a cmp $b
} map {chomp($_); $_} <DATA>;

all_pod_coverage_ok({trustme => \@options});


__DATA__
archiver_config
mailer_config
poster_config
reporter_config
runsmoke_config
sendreport_config
smokeperl_config
synctree_config
adir
archive
bcc
cc
ccp5p_onfail
cdir
cfg
curlbin
ddir
defaultenv
fdir
force_c_locale
from
fsync
gitbin
gitbranchfile
gitdfbranch
gitdir
gitorigin
harness3opts
harness_destruct
harnessonly
hdir
is56x
is_vms
is_win32
jsnfile
killtime
lfile
locale
mail
mail_type
mailbin
mailxbin
makeopt
mdir
mserver
mspass
msport
msuser
opt_continue
outfile
poster
report
rptfile
rsyncbin
rsyncopts
rsyncsource
send_log
send_out
sendemailbin
sendmailbin
showcfg
skip_tests
smokedb_url
swbcc
swcc
syncer
testmake
to
ua_timeout
un_file
un_position
user_note
vmsmake
w32args
w32cc
w32make
