#!/usr/bin/perl -w
use strict;

use Config;
use Cwd;
use File::Spec;
use File::Path;
use Data::Dumper;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );

use Getopt::Long;
my %options = ( 
    config  => undef, 
    jcl     => undef, 
    log     => undef,
    default => undef,
    prefix  => undef,
    oldcfg  => 0,
);
GetOptions( \%options, 
    'config|c=s', 'jcl|j=s', 'log|l=s', 
    'prefix|p=s', 'default|d=s'
);
$options{prefix} = 'smokecurrent' unless defined $options{prefix};

my %suffix = ( config => '_config', jcl => '', log => '.log' );
foreach my $opt (qw( config jcl log )) {
    my $key = defined $options{$opt} ? $opt : 'prefix';
    $options{$opt} = "$options{ $key }$suffix{ $opt }";
}

use vars qw( $VERSION $conf );
$VERSION = '0.022'; # $Id$

eval { require $options{config} };
$options{oldcfg} = 1, print "Using '$options{config}' for defaults.\n" 
    unless $@;
if ( $@ || $options{default} ) {
    my $df_key = $options{default} ? 'default' : 'prefix';
    my $df_config = "$options{ $df_key }_dfconfig";
    local $@;
    eval { require $df_config };
    $options{oldcfg} = 0, print "Using '$df_config' for more defaults.\n"
        unless $@;
} 

=head1 NAME

configsmoke.pl - Create a configuration for B<smokeperl.pl>

=head1 SYNOPSIS

   $ perl configsmoke.pl [options]

=head1 OPTIONS

Current options:

  -c configname When ommited 'perlcurrent_config' is used
  -j jclname    When ommited 'perlcurrent' is used
  -l logfile    When ommited 'perlcurrent.log' is used
  -p prefix     Set -c and -j and -l at once

=cut

sub is_win32() { $^O eq 'MSWin32' }

my %config = ( perl_version => $conf->{perl_version} || '5.9.x' );

my %mailers = get_avail_mailers();
my @mailers = sort keys %mailers;
my @syncers = get_avail_sync();
my $syncmsg = join "\n", @{ { 
    rsync    => "\trsync - Use the rsync(1) program [preferred]",
    copy     => "\tcopy - Use File::Copy to copy from a local directory",
    hardlink => "\thardlink - Copy from a local directory using link()",
    snapshot => "\tsnapshot - Get a snapshot using Net::FTP (or LWP::Simple)",
} }{ @syncers };
my @untars = get_avail_tar();
my $untarmsg = join "", map "\n\t$_" => @untars;

my %versions = (
    '5.6.x' => { source => 'ftp.linux.activestate.com::perl-5.6.x',
                 ddir   => File::Spec->rel2abs( 
                               File::Spec->catdir( File::Spec->updir,
                                                   'perl-5.6.x' ) ),
                 cfg    => 'perl56x.cfg',
                 text   => 'Perl 5.6.2-to-be',
                 is56x  => 1 },
    '5.8.x' => { source =>  'ftp.linux.activestate.com::perl-5.8.x',
                 server => 'http://www.iki.fi',
                 sdir   => '/jhi',
                 sfile  => 'perl@19856.tgz',
                 pdir   => '/pub/staff/gsar/APC/perl-5.8.x-diffs',
                 ddir   => File::Spec->rel2abs( 
                               File::Spec->catdir( File::Spec->updir,
                                                   'perl-5.8.x' ) ),
                 text   => 'Perl 5.8.1-to-be',
                 cfg    => ( $^O eq 'MSWin32' 
                        ? 'w32current.cfg' :'perlcurrent.cfg' ),
                 is56x  => 0 },
    '5.9.x' => { source => 'ftp.linux.activestate.com::perl-current',
                 server => 'ftp.funet.fi',
                 sdir   => '/pub/languages/perl/snap/',
                 sfile  => '',
                 pdir   => '/pub/staff/gsar/APC/perl-current-diffs',
                 ddir   => File::Spec->rel2abs( 
                               File::Spec->catdir( File::Spec->updir,
                                                   'perl-current' ) ),
                 text   => 'Perl 5.10.0-to-be',
                 cfg    => ( $^O eq 'MSWin32' 
                        ? 'w32current.cfg' :'perlcurrent.cfg' ),
                 is56x  => 0 },
);
my @pversions = sort keys %versions;
my $smoke_version = join "\n", map {
    "\t$_ - $versions{ $_ }->{text}"
} @pversions;

my %opt = (
    perl_version => {
        msg => "Which version are you going to smoke?\n$smoke_version",
        alt => [ @pversions ],
        dft => $pversions[-1],
    },

    # is this a perl-5.6.x smoke?
    is56x => {
        msg => "Is this configuration for perl-5.6.x (MAINT)?
\tThis will ensure only one pass of 'make test'.",
        alt => [qw( N y )],
        dft => 'N',
    },
    # Destination directory
    ddir => {
        msg => "Where would you like the new source-tree?
\tThis directory is also used as the build directory.",
        alt => [ ],
        dft => File::Spec->rel2abs( File::Spec->catdir( File::Spec->updir,
                                                        'perl-current' ) ),
    },
    use_old => {
        msg => "It looks like there is already a source-tree there.\n" .
               "Should it still be used for smoke testing?",
        alt => [qw( N y )],
        dft => 'n',
    },
    # misc
    cfg => {
        msg => 'Which build-configuration file would you like to use?',
        alt => [ ],
        dft => File::Spec->rel2abs( is_win32
                                    ? 'w32current.cfg' : 'perlcurrent.cfg' ),
    },
    change_cfg => {
        msg => undef, # Set later...
        alt => [qw( Y n )],
        dft => 'y',
    },
    umask => {
        msg => 'What umask can be used (0 preferred)?',
        alt => [ ],
        dft => '0',
    },
    renice => {
        msg => "With which value should 'renice' be run " .
               "(leave '0' for no 'renice')?",
        alt => [ 0..20 ],
        dft => 0,
    },
    v => {
        msg => 'How verbose do you want the output?',
        alt => [qw( 0 1 2 )],
        dft => 1,
    },
    # syncing the source-tree
    want_forest => {
        msg => "Would you like the 'Nick Clark' master sync trees?
\tPlease see 'perldoc $0' for an explanation.",
        alt => [qw( N y )],
        dft => 'n',
    },
    forest_mdir => {
        msg => 'Where would you like the master source-tree?',
        alt => [ ],
        dft => File::Spec->rel2abs( File::Spec->catdir( File::Spec->updir,
                                                        'perl-master' ) ),
    },
    forest_hdir => {
        msg => 'Where would you like the intermediate source-tree?',
        alt => [ ],
        dft => File::Spec->rel2abs( File::Spec->catdir( File::Spec->updir,
                                                        'perl-inter' ) ),
    },
    fsync => { 
        msg => "How would you like to sync your master source-tree?\n$syncmsg",
        alt => [ @syncers ], 
        dft => $syncers[0],
    },
    sync_type => { 
        msg => "How would you like to sync your source-tree?\n$syncmsg",
        alt => [ @syncers ], 
        dft => $syncers[0],
    },
    source => {
        msg => 'Where would you like to rsync from?',
        alt => [ ],
        dft => 'ftp.linux.activestate.com::perl-current',
    },
    rsync => {
        msg => 'Which rsync program should be used?',
        alt => [ ],
        dft => whereis( 'rsync' ),
    },
    opts => {
        msg => 'Which arguments should be used for rsync?',
        alt => [ ],
        dft => '-az --delete',
    },

    server => {
        msg => "Where would you like to FTP the snapshots from?
\tsnapshots on a webserver can be downloaded with the use
\tof LWP::Simple. Just have the server-name start with http://",
        alt => [ ],
        dft => 'ftp.funet.fi',
    },
    sdir => {
        msg => 'Which directory should the snapshots be FTPed from?',
        alt => [ ],
        dft => '/pub/languages/perl/snap',
    },
    sfile => {
        msg => "Which file should be FTPed?
\tLeave empty to automatically find newest.
\tMandatory for HTTP! (see also --snapshot switch in perlsmoke.pl)",
        alt => [ ],
        dft => '',
    },

    tar => {
        msg => "How should the snapshots be extracted?
Examples:$untarmsg",
        alt => [ ],
        dft => (get_avail_tar())[0],
    },

    snapext => {
        msg => 'What type of snapshots should be FTPed?',
        alt => [qw( tgz tbz )],
        dft => 'tgz',
    },

    patchup => {
        msg => 'Would you like to try to patchup your snapshot?',
        alt => [qw( N y ) ],
        dft => 'n',
    },

    pserver => {
        msg => 'Which server would you like the patches FTPed from?',
        alt => [ ],
        dft => 'ftp.linux.activestate.com',
    },

    pdir => {
        msg => 'Which directory should the patches FTPed from?',
        alt => [ ],
        dft => '/pub/staff/gsar/APC/perl-current-diffs',
    },

    unzip => {
        msg => 'How should the patches be unzipped?',
        alt => [ ],
        dft => whereis( 'gzip' ) . " -cd",
    },

    cleanup => {
        msg => "Remove applied patch-files?\n" .
               "0(none) 1(snapshot)",
        alt => [qw( 0 1 )],
        dft => 1,
    },

    cdir => {
        msg => 'From which directory should the source-tree be copied?',
        alt => [ ],
        dft => undef,
    },

    hdir => {
        msg => 'From which directory should the source-tree be hardlinked?',
        alt => [ ],
        dft => undef,
    },

    patch => {
        msg => undef,
        alt => [ ],
        dft => whereis( 'gpatch') || whereis( 'patch' ),
    },

    popts => {
        msg => undef,
        alt => [ ],
        dft => '',
    },

    pfile => {
        msg => "What file is used for specifying patches " .
               "(leave empty for none)?
\tPlease read the documentation.",
        alt => [ ],
        dft => ''
    },

    # mail stuff
    mail => {
        msg => "Would you like your reports send by e-mail?",
        alt => [qw( Y n )],
        dft => 'y',
    },
    mail_type => {
        msg => 'Which mail facility should be used?',
        alt => [ @mailers ],
        dft => $mailers[0],
        nocase => 1,
    },
    mserver => {
        msg => 'Which SMTP server should be used to send the report?' .
               "\nLeave empty to use local sendmail",
        alt => [ ],
        dft => 'localhost',
    },

    to => {
       msg => "To which address(es) should the report be send " .
              "(comma separated list)?",
       alt => [ ],
       dft => 'smokers-reports@perl.org',
    },

    cc => {
       msg => "To which address(es) should the report be CC'ed " .
              "(comma separated list)?",
       alt => [ ],
       dft => '',
    },

    from => {
        msg => 'Which address should be used for From?',
        alt => [ ],
        dft => '',
    },
    force_c_locale => {
        msg => "Should \$ENV{LC_ALL} be forced to 'C'?",
        alt => [qw( N y )],
        dft => 'n',
    },
    locale => {
        msg => 'What locale should be used for extra testing ' .
               '(leave empty for none)?',
        alt => [ ],
        dft => '',
        chk => '(?:utf-?8$)|^$',
    },
    smartsmoke => {
        msg => 'Skip smoke unless patchlevel changed?',
        alt => [qw( Y n )],
        dft => 'y',
    },
    killtime => {
        msg => "Should this smoke be aborted on/after a specific time?
\tuse HH:MM to specify a point in time (24 hour notation)
\tuse +HH:MM to specify a duration
\tleave empty to finish the smoke without aborting",
        dft => "",
        alt => [ ],
        chk => '^(?:(?:\+\d+)|(?:(?:[0-1]?[0-9])|(?:2[0-3])):[0-5]?[0-9])|$',
    },
    # Schedule stuff
    docron => {
        msg => 'Should the smoke be scheduled?',
        alt => [qw( Y n )],
        dft => 'y',
    },
    crontime => {
        msg => 'At what time should the smoke be scheduled?',
        alt => [ ],
        dft => '22:25',
        chk => '(?:random|(?:[012]?\d:[0-5]?\d))',
    },
);

print <<EOMSG;

Welcome to the Perl core smoke test suite. 

You will be asked some questions in order to configure this test suite.
Please make sure to read the documentation "perldoc configsmoke.pl"
in case you do not understand a question.

* Values in angled-brackets (<>) are alternatives (none other allowed)
* Values in square-brackets ([]) are default values (<Enter> confirms)
* Use single space to clear a value

EOMSG

my $arg;

=head1 DESCRIPTION

B<Test::Smoke> is the symbolic name for a set of scripts and modules
that try to run the perl core tests on as many configurations as possible
and combine the results into an easy to read report.

The main script is F<smokeperl.pl>, and this uses a configuration file
that is created by this program (F<configsmoke.pl>).  There is no default
configuration as some actions can be rather destructive, so you will need
to create your own configuration by running this program!

By default the configuration file created is called F<smokecurrent_config>,
this can be changed by specifying the C<< -c <prefix> >> or C<< -p <prefix> >>
switch at the command line (C<-c> will override C<-p> when both are specified).

    $ perl configsmoke.pl -c mysmoke

will create F<mysmoke_config> as the configuration file.

After you are done configuring, a small job command list is written.
For MSWin32 this is called F<smokecurrent.cmd> otherwise this is called
F<smokecurrent.sh>. Again the default prefix can be overridden by specifying
the C<< -j <prefix> >> or C<< -p <prefix> >> switch.

All output (stdout, stderr) from F<smokeperl.pl> and its sub-processes
is redirected to a logfile called F<smokecurrent.log> by the small jcl. 
(Use C<< -l <prefix> >> or C<< -p <prefix> >> to override).

There are two additional configuration default files
F<smoke56x_dfconfig> and F<smoke58x_dfconfig> to help you configure 
B<Test::Smoke> for these two maintenance branches of the source-tree.

To create a configuration for the perl 5.8.x brach:

    $ perl configsmoke.pl -p smoke58x

This will read additional defaults from F<smoke58x_dfconfig> and create
F<smoke58x_config> and F<smoke58x.sh>/F<smoke58x.cmd> and logfile will be
F<smoke58x.log>.

The same goes for the perl 5.6.x branch:

    $perl configsmoke.pl -p smoke56x

=head1 CONFIGURATION

Use of the program:

=over 4

=item *

Values in angled-brackets (<>) are alternatives (none other allowed)

=item *

Values in square-brackets ([]) are default values (<Enter> confirms)

=item *

Use single space to clear a value

=back

Here is a description of the configuration sections.

=over 4

=item perl_version

C<perl_version> sets a number of default_values. 
This makes the F<smoke5?x_dfconfig> files almost obsolete, 
although they still provide a nice way to set the prefix
and set the perl_version.

=cut

$arg = 'perl_version';
my $pversion = prompt( $arg );
$config{ $arg } = $pversion; 

foreach my $var ( keys %{ $versions{ $pversion } } ) {
    $var eq 'text' and next;
    $opt{ $var }->{dft} = $versions{ $pversion }->{ $var };
}

$config{is56x} = $versions{ $pversion }->{is56x};

# Now we need to reset avail_sync; no snapshots for 5.6.x!
$opt{fsync}->{alt} = $opt{sync_type}->{alt} = [ get_avail_sync() ];
$opt{fsync}->{dft} = $opt{sync_type}->{dft} = $opt{fsync}->{alt}[0];

=item ddir

C<ddir> is the destination directory. This is used to put the
source-tree in and build perl. If a source-tree appears to be there
you will need to confirm your choice.

=cut

BUILDDIR: {
    $arg = 'ddir';
    $config{ $arg } = prompt_dir( $arg );
    my $cwd = cwd;
    unless ( chdir $config{ $arg } ) {
        warn "Can't chdir($config{ $arg }): $!\n";
        redo BUILDDIR;
    }
    my $bdir = $config{ $arg } = cwd;
    chdir $cwd or die "Can't chdir($cwd) back: $!\n";
    if ( $cwd eq $bdir ) {
        print "The current directory *cannot* be used for smoke testing\n";
        redo BUILDDIR;
    }

    $config{ $arg } = File::Spec->canonpath( $config{ $arg } );
    my $manifest  = File::Spec->catfile( $config{ $arg }, 'MANIFEST' );
    my $dot_patch = File::Spec->catfile( $config{ $arg }, '.patch' );
    if ( -e $manifest && -e $dot_patch ) {
        $opt{use_old}->{dft} = $options{oldcfg} && 
                               ($conf->{ddir}||"") eq $config{ddir}
            ? 'y' : $opt{use_old}->{dft};
        my $use_old = prompt_yn( 'use_old' );
        redo BUILDDIR unless $use_old;
    }
}

=item cfg

C<cfg> is the path to the file that holds the build-configurations.
There are several build-cfg files provided with the distribution:

=over 4

=item F<perlcurrent.cfg> for 5.8.x+ on unixy systems

=item F<w32current.cfg> for 5.8.x+ on MSWin32

=item F<perl56x.cfg> for 5.6.x (MAINT) on unixy systems

=back

Note: 5.6.x on MSWin32 is not yet provided, but commenting out the
B<-Duselargefiles> section from F<w32current.cfg> should be enough.

=cut

$arg = 'cfg';
$config{ $arg } = prompt_file( $arg );
check_buildcfg( $config{ $arg } );

=item Nick Clark hardlink forest

Here is how Nick described it to me:

My plan is to use a few more directories, and avoid make distclean:

=over 4

=item 1

rsync as before, but to a master directory. this directory is only used 
for rsyncing from the server

=item 2

copy that directory (as a hardlink forest) - gnu cp can do it as cp -lr,
and I have a perl script to replicate that (which works nicely on FreeBSD)
as a clean master source directory for this smoke session

=item 3

run the regen headers script (which 5.9.0 now has as a distinct script)
rather than just a Makefile target

I now have a clean, up-to-date source tree with accurate headers. For each
smoking configuration

=item 4

copy that directory (hard links again)

=item 5

in the copy directory. Configure, build and test

=item 6

delete the copy directory

=back

deleting a directory seems to be faster than make distclean.

=cut

# Check to see if you want the Nick Clark forest
$arg = 'want_forest';
$opt{ $arg }{dft} = exists $conf->{sync_type}
                  ? $conf->{sync_type} eq 'forest'
                  : $opt{ $arg }{dft};
my $want_forest = prompt_yn( $arg );
FOREST: {
    last FOREST unless $want_forest;

    $config{mdir} = prompt_dir( 'forest_mdir' );

    $config{fdir} = prompt_dir( 'forest_hdir' );

    $config{sync_type} = 'forest';
}

=item sync_type (fsync)

C<sync_type> (or C<fsync> if you want_forest) can be one of four:

=over 4

=item rsync

This will use the B<rsync> program to sync up with the repository.
F<configsmoke.pl> checks to see if it can find B<rsync> in your path.

The default switches passed to B<rsync> are: S<< B<-az --delete> >>

=item snapshot

This will use B<Net::FTP> to try to find the latest snapshot on
<ftp://ftp.funet.fi/languages/perl/snap/>. 

You can also get the perl-5.8.x snapshots (and others) from via HTTP
if you have B<LWP> installed. There are two things you should remember:
1) start the server-name B<http://> 2) the snapshot-file must be
specified.

Snapshots are not in sync with the repository, so if you have a working
B<patch> program, you can choose to "upgrade" your snapshot by fetching 
all the seperate patches from the repository and applying them.

=item copy

This will use B<File::Copy> and B<File::Find> to just copy from a
local source directory.

=item hardlink

This will use B<File::Find> and the B<link> function to copy from a 
local source directory. (This is also used if you choose "forest".)

=back

See also L<Test::Smoke::Syncer>

=cut

$arg = $want_forest ? 'fsync' : 'sync_type';
$config{ $arg } = lc prompt( $arg );

SYNCER: {
    local $_ = $config{ $arg};
    /^rsync$/ && do {
        $arg = 'source';
        $config{ $arg } = prompt( $arg );

        $arg = 'rsync';
        $config{ $arg } = prompt( $arg );

        $arg = 'opts';
        $config{ $arg } = prompt( $arg );

        last SYNCER;
    };

    /^snapshot$/ && do {
        for $arg ( qw( server sdir sfile ) ) {
            if ( $arg ne 'server' && $config{server} =~ m|^https?://|i ) {
                $opt{ $arg }->{msg} =~ s/\bFTPed/HTTPed/;
                $opt{ $arg }->{msg} =~ s/^\tLeave.+\n//m;
            }
            $config{ $arg } = prompt( $arg );
        }
        unless ( $config{sfile} ) {
            $arg = ' snapext';
            $config{ $arg } = prompt( $arg );
        }
        $arg = 'tar';
        $config{ $arg } = prompt( $arg );

        $arg = 'patchup';
        if ( whereis( 'patch' ) ) {
            $config{ $arg } = lc prompt( $arg ) eq 'y' ? 1 : 0;

            if ( $config{ $arg } ) {
                for $arg (qw( pserver pdir unzip patch )) {
                    $config{ $arg } = prompt( $arg );
                }
                $opt{cleanup}->{msg} .= " 2(patches) 3(both)";
                $opt{cleanup}->{alt}  = [0, 1, 2, 3];
            }
	} else {
	    $config{ $arg } = 0;
        }
        $arg = 'cleanup';
        $config{ $arg } = prompt( $arg );

        last SYNCER;
    };

    /^copy$/ && do {
        $arg = 'cdir';
        $config{ $arg } = prompt( $arg );

        last SYNCER;
    };

    /^hardlink$/ && do {
        $arg = 'hdir';
        $config{ $arg } = prompt_dir( $arg );

        last SYNCER;
    };
}

=item pfile

C<pfile> is the path to a textfile that holds the names of patches to
be applied before smoking. This can be used to run a smoke test on proposed
patches that have not been applied (yet) or to see the effect of
reversing an already applied patch. The file format is simple:

  * one patchfile per line
  * optionally followed by ';' and options to pass to patch

If the file does not exist yet, a skeleton version will be created
for you.

You will need a working B<patch> program to use this feature.

B<TODO>:
There is an issue when using the "forest" sync, but I will look into that.

=cut

# Is it just my NetBSD-1.5 box with an old patch?
my $patchbin = whereis( 'gpatch' ) || whereis( 'patch' );
PATCHER: {
    last PATCHER unless $patchbin;
    $config{patch} = $patchbin;
    print "\nFound [$config{patch}]";
    $arg = 'pfile';
    $config{ $arg } = prompt_file( $arg, 1 );

    if ( $config{ $arg } ) {
        $config{patch_type}  = 'multi';
        last PATCHER if -f $config{ $arg };
        local *PATCHES;
        open PATCHES, "> $config{$arg}" or last PATCHER;
        print PATCHES <<EOMSG;
# Put one filename of a patch on a line, optional args for patch
# follow the filename separated by a semi-colon (;) [-p1] is default
# /path/to/patchfile.patch;-p0 -R
# Empty lines and lines starting with '#' are ignored
# File paths are relative to '$config{ddir}' if not absolute
EOMSG
        close PATCHES or last PATCHER;
        print "Created skeleton '$config{$arg}'\n";
    }
}

=item force_c_locale

C<force_c_locale> is passed as a switch to F<mktest.pl> to indicate that
C<$ENV{LC_ALL}> should be forced to "C" during B<make test>.

=cut

unless ( $config{is56x} ) {
    $arg = 'force_c_locale';
    $config{ $arg } = prompt_yn( $arg );
}

=item locale

C<locale> and its value are passed to F<mktest.pl> and its value is passed
to F<mkovz.pl>. F<mktest.pl> will do an extra pass of B<make test> with 
C<< $ENV{LC_ALL} >> set to that locale (and C<< $ENV{PERL_UNICODE} = ""; >>,
C<< $ENV{PERLIO} = "perlio"; >>). This feature should only be used with
UTF8 locales, that is why this is checked (by regex only).

B<If you know of a way to get the utf8 locales on your system, which is
not coverd here, please let me know!>

=cut

UTF8_LOCALE: {
    my @locale_utf8 = $config{is56x} ? () : check_locale();
    last UTF8_LOCALE unless @locale_utf8;

    my $list = join " |", @locale_utf8;
    format STDOUT =
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~~
$list
.
    local $: = "|";
    $arg = 'locale';
    print "\nI found these UTF-8 locales:\n";
    write;
    $config{ $arg } = prompt( $arg );
}

=item mail

C<{mail}> will set the new default for L<smokeperl.pl>

=item mail_type

See L<Test::Smoke::Mailer> and L<mailrpt.pl>

=cut

