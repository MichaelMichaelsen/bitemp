#!/usr/bin/perl
#
# checkbitemp.pl - check the rules for bitemp on the sqlite3 database
#
# SYNOPSIS
# ========
#   checkbitemp.pl --csv=<csvfilename> [--log=<logfilename>] [--info=<infofilename>] --sum=<testsummaryreport>
#
use strict;
use warnings;
use Getopt::Long;
use Date::Parse;
use Term::ProgressBar 2.00;
use File::Basename;
use Number::Format;
use Data::Dumper;

my $debug=0; # When debug is on the progress bar is not running
$|=1;
my $dk = new Number::Format( -thousands_sep => '.',
                             -decimal_point => ',',
                             -int_curr_symbol => 'DKK');
#
# nobitemp - listnames of objects, where there is no bitemp to check
#
my %nobitemp = ( 'BygningEjendomsrelationList' => 1,
                 'EnhedEjendomsrelationList' => 1,
                 'GrundJordstykkeList' => 1,
                 'Jordstykke_SekundaerforretningList' => 1,
                 'Optagetvej_JordstykkeList' => 1,
                 'Samletfastejendom_JordstykkeList' => 1,
                 'Samletfastejendom_SekundaerforList' => 1,
                 'StormfaldList' => 1,
                 'Temalinje_JordstykkeList' => 1,
                 'FordelingAfFordelingsarealList' => 1,
                 'Ejerskifte_BilagsbankRefList' => 1); 
