package Test::Smoke::Syncer;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.018';

use Config;
use Cwd;
use File::Spec;
require File::Path;

my %CONFIG = (
    df_sync     => 'rsync',
    df_ddir     => File::Spec->rel2abs( 'perl-current', File::Spec->curdir ),
    df_v        => 0,

# these settings have to do synctype==rsync
    df_rsync    => 'rsync', # you might want a path there
    df_opts     => '-az --delete',
    df_source   => 'public.activestate.com::perl-current',

    rsync       => [qw( rsync source opts )],

# these settings have to do with synctype==snapshot
    df_ftp      => 'Net::FTP',
    df_server   => 'public.activestate.com',
    df_sdir     => '/pub/apc/perl-current-snap',
    df_sfile    => '',
    df_snapext  => 'tar.gz',

    df_tar      => ( $^O eq 'MSWin32' ?
        'Archive::Tar' : 'gzip -d -c %s | tar xf -' ),

    df_patchup  => 0,
    df_pserver  => 'public.activestate.com',
    df_pdir     => '/pub/apc/perl-current-diffs',
    df_ftpusr   => 'anonymous',
    df_ftppwd   => 'smokers@perl.org',
    df_unzip    => $^O eq 'MSWin32' ? 'Compress::Zlib' : 'gzip -dc',
    df_patchbin => 'patch',
    df_cleanup  => 1,
    snapshot    => [qw( ftp server sdir sfile snapext tar ftpusr ftppwd
                       patchup pserver pdir unzip patchbin cleanup )],

# these settings have to do with synctype==copy
    df_cdir    => undef,

    copy       => [qw( cdir )],

# these settings have to do with synctype==hardlink
    df_hdir    => undef,
    df_haslink => ($Config{d_link}||'') eq 'define',

    hardlink   => [qw( hdir haslink )],

# these have to do 'forest'
    df_fsync   => 'rsync',
    df_mdir    => undef,
    df_fdir    => undef,

    forest     => [qw( fsync mdir fdir )],

# these settings have to do with synctype==ftp
    df_ftphost => 'public.activestate.com',
    df_ftpsdir => '/pub/apc/perl-current',
    df_ftpcdir => '/pub/apc/perl-current-diffs',

    ftp        => [qw( ftphost ftpusr ftppwd ftpsdir ftpcdir )],

# misc.
    valid_type => { rsync => 1, snapshot => 1,
                    copy  => 1, hardlink => 1, ftp => 1 },
);

{
    my %allkeys = map { ($_ => 1) } 
        map @{ $CONFIG{ $_ } } => keys %{ $CONFIG{valid_type} };
    push @{ $CONFIG{forest} }, keys %allkeys;
    $CONFIG{valid_type}->{forest} = 1;
}

=head1 NAME

Test::Smoke::Syncer - OO interface for syncing the perl source-tree

=head1 SYNOPSIS

    use Test::Smoke::Syncer;

    my $type = 'rsync'; # or 'snapshot' or 'copy'
    my $syncer = Test::Smoke::Syncer->new( $type => %sync_config );
    my $patch_level = $syncer->sync;

=head1 DESCRIPTION

At this moment we support three basic types of syncing the perl source-tree.

=over 4

=item rsync

This method uses the B<rsync> program with the C<< --delete >> option 
to get your perl source-tree up to date.

=item snapshot

This method uses the B<Net::FTP> or the B<LWP> module to get the 
latest snapshot. When the B<server> attribute starts with I<http://>
the fetching is done by C<LWP::Simple::mirror()>.
To emulate the C<< rsync --delete >> effect, the current source-tree
is removed.

The snapshot tarball is handled by either B<tar>/B<gzip> or 
B<Archive::Tar>/B<Compress::Zlib>.

=item copy

This method uses the B<File::Copy> module to copy an existing source-tree
from somewhere on the system (in case rsync doesn't work), this also 
removes the current source-tree first.

=item forest

This method will sync the source-tree in one of the above basic methods.
After that, it will create an intermediate copy of the master directory 
as hardlinks and run the F<regen_headers.pl> script. This should yield
an up-to-date source-tree. The intermadite directory is now copied as 
hardlinks to its final directory ({ddir}).

This can be used to change the way B<make distclean> is run from 
F<mktest.pl> (removes all files that are not in the intermediate
directory, which may prove faster than traditional B<make distclean>).

=back

=head1 METHODS

=over 4

=cut

=item Test::Smoke::Syncer->new( $type, %sync_config )

[ Constructor | Public ]

Initialise a new object and check all relevant arguments.
It returns an object of the appropriate B<Test::Smoke::Syncer::*> class.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my $sync_type = lc shift || $CONFIG{df_sync};

    unless ( exists $CONFIG{valid_type}->{$sync_type} ) {
        require Carp;
        Carp::croak "Invalid sync_type '$sync_type'";
    };

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } ( v => ddir => @{ $CONFIG{ $sync_type } } );
    if ( ! File::Spec->file_name_is_absolute( $fields{ddir} ) ) {
        $fields{ddir} = File::Spec->catdir( cwd(), $fields{ddir} );
    }
    $fields{ddir} = File::Spec->rel2abs( $fields{ddir} );

    DO_NEW: {
        local *_; $_ = $sync_type;

        /^rsync$/    && return Test::Smoke::Syncer::Rsync->new( %fields );
        /^snapshot$/ && return Test::Smoke::Syncer::Snapshot->new( %fields );
        /^copy$/     && return Test::Smoke::Syncer::Copy->new( %fields );
        /^hardlink$/ && return Test::Smoke::Syncer::Hardlink->new( %fields );
        /^ftp$/      && return Test::Smoke::Syncer::FTP->new( %fields );
        /^forest$/   && return Test::Smoke::Syncer::Forest->new( %fields );

        require Carp;
        Carp::croak "Synctype '$_', not yet implemented.";
    }

}

