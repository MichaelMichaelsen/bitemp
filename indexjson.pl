#!/usr/bin/perl
#
# indexjson.pl - create an index for a json file that has the following structure
#
# {
#   "List1" : [
#       {object1},
#       {object2},
#       ...
#       {objectN}
#      ],
#   "List2" : [
#       {object1},
#       {object2},
#       ...
#       {objectN}
#      ],
#      ...
#   "ListN" : [
#       {object1},
#       {object2},
#       ...
#       {objectN}
#      ]
# }
#
#
# SYNOPSIS
# ========
#
#   indexjson.pl --zipfile=<zipfile> --csv=<csvfile> --log=<logfile>
#
# where
#   zipfile   - input json zipfile
#   csv        - output csv file (default index.csv)
#   log        - output log      (default indexjson.log)
#
#  CSV file format
#
#  ID, STARTPOS, ENDPOS, LINENO, LISTNAME
#
#  ID               - the uniq id (either Id or id_lokalID for the object)
#  STARTPOS         - Start byte position of the object
#  ENDPOS           - End byte position (the separation comma)
#  LINENO           - Line number for the end of the object
#  LISTNAME         - The name of the list
#  VIRKTIMEFRA      - Virkningstid start
#  VIRKTIMETIL      - Virkningstid end
#  REGTIMEFRA       - Registreringstid start
#  REGTIMETIL       - Registreringstid end
#  STATUS           - Status
#
# The script creates :
#   <basenamem zipfile>.csv
#   <basenamem zipfile>.log
#
use strict;
use warnings;
use Getopt::Long;
use JSON::SL;
use JSON;
use Cwd 'abs_path';
use File::Basename;
use Data::Dumper;
use Term::ProgressBar 2.00;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Number::Format;
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
sub usage{
  printf "Usage: \n";
  printf "  indexjson.pl --zipfile=<zipfile> [--csv=<csvfile>] [--info=<infofile>]\n"
}
#
# Main
#
$|=1;
my $zipfile = "";
my $csvfile  = "";
my $infofile  = "";
GetOptions( "zipfile=s"          => \$zipfile,
            "csv=s"              => \$csvfile,
		       	"info=s"             => \$infofile);

if ($zipfile eq "") {
  printf "No zipfile specified in arguments \n";
  usage();
  exit()
}
if (!-e $zipfile) { 
  printf "Unable to locate zipfile\n";
  usage();
  exit()
}
my $basename = basename($zipfile,'.zip');
if ($csvfile eq "") {
  $csvfile = $basename.'.csv'
}
if ($infofile eq "") {
  $infofile = $basename.'.inf'
}
printf "Input file %s\n", $zipfile;
printf "Csv file   %s\n", $csvfile;
printf "Info file  %s\n", $infofile;
#
# Check if this is symbolic link
#
my $abszipfile = (-l  $zipfile ) ? (abs_path($zipfile) ) : ($zipfile);
#printf "%s\n", $abszipfile;
#
my $dk = new Number::Format(-thousands_sep   => '.',
                            -decimal_point   => ',',
                            -int_curr_symbol => 'DKK');
my $datafile = getDataFilename($abszipfile);

open(my $fh,
    "7z x -so $abszipfile $datafile|" ) or die "Unable to open process $abszipfile";
open(my $csvfh,       ">$csvfile" ) or die "Unable to create $csvfile";
open(my $infofh,      ">$infofile" ) or die "Unable to open $infofile";

my $p = JSON::SL->new;

#look for everthing past the first level (i.e. everything in the array)
$p->set_jsonpointer(["/^/^"]);

my $lineno     = 0;
my $filebefore = 0;
my $fileafter  = 0;
my $list       = "";
my $oldlist    = "";

my $totalnumberofobjects
               = 0;
