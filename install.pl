#!/usr/bin/env perl

# poor man's install

use strict;
use warnings;

use Archive::Tar;
use Data::Dumper;
use English        qw(-no_match_vars);
use File::Basename qw(dirname);
use File::Path     qw(make_path remove_tree);
use File::Copy     qw(copy);
use File::Temp     qw(tempdir);
use Getopt::Long   qw(:config no_ignore_case);
use JSON;

our $VERSION = '0.01';

use Readonly;

# booleans
Readonly our $SUCCESS => 0;
Readonly our $FAILURE => 1;
Readonly our $TRUE    => 1;
Readonly our $FALSE   => 0;
Readonly our $EMPTY   => q{};

########################################################################
sub help {
########################################################################
  print <<"END_OF_HELP";
usage: $PROGRAM_NAME Options package | install

Options
-------
-h, --help                    help
-c, ---cleanup, --no-cleanup  remove temp directory, default: cleanup
-d, --destdir                 destination directory, default: /
-D, --dryrun                  report, but don't execute
-g, --group                   default group for files
-t, --tarball                 name of the tarball
-m, --manifest                default: manifest.json
-o, --overwrite               overwrite existing files, default: do not overwrite
-O, --owner                   default owner for files
-v, --verbose                 verbose output

Hints
-----
1. tarballs are assumed to be in gzip format
2. if you provide just name name of the tarball, .tar.gz is assumed
3. use -d to place files under a different directory other than /
4. use -D to do a dryrun
5. -D implies -v

Version: $VERSION
(c) Copyright 2023, Rob Lauer, All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
END_OF_HELP

  return;
}

########################################################################
sub message {
########################################################################
  my (%options) = @_;

  return if !$options{verbose} && !$options{warning};

  my $message = $options{message} // $options{warning};

  if ( $options{dryrun} && !$options{warning} ) {
    $message = "(dryrun) $message";
  }

  return print "$message\n";
}

########################################################################
sub fetch_manifest {
########################################################################
  my ($file) = @_;

  die 'no manifest found'
    if !$file | !-e $file;

  open my $fh, '<', $file
    or die "could not open $file for reading\n";

  local $RS = undef;

  my $manifest = JSON->new->decode(<$fh>);

  close $fh;

  return $manifest;
}

########################################################################
sub extract {
########################################################################
  my (%options) = @_;

  die $options{tarball} . ' does not exist'
    if !-e $options{tarball};

  my $tmpdir = tempdir();

  my $archive = Archive::Tar->new( $options{tarball} );
  $archive->setcwd($tmpdir);

  message %options,
    message => sprintf 'extracting %s to %s',
    $options{tarball}, $tmpdir;

  $archive->extract();

  return $tmpdir;
}

########################################################################
sub list {
########################################################################
  my (%options) = @_;

  printf "%s\n", join "\n", sort( list_manifest( $options{manifest_file} ) );

  return $SUCCESS;
}

########################################################################
sub create_dirs {
########################################################################
  my (%options) = @_;

  my $manifest = $options{manifest};

  my @dirs = keys %{ $manifest->{files} };

  foreach my $dir (@dirs) {
    my $target_dir = sprintf '%s%s', $options{destdir}, $dir;

    next if -d $target_dir;

    message %options, message => sprintf '...creating %s', $target_dir;

    next if $options{dryrun};

    make_path($target_dir);
  }

  return @dirs;
}

########################################################################
sub list_manifest {
########################################################################
  my ($manifest) = @_;

  if ( !ref $manifest ) {
    die 'no manifest'
      if !-e $manifest;

    $manifest = fetch_manifest($manifest);
  }

  my @files
    = map { @{ $manifest->{files}->{$_} } } keys %{ $manifest->{files} };

  for (@files) {
    next if !ref $_;
    ($_) = keys %{$_};
  }

  return @files;
}

########################################################################
sub install_files {
########################################################################
  my (%options) = @_;

  my $tmpdir = $options{tmpdir};

  my $manifest_file = sprintf '%s/%s', $tmpdir, $options{manifest_file};

  die 'no manifest'
    if !-e $manifest_file;

  my $manifest = fetch_manifest($manifest_file);

  my @dirs = create_dirs( %options, manifest => $manifest );

  my $file_count = 0;

  foreach my $dir (@dirs) {
    my @files = @{ $manifest->{files}->{$dir} };

    foreach my $file (@files) {
      my ( $mode, $owner, $group );

      if ( ref $file ) {
        my $file_spec = $file;

        ($file) = keys %{$file_spec};

        ( $mode, $owner, $group ) = @{ $file_spec->{$file} };
      }

      $mode  //= $options{mode} // '0644';
      $owner //= $options{owner};
      $group //= $options{group};

      my $target = sprintf '%s%s/%s', $options{destdir}, $dir, $file;

      if ( !$options{overwrite} && -e $target ) {
        message %options, warning => sprintf '...skipping %s', $target;
        next;
      }

      my $dirname = dirname $target;

      if ( !-d $dirname ) {
        message %options, message => 'creating directory: ' . $dirname;

        if ( !$options{dryrun} ) {
          make_path $dirname;
        }
      }

      message %options,
        message => sprintf '...copying %s -> %s',
        $file,
        $target;

      next if $options{dryrun};

      copy "$tmpdir/$file", $target;

      set_file_perms( $target, $mode, $owner, $group );
    }
  }

  if ( $options{cleanup} ) {
    message %options, message => "...removing $tmpdir";

    remove_tree($tmpdir);
  }

  return $SUCCESS;
}

########################################################################
sub set_file_perms {
########################################################################
  my ( $file, $mode, $owner, $group ) = @_;

  if ( defined $mode ) {

    die 'invalid mode'
      if length($mode) != 4 || $mode !~ /^0/xsm;

    chmod oct($mode), $file;
  }

  my ( $id, $gid );

  if ( defined $owner ) {
    ( undef, undef, $id ) = getpwnam $owner;
  }

  if ( $owner && $group ) {
    ( undef, undef, $gid ) = getgrnam $group;
  }
  else {
    $gid = $id;
  }

  if ( $owner eq 'root' || ( $gid && $id ) ) {
    chown $id, $gid, $file;
  }

  return;
}

########################################################################
sub create_package {
########################################################################
  my (%options) = @_;

  die 'no tarball'
    if !$options{tarball};

  if ( !$options{manifest} ) {
    $options{manifest} = fetch_manifest( $options{manifest_file} );
  }

  my $archive = Archive::Tar->new;

  my $manifest = $options{manifest};
  my $files    = $manifest->{files};

  my @files = list_manifest $manifest;

  $archive->add_files( $options{manifest_file}, @files );

  $archive->write( $options{tarball}, COMPRESS_GZIP );

  return $SUCCESS;
}

########################################################################
sub install {
########################################################################
  my (%options) = @_;

  install_files( %options, tmpdir => extract(%options) );

  return $SUCCESS;
}

########################################################################
sub main {
########################################################################
  my @options_specs = qw(
    cleanup!
    destdir|d=s
    dryrun|D
    group|g
    help
    manifest|m=s
    mode|M=s
    overwrite|o
    owner|O=s
    tarball|t=s
    verbose|v
  );

  my %options = (
    cleanup => $TRUE,
    destdir => $EMPTY
  );

  GetOptions( \%options, @options_specs );

  if ( $options{destdir} && $options{destdir} !~ /\/z/xsm ) {
    $options{destdir} = "$options{destdir}/";
  }

  if ( $options{destdir} && !-d $options{destdir} ) {
    message %options,
      message => sprintf 'creating destdir: %s',
      $options{destdir};

    if ( !$options{dryrun} ) {
      make_path $options{destdir};
    }
  }

  if ( $options{tarball} && $options{tarball} !~ /[.]tar[.]gz\z/xsm ) {
    $options{tarball} = sprintf '%s.tar.gz', $options{tarball};
  }

  $options{manifest_file} = delete $options{manifest};
  $options{manifest_file} //= 'manifest.json';

  my $command = shift @ARGV;

  $command //= 'help';

  die '--tarball is a required argument'
    if !$options{tarball} && !grep {/$command/} qw(help list);

  $options{verbose} //= $options{dryrun};

  my %actions = (
    install => \&install,
    package => \&create_package,
    list    => \&list,
    help    => \&help,
  );

  $command = $actions{$command} ? $command : 'help';

  $actions{$command}->(%options);

  return $SUCCESS;
}

exit main();

1;

__END__