my %info;
my $incident   = 0;
my %violation;
#
# usage
#
sub usage{
  my $msg = shift;
  printf "%s\n", $  msg;
  printf "Usage:\n";
  printf "   checkbitemp.pl --csv=<csvfilename> [--log=<logfilename>] [--info=<infofilename>] --sum=<testsummaryreport>\n";
}
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
#
# reportincident
#
sub reportincident{
  my $resfh    = shift;
  my $rule     = shift;
  my $lineref  = shift;

  $incident++;

  #
  # Add to the csv file (result file)
  #
  if ($debug) {
    printf $resfh  "+++ %d ++++\n", $incident;
    printf "Number of lines %d\n", scalar @$lineref;
  }
  # printf $resfh "Incident %d\n", $incident;
  my $lineno = 0;
  my $listname;
  for my $line (@{$lineref}) {
    $lineno++;
    printf $resfh "%d,%d,%d,%s\n", $incident, $lineno, $rule, $line;
    my @record = split(/,/,$line);
    $listname = $record[4];
    printf "%d,%d,%d,%s\n", $incident, $lineno, $rule, $line if ($debug)
  }
  $violation{$listname}{$rule}++
}
#
# compare two objects based on the registreringfra time
#
sub objcompare{
  return $a->{reg}{fra} <=> $b->{reg}{fra};
}
#
# analyseTimeRanges - take a list of objects and analyze if the rules for bitemporarity has been vaiolated
#
sub analyseTimeRanges{
  my $logfile       = shift;
  my $resfh         = shift; 
  my $objectlistref = shift;  
  my @sortobjectlist;

  # print  Dumper(@$objectlistref);
  my @objectlist = @{$objectlistref};
  # print Dumper(@objectlist);
  @sortobjectlist = sort objcompare @{$objectlistref};

  my $rule =0;
  my $numberofobjects = scalar @$objectlistref;
  for my $i (1..$numberofobjects-1) {
    # printf "Comparing:\n";
    my $j=$i-1;

    my $aregfra = $sortobjectlist[$j]->{registrering}{fra};
    my $aregtil = $sortobjectlist[$j]->{registrering}{til};
    my $aregistreringtil   = $sortobjectlist[$j]->{reg}{til};
    my $aline   = $sortobjectlist[$j]->{line};

    my $bregfra = $sortobjectlist[$i]->{registrering}{fra};
    my $bregtil = $sortobjectlist[$i]->{registrering}{til};
    my $bregistreringtil   = $sortobjectlist[$i]->{reg}{til};
    my $bline   = $sortobjectlist[$i]->{line};

    if ($aregtil eq 0 || $bregtil eq 0 ) {
      if ($bregtil eq 0  && $aregistreringtil > $bregistreringtil ) {
        $rule = 6; 
        my @lines;
        push(@lines, $aline, $bline);
        reportincident($resfh, $rule, \@lines);
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
    my $line1     = $sortobjectlist[$j]->{line};

    my $uuid2     = $sortobjectlist[$i]->{uuid};
    my $regfra2   = $sortobjectlist[$i]->{registrering}{fra};
    my $regtil2   = $sortobjectlist[$i]->{registrering}{til};
    my $virkfra2  = $sortobjectlist[$i]->{virkning}{fra};
    my $virktil2  = $sortobjectlist[$i]->{virkning}{til};
    my $listname2 = $sortobjectlist[$i]->{listname};
    my $line2     = $sortobjectlist[$i]->{line};
    #
    # Regel 7. Duplikerede objekter
    #
    if ( $uuid1 eq $uuid2 &&
         $regfra1 eq $regfra2 && 
         $regtil1 eq $regtil2 && 
         $virkfra1 eq $virkfra2 &&
         $virktil1 eq $virktil2
         ) {
      $rule = 7; 
      if ($debug) {
        printf "Rule %d\n", $rule;
        printf "Listname %40s %40s\n", $listname1, $listname2;
        printf "uuid     %40s %40s\n", $uuid1, $uuid2;
        printf "regfra   %40s %40s\n", $regfra1, $regfra2;
        printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
        printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
        printf "virktil  %40s %40s\n", $virktil1, $virktil2;

      }

      my @lines;
      push(@lines, $line1, $line2);
      reportincident($resfh, $rule, \@lines);

    }
    #
    # Regel 8. RegisteringTil skal lukkes ved opdatering
    #
    if ( $uuid1 eq $uuid2 &&
         $regfra1 eq $regfra2 &&
         $regtil1 eq ''
         ) {
      $rule = 8; 
      if ($debug) {
        printf "Rule %d\n", $rule;
        printf "Listname %40s %40s\n", $listname1, $listname2;
        printf "uuid     %40s %40s\n", $uuid1, $uuid2;
        printf "regfra   %40s %40s\n", $regfra1, $regfra2;
        printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
        printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
        printf "virktil  %40s %40s\n", $virktil1, $virktil2;

      }
      my @lines;
      push(@lines, $line1, $line2);
      reportincident($resfh, $rule, \@lines);

    }
    #
    # Regel 9. Overlappen registreringstidsintervaller
    #
    # if ( $uuid1 eq $uuid2 &&
    #      ($regtil1 eq '0' || $regtil2 eq '0') &&
    #      $regfra1 gt $regfra2 &&
    #      $regtil1 gt $regfra2
    #   ) {
    #   $rule = 9; 
    #   if ($debug) {
    #     printf "-------------------------------------------------------\n";
    #     printf "Rule %d\n", $rule;
    #     printf "L1:%40s\nL2:%40s\n", $line1,  $line2;
    #     printf "Listname %40s %40s\n", $listname1, $listname2;
    #     printf "uuid     %40s %40s\n", $uuid1, $uuid2;
    #     printf "regfra   %40s %40s\n", $regfra1, $regfra2;
    #     printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
    #     printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
    #     printf "virktil  %40s %40s\n", $virktil1, $virktil2;
    #   }
    #   my @lines;
    #   push(@lines, $line1, $line2);
    #   reportincident($resfh, $rule, \@lines);

    # }
  }
}  

my $csvfile = '';
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

if ($csvfile eq "") {
  usage("No csv file specified");
  die
}
if (!-e $csvfile) {
  usage("Unable to locate csvfile $csvfile");
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
select($resfh);
$|++;
getinfo($infofh);
#
# Perfomance settings
#
my $recno        = 0;
my $next_update 
                 = 0;
my $totalrecords = $info{'Total number of objects'};
my $progress;
if (!$debug) {
  $progress    = Term::ProgressBar->new($totalrecords);
}
my $olduuid       = '';

my $objectno      = 0;
my @objectlist;
my %rules;
my $oldlist       = "";
my $rule          = 0;
while(my $line    = <$csvfh>) {
  chomp($line);
  #  
  #  $id, $filebefore, $fileafter, $lineno, $list, $regtimefra, $regtimetil, $virktimefra, $virktimetil
  #
  my @row         = split(/,/,$line);
  my $uuid        = $row[0];
  my $lineno      = $row[3];
  my $listname    = $row[4];
  my $regtimefra  = $row[5] || 0;
  my $regtimetil  = $row[6] || 0;
  my $virktimefra = $row[7] || 0;
  my $virktimetil = $row[8] || 0;
  my $status      = $row[9] || 0;
  my $regfra      = str2time($regtimefra);
  my $regtil      = str2time($regtimetil);
  my $virkfra     = str2time($virktimefra);
  my $virktil     = str2time($virktimetil);

  $recno++;
  if ($debug) {
    printf "%5d:%s\n",$recno, join(",", $uuid, $lineno, $listname, $regtimefra, $regtimetil, $virktimefra, $virktimetil, $status);
    printf "%5d:%s\n",$recno, join(",", $uuid, $lineno, $listname, $regfra, $regtil, $virkfra, $virktil, $status)
  }
  # if ($recno >= 2933734) {
  #   printf "%d: %s\n", $recno, $line;
  #   my $no = scalar @objectlist;
  #   printf "Entries %d\n", $no;
  #   for my $i (0..$no-1) {
  #     printf "%2d: Line %s\n", $i, $objectlist[$i]->{line}
  #   }
  # }
  if ($uuid ne $olduuid ) {
    $olduuid = $uuid;
    my $no = scalar( @objectlist );
    if ($uuid ne '' and  $no > 1) {
      analyseTimeRanges($logfh, $resfh, \@objectlist)
    }
    @objectlist = ();
    $objectno++;
  }

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
  # Skip record if are in the nobitemp set
  #
  next if (defined $nobitemp{$listname});
  my $object = { listname       => $listname, 
                 reg            => { fra => $regfra, til => $regtil},
                 virk           => { fra => $virkfra, til => $virktil},
                 registrering   => { fra => $regtimefra, til => $regtimetil},
                 virkning       => { fra => $virktimefra, til => $virktimetil},
                 status         => $status,
                 uuid           => $uuid,
                 line           => $line};
  push(@objectlist, $object); 
  #
  # Rule 1. Regtimefra must not be null
  # ===================================
  #
  if ($regtimefra eq '0' || $regtimefra eq '') {

    $rule = 1;
    my @lines;
    push(@lines, $line);
    reportincident($resfh, $rule, \@lines);
  }
  #
  # Rule 2. Missing Virkningfra
  # ===========================
  # 
  if ($virktimefra eq '0' || $virktimefra eq '') {
    $rule = 2;  
    my @lines;
    push(@lines, $line);
    reportincident($resfh, $rule, \@lines);
  }
  #
  # Rule 3. Status must exists
  # ===========================
  # 
  if ($status eq '0' || $status eq '') {
    $rule = 3;  
    my @lines;
    push(@lines, $line);
    reportincident($resfh, $rule, \@lines);
  }
  #
  # Rule 4. Regtil > Regfra
  # ===========================
  # 
  if ($regtimetil ne '0' && $regfra > $regtil) {
    if ($debug) {
      printf "4>%5d,%s,%s,%s\n", $recno, $regtimetil, $regfra, $regtil;
    }
    $rule = 4;  
    my @lines;
    push(@lines, $line);
    reportincident($resfh, $rule, \@lines);
  }
  #
  # Rule 5. Virktil > Virkfra
  # ===========================
  # 
  if ($virktimetil ne '0' && $virktimefra > $virktimetil) {

    $rule = 5;  
    my @lines;
    push(@lines, $line);
    if ($debug) {
      printf "5>%5d,%s,%s,%s,%s\n", $recno, $virktimefra, $virktimetil,$virkfra,$virktil;
    }
    reportincident($resfh, $rule, \@lines);
  }

}
for my $listname (keys %violation) {
  for my $rule (keys %{$violation{$listname}}) {
    printf $sumfh "%s, %s, %d\n", $listname, $rule, $violation{$listname}{$rule}
  }
}
close($csvfh);
close($logfh);
close($sumfh);
