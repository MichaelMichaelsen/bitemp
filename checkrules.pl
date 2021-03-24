#!/usr/bin/perl
#
# checkrules.pl - check the rules for bitemp on the sqlite3 database
#
# SYNOPSIS
# ========
#   chekrules.pl --csv=<csvfilename> [--log=<logfilename>] [--info=<infofilename>] --sum=<testsummaryreport>
#
use strict;
use warnings;
use Getopt::Long;
use Date::Parse;
use Term::ProgressBar 2.00;
use File::Basename;
use Number::Format;

my $debug=0; # When debug is on the progress bar is not running

my $dk = new Number::Format( -thousands_sep => '.',
                             -decimal_point => ',',
                             -int_curr_symbol => 'DKK');

sub dumpinfo {
  my $message   = shift;
  my $fh        = shift;
  my $recno     = shift;
  my $lineno    = shift;
  my $line      = shift;
  my $objectref = shift;

  printf $fh "%s (%d, %d)\n", $message, $lineno, $recno;

  my @row = split(/,/,$line);
  my $uuid       = $row[0];
  my $listname   = $row[4];
  my $regtimefra = $row[5] || 0;
  my $regtimetil = $row[6] || 0;
  my $virktimefra= $row[7] || 0;
  my $virktimetil= $row[8] || 0;
  my $status     = $row[9] || 0;

  printf $fh "UUID    \t%s\n", $uuid;
  printf $fh "Listname\t%s\n", $listname;
  printf $fh "Reg Fra \t%s (%s)\n", $regtimefra, str2time($regtimefra);
  printf $fh "Reg Til \t%s (%s)\n", $regtimetil, str2time($regtimetil);
  printf $fh "Virk Fra\t%s (%s)\n", $virktimefra, str2time($virktimefra);
  printf $fh "Virk Til\t%s (%s)\n", $virktimetil, str2time($virktimetil);
  printf $fh "Status  \t%s\n", $status;

}
sub usage{
  my $msg = shift;
  printf "%s\n", $msg;
}
#
# compare two objects based on the registreringfra time
#
sub objcompare{
  my $aregtimefra = str2time($a->{registrering}{fra});
  my $bregtimefra = str2time($b->{registrering}{fra});
  return $aregtimefra <=> $bregtimefra
}
#
# analyseTimeRanges - take a list of objects and analyze if the rules for bitemporarity has been vaiolated
#
sub analyseTimeRanges{
  my $fh = shift;
  my $resfh = shift; 
  my $objectlistref = shift;

  my @sortobjectlist;

  @sortobjectlist = sort objcompare @{$objectlistref};

  # my $objectno=0;
  # for my $o (@sortobjectlist) {
  #   printf "%2d: %s, %s, %s, %s, %s\n", $objectno++, 
  #     $o->{uuid}, 
  #     $o->{registrering}{fra}, $o->{registrering}{til},
  #     $o->{virkning}{fra}, $o->{virkning}{til};
    
  # };
  my $numberofobjects = scalar @{$objectlistref};
  for my $i (1..$numberofobjects-1) {
    # printf "Comparing:\n";
    my $j=$i-1;
    # printf "A%2d: %s, %s, %s, %s, %s\n", $j, 
    #   $sortobjectlist[$j]->{uuid}, 
    #   $sortobjectlist[$j]->{registrering}{fra}, $sortobjectlist[$j]->{registrering}{til},
    #   $sortobjectlist[$j]->{virkning}{fra}, $sortobjectlist[$j]->{virkning}{til};   
    # printf "B%2d: %s, %s, %s, %s, %s\n", $i, 
    #   $sortobjectlist[$i]->{uuid}, 
    #   $sortobjectlist[$i]->{registrering}{fra}, $sortobjectlist[$i]->{registrering}{til},
    #   $sortobjectlist[$i]->{virkning}{fra}, $sortobjectlist[$i]->{virkning}{til};
    #
    # Work on registereingtidsinterval
    #
    my $aregfratime = $sortobjectlist[$j]->{registrering}{fra};
    my $aregtiltime = $sortobjectlist[$j]->{registrering}{til};
    my $bregfratime = $sortobjectlist[$i]->{registrering}{fra};
    my $bregtiltime = $sortobjectlist[$i]->{registrering}{til};

    my $aregfra = str2time($aregfratime);
    my $aregtil = str2time($aregtiltime);
    my $bregfra = str2time($bregfratime);
    my $bregtil = str2time($bregtiltime);

    if ($aregtiltime eq '' || $bregtiltime eq '' ) {
      if ($bregtiltime eq ''  && $aregtil > $bregtil ) {
        printf "Violation (registreringtil(A) > registreringtil(B)\n";
        printf "A %s(%s) > B %s(%s)\n", $sortobjectlist[$j]->{registrering}{til}, $aregtil, $sortobjectlist[$i]->{registrering}{til}, $bregtil
      }
    }
  }
  #
  # Check for duplicates 
  #
  for my $i (1..$numberofobjects-1) {
    my $j=$i-1;
    my $uuid1     = $sortobjectlist[$j]->{uuid};
    my $regfra1   = $sortobjectlist[$j]->{registrering}{fra};
    my $regtil1   = $sortobjectlist[$j]->{registrering}{til};
    my $virkfra1  = $sortobjectlist[$j]->{virkning}{fra};
    my $virktil1  = $sortobjectlist[$j]->{virkning}{til};
    my $listname1 = $sortobjectlist[$j]->{listname};

    my $uuid2     = $sortobjectlist[$i]->{uuid};
    my $regfra2   = $sortobjectlist[$i]->{registrering}{fra};
    my $regtil2   = $sortobjectlist[$i]->{registrering}{til};
    my $virkfra2  = $sortobjectlist[$i]->{virkning}{fra};
    my $virktil2  = $sortobjectlist[$i]->{virkning}{til};
    my $listname2 = $sortobjectlist[$i]->{listname};

    if ( $uuid1 eq $uuid2 &&
         $regfra1 eq $regfra2 && 
         $regtil1 eq $regtil2 && 
         $virkfra1 eq $virkfra2 &&
         $virktil1 eq $virktil2
         ) {
      if ($debug) {
        printf "Duplet found\n";
        printf "Listname %40s %40s\n", $listname1, $listname2;
        printf "uuid     %40s %40s\n", $uuid1, $uuid2;
        printf "regfra   %40s %40s\n", $regfra1, $regfra2;
        printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
        printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
        printf "virktil  %40s %40s\n", $virktil1, $virktil2;

      }
      printf $resfh "61,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      printf $resfh "62,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }
    if ( $uuid1 eq $uuid2 &&
         $regfra1 eq $regfra2 &&
         $regtil1 eq '0' &&
         $regtil2 eq '0' &&
         $virktil1 eq '0' &&
         $virktil2 eq '0'
         ) {
      if ($debug) {
        printf "Duplet found\n";
        printf "Listname %40s %40s\n", $listname1, $listname2;
        printf "uuid     %40s %40s\n", $uuid1, $uuid2;
        printf "regfra   %40s %40s\n", $regfra1, $regfra2;
        printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
        printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
        printf "virktil  %40s %40s\n", $virktil1, $virktil2;

      }
      printf $resfh "71,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      printf $resfh "72,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }
    if ( $uuid1 eq $uuid2 &&
         $regtil1 ne '0' &&
         $regfra1 ne $regfra2 &&
         $regtil1 ne $regfra2
      ) {
      if ($debug) {
        printf "Duplet found\n";
        printf "Listname %40s %40s\n", $listname1, $listname2;
        printf "uuid     %40s %40s\n", $uuid1, $uuid2;
        printf "regfra   %40s %40s\n", $regfra1, $regfra2;
        printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
        printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
        printf "virktil  %40s %40s\n", $virktil1, $virktil2;
      }
      printf $resfh "81,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      printf $resfh "82,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }
    if ( $uuid1 eq $uuid2 &&
         ($regtil1 eq '0' || $regtil2 eq '0') &&
         $regfra1 ne $regfra2 &&
         $regtil1 ne $regfra2
      ) {
      if ($debug) {
        printf "Duplet found\n";
        printf "Listname %40s %40s\n", $listname1, $listname2;
        printf "uuid     %40s %40s\n", $uuid1, $uuid2;
        printf "regfra   %40s %40s\n", $regfra1, $regfra2;
        printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
        printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
        printf "virktil  %40s %40s\n", $virktil1, $virktil2;
      }
      printf $resfh "91,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      printf $resfh "92,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }

  }
  # printf "-------------------------------\n";
}
my %info;
#
# getinfo - Reads the info file with statistics
#
sub getinfo{
  my $fh = shift;
  while (my $line = <$fh>) {
    chomp($line);
    my ($var,$value) = split(/,/,$line);
    $info{$var} = $value
  }
}

$|=1;
my $csvfile;
my $logfile;
my $infofile = '';

my $sumfile='';
my $resultfile='';


GetOptions( "csv=s"    => \$csvfile,
            "log=s"    => \$logfile,
            "info=s"   => \$infofile,
            "sum=s"    => \$sumfile,
            "debug"    => \$debug,
            "result"   => \$resultfile);

if (!-e $csvfile) {
  usage("Unable to locate csvfile $csvfile");
  die
}
if ($csvfile eq "") {
  usage("No csv file specified");
  die
}
my $basename = basename($csvfile,'.csv');

if ($infofile eq "") {
  $infofile = $basename.'.inf'
}
if ($sumfile eq "") {
  $sumfile = $basename.'.sum'
}
if ($resultfile eq "") {
  $resultfile = $basename.'.res'
}

$logfile = $basename.'.log';

#
# checkForOverlap - check that the registreringstid and virkningstid do not overlap.
#
printf "Csv file    %s\n", $csvfile;
printf "Info file   %s\n", $infofile;
printf "Log file    %s\n", $logfile;
printf "Sum file    %s\n", $sumfile;
printf "Result file %s\n", $resultfile;

open(my $logfh, ">$logfile") or die "Unable to open logfile $logfile";
open(my $csvfh,   $csvfile) or die "Unable to open $csvfile";
open(my $infofh,  $infofile ) or die "Unable to open $infofile";
open(my $sumfh, ">$sumfile") or die "Unable to create test summary file $sumfile";
open(my $resfh, ">$resultfile") or die "Unable to create result file $resultfile";

getinfo($infofh);
#
# Perfomance settings
#
my $recno      = 0;
my $next_update 
               = 0;
my $totalrecords 
               = $info{'Total number of objects'};
my $progress;
if (!$debug) {
  $progress    = Term::ProgressBar->new($totalrecords);
}
my $olduuid    = '';
my $objectno   = 0;
my @objectlist;
my %rules;
my $oldlist= "";
while(my $line = <$csvfh>) {
  chomp($line);
  #  
  #  $id, $filebefore, $fileafter, $lineno, $list, $regtimefra, $regtimetil, $virktimefra, $virktimetil
  #
  my @row = split(/,/,$line);
  my $uuid        = $row[0];
  my $lineno      = $row[3];
  my $listname    = $row[4];
  my $regtimefra  = $row[5] || 0;
  my $regtimetil  = $row[6] || 0;
  my $virktimefra = $row[7] || 0;
  my $virktimetil = $row[8] || 0;
  my $status      = $row[9] || 0;
  $recno++;

  if ($uuid ne $olduuid ) {
    #
    # Got a new key uuid and the previous list of object contains more than one object
    #
    #printf "N%s, %s, %d\n", $uuid, $olduuid, $recno;
 
    if ($uuid ne '' and scalar @objectlist > 1) {
      analyseTimeRanges($logfh, $resfh, \@objectlist)
    }
    $olduuid = $uuid;
    @objectlist = ();
    $objectno++;
  } 
  # else {
  #   printf " %s, %s, %d\n", $uuid, $olduuid, $recno;
  # }
  my $object = { listname => $listname, 
                 registrering => { fra => $regtimefra, til => $regtimetil},
                 virkning     => { fra => $virktimefra, til => $virktimetil},
                 uuid => $uuid};
  push(@objectlist, $object);
  #
  # Status bar update
  #
  if (!$debug ) {
    $next_update = $progress->update($recno) if $recno >= $next_update;
  }
  if ($listname ne $oldlist) {
    my $message = $listname;
    if ($oldlist ne "") {
      $message = $oldlist.' '.$dk->format_number($recno);
    }
    if (!$debug) {
      $progress->message($message);
    }
    $oldlist = $listname
  }
  #
  # Rule 1. Alle registreringfra must not be null.
  #
  if ( $regtimefra eq "" ) {
    my $rule = "Rule 1. Missing registreringfra";
    dumpinfo($rule, $logfh, $recno, $lineno, $line, $object);
    printf $resfh "1,%s\n", $line;
    $rules{$rule}++;
  }
  if ( $virktimefra eq "" ) {
    my $rule = "Rule 2. Missing virkningfra";
    dumpinfo($rule, $logfh, $recno, $lineno, $line, $object);
    printf $resfh "2,%s\n", $line;
    $rules{$rule}++;

  }
  if ( !defined($status) or $status eq "" ) {
    my $rule = "Rule 3. status must be have a value";
    dumpinfo("Rule 3. status must be have a value", $logfh, $recno, $lineno, $line, $object);
    printf $resfh "3,%s\n", $line;
    $rules{$rule}++;
  }
  # printf "%s, %s, %s, %s\n", $regtimefra, $regtimetil, $virktimefra, $virktimetil;
 
  my $regfra  = str2time($regtimefra);
  my $regtil  = str2time($regtimetil);
  my $virkfra = str2time($virktimefra);
  my $virktil = str2time($virktimetil);
  # printf "%s, %s, %s, %s\n", $regfra, $regtil, $virkfra, $virktil;
  if ( $regtimetil ne "0" and $regfra > $regtil ) {
    my $rule = "Rule 4. Registreringstid (fra > til)";
    dumpinfo($rule, $logfh, $recno, $lineno, $line, $object );
    printf $resfh "4,%s\n", $line;
    # printf $logfh "Regtil %s\n", $regtil;
    $rules{$rule}++; 
  }

  if ( $virktimetil ne "0" and $virkfra > $virktil ) {
    my $rule = "Rule 5. Virkningstid (fra > til)";
    dumpinfo($rule,$logfh, $recno, $lineno, $line, $object );
    printf $resfh "5,%s\n", $line;
    # printf $logfh  "Virktil %s\n", $virktil;
    $rules{$rule}++; 
  }

}
for my $rule (keys %rules) {
  printf $sumfh "%s, %d\n", $rule, $rules{$rule}
}
close($csvfh);
close($logfh);
close($sumfh);
