#!/usr/bin/perl
#
# checkbitemp.pl - check the rules for bitemp on the sqlite3 database
#
# SYNOPSIS
# ========
#  checkbitempdb.pl --database=<filename> --table=<tablename> [--log=<logfilename>] [--info=<infofilename>] [--sum=<summaryfile>]
#
use strict;
use warnings;
use Getopt::Long;
use Date::Parse;
use Term::ProgressBar 2.00;
use File::Basename;
use Number::Format;
use Data::Dumper;
use DBI;

my $debug=0; # When debug is on the progress bar is not running
$|=1;
my $dk = new Number::Format( -thousands_sep => '.',
                             -decimal_point => ',',
                             -int_curr_symbol => 'DKK');

my %info;
my $incident   = 0;
#
# usage
#
sub usage{
  my $msg = shift;
  printf "%s\n", $  msg;
  printf "Usage:\n";
  printf "   checkbitempdb.pl --database=<filename> --table=<tablename> [--log=<logfilename>] [--info=<infofilename>] [--sum=<summaryfile>]\n";
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
    print Dumper($lineref);
    printf "Number of lines %d\n", scalar @$lineref;
    printf "Filehandle\n";
    print Dumper($resfh)
  }
  # printf $resfh "Incident %d\n", $incident;
  my $lineno = 0;
  for my $line (@{$lineref}) {
    $lineno++;
    printf $resfh "%d,%d,%d,%s\n", $incident, $lineno, $rule, $line;
    printf "%d,%d,%d,%s\n", $incident, $lineno, $rule, $line if ($debug)
  }
}
#
# compare two objects based on the registreringfra time
#
sub objcompare{
  return $a->{registrering}{fra} <=> $b->{registrering}{fra};
}
#
# analyseTimeRanges - take a list of objects and analyze if the rules for bitemporarity has been vaiolated
#
sub analyseTimeRanges{
  my $resfh = shift; 
  my $objectlistref = shift;

  my @sortobjectlist;

  @sortobjectlist = sort objcompare @{$objectlistref};

  # my $objectno=0;
  # for my $o (@sortobjectlist) {
  #   printf "%2d: %s, %s, %s, %s, %s\n", $objectno++, 
  #     $o->{uuid}, 
  #     $o->{registrering}{fra}, $o->{registrering}{til},
  #     $o->{virkning}{fra}, $o->{virkning}{til}>    
  # };
  my $rule =0;
  my $numberofobjects = scalar @{$objectlistref};
  for my $i (1..$numberofobjects-1) {
    # printf "Comparing:\n";
    my $j=$i-1;

    my $aregfra = $sortobjectlist[$j]->{registrering}{fra};
    my $aregtil = $sortobjectlist[$j]->{registrering}{til};
    my $aline   = $sortobjectlist[$j]->{line};

    my $bregfra = $sortobjectlist[$i]->{registrering}{fra};
    my $bregtil = $sortobjectlist[$i]->{registrering}{til};
    my $bline   = $sortobjectlist[$i]->{line};

    if ($aregtil eq 0 || $bregtil eq 0 ) {
      if ($bregtil eq 0  && $aregtil > $bregtil ) {
        $rule = 6; 
        my @lines;
        push(@lines, $aline, $bline);
        reportincident($resfh, $rule, \@lines);
        # printf "Violation (registreringtil(A) > registreringtil(B)\n";
        # printf "A %s(%s) > B %s(%s)\n", $sortobjectlist[$j]->{registrering}{til}, $aregtil, $sortobjectlist[$i]->{registrering}{til}, $bregtil
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
    my $line2     = $sortobjectlist[$j]->{line};

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
      push(@lines, $line1, $line1);
      reportincident($resfh, $rule, \@lines);
      # printf $resfh "61,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      # printf $resfh "62,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }
    if ( $uuid1 eq $uuid2 &&
         $regfra1 eq $regfra2 &&
         $regtil1 eq '0' &&
         $regtil2 eq '0' &&
         $virktil1 eq '0' &&
         $virktil2 eq '0'
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
      push(@lines, $line1, $line1);
      reportincident($resfh, $rule, \@lines);
      # printf $resfh "71,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      # printf $resfh "72,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }
    # if ( $uuid1 eq $uuid2 &&
    #      $regtil1 ne '0' &&
    #      $regfra1 ne $regfra2 &&
    #      $regtil1 ne $regfra2
    #   ) {
    #   $rule = 9; 
    #   if ($debug) {
    #     printf "Rule %d\n", $rule;
    #     printf "Listname %40s %40s\n", $listname1, $listname2;
    #     printf "uuid     %40s %40s\n", $uuid1, $uuid2;
    #     printf "regfra   %40s %40s\n", $regfra1, $regfra2;
    #     printf "regtil   %40s %40s\n", $regtil1, $regtil2;     
    #     printf "virkfra  %40s %40s\n", $virkfra1, $virkfra2;
    #     printf "virktil  %40s %40s\n", $virktil1, $virktil2;
    #   }
    #   my @lines;
    #   push(@lines, $line1, $line1);
    #   reportincident($resfh, $rule, \@lines);

    #   # printf $resfh "81,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
    #   # printf $resfh "82,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    # }
    if ( $uuid1 eq $uuid2 &&
         ($regtil1 eq '0' || $regtil2 eq '0') &&
         $regfra1 ne $regfra2 &&
         $regtil1 ne $regfra2
      ) {
      $rule = 9; 
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
      push(@lines, $line1, $line1);
      reportincident($resfh, $rule, \@lines);

      # printf $resfh "91,%s,%s,%s,%s,%s,%s\n", $listname1, $uuid1, $regfra1, $regtil1, $virkfra1, $virktil1;
      # printf $resfh "92,%s,%s,%s,%s,%s,%s\n", $listname2, $uuid2, $regfra2, $regtil2, $virkfra2, $virktil2;

    }
  }
}  

my $logfile;
my $infofile = '';
my $sumfile='';
my $resultfile='';
my $database ='';
my $table = '';
GetOptions( "database=s" => \$database,
            "table=s"    => \$table,
            "log=s"      => \$logfile,
            "info=s"     => \$infofile,
            "sum=s"      => \$sumfile,
            "debug"      => \$debug,
            "result"     => \$resultfile);

my $basename = basename($database,'.db');

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
printf "Database    %s\n", $basename;
printf "Table       %s\n", $table;
printf "Info file   %s\n", $infofile;
printf "Log file    %s\n", $logfile;
printf "Sum file    %s\n", $sumfile;
printf "Result file %s\n", $resultfile;

open(my $logfh, ">$logfile" ) or die "Unable to open logfile $logfile";
open(my $infofh,  $infofile ) or die "Unable to open $infofile";
open(my $sumfh, ">$sumfile" ) or die "Unable to create test summary file $sumfile";
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

my $driver   = "SQLite";
my $uuiddsn  = "DBI:$driver:dbname=$database";
my $userid   = "";
my $password = "";
my $dbh      = DBI->connect($uuiddsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;
my $stmt     = qq(select * from $table order by uuid);
my $sth      = $dbh->prepare( $stmt );

$sth->execute();
while (my @row = $sth->fetchrow_array()) {
  #  
  #  $id, $filebefore, $fileafter, $lineno, $list, $regtimefra, $regtimetil, $virktimefra, $virktimetil
  #
  my $line = join(',',@row);
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


  if ($uuid ne $olduuid ) {
    #
    # Got a new key uuid and the previous list of object contains more than one object
    #
    #printf "N%s, %s, %d\n", $uuid, $olduuid, $recno;
 
    if ($uuid ne '' and scalar @objectlist > 1) {
      analyseTimeRanges($resfh, \@objectlist)
    }
    $olduuid = $uuid;
    @objectlist = ();
    $objectno++;
  }
  my $object = { listname => $listname, 
                 registrering => { fra => $regfra, til => $regtil},
                 virkning     => { fra => $virkfra, til => $virktil},
                 status   => $status,
                 uuid => $uuid,
                 line => $line};
  push(@objectlist, $object); 
  if (!$debug ) {
    $next_update = $progress->update($recno) if $recno >= $next_update;
  }

  #
  # Rule 1. Regtimefra must not be null
  # ===================================
  #
  if ($regtimefra eq '0' || $regtimefra eq '') {

    $rule = 1;
    my @lines;
    push(@lines, $line);
    reportincident($resfh, $rule, \@lines);
    $rules{$rule}++
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
    $rules{$rule}++
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
    $rules{$rule}++
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
    $rules{$rule}++
  }
  #
  # Rule 5. Virktil > Virkfra
  # ===========================
  # 
  if ($virktimetil ne '0' && $virkfra > $virktil) {

    $rule = 5;  
    my @lines;
    push(@lines, $line);
    if ($debug) {
      printf "5>%5d,%s,%s,%s,%s\n", $recno, $virktimefra, $virktimetil,$virkfra,$virktil;
      printf Dumper(@lines)
    }
    reportincident($resfh, $rule, \@lines);
    $rules{$rule}++
  }

}
for my $rule (keys %rules) {
  printf $sumfh "%s, %d\n", $rule, $rules{$rule}
}
close($logfh);
close($sumfh);