=item Test::Smoke::Syncer->config( $key[, $value] )

[ Accessor | Public ]

C<config()> is an interface to the package lexical C<%CONFIG>, 
which holds all the default values for the C<new()> arguments.

With the special key B<all_defaults> this returns a reference
to a hash holding all the default values.

=cut

sub config {
    my $dummy = shift;

    my $key = lc shift;

    if ( $key eq 'all_defaults' ) {
        my %default = map {
            my( $pass_key ) = $_ =~ /^df_(.+)/;
            ( $pass_key => $CONFIG{ $_ } );
        } grep /^df_/ => keys %CONFIG;
        return \%default;
    }

    return undef unless exists $CONFIG{ "df_$key" };

    $CONFIG{ "df_$key" } = shift if @_;

    return $CONFIG{ "df_$key" };
}

=item $syncer->_clear_souce_tree( [$tree_dir] )

[ Method | private-ish ]

C<_clear_source_tree()> removes B<all> files in the source-tree 
using B<File::Path::rmtree()>. (See L<File::Path> for caveats.)

If C<$tree_dir> is not specified, C<< $self->{ddir} >> is used.

=cut

sub _clear_source_tree {
    my( $self, $tree_dir ) = @_;

    $tree_dir ||= $self->{ddir};

    $self->{v} and print "Clear source-tree from '$tree_dir' ";
    my $cnt = File::Path::rmtree( $tree_dir, $self->{v} > 1 );

    File::Path::mkpath( $tree_dir, $self->{v} > 1 ) unless -d $tree_dir;
    $self->{v} and print "$cnt items OK\n";

}

=item $syncer->_relocate_tree( $source_dir )

[ Method | Private-ish ]

C<_relocate_tree()> uses B<File::Copy::move()> to move the source-tree 
from C<< $source_dir >> to its destination (C<< $self->{ddir} >>).

=cut

sub _relocate_tree {
    my( $self, $source_dir ) = @_;

    require File::Copy;

    $self->{v} and print "relocate source-tree ";

    # try to move it at once (sort of a rename)
    my $ok = $source_dir eq $self->{ddir}
           ? 1 : File::Copy::move( $source_dir, $self->{ddir} );

    # Failing that: Copy-By-File :-(
    if ( ! $ok && -d $source_dir ) {
        my $cwd = cwd();
        chdir $source_dir or do {
            print "Cannot chdir($source_dir): $!\n";
            return 0;
        };
        require File::Find;
	File::Find::finddepth( sub {

            my $dest = File::Spec->canonpath( $File::Find::name );
            $dest =~ s/^\Q$source_dir//;
            $dest = File::Spec->catfile( $self->{ddir}, $dest );

            $self->{v} > 1 and print "move $_ $dest\n";
	    File::Copy::move( $_, $dest );
        }, "./" );
        chdir $cwd or print "Cannot chdir($cwd) back: $!\n";
	File::Path::rmtree( $source_dir, $self->{v} > 1 );
        $ok = ! -d $source_dir;
    }
    die "Can't move '$source_dir' to $self->{ddir}'" unless $ok;
    $self->{v} and print "OK\n";
}

=item $syncer->check_dot_patch( )

[ Method | Public ]

C<check_dot_patch()> checks if there is a '.patch' file in the source-tree.
It will try to create one if it is not there (this is the case for snapshots).

It returns the patchlevel found or C<undef>.

=cut

sub check_dot_patch {
    my $self = shift;

    my $dot_patch = File::Spec->catfile( $self->{ddir}, '.patch' );

    local *DOTPATCH;
    my $patch_level = '?????';
    if ( open DOTPATCH, "< $dot_patch" ) {
        chomp( $patch_level = <DOTPATCH> );
        close DOTPATCH;
        $patch_level =~ tr/0-9//cd;
        $self->{patchlevel} = $1 if $patch_level =~/^([0-9]+)$/;
        $self->{patchlevel} and return $self->{patchlevel};
    }

    # There does not seem to be a '.patch', try 'patchlevel.h'
    local *PATCHLEVEL_H;
    my $patchlevel_h = File::Spec->catfile( $self->{ddir}, 'patchlevel.h' );
    if ( open PATCHLEVEL_H, "< $patchlevel_h" ) {
        my $declaration_seen = 0;
        while ( <PATCHLEVEL_H> ) {
            $declaration_seen ||= /local_patches\[\]/;
            $declaration_seen && /^\s+,"(?:DEVEL|MAINT)(\d+)|(RC\d+)"/ or next;
            $patch_level = $1 || $2 || '?????';
            if ( $patch_level =~ /^RC/ ) {
                $patch_level = $self->version_from_patchlevel_h .
                               "-$patch_level";
            } else {
                $patch_level++;
            }
        }
        # save 'patchlevel.h' mtime, so you can set it on '.patch'
        my $mtime = ( stat PATCHLEVEL_H )[9];
        close PATCHLEVEL_H;
        # Now create '.patch' and return if $patch_level
        # The patchlevel is off by one in snapshots
        if ( $patch_level && $patch_level !~ /-RC\d+$/ ) {
            if ( open DOTPATCH, "> $dot_patch" ) {
                print DOTPATCH "$patch_level\n";
                close DOTPATCH; # no use generating the error
                utime $mtime, $mtime, $dot_patch;
            }
            $self->{patchlevel} = $patch_level;
            return $self->{patchlevel};
        } else {
            $self->{patchlevel} = $patch_level;
            return $self->{patchlevel}
        }
    }
    return undef;
}