my %numberofobjects;
my $bytesize   = getSize($zipfile);
my $averagelinesize = 40;
my $recordsestimated = int($bytesize/$averagelinesize*1.2);
printf "Data size %s (bytes)\n", $dk->format_bytes($bytesize);
printf "Extimated number of lines %s\n", $dk->format_number($recordsestimated);
my $progress   = Term::ProgressBar->new($recordsestimated);
my $next_update= 0;
my $tbuf="";
while (my $buf = <$fh>) {

  $buf =~ s/\r\n$//; # remove cr nl (DOS text)
  $buf =~ s/\n$//;   # remove nl (UNIX text)

  #
  # Remove all non-ascii characters
  #
  $buf =~ s/[^[:ascii:]]//g;
  my $orgbuf    = $buf;
  my $orglength = length($buf);

  $lineno++;
  $next_update = $progress->update($lineno) if $lineno >= $next_update;
  if ($buf =~ /\"(\w*List)\"\:/) {
    $list = $1;
    if ($list ne $oldlist) {  
      $oldlist = $list;
      if ($oldlist ne "") {
        $progress->message($list." ".$dk->format_number($lineno))
      }
    }
  }
  #
  # Special case for starting
  #
  if ($lineno == 3 ){
    $filebefore = tell();
  }
  $fileafter = tell();

  #
  # If we meet a multi line, then we skip the parsing for that line, such as
  #       1699494495: <"byg500Notatlinjer":"[1] logistikcenter og museumsmagasin>  -- skip
  #   >   1699494496: <[26] mangler fortsat: drift- og vedligeholdelsesplan (brand) -	El-sikkerhedsattest -	afstningsplan",
  #
  # But avoid data like 
  # 148154772	"byg500Notatlinjer":"[19] Lejet grund, ejendomsnr.: 34579
  # 148154773	[26] \"DINA\"",
  # 444243612	"byg500Notatlinjer":"[6] OVERDÆKKET TERRASSE PÅ 16 M2 - OPFØRT I 1966
  # 444243613	[11] TAGDÆKNING : \"ANDET\" = DECRA-PLADER",
  # 170588258	"byg500Notatlinjer":"[8] Badeværelser i kælder < 1,25m inkl. i boligarealet (20 m²)
  # 170588259	[9] Åbne terrasser (ikke overdækkede): 67,5 m²
  # 170588260	[17] Opvarmning: jordvarmeanlæg - ikke færdigmeldt endnu
  # 170588261	[80] Bebygget areal: stueplan; kælder er større end stueplan; huset er bygget som \"kryds\"",
  #
  my $ending        = () = $buf =~ /,$/g;
	my $objectending  = () = $buf =~ /(,\{|\{|\]|\})$/g;
  
  if ( $ending == 1 || $objectending == 1) {
    # printf "FEED %14d: <%s>\n", $lineno, $tbuf.$buf if $lineno > 1699493496;
    $p->feed($tbuf.$buf); 
    $tbuf = "";
    #printf "FEED %14d: <%s>\n", $lineno, $tbuf;
  }
  else {
    $tbuf .= $buf;
    # printf "CONT %14d: <%s>\n", $lineno, $tbuf if $lineno > 1699493496;
    #printf "CONT %14d: <%s>\n", $lineno, $buf;
    next
  }
  #fetch anything that completed the parse and matches the JSON Pointer

  while (my $obj = $p->fetch) {
    # print Dumper($obj);
    #printf "%s - %s\n",$obj->{Path},$obj->{Value};
    #printf "%s",to_json($obj->{Value}, {utf8 => 0, pretty => 1});
    my $id= "";
    my $regtimefra = "";
    my $regtimetil = "";
    my $virktimefra = "";
    my $virktimetil = "";
    my $status = "";
    if (defined $obj->{Value}{registreringFra}) {
      $regtimefra =  $obj->{Value}{registreringFra}
    };
    if (defined $obj->{Value}{registreringTil}) {
      $regtimetil =  $obj->{Value}{registreringTil}
    }
    if (defined $obj->{Value}{virkningFra}) {
      $virktimefra =  $obj->{Value}{virkningFra}
    };
    if (defined $obj->{Value}{virkningTil}) {
      $virktimetil =  $obj->{Value}{virkningTil}
    };
    if (defined $obj->{Value}{id}) {
      $id = $obj->{Value}{id};
    } elsif (defined $obj->{Value}{id_lokalId}) {
      $id = $obj->{Value}{id_lokalId};
    }
    if (defined $obj->{Value}{status}) {
      $status = $obj->{Value}{status}
    }
    printf $csvfh "%s\n", join(",", $id, $filebefore, $fileafter, $lineno, $list, $regtimefra, $regtimetil, $virktimefra, $virktimetil, $status);

    $totalnumberofobjects++;
    $numberofobjects{$list}++;
    $filebefore = $fileafter;
  }
  #printf "(%d,%d,%d) next\n",$lineno,$filebefore, $fileafter;

}

foreach $list (sort keys %numberofobjects) {
  printf $infofh "%s, %d\n", $list, $numberofobjects{$list};
}

printf $infofh "Total number of objects, %d\n", $totalnumberofobjects;
close($fh);
close($infofh);
close($csvfh);