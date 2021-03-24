#!/usr/bin/perl
#
# lookup.pl - Lookup in the file between to byte positions
#
# SYNOPSIS
#   lookup.pl --zipfile=<filename> --position=<startposition>,<endposition>
#
#
use strict;
use Getopt::Long;
use Fcntl qw(:seek);
use IO::File;
use Data::Dumper;
use Term::ProgressBar 2.00;

my $buffersize = 40*1024*1024;
#
# getDatafilename - extract the datafilename from the zip-archive
#
sub getDataFilename{
  my $zipfile = shift;
  #
  # list the files in the archive
  #
  open(my $zipfh, "zipinfo -1 $zipfile|") or die "Unable to list archive";
  my $datafile;
  while (my $file=<$zipfh>) {
    chomp($file);
    #printf "%s\n", $file;
    if ($file !~ /Metadata/) {
      $datafile = $file;
    }
  }
  close($zipfh);
  return $datafile
}
#
# Usage
# 
sub usage {
  my $message = shift;
  printf "%s\n", $message;
  printf "Usage:\n";
  printf "   lookup.pl --zip=<zipfile> --position=<start>,<end> [--silent]\n"
}
my $position;
my $zipfile = "";
my $buffer;
my $silent=0;
GetOptions( "position=s"  => \$position,
            "silent"      => \$silent,
            "zip=s"       => \$zipfile);
# printf "Position %s\n", $position;
if (! -e $zipfile) {
  usage( "Unable to locate $zipfile");
  die()
}
my $datafile = getDataFilename($zipfile);
my ($startposition,$endposition) = split(/,/,$position);
#
# Check if the position is valid
#
my $intstart = int($startposition);
my $intend   = int($endposition);
if ($intstart > $intend) {
  usage("Start position must less than end position");
  die();
}
# printf "Start %d\n", $startposition;
# open(my $fh,
#     "7z x -so $zipfile $datafile|" ) or die "Unable to open process $zipfile";
my $fh = new IO::File("7z x -so $zipfile $datafile|") or die "Unable to open process $zipfile";

# seek($fh,$startposition,SEEK_SET);
$fh->setpos($startposition);
my $bytes = $endposition - $startposition;
my $location = 0;
my $buffers  = int($startposition / $buffersize);
my $progress   = Term::ProgressBar->new($buffers) if !$silent;
$progress->message("Buffers ".$buffers) if !$silent;
my $next_update = 0;
# printf "%d buffers.\n", $buffers;
my $rb;
$|=1;
for my $i (1..$buffers) {
  $rb = read($fh,$buffer, $buffersize);
  if (!$silent) {
    $next_update = $progress->update($i) if $i >= $next_update;
  }
}
my $rest = $startposition % $buffersize;
my $rb   = read($fh, $buffer, $rest + 1);

$rb         = read($fh,$buffer,$bytes - 1);
printf "%s\n",$buffer;