=item version_from_patchlevel_h( $ddir )

C<version_from_patchlevel_h()> returns a "dotted" version as derived 
from the F<patchlevel.h> file in the distribution.

=cut

sub version_from_patchlevel_h {
    my $self = shift;

    require Test::Smoke::Util;
    return Test::Smoke::Util::version_from_patchelevel( $self->{ddir} );
}
 
=item $syncer->clean_from_directory( $source_dir[, @leave_these] )

C<clean_from_directory()> uses File::Find to get the contents of
C<$source_dir> and compare these to {ddir} and remove all other files.

The contents of @leave_these should be in "MANIFEST-format"
(See L<Test::Smoke::SourceTree>).

=cut

sub clean_from_directory {
    my $self = shift;
    my $source_dir = File::Spec->rel2abs( shift );

    require Test::Smoke::SourceTree;
    my $tree = Test::Smoke::SourceTree->new( $source_dir );

    my @leave_these = @_ ? @_ : ();
    my %orig_dir = map { ( $_ => 1) } @leave_these;
    File::Find::find( sub {
        return unless -f;
        my $file = $tree->abs2mani( $File::Find::name );
        $orig_dir{ $file } = 1;
    }, $source_dir );

    $tree = Test::Smoke::SourceTree->new( $self->{ddir} );
    File::Find::find( sub {
        return unless -f;
        my $file = $tree->abs2mani( $File::Find::name );
        return if exists $orig_dir{ $file };
        $self->{v} > 1 and print "Unlink '$file'";
        1 while unlink $_;
        $self->{v} > 1 and print -e $_ ? ": $!\n" : "\n";
    }, $self->{ddir} );
}

=item $syncer->pre_sync

C<pre_sync()> should be called by the C<sync()> methos to setup the
sync environment. Currently only useful on I<OpenVMS>.

=cut

sub pre_sync {
    return 1 unless $^O eq 'VMS';
    my $self = shift;
    require Test::Smoke::Util;

    Test::Smoke::Util::set_vms_rooted_logical( TSP5SRC => $self->{ddir} );
    $self->{vms_ddir} = $self->{ddir};
    $self->{ddir} = 'TSP5SRC:[000000]';
}

# Set skeleton-sub
sub sync { 
    require Carp; 
    Carp::croak ref( $_[0] ) . "->sync() not yet implemented.";
}

=item $syncer->post_sync

C<post_sync()> should be called by the C<sync()> methos to unset the
sync environment. Currently only useful on I<OpenVMS>.

=cut

sub post_sync {
    return 1 unless $^O eq 'VMS';
    my $self = shift;

    ( my $logical = $self->{ddir} || '' ) =~ s/:\[000000\]$//;
    return unless $logical;
    my $result = system "DEASSIGN/JOB $logical";

    $self->{ddir} = delete $self->{vms_ddir};
    return $result == 0;
}

1;

=back

=head1 Test::Smoke::Syncer::Rsync

This handles syncing with the B<rsync> program. 
It should only be visible from the "parent-package" so no direct 
user-calls on this.

=over 4

=cut

package Test::Smoke::Syncer::Rsync;

@Test::Smoke::Syncer::Rsync::ISA = qw( Test::Smoke::Syncer );

=item Test::Smoke::Syncer::Rsync->new( %args )

This crates the new object. Keys for C<%args>:

  * ddir:   destination directory ( ./perl-current )
  * source: the rsync source ( ftp.linux.activestate.com::perl-current )
  * opts:   the options for rsync ( -az --delete )
  * rsync:  the full path to the rsync program ( rsync )
  * v:      verbose

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    return bless { @_ }, $class;
}

=item $object->sync( )

Do the actual sync using a call to the B<rsync> program.

B<rsync> can also be used as a smart version of copy. If you 
use a local directory to rsync from, make sure the destination path
ends with a I<path separator>! (This does not seem to work for source
paths mounted via NFS.)

=cut

sub sync {
    my $self = shift;
    $self->pre_sync;

    my $command = join " ", $self->{rsync}, $self->{opts};
    $command .= " -v" if $self->{v};
    my $redir = $self->{v} ? "" : " >" . File::Spec->devnull;

    $command .= " $self->{source} $self->{ddir}$redir";

    $self->{v} > 1 and print "[$command]\n";
    if ( system $command ) {
        my $err = $? >> 8;
        require Carp;
        Carp::carp "Problem during rsync ($err)";
    }

    my $plevel = $self->check_dot_patch;
    $self->post_sync;
    return $plevel;
}

=back

=head1 Test::Smoke::Syncer::Snapshot

This handles syncing from a snapshot with the B<Net::FTP> module. 
It should only be visible from the "parent-package" so no direct 
user-calls on this.

=over 4

=cut

package Test::Smoke::Syncer::Snapshot;

@Test::Smoke::Syncer::Snapshot::ISA = qw( Test::Smoke::Syncer );

use Cwd;
use File::Path;

=item Test::Smoke::Syncer::Snapshot->new( %args )

This crates the new object. Keys for C<%args>:

  * ddir:    destination directory ( ./perl-current )
  * server:  the server to get the snapshot from ( public.activestate.com )
  * sdir:    server directory ( /pub/apc/perl-current-snap )
  * snapext: the extension used for snapdhots ( tgz )
  * tar:     howto untar ( Archive::Tar or 'gzip -d -c %s | tar x -' )
  * v:       verbose

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    return bless { @_ }, $class;
}

=item $syncer->sync( )

Make a connection to the ftp server, change to the {sdir} directory.
Get the list of snapshots (C<< /^perl@\d+\.tgz$/ >>) and determin the 
highest patchlevel. Fetch this file.  Remove the current source-tree
and extract the snapshot.

=cut

sub sync {
    my $self = shift;

    $self->pre_sync;
    # we need to have {ddir} before we can save the snapshot
    -d $self->{ddir} or mkpath( $self->{ddir} );

    $self->{snapshot} = $self->_fetch_snapshot or return undef;

    $self->_clear_source_tree;

    $self->_extract_snapshot;

    $self->patch_a_snapshot if $self->{patchup};

    my $plevel = $self->check_dot_patch;
    $self->post_sync;
    return $plevel;
}

=item $syncer->_fetch_snapshot( )

C<_fetch_snapshot()> checks to see if 
C<< S<< $self->{server} =~ m|^https?://| >> && $self->{sfile} >>.
If so let B<LWP::Simple> do the fetching else do the FTP thing.

=cut

sub _fetch_snapshot {
    my $self = shift;

    return $self->_fetch_snapshot_HTTP if $self->{server} =~ m|^https?://|i;

    require Net::FTP;
    my $ftp = Net::FTP->new($self->{server}, Debug => 0, Passive => 1) or do {
        require Carp;
        Carp::carp "[Net::FTP] Can't open $self->{server}: $@";
        return undef;
    };

    my @login = ( $self->{ftpusr}, $self->{ftppwd} );
    $ftp->login( @login ) or do {
        require Carp;
        Carp::carp "[Net:FTP] Can't login( @login )";
        return undef;
    };

    $self->{v} and print "Connected to $self->{server}\n";
    $ftp->cwd( $self->{sdir} ) or do {
        require Carp;
        Carp::carp "[Net::FTP] Can't chdir '$self->{sdir}'";
        return undef;
    };

    my $snap_name = $self->{sfile} ||
                    __find_snap_name( $ftp, $self->{snapext}, $self->{v} );

    unless ( $snap_name ) {
        require Carp;
        Carp::carp "Couldn't find a snapshot at $self->{server}$self->{sdir}";
        return undef;
    }

    $ftp->binary(); # before you ask for size!
    my $snap_size = $ftp->size( $snap_name );
    my $ddir_var = $self->{vms_ddir} ? 'vms_ddir' : 'ddir';
    my $local_snap = File::Spec->catfile( $self->{ $ddir_var },
                                          File::Spec->updir, $snap_name );
    $local_snap = File::Spec->canonpath( $local_snap );

    if ( -f $local_snap && $snap_size == -s $local_snap ) {
        $self->{v} and print "Skipping download of '$snap_name'\n";
    } else {
        $self->{v} and print "get ftp://$self->{server}$self->{sdir}/" .
                             "$snap_name\n as $local_snap ";
        my $l_file = $ftp->get( $snap_name, $local_snap );
        my $ok = $l_file eq $local_snap && $snap_size == -s $local_snap;
        $ok or printf "Error in get(%s) [%d]\n", $l_file || "", 
                                                 (-s $local_snap);
        $ok && $self->{v} and print "[$snap_size] OK\n";
    }
    $ftp->quit;

    return $local_snap;
}

=item $syncer->_fetch_snapshot_HTTP( )

C<_fetch_snapshot_HTTP()> simply invokes C<< LWP::Simple::mirror() >>.

=cut

sub _fetch_snapshot_HTTP {
    my $self = shift;

    require LWP::Simple;
    my $snap_name = $self->{sfile};

    unless ( $snap_name ) {
        require Carp;
        Carp::carp "No snapshot specified for $self->{server}$self->{sdir}";
        return undef;
    }

    my $local_snap = File::Spec->catfile( $self->{ddir},
                                          File::Spec->updir, $snap_name );
    $local_snap = File::Spec->canonpath( $local_snap );

    my $remote_snap = "$self->{server}$self->{sdir}/$self->{sfile}";

    $self->{v} and print "LWP::Simple::mirror($remote_snap)";
    my $result = LWP::Simple::mirror( $remote_snap, $local_snap );
    if ( LWP::Simple::is_success( $result ) ) {
        $self->{v} and print " OK\n";
        return $local_snap;
    } elsif ( LWP::Simple::is_error( $result ) ) {
        $self->{v} and print " not OK\n";
        return undef;
    } else {
        $self->{v} and print " skipped\n";
        return $local_snap;
    }
}

=item __find_snap_name( $ftp, $snapext[, $verbose] )

[Not a method!]

Get a list with all the B<perl@\d+> files, use an ST to sort these and
return the one with the highes number.

=cut

sub __find_snap_name {
    my( $ftp, $snapext, $verbose ) = @_;
    $snapext ||= 'tgz';
    $verbose ||= 0;
    $verbose > 1 and print "Looking for /$snapext\$/\n";

    my @list = $ftp->ls();

    my $snap_name = ( map $_->[0], sort { $a->[1] <=> $b->[1] } map {
        my( $p_level ) = /^perl[@#_](\d+)/;
        $verbose > 1 and print "Kept: $_ ($p_level)\n";
        [ $_, $p_level ]
    } grep {
    	/^perl[@#_]\d+/ &&
    	/$snapext$/ 
    } map { $verbose > 1 and print "Found snapname: $_\n"; $_ } @list )[-1];

    return $snap_name;
}

=item $syncer->_extract_snapshot( )

C<_extract_snapshot()> checks the B<tar> attribute to find out how to 
extract the snapshot. This could be an external command or the 
B<Archive::Tar>/B<Comperss::Zlib> modules.

=cut

sub _extract_snapshot {
    my $self = shift;

    unless ( $self->{snapshot} && -f $self->{snapshot} ) {
        require Carp;
        Carp::carp "No snapshot to be extracted!";
        return undef;
    }

    my $cwd = cwd();

    # Files in the snapshot are relative to the 'perl/' directory,
    # they may need to be moved and that is not easy when you've
    # extracted them in the target directory! so we go updir()
    my $extract_base = File::Spec->catdir( $self->{ddir},
                                           File::Spec->updir );
    chdir $extract_base or do {
        require Carp;
        Carp::croak "Can't chdir '$extract_base': $!";
    };

    my $snap_base;
    EXTRACT: {
        local $_ = $self->{tar} || 'Archive::Tar';

        /^Archive::Tar$/ && do {
            $snap_base = $self->_extract_with_Archive_Tar;
            last EXTRACT;
        };

        # assume a commandline template for $self->{tar}
        $snap_base = $self->_extract_with_external;
    }

    $self->_relocate_tree( $snap_base );

    chdir $cwd or do {
        require Carp;
        Carp::croak "Can't chdir($extract_base) back: $!";
    };

    if ( $self->{cleanup} & 1 ) {
        1 while unlink $self->{snapshot};
    }
}

=item $syncer->_extract_with_Archive_Tar( )

C<_extract_with_Archive_Tar()> uses the B<Archive::Tar> and
B<Compress::Zlib> modules to extract the snapshot. 
(This tested verry slow on my Linux box!)

=cut

sub _extract_with_Archive_Tar {
    my $self = shift;

    require Archive::Tar;

    my $archive = Archive::Tar->new() or do {
        require Carp;
        Carp::carp "Can't Archive::Tar->new: " . $Archive::Tar::error;
        return undef;
    };

    $self->{v} and printf "Extracting '$self->{snapshot}' (%s) ", cwd();
    $archive->read( $self->{snapshot}, 1 );
    $Archive::Tar::error and do {
        require Carp;
        Carp::carp "Error reading '$self->{snapshot}': ".$Archive::Tar::error;
        return undef;
    };
    my @files = $archive->list_files;
    $archive->extract( @files );
    $self->{v} and printf "%d items OK.\n", scalar @files;

    ( my $prefix = $files[0] ) =~ s|^([^/]+).+$|$1|;
    my $base_dir = File::Spec->canonpath(File::Spec->catdir( cwd(), $prefix ));
    $self->{v} and print "Snapshot prefix: '$base_dir'\n";
    return $base_dir;
}

=item $syncer->_extract_with_external( )

C<_extract_with_external()> uses C<< $self->{tar} >> as a sprintf() 
template to build a command. Yes that might be dangerous!

=cut

sub _extract_with_external {
    my $self = shift;

    my @dirs_pre = __get_directory_names();

    if ( $^O ne 'VMS' ) {
        my $command = sprintf $self->{tar}, $self->{snapshot};
        $command .= " $self->{snapshot}" if $command eq $self->{tar};
    
        $self->{v} and print "$command ";
        if ( system $command ) {
            my $error = $? >> 8;
            require Carp;
            Carp::carp "Error in command: $error";
            return undef;
        };
        $self->{v} and print "OK\n";
    } else {
        __vms_untargz( $self->{tar}, $self->{snapshot}, $self->{v} );
    }

    # Yes another process can also create directories here!
    # Be careful.
    my %dirs_post = map { ($_ => 1) } __get_directory_names();
    exists $dirs_post{ $_ } and delete $dirs_post{ $_ }
        foreach @dirs_pre;
    # I'll pick the first one that has 'perl' in it
    my( $prefix ) = grep /\bperl/ || /perl\b/ => keys %dirs_post;
    $prefix ||= 'perl';

    my $base_dir = File::Spec->canonpath(File::Spec->catdir( cwd(), $prefix ));
    $self->{v} and print "Snapshot prefix: '$base_dir'\n";
    return $base_dir;
}

=item __vms_untargz( $untargz, $tgzfile, $verbose )

Gunzip and extract the archive in C<$tgzfile> using a small DCL script

=cut

sub __vms_untargz {
    my( $cmd, $file, $verbose ) = @_;
    my( $gzip_cmd, $tar_cmd ) = split /\s*\|\s*/, $cmd;
    my $gzip = $gzip_cmd =~ /^(\S+)/ ? $1 : 'GZIP';
    my $tar  = $tar_cmd  =~ /^(\S+)/
        ? $1 : (whereis( 'vmstar' ) || whereis( 'tar' ) );
    my $tar_sw = $verbose ? '-xvf' : '-xf';

    $verbose and print "Writing 'TS-UNTGZ.COM'";
    local *TMPCOM;
    open TMPCOM, "> TS-UNTGZ.COM" or return 0;
    print TMPCOM <<EO_UNTGZ; close TMPCOM or return 0;
\$ define/user sys\$output TS-UNTGZ.TAR
\$ $gzip "-cd" $file
\$ $tar $tar_sw TS-UNTGZ.TAR
\$ delete TS-UNTGZ.TAR;*
EO_UNTGZ
    $verbose and print " OK\n";

    my $ret = system "\@TS-UNTGZ.COM";
#    1 while unlink "TS-UNTGZ.COM";

    return ! $ret;
}

=item $syncer->patch_a_snapshot( $patch_number )

C<patch_a_snapshot()> tries to fetch all the patches between
C<$patch_number> and C<perl-current> and apply them. 
This requires a working B<patch> program.

You should pass this extra information to
C<< Test::Smoke::Syncer::Snapshot->new() >>:

  * patchup:  should we do this? ( 0 )
  * pserver:  which FTP server? ( public.activestate.com )
  * pdir:     directory ( /pub/apc/perl-current-diffs )
  * unzip:    ( gzip ) [ Compress::Zlib ]
  * patchbin: ( patch )
  * cleanup:  remove patches after applied? ( 1 )

=cut

sub patch_a_snapshot {
    my( $self, $patch_number ) = @_;

    $patch_number ||= $self->check_dot_patch;

    my @patches = $self->_get_patches( $patch_number );

    $self->_apply_patches( @patches );

    return $self->check_dot_patch;
}

=item $syncer->_get_patches( [$patch_number] )

C<_get_patches()> sets up the FTP connection and gets all patches 
beyond C<$patch_number>. Remember that patch numbers  do not have to be 
consecutive.

=cut

sub _get_patches {
    my( $self, $patch_number ) = @_;

    my $ftp = Net::FTP->new($self->{pserver}, Debug => 0, Passive => 1) or do {
        require Carp;
        Carp::carp "[Net::FTP] Can't open '$self->{pserver}': $@";
        return undef;
    };

    my @user_info = ( $self->{ftpusr}, $self->{ftppwd} );
    $ftp->login( @user_info ) or do {
        require Carp;
        Carp::carp "[Net::FTP] Can't login( @user_info )" ;
        return undef;
    };

    $ftp->cwd( $self->{pdir} ) or do {
        require Carp;
        Carp::carp "[Net::FTP] Can't cd '$self->{pdir}'";
        return undef;
    };

    $self->{v} and print "Connected to $self->{pserver}\n";
    my @patch_list;

    $ftp->binary;
    foreach my $entry ( $ftp->ls ) {
        next unless $entry =~ /^(\d+)\.gz$/;
        my $patch_num = $1;
        next unless $patch_num > $patch_number;

        my $local_patch = File::Spec->catfile( $self->{ddir},
					       File::Spec->updir, $entry );
        my $patch_size = $ftp->size( $entry );
        my $l_file;
        if ( -f $local_patch && -s $local_patch == $patch_size ) {
            $self->{v} and print "Skip $entry $patch_size\n";
            $l_file = $local_patch;
        } else {
            $self->{v} and print "get $entry ";
            $l_file = $ftp->get( $entry, $local_patch );
            $self->{v} and printf "%d OK\n", -s $local_patch;
        }
        push @patch_list, $local_patch if $l_file;
    }
    $ftp->quit;

    @patch_list = map $_->[0] => sort { $a->[1] <=> $b->[1] } map {
        my( $patch_num ) = /(\d+).gz$/;
        [ $_, $patch_num ];
    } @patch_list;

    return @patch_list;
}

=item $syncer->_apply_patches( @patch_list )

C<_apply_patches()> calls the B<patch> program to apply the patch
and updates B<.patch> accordingly.

C<@patch_list> is a list of filenames of these patches.

Checks the B<unzip> attribute to find out how to unzip the patch and 
uses the B<Test::Smoke::Patcher> module to apply the patch.

=cut

sub _apply_patches {
    my( $self, @patch_list ) = @_;

    my $cwd = cwd();
    chdir $self->{ddir} or do {
        require Carp;
        Carp::croak "Cannot chdir($self->{ddir}): $!";
    };

    require Test::Smoke::Patcher;
    foreach my $file ( @patch_list ) {

        my $patch = $self->_read_patch( $file ) or next;

        my $patcher = Test::Smoke::Patcher->new( single => {
            ddir     => $self->{ddir},
            patchbin => $self->{patchbin},
            pfile    => \$patch,
            v        => $self->{v},
        });
        eval { $patcher->patch };
        if ( $@ ) {
             require Carp;
	     Carp::carp "Error while patching:\n\t$@";
             next;
        }

        $self->_fix_dot_patch( $1 ) if $file =~ /(\d+)\.gz$/;

        if ( $self->{cleanup} & 2 ) {
            1 while unlink $file;
        }
    }
    chdir $cwd or do {
        require Carp;
        Carp::croak "Cannot chdir($cwd) back: $!";
    };
}

=item $syncer->_read_patch( $file )

C<_read_patch()> unzips the patch and returns the contents.

=cut

sub _read_patch {
    my( $self, $file ) = @_;

    return undef unless -f $file;

    my $content;
    if ( $self->{unzip} eq 'Compress::Zlib' ) {
        require Compress::Zlib;
        my $unzip = Compress::Zlib::gzopen( $file, 'rb' ) or do {
            require Carp;
            Carp::carp "Can't open '$file': $Compress::Zlib::gzerrno";
            return undef;
        };

        my $buffer;
        $content .= $buffer while $unzip->gzread( $buffer ) > 0;
 
        unless ( $Compress::Zlib::gzerrno == Compress::Zlib::Z_STREAM_END() ) {
            require Carp;
            Carp::carp "Error reading '$file': $Compress::Zlib::gzerrno" ;
        }

        $unzip->gzclose;
    } else {

        # this calls out for `$self->{unzip} $file`
        # {unzip} could be like 'zcat', 'gunzip -c', 'gzip -dc'

        $content = `$self->{unzip} $file`;
    }

    return $content;
}

=item $syncer->_fix_dot_patch( $new_level );

C<_fix_dot_patch()> updates the B<.patch> file with the new patch level.

=cut

sub _fix_dot_patch {
    my( $self, $new_level ) = @_;

    return $self->check_dot_patch 
        unless defined $new_level && $new_level =~ /^\d+$/;

    my $dot_patch = File::Spec->catfile( $self->{ddir}, '.patch' );

    local *DOTPATCH;
    if ( open DOTPATCH, "> $dot_patch" ) {
        print DOTPATCH "$new_level\n";
        return close DOTPATCH ? $new_level : $self->check_dot_patch;
    }

    return $self->check_dot_patch;
}

=item __get_directory_names( [$dir] )

[This is B<not> a method]

C<__get_directory_names()> retruns all directory names from 
C<< $dir || cwd() >>. It does not look at symlinks (there should 
not be any in the perl source-tree).

=cut

sub __get_directory_names {
    my $dir = shift || cwd();

    local *DIR;
    opendir DIR, $dir or return ();
    my @dirs = grep -d File::Spec->catfile( $dir, $_ ) => readdir DIR;
    closedir DIR;

    return @dirs;
}

=back

=head1 Test::Smoke::Syncer::Copy

This handles syncing with the B<File::Copy> module from a local 
directory. It uses the B<MANIFEST> file is the source directory
to determine which fiels to copy. The current source-tree removed 
before the actual copying.

=over 4

=cut

package Test::Smoke::Syncer::Copy;

@Test::Smoke::Syncer::Copy::ISA = qw( Test::Smoke::Syncer );

=item Test::Smoke::Syncer::Copy->new( %args )

This crates the new object. Keys for C<%args>:

  * ddir:    destination directory ( ./perl-current )
  * cdir:    directory to copy from ( undef )
  * v:       verbose

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    return bless { @_ }, $class;
}

=item $syncer->sync( )

This uses B<Test::Smoke::SourceTree> to do the actual copying.  After
that it will clean up the source-tree (from F<MANIFEST>, but ignoring
F<MANIFEST.SKIP>!).

=cut

sub sync {
    my $self = shift;

    $self->pre_sync;
    require Test::Smoke::SourceTree;

    my $tree = Test::Smoke::SourceTree->new( $self->{cdir} );
    $tree->copy_from_MANIFEST( $self->{ddir}, $self->{v} );

    $tree = Test::Smoke::SourceTree->new( $self->{ddir} );
    $tree->clean_from_MANIFEST( 'MANIFEST.SKIP' );

    my $plevel = $self->check_dot_patch;
    $self->post_sync;
    return $plevel;
}

=back

=head1 Test::Smoke::Syncer::Hardlink

This handles syncing by copying the source-tree from a local directory
using the B<link> function. This can be used as an alternative for
B<make distclean>.

Thanks to Nicholas Clark for donating this suggestion!

=over 4

=cut

package Test::Smoke::Syncer::Hardlink;

@Test::Smoke::Syncer::Hardlink::ISA = qw( Test::Smoke::Syncer );

require File::Find;

=item Test::Smoke::Syncer::Hardlink->new( %args )

Keys for C<%args>:

  * ddir: destination directory
  * hdir: source directory
  * v:    verbose

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my %args = @_;
    unless ( $args{hdir} ) {
        require Carp;
        Carp::croak "No source-directory (hdir) specified for " . __PACKAGE__;
    }
    return bless \%args, $class;
}

=item $syncer->sync( )

C<sync()> uses the B<File::Find> module to make the hardlink forest in {ddir}.

=cut

sub sync {
    my $self = shift;

    $self->pre_sync;
    require File::Copy unless $self->{haslink};

    -d $self->{ddir} or File::Path::mkpath( $self->{ddir} );

    my $source_dir = File::Spec->canonpath( $self->{hdir} );

    File::Find::find( sub {
        my $dest = File::Spec->abs2rel( $File::Find::name, $source_dir );
        # nasty thing in older File::Spec::Win32::abs2rel()
        $^O eq 'MSWin32' and $dest =~ s|^[a-z]:(?![/\\])||i;
        $dest = File::Spec->catfile( $self->{ddir}, $dest );
        if ( -d ) {
            mkdir $dest, (stat _)[2] & 07777;
        } else {
            -e $dest and 1 while unlink $dest;
            $self->{v} > 1 and print "link $_ $dest";
            my $ok = $self->{haslink}
                ? link $_, $dest
                : File::Copy::copy( $_, $dest );
            if ( $self->{v} > 1 ) {
                print $ok ? " OK\n" : " $!\n";
            }
        }
    }, $source_dir );

    $self->clean_from_directory( $source_dir );

    $self->post_sync;
    return $self->check_dot_patch();
}

=back

=head1 Test::Smoke::Syncer::FTP

This handles syncing by getting the source-tree from ActiveState's APC
repository. It uses the C<Test::Smoke::FTPClient> that implements a
mirror function.

=cut

package Test::Smoke::Syncer::FTP;

@Test::Smoke::Syncer::FTP::ISA = qw( Test::Smoke::Syncer );

use File::Spec::Functions;

=head2 Test::Smoke::Syncer::FTP->new( %args )

Known args for this class:

    * ftphost (public.activestate.com)
    * ftpusr  (anonymous)
    * ftppwd  (smokers@perl.org)
    * ftpsdir (/pub/apc/perl-????)
    * ftpcdir (/pub/apc/perl-????-diffs)

    * ddir
    * v

=cut

sub new {
    my $class = shift;

    return bless { @_ }, $class;
}

=head2 $syncer->sync()

This does the actual syncing:

    * Check {ftpcdir} for the latest changenumber
    * Mirror 

=cut

sub sync {
    my $self = shift;

    $self->pre_sync;
    require Test::Smoke::FTPClient;

    my $fc = Test::Smoke::FTPClient->new( $self->{ftphost}, {
        v       => $self->{v},
        passive => $self->{ftppassive},
        fuser   => $self->{ftpusr},
        fpwd    => $self->{ftppwd},
    } );

    $fc->connect;

    $fc->mirror( @{ $self }{qw( ftpsdir ddir )}, 1 ) or return;

    $self->{client} = $fc;

    my $plevel = $self->create_dot_patch;
    $self->post_sync;
    return $plevel;
}

=head2 $syncer->create_dat_patch

This needs to go to the *-diffs directory on APC and find the patch
whith the highest number, that should be our current patchlevel.

=cut

sub create_dot_patch {
    my $self = shift;
    my $ftp = $self->{client}->{client};

    $ftp->cwd( $self->{ftpcdir} );
    my $plevel = (sort { $b <=> $a } map {
        s/\.gz$//; $_
    } grep /\d+\.gz/ => $ftp->ls)[0];

    my $dotpatch = catfile( $self->{ddir}, '.patch' );
    local *DOTPATH;
    if ( open DOTPATCH, "> $dotpatch" ) {
        print DOTPATCH $plevel;
        close DOTPATCH or do {
            require Carp;
            Carp::carp( "Error writing '$dotpatch': $!" );
        };
    } else {
        require Carp;
        Carp::carp( "Error creating '$dotpatch': $!" );
    }
    return $plevel;
}

1;

=head1 Test::Smoke::Syncer::Forest

This handles syncing by setting up a master directory that is in sync
with either a snapshot or the repository. Then it creates a copy of
this master directory as a hardlink forest and the B<regenheaders.pl>
script is run (if found). Now the source-tree should be up to date
and ready to be copied as a hardlink forest again, to its final
destination.

Thanks to Nicholas Clark for donating this idea.

=over 4

=cut

package Test::Smoke::Syncer::Forest;

@Test::Smoke::Syncer::Forest::ISA = qw( Test::Smoke::Syncer );


=item Test::Smoke::Syncer::Forest->new( %args )

Keys for C<%args>:

  * All keys from the other methods (depending on {fsync})
  * fsync: which master sync method is to be used
  * mdir:  master directory
  * fdir:  intermediate directory (first hardlink forest)

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    return bless { @_ }, $class;
}

=item $syncer->sync( )

C<sync()> starts with a "traditional" sync according to {ftype} in {mdir}.
It then creates a copy of {mdir} in {fdir} with hardlinks an tries to run
the B<regen_headers.pl> script in {fdir}. This directory should now contain
an up to date (working) source-tree wich again using hardlinks is copied
to the destination directory {ddir}.


=cut

sub sync {
    my $self = shift;

    my %args = map { ( $_ => $self->{ $_ } ) } keys %$self;
    $args{ddir} = $self->{mdir};
    $self->{v} and print "Prepare to sync ($self->{fsync}|$args{ddir})\n";
    my $syncer = Test::Smoke::Syncer->new( $self->{fsync}, \%args );
    $syncer->sync;

    # Now copy the master
    $args{ddir} = $self->{fdir};
    $args{hdir} = $self->{mdir};
    $self->{v} and print "Prepare to sync (hardlink|$args{ddir})\n";
    $syncer = Test::Smoke::Syncer->new( hardlink => \%args );
    $syncer->sync;

    # now try to run the 'regen_headers.pl' script
    if ( -e File::Spec->catfile( $self->{fdir}, 'regen_headers.pl' ) ) {
        $self->{v} and print "Run 'regen_headers.pl' ($self->{fdir})\n";
        my $cwd = Cwd::cwd();
        chdir $self->{fdir} or do {
            require Carp;
            Carp::croak "Cannot chdir($self->{fdir}) in forest: $!";
        };
        system( "$^X regen_headers.pl" ) == 0 or do {
            require Carp;
            Carp::carp "Error while running 'regen_headers.pl'";
        };
        chdir $cwd or do {
            require Carp;
            Carp::croak "Cannot chdir($cwd) back: $!";
        };
    }

    $args{ddir} = $self->{ddir};
    $args{hdir} = $self->{fdir};
    $self->{v} and print "Prepare to sync (hardlink|$args{ddir})\n";
    $syncer = Test::Smoke::Syncer->new( hardlink => \%args );
    my $plevel = $syncer->sync;

    return $plevel;
}

=back

=head1 SEE ALSO

L<rsync>, L<gzip>, L<tar>, L<Archive::Tar>, L<Compress::Zlib>,
L<File::Copy>, L<Test::Smoke::SourceTree>

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

  * <http://www.perl.com/perl/misc/Artistic.html>,
  * <http://www.gnu.org/copyleft/gpl.html>

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