$arg = 'mail';
$config{ $arg } = prompt_yn( $arg );
MAIL: {
    last MAIL unless $config{mail};
    $arg = 'mail_type';
    $config{ $arg } = prompt( $arg );

    $arg = 'to';
    while ( !$config{ $arg } ) { $config{ $arg } = prompt( $arg ) }

    MAILER: {
        local $_ = $config{ 'mail_type' };

        /^mailx?$/         && do { last MAILER };
        /^sendmail$/       && do {
            $arg = 'from';
            $config{ $arg } = prompt( $arg );
	};

        /^(?:Mail::Sendmail|MIME::Lite)$/ && do {
            $arg = 'from';
            $config{ $arg } = prompt( $arg );

            $arg = 'mserver';
            $config{ $arg } = prompt( $arg );
        };
    }
    $arg = 'cc';
    $config{ $arg } = prompt( $arg );
}

=item w32args

For MSWin32 we need some extra information that is passed to
F<mktest.pl> in order to compensate for the lack of B<Configure>.

See L<Test::Smoke::Util/"Configure_win32( )"> and L<W32Configure.pl>

=cut

WIN32: {
    last WIN32 unless is_win32;

    my $osvers = get_Win_version();
    my %compilers = get_avail_w32compilers();

    my $dft_compiler = $conf->{w32cc} ? $conf->{w32cc} : "";
    $dft_compiler ||= ( sort keys %compilers )[-1];
    $opt{w32cc} = {
        msg => 'What compiler should be used?',
        alt => [ keys %compilers ],
        dft => $dft_compiler,
    };

    print <<EO_MSG;

I see you are on $^O ($osvers).
No problem, but we need extra information.
EO_MSG

    $config{w32cc} = uc prompt( 'w32cc' );

    $opt{w32make} = {
        alt => $compilers{ $config{w32cc} }->{maker},
        dft => ( sort @{ $compilers{ $config{w32cc} }->{maker} } )[-1],
    };
    $opt{w32make}->{msg} = @{ $compilers{ $config{w32cc} }->{maker} } > 1 
        ? "Which make should be used" : undef;

    $config{w32make} = prompt( 'w32make' );

    $config{w32args} = [ 
        "--win32-cctype" => $config{w32cc},
        "--win32-maker"  => $config{w32make},
        "osvers=$osvers", 
        $compilers{ $config{w32cc} }->{ccversarg},
    ];
}

=item umask

C<umask> will be set in the shell-script that starts the smoke.

=item renice

C<renice> will add a line in the shell-script that starts the smoke.

=cut

unless ( is_win32 ) {
    $arg = 'umask';
    $config{ $arg } = prompt( $arg );

    $arg = 'renice';
    $config{ $arg } = prompt( $arg );
}

=item v

The verbosity level: 0, 1 or 2

=cut

$arg = 'v';
$config{ $arg } = prompt( $arg );

=item smartsmoke

C<smartsmoke> indicates that the smoke need not happen if the patchlevel
is the same after syncing the source-tree.

=cut

$arg = 'smartsmoke';
$config{ $arg } = prompt_yn( $arg );

=item killtime

When C<< $Config{d_alarm} >> is found we can use C<alarm()> to abort 
long running smokes. Leave this value empty to keep the old behaviour.

    07:30 => F<mktest.pl> is aborted on 7:30 localtime
   +23:45 => F<mktest.pl> is aborted after 23 hours and 45 minutes

Thank you Jarkko for donating this suggestion.

=cut

if ( $Config{d_alarm} ) {
    $arg = 'killtime';
    $config{ $arg } = prompt( $arg );
}

=item schedule stuff

=over 4

=item cron/crontab

We try to detect 'crontab' or 'cron', read the contents of 
B<crontab -l>, detect ourself and comment us out.
Then we add an new entry.

=item MSWin32 at.exe

We only add a new entry, you will need to remove existing entries,
as F<at.exe> has not got a way comment-out entries.

=back

=cut

my( $cron, $has_crond,  $crontime );
SCHEDULE: { 
    ( $cron, $has_crond ) = get_avail_scheduler();

    last SCHEDULE unless $cron;

    print "\nFound '$cron' as your scheduler";
    print "\nYou do not seem to be running 'cron' or 'crond'"
        unless is_win32 || $has_crond;
    my $do_schedule = prompt_yn( 'docron' );
    last SCHEDULE unless $do_schedule;

    $opt{crontime}->{dft} = sprintf "%02d:%02d", rand(24), rand(60);
    $crontime = prompt( 'crontime' );

    my( @current_cron, $new_entry );
    local *CRON;
    if ( open CRON, is_win32 ? "$cron |" : "$cron -l |" ) {
        @current_cron = <CRON>;
        close CRON or warn "Error reading schedule\n";
    }

    my $cron_smoke = "crontab.smoke";
    # we might need some cleaning
    if ( is_win32 ) {
        @current_cron = grep /^\s+\d+\s+.+\d+:\d+\s/ => @current_cron;

        my $jcl = File::Spec->rel2abs( "$options{jcl}.cmd" );
        $new_entry = schedule_entry( $jcl, $cron, $crontime );

    } else { # Filter out the BSDish "DO NOT EDIT..." lines
        if ( "@current_cron" =~ /^# DO NOT EDIT THIS FILE/ ) {
            splice @current_cron, 0, 3;
        }
        foreach ( @current_cron ) {
            s/^(?<!#)(\d+.+(?:$options{jcl}|smoke)\.sh)/#$1/;
	}

        my $jcl = File::Spec->rel2abs( "$options{jcl}.sh" );
        $new_entry = schedule_entry( $jcl, $cron, $crontime );
        if ( open CRON, "> $cron_smoke" ) {
            print CRON @current_cron, "$new_entry\n";
            close CRON or warn "Error while writing '$cron_smoke': $!";
        }

    }

    print "I will use this to add to:\n", @current_cron;
    $opt{add2cron} = {
        msg => "Add this line to your schedule?\n\t$new_entry\n",
        alt => [qw( Y n )],
        dft => 'y',
    };
    my $add2cron = prompt_yn( 'add2cron' );
    if ( !is_win32 && !$add2cron ) {
        print "\nLeft '$cron_smoke' in case you want to use it.\n";
    }
    last SCHEDULE unless $add2cron;

    if ( is_win32 ) {
        system $new_entry;
    } else {
        my $nok = system $cron, $cron_smoke;
        if ( $nok ) {
            print "\nCouldn't set new crontab\nLeft '$cron_smoke'\n";
        } else {
            unlink $cron_smoke;
        }
    }
}

my $jcl;
SAVEALL: {
    save_config();
    if ( is_win32 ) {
        $jcl = write_bat();
    } else {
        $jcl = write_sh();
    }
}

print <<EOMSG;

Run the perl core test smoke suite with:
\t$jcl

Please check "$config{cfg}" 
for the configurations you want to test.

Have the appropriate amount of fun!

                                    The Test::Smoke team.
EOMSG

sub save_config {
    my $dumper = Data::Dumper->new([ \%config ], [ 'conf' ]);
    Data::Dumper->can( 'Sortkeys' ) and 
        $dumper->Sortkeys( \&sort_configkeys );
    local *CONFIG;
    open CONFIG, "> $options{config}" or
        die "Cannot write '$options{config}': $!";
    print CONFIG $dumper->Dump;
    close CONFIG or warn "Error writing '$options{config}': $!" and return;

    print "Finished writing '$options{config}'\n";
}

sub sort_configkeys {
    my @order = qw( perl_version is56x
        cfg ddir sync_type fsync 
        rsync opts source 
        tar server sdir sfile patchup pserver pdir unzip patch cleanup
        cdir hdir
        patch pfile
        force_c_locale locale
        mail mail_type mserver to from cc
        w32args w32cc w32make
        umask renice
        smartsmoke v
        killtime );

    my $i = 0;
    my %keyorder = map { $_ => $i++ } @order;

    my @keyord = sort { 
        $a <=> $b 
    } @keyorder{ grep exists $keyorder{ $_}, keys %{ $_[0] } };

    return [ @order[ @keyord ], 
             sort grep !exists $keyorder{ $_ }, keys %{ $_[0] } ];
}

sub write_sh {
    my $cwd = cwd();
    my $jcl = "$options{jcl}.sh";
    my $cronline = schedule_entry( File::Spec->catfile( $cwd, $jcl ), 
                                   $cron, $crontime );
    local *MYSMOKESH;
    open MYSMOKESH, "> $jcl" or
        die "Cannot write '$jcl': $!";
    print MYSMOKESH <<EO_SH;
#! /bin/sh
#
# Written by $0 v$VERSION
# @{[ scalar localtime ]}
#
# $cronline
@{[ renice( $config{renice} ) ]}
cd $cwd
CFGNAME=$options{config}
LOCKFILE=$options{prefix}.lck
if test -f "\$LOCKFILE" && test -s "\$LOCKFILE" ; then
    echo "We seem to be running (or remove \$LOCKFILE)" >& 2
    exit 200
fi
echo "\$LOCKFILE" > "\$LOCKFILE"

PATH=$cwd:$ENV{PATH}
export PATH
umask $config{umask}
$^X smokeperl.pl -c "\$CFGNAME" \$\* > $options{log} 2>&1

rm "\$LOCKFILE"
EO_SH
    close MYSMOKESH or warn "Error writing '$jcl': $!";

    chmod 0755, $jcl or warn "Cannot chmod 0755 $jcl: $!";
    print "Finished writing '$jcl'\n";

    return File::Spec->canonpath( File::Spec->rel2abs( $jcl ) );
}

sub write_bat {
    my $cwd = File::Spec->canonpath( cwd() );

    my $copycmd = $config{w32args}->[1] ne "BORLAND" ? "" : <<EOCOPYCMD;

REM I found hanging XCOPY while smoking with BORLAND
set COPYCMD=/Y %COPYCMD%

EOCOPYCMD

    my $jcl = "$options{jcl}.cmd";
    my $atline = schedule_entry( File::Spec->catfile( $cwd, $jcl ), 
                                 $cron, $crontime );
    local *MYSMOKEBAT;
    open MYSMOKEBAT, "> $jcl" or
        die "Cannot write '$jcl': $!";
    print MYSMOKEBAT <<EO_BAT;
\@echo off
setlocal

REM Written by $0 v$VERSION
REM @{[ scalar localtime ]}
$copycmd
REM $atline

set WD=$cwd\
rem Change drive-Letter
for \%\%L in ( "\%WD\%" ) do \%\%~dL
cd "\%WD\%"
set CFGNAME=$options{config}
set LOCKFILE=$options{prefix}.lck
if NOT EXIST \%LOCKFILE\% goto START_SMOKE
    FIND "\%LOCKFILE\%" \%LOCKFILE\% > NUL:
    if ERRORLEVEL 1 goto START_SMOKE
    echo We seem to be running [or remove \%LOCKFILE\%]>&2
    goto :EOF

:START_SMOKE
    echo \%LOCKFILE\% > \%LOCKFILE\%
    set OLD_PATH=\%PATH\%
    set PATH=$cwd;\%PATH\%
    $^X smokeperl.pl -c "\%CFGNAME\%" \%* > "\%WD\%\\$options{log}" 2>&1
    set PATH=\%OLD_PATH\%

del \%LOCKFILE\%
EO_BAT
    close MYSMOKEBAT or warn "Error writing '$jcl': $!";

    print "Finished writing '$jcl'\n";

    return File::Spec->canonpath( File::Spec->rel2abs( $jcl ) );
}

sub prompt {
    my( $message, $alt, $df_val, $chk ) = 
        @{ $opt{ $_[0] } }{qw( msg alt dft chk )};

    $df_val = $conf->{ $_[0] } if exists $conf->{ $_[0] };
    unless ( defined $message ) {
        my $retval = defined $df_val ? $df_val : "undef";
        (caller 1)[3] or print "Got [$retval]\n";
        return $df_val;
    }
    $message =~ s/\s+$//;

    my %ok_val;
    %ok_val = map { (lc $_ => 1) } @$alt if @$alt;
    $chk ||= '.*';

    my $default = defined $df_val ? $df_val : 'undef';
    if ( @$alt && defined $df_val ) {
        $default = $df_val = $alt->[0] unless exists $ok_val{ $df_val };
    }
    my $alts    = @$alt ? "<" . join( "|", @$alt ) . "> " : "";
    print "\n$message\n";

    my( $input, $clear );
    INPUT: {
        print "$alts\[$default] \$ ";
        chomp( $input = <STDIN> );
        if ( $input eq " " ) {
            $input = "";
            $clear = 1;
        } else {
            $input =~ s/^\s+//;
            $input =~ s/\s+$//;
            $input = $df_val unless length $input;
        }

        printf "Input does not match $chk\n" and redo INPUT
            unless $input =~ m/$chk/i;

        last INPUT unless %ok_val;
        printf "Expected one of: '%s'\n", join "', '", @$alt and redo INPUT
            unless exists $ok_val{ lc $input };

    }

    my $retval = length $input ? $input : $clear ? "" : $df_val;
    (caller 1)[3] or print "Got [$retval]\n";
    return $retval;
}

sub prompt_dir {

    if ( exists $conf->{ $_[0] } )  {
        $conf->{ $_[0] } = File::Spec->rel2abs( $conf->{ $_[0] } )
            unless File::Spec->file_name_is_absolute( $conf->{ $_[0] } );
    }

    GETDIR: {
    

        my $dir = prompt( @_ );

        # thanks to perlfaq5
        $dir =~ s{^ ~ ([^/]*)}
                 {$1 ? ( getpwnam $1 )[7] : 
                       ( $ENV{HOME} || $ENV{LOGDIR} || 
                         "$ENV{HOMEDRIVE}$ENV{HOMEPATH}" )}ex;

        my $cwd = cwd();
        File::Path::mkpath( $dir, 1, 0755 ) unless -d $dir;
        chdir $dir or warn "Cannot chdir($dir): $!\n" and redo GETDIR;
        $dir = File::Spec->canonpath( cwd() );
        chdir $cwd or die "Cannot chdir($cwd) back: $!";

        print "Got [$dir]\n";
        return $dir;
    }
}

sub prompt_file {
    my( $arg, $no_valid ) = @_;

    GETFILE: {
        my $file = prompt( $arg );


        # thaks to perlfaq5
        $file =~ s{^ ~ ([^/]*)}
                  {$1 ? ( getpwnam $1 )[7] : 
                   ( $ENV{HOME} || $ENV{LOGDIR} ||
                   "$ENV{HOMEDRIVE}$ENV{HOMEPATH}" )}ex;
        $file = File::Spec->rel2abs( $file ) unless !$file && $no_valid;

        print "'$file' does not exist: $!\n" and redo GETFILE
	    unless -f $file || $no_valid;

        printf "Got[%s]\n", defined $file ? $file : 'undef';
        return $file;
    }
}

sub prompt_yn {
    my( $arg ) = @_;

    $opt{ $arg }{dft} ||= "0";
    $opt{ $arg }{dft} =~ tr/01/ny/;
    if ( exists $conf->{ $arg } ) {
        $conf->{ $arg } ||= "0";
        $conf->{ $arg } =~ tr/01/ny/;
    }

    my $yesno = lc prompt( $arg );
    print "Got [$yesno]\n";
    ( my $retval = $yesno ) =~ tr/ny/01/;
    return $retval;
}

sub whereis {
    my( $prog, $find_all ) = @_;
    return '' unless $prog; # you shouldn't call it '0'!

    my $p_sep = $Config::Config{path_sep};
    my @path = split /\Q$p_sep\E/, $ENV{PATH};
    my @pext = split /\Q$p_sep\E/, $ENV{PATHEXT} || '';
    unshift @pext, '';

    my @fnames;
    foreach my $dir ( @path ) {
        foreach my $ext ( @pext ) {
            my $fname = File::Spec->catfile( $dir, "$prog$ext" );
            if ( -x $fname ) {
                return $fname unless $find_all;
                push @fnames, $fname;
            }
        }
    }
    return @fnames ? wantarray ? @fnames : \@fnames : '';
}

sub renice {
    my $rn_val = shift;

    return $rn_val ? <<EORENICE : <<EOCOMMENT
# Run renice:
(renice -n $rn_val \$\$ >/dev/null 2>&1) || (renice $rn_val \$\$ >/dev/null 2>&1)
EORENICE
# Uncomment this to be as nice as possible. (Jarkko)
# (renice -n 20 \$\$ >/dev/null 2>&1) || (renice 20 \$\$ >/dev/null 2>&1)
EOCOMMENT

}

sub get_avail_sync {

    my @synctype = qw( copy hardlink );
    eval { local $^W; require Net::FTP };
    my $has_ftp = !$@;

    eval { local $^W; require LWP::Simple };
    my $has_lwp = !$@;

    my $pversion = $config{perl_version} || '5.9.x';

    # (has_ftp && 5.9.x) || (has_lwp && !5.6.x)
    unshift @synctype, 'snapshot' 
        if ( $has_ftp && $pversion eq '5.9.x' ) ||
           ( $has_lwp && $pversion ne '5.6.x' );
    unshift @synctype, 'rsync' if whereis( 'rsync' );
    return @synctype;
}

sub get_avail_tar {

    my $use_modules = 0;
    eval { require Archive::Tar };
    unless ( $@ ) {
        eval { require Compress::Zlib };
        $use_modules = !$@;
    }

    my $fmt = tar_fmt();

    return $fmt && $use_modules 
        ? ( $fmt, 'Archive::Tar' )
        : $fmt ? ( $fmt ) : $use_modules ? ( 'Archive::Tar' ) : ();
    
}

sub tar_fmt {
    my $tar  = whereis( 'tar' );
    my $gzip = whereis( 'gzip' );

    return $tar && $gzip 
        ? "$gzip -cd %s | $tar -xf -"
        : $tar ? "tar -xzf %s" : "";
}

sub check_locale {
    # I only know one way...
    my $locale = whereis( 'locale' );
    return unless $locale;
    return grep /utf-?8$/i => split /\n/, `$locale -a`;
}

sub get_avail_scheduler {
    my( $scheduler, $crond );
    if ( is_win32 ) { # We're looking for 'at.exe'
        $scheduler = whereis( 'at' );
    } else { # We're looking for 'crontab' or 'cron'
        $scheduler = whereis( 'crontab' ) || whereis( 'cron' );
        ( $crond ) = grep /\bcrond?\b/ => `ps -e`;
    }
    return ( $scheduler, $crond );
}

sub schedule_entry {
    my( $script, $cron, $crontime ) = @_;

    return '' unless $crontime;
    my( $hour, $min ) = $crontime =~ /(\d+):(\d+)/;

    my $entry;
    if ( is_win32 ) {
        $entry = sprintf qq[$cron %02d:%02d /EVERY:M,T,W,Th,F,S,Su "%s"],
                 $hour, $min, $script;
    } else {
        $entry = sprintf qq[%02d %02d * * * '%s'], $min, $hour, $script;
    }
    return $entry;
}

sub get_avail_mailers {
    my %map;
    my $mailer = 'mail';
    $map{ $mailer } = whereis( $mailer );
    $mailer = 'mailx';
    $map{ $mailer } = whereis( $mailer );
    {
        $mailer = 'sendmail';
        local $ENV{PATH} = "$ENV{PATH}$Config{path_sep}/usr/sbin";
        $map{ $mailer } = whereis( $mailer );
    }

    eval { require Mail::Sendmail };
    $map{ 'Mail::Sendmail' } = $@ ? '' : 'Mail::Sendmail';

    eval { require MIME::Lite };
    $map{ 'MIME::Lite' } = $@ ? '' : 'MIME::Lite';

    return map { ( $_ => $map{ $_ }) } grep length $map{ $_ } => keys %map;
}
        
sub get_avail_w32compilers {

    my %map = (
        MSVC => { ccname => 'cl',    maker => [ 'nmake' ] },
        BCC  => { ccname => 'bcc32', maker => [ 'dmake' ] },
        GCC  => { ccname => 'gcc',   maker => [ 'dmake' ] },
    );

    my $CC = 'MSVC';
    if ( $map{ $CC }->{ccbin} = whereis( $map{ $CC }->{ccname} ) ) {
        # No, cl doesn't support --version (One can but try)
        my $output =`"$map{ $CC }->{ccbin}" --version 2>&1`;
        my $ccvers = $output =~ /^.*Version\s+([\d.]+)/ ? $1 : '?';
        $map{ $CC }->{ccversarg} = "ccversion=$ccvers";
        my $mainvers = $ccvers =~ /^(\d+)/ ? $1 : 1;
        $map{ $CC }->{CCTYPE} = $mainvers < 12 ? 'MSVC' : 'MSVC60';
    }

    $CC = 'BCC';
    if ( $map{ $CC }->{ccbin} = whereis( $map{ $CC }->{ccname} ) ) {
        # No, bcc32 doesn't support --version (One can but try)
        my $output = `"$map{ $CC }->{ccbin}" --version 2>&1`;
        my $ccvers = $output =~ /(\d+.*)/ ? $1 : '?';
        $ccvers =~ s/\s+copyright.*//i;
        $map{ $CC }->{ccversarg} = "ccversion=$ccvers";
        $map{ $CC }->{CCTYPE} = 'BORLAND';
    }

    $CC = 'GCC';
    if ( $map{ $CC }->{ccbin} = whereis( $map{ $CC }->{ccname} ) ) {
        local *STDERR;
        open STDERR, ">&STDOUT"; #do we need an error?
        select( (select( STDERR ), $|++ )[0] );
        my $output = `"$map{ $CC }->{ccbin}" --version`;
        my $ccvers = $output =~ /(\d+.*)/ ? $1 : '?';
        $ccvers =~ s/\s+copyright.*//i;
        $map{ $CC }->{ccversarg} = "gccversion=$ccvers";
        $map{ $CC }->{CCTYPE} = $CC
    }

    return map {
       ( $map{ $_ }->{CCTYPE} => $map{ $_ } )
    } grep length $map{ $_ }->{ccbin} => keys %map;
}

sub get_Win_version {
    my @osversion = Win32::GetOSVersion();

    my $win_version = join '.', @osversion[ 1, 2 ];
    $win_version .= " $osversion[0]" if $osversion[0];

    return $win_version;
}

=item check_buildcfg

We will try to check the build configurations file to see if we should
comment some options out.

=cut

sub check_buildcfg {
    my( $file_name ) = @_;

    local *BCFG;
    open BCFG, "< $file_name" or do {
        warn "Cannot read '$file_name': $!\n" .
             "Will not check the build configuration file!";
        return;
    };
    my @bcfg = <BCFG>;
    close BCFG;
    my $oldcfg = join "", grep !/^#/ => @bcfg;

    my @no_option = ( );
    OSCHECK: {
        local $_ = $^O;
        /darwin|bsd/i && do { 
            # No -Duselongdouble, -Dusemorebits, -Duse64bitall
            @no_option = qw( -Duselongdouble -Dusemorebits -Duse64bitall );
        };

	/linux/i && do {
            # No -Duse64bitall
            @no_option = qw( -Duse64bitall );
        };
        foreach my $option ( @no_option ) {
            !/^#/ && /\Q$option\E/ && s/^/#/ for @bcfg;
        }
    }
    my $newcfg = join "", grep !/^#/ => @bcfg;
    return if $oldcfg eq $newcfg;

    my $options = join "|", map "\Q$_\E" => sort {
        lenght( $b||"" ) <=> length( $a||"" )
    } @no_option;

    my $display = join "", map "\t$_" 
        => grep !/^#/ || ( /^#/ && /$options/ ) => @bcfg;
    $opt{change_cfg}->{msg} = <<EOMSG;
Some options that do not apply to your platform were found.
(Comment-lines left out below, but will be written to disk.)
$display
Write the changed config to disk?
EOMSG

    my $write_it = prompt_yn( 'change_cfg' );
    finish_cfgcheck( $write_it, $file_name, \@bcfg);
}

=item finish_cfgcheck


=cut

sub finish_cfgcheck {
    my( $overwrite, $fname, $bcfg ) = @_;

    if ( $overwrite ) {
        my $backup = "$fname.bak";
        -f $backup and chmod( 0775, $backup ) and unlink $backup;
        rename $fname, $backup or 
            warn "Cannot rename '$fname' to '$backup': $!";
    } else {
        $fname = "$options{prefix}.cfg";
    }
    # change the filemode (make install makes perlcurrent.cfg readonly)
    -f $fname and chmod 0775, $fname;
    open BCFG, "> $fname" or do {
        warn "Cannot write '$fname': $!";
        return;
    };
    print BCFG @$bcfg;
    close BCFG or do {
        warn "Error on close '$fname': $!";
        return;
    };
    print "Wrote '$fname'\n";
}

=back

=head1 TODO

Schedule, logfile optional

=head1 REVISION

In case I forget to update the C<$VERSION>:

    $Id$

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * L<http://www.perl.com/perl/misc/Artistic.html>

=item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
