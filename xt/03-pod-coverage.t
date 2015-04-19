#! perl -w
use strict;

use Test::Pod::Coverage;

my @options = sort {
    length($b) <=> length($a) ||
    $a cmp $b
} map {chomp($_); $_} <DATA>;

all_pod_coverage_ok({trustme => \@options});


__DATA__
adir
archive
archiver_config
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
hasharness3
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
mailer_config
mailxbin
makeopt
mdir
mserver
mspass
msport
msuser
opt_continue
outfile
patchlevel
poster
poster_config
report
reporter_config
rptfile
rsyncbin
rsyncopts
rsyncsource
runsmoke_config
send_log
send_out
sendemailbin
sendmailbin
sendreport_config
showcfg
skip_tests
smartsmoke
smokedb_url
smokeperl_config
swbcc
swcc
sync
syncer
synctree_config
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
