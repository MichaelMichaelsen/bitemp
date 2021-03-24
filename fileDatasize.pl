#!/usr/bin/perl
#
# fileDatazip - get the file size of the data file in the Archive
#
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Data::Dumper;

#
# getSize - extract the datafilename from the zip-archive
#
sub getSize {
  my $zipfile = shift;
  my $basename = basename($zipfile, '.zip');
  my $datafile = $basename . '.json';

  my $realsize;
  my $compressedsize;
  #
  # list the files in the archive
  #
  open (my $fh, "zipinfo -l $zipfile|");
  while (my $line = <$fh>) {
    chomp($line);
    if ($line =~ /$datafile/g) {
      # -rw----     4.5 fat 30162527823 bx 2652684837 defN 20-Jun-11 19:09 DATVER-DAR-Total_20200611165859.json
      if ($line =~ /\s*\S*\s*\S*\s*\w*\s*(\w*)\s*\w*\s*(\w*)/) {
        # printf "%s, %s\n", $1, $2;
        $realsize  = int($1);
        $compressedsize = int($2)
      }
    }
  }
  close($fh);
  # printf "Compressionrate %.2f %%\n", 100.0 - $compressedsize/$realsize * 100.0;
  return $realsize
}
my $filename = '/media/mmi/SDFE-DATA/validation/bitemp/DATVER-DAR-Total_20200611165859/DATVER-DAR-Total_20200611165859.zip';
printf "%s\n", $filename;
my $filesize = getSize($filename);
printf "%d\n", $filesize;
my $averagelinesize = 40;
printf "Estimated number of lines %d\n", int($filesize / $averagelinesize);