#!/usr/bin/perl
#
# testrapport.pl - make the test rapport
#
# SYNOPSIS
# ========
#   testrapport.pl --zip=<zipfile> [--rapport=<reportfile>]
#
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use JSON;
use XML::LibXML::Simple;
use File::stat;
use Number::Bytes::Human qw(format_bytes);
use Number::Format;
use POSIX qw(strftime);
use Cwd;

my $dk = new Number::Format( -thousands_sep => '.',
                             -decimal_point => ',',
                             -int_curr_symbol => 'DKK');
my %info;
my $metadata;
my @ruledescriptions;
my $maxincidents = 100;

$ruledescriptions[ 1] = "Registreringfra må ikke være null (tom)";
$ruledescriptions[ 2] = "Virkningstid må ikke være null (tom)";
$ruledescriptions[ 3] = "Status må ikke være null (tom)";
$ruledescriptions[ 4] = "Registreringfra skal være mindre end registreringtil";
$ruledescriptions[ 5] = "Virkningfra skal være mindre end virkningtil";
$ruledescriptions[ 6] = "Registreringstid for to instanser må ikke overlappe";
$ruledescriptions[ 7] = "Overlap (registreringtil(A) > registreringtil(B))";
$ruledescriptions[ 8] = "Duplikerede virkning og registrering";
$ruledescriptions[ 9] = "Huller i registringstidsintervaller";

sub cmpstarttime {
    $a->timestart <=> $b->timestart
}
sub dumpinfo {
  my $message = shift;
  my $fh = shift;
  my $recno = shift;
  my $rowref = shift;
  printf $fh "%s (%d) -> %s\n", $message, $recno, join(",", @{$rowref})
}
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
# reportFileInfo - Add a section for file information
#
sub reportFileInfo {
  my $filename = shift;
  my $fh = shift;
  my $sb = stat($filename);
  my $dir = getcwd;

  printf $fh "# Information for Filedownload\n\n";
  printf $fh "## File Information\n";
  printf $fh "\n";
  printf $fh "| Parameter | Value |\n";
  printf $fh "|--------|-----------------:|\n";
  printf $fh "| Filename | %s |\n", $filename;
  printf $fh "| Directory | %s |\n", $dir;
  printf $fh "| Size (packed) | %s |\n", $dk->format_bytes($sb->size);
  printf $fh "| Size (unpacked) | %s |\n", $dk->format_bytes(getSize($filename));
  printf $fh "\n";

}
#
# getinfo - Reads the info file with statistics
#
sub getinfo{
  my $fh = shift;
  while (my $line = <$fh>) {
    chomp($line);
    # printf "%s\n", $line;
    my ($var,$value) = split(/,/,$line);
    $info{$var} = $value
  }
}
#
# reportInfo - writes down the main statistics in the info file
#
sub reportInfo{
  my $fh = shift;
  printf $fh "# General information\n";
  printf $fh "\n";
  printf $fh "## Number of records for each list and total\n";
  printf $fh "\n";
  
  printf $fh "| List | Records |\n";
  printf $fh "|--------|-----------------:|\n";
  for my $key (sort keys %info) {
    printf $fh "| %s | %10s  |\n", $key, $dk->format_number($info{$key})
  }
  printf $fh "\n";

}
#
# Open the zip file to get the metadatafile
#
sub getMetadatafilename {
  my $file = shift;
 
  open(ZIPLIST,"unzip -l $file|") or die "Unable to list zip content $file";

  my $metafilename;

  while (my $line=<ZIPLIST>) {
    chomp($line);
    if ($line =~ /Metadata/) {
      # printf "%s\n", $line;
      $line =~ /(\b(\w|[-]|\.)*$)/;
      $metafilename = $1;
      # printf "%s\n", $metafilename
    }
  }
  close(ZIPLIST);
  return $metafilename;
}
#
# 
sub getMetadata{
  my $zipfilename = shift;

  my $metafilename = getMetadatafilename($zipfilename);
  open(my $metafile, "unzip -p $zipfilename   $metafilename |") or die "Unable to read $metafilename";

  while (my $line = <$metafile>) {
    chomp($line);
    $metadata .= $line;
  }
  # printf "%s\n", $metadata;
  close($metafile);
}
sub reportMetadataJSON{
  my $fh = shift;

  my $metadatajson = JSON->new->utf8->decode($metadata);

  # print Dumper($metadatajson);
  my $leverancenavn      = $metadatajson->{leveranceNavn};
  my $miljoe             = $metadatajson->{miljoe};
  my $fortroligData      = $metadatajson->{fortroligData};
  my $omfattedafPDL      = $metadatajson->{dataOmfattetAfPersondataloven};

  my $md5checksum        = $metadatajson->{MD5CheckSum};
  my $udtreakstidspunktstart
                         = $metadatajson->{DatafordelerUdtraekstidspunkt}[0]{deltavindueStart};
  my $udtreakstidspunktslut
                         = $metadatajson->{DatafordelerUdtraekstidspunkt}[0]{deltavindueSlut};
  my $tilgaengelighedsperiode
                         = $metadatajson->{tilgaengelighedsperiode};

  my $abonnementnavn     = $metadatajson->{AbonnementsOplysninger}[0]{abonnementnavn};
  my $tjenestenavn       = $metadatajson->{AbonnementsOplysninger}[0]{tjenestenavn};
  my $webBrugernavn      = $metadatajson->{AbonnementsOplysninger}[0]{webBrugernavn};
  my $tjenesteversion    = $metadatajson->{AbonnementsOplysninger}[0]{tjenesteversion};
  my $oprettelsesdato    = $metadatajson->{AbonnementsOplysninger}[0]{oprettelsesdato};
  my $senesteAbonnementRedigeringsdato
                         = $metadatajson->{AbonnementsOplysninger}[0]{senesteAbonnementRedigeringsdato};
  my $gentagelsesinterval= $metadatajson->{AbonnementsOplysninger}[0]{gentagelsesinterval};

  printf $fh "## Metadata\n";
  printf $fh "\n";
  printf $fh "### Generelle Parametre\n";
  printf $fh "| Parameter | Value |\n";
  printf $fh "|--------|-----------------:|\n";
  printf $fh "|  Leverancenavn | %s |\n",  $leverancenavn;
  printf $fh "|  Miljø | %s |\n",  $miljoe;
  printf $fh "|  Fortrolig Data | %s |\n",  $fortroligData;
  printf $fh "|  Omfattet af Persondataloven | %s |\n",  $omfattedafPDL;
  printf $fh "|  MD5 checksum | %s |\n",  $md5checksum;
  printf $fh "|  Udtrækstidspunkt Start | %s |\n",  $udtreakstidspunktstart;
  printf $fh "|  Udtrækstidspunkt Slut | %s |\n",  $udtreakstidspunktslut;
  printf $fh "| Tilgængelighedsperiode | %s |\n", $tilgaengelighedsperiode;
  printf $fh "\n";

  printf $fh "### AbonnementsOplysninger\n";

  printf $fh "| Parameter | Value |\n";
  printf $fh "|--------|-----------------:|\n";
  printf $fh "|  WEB Brugernavn | %s |\n", $webBrugernavn;  
  printf $fh "|  Abonnementsnavn | %s |\n", $abonnementnavn;
  printf $fh "|  Tjenestenavn    | %s |\n", $tjenestenavn;
  printf $fh "|  Tjenesteversion    | %s |\n", $tjenesteversion;
  printf $fh "|  Oprettelsesdato    | %s |\n", $oprettelsesdato;
  printf $fh "|  Seneste Abonnementredigeringsdato    | %s |\n", $senesteAbonnementRedigeringsdato;
  printf $fh "|  Gentagelsesinterval   | %s |\n", $gentagelsesinterval;
  printf $fh "\n";

  printf $fh "### Brugerudfyldte Parametre\n\n";
  printf $fh "| Parameter | Value |\n";
  printf $fh "|--------|-----------------:|\n";
  for my $parameter (sort @{$metadatajson->{BrugerUdfyldteParametre}}) {
    printf $fh "| %s | %s |\n", $parameter->{parameternavn},$parameter->{parametervaerdi}; 
  }
  printf $fh "\n";
}
sub printIncidents{
  my $fh       = shift;
  my $incident = shift;
  my $lineref  = shift;
  my @printlines;
  my $i=0;
  my $rows = scalar(@{$lineref});
  for my $info (@{$lineref}) {
    # printf "%s\n", $info;  
    my ($incident, $linenumber, $rule, $id, $filebefore, $fileafter, $lineno, $list, $regtimefra, $regtimetil, $virktimefra, $virktimetil, $status) = split(/,/,$info);
    $printlines[$i]->{incident}      = $incident;
    $printlines[$i]->{rule}          = $rule;
    $printlines[$i]->{id}            = $id;
    $printlines[$i]->{filebefore}    = $filebefore;
    $printlines[$i]->{fileafter}     = $fileafter;
    $printlines[$i]->{list}          = $list;
    $printlines[$i]->{regtimefra}    = $regtimefra;
    $printlines[$i]->{regtimetil}    = $regtimetil;
    $printlines[$i]->{virktimefra}   = $virktimefra;
    $printlines[$i]->{virktimetil}   = $virktimetil;
    $printlines[$i]->{status}        = $status;
    $i++
  }
  my $rule     = $printlines[0]->{rule};
  printf $fh "#### Incident %d\n\n", $incident;
  printf $fh "Rule %d violated\n\n", $rule;
  printf $fh "%s\n\n", $ruledescriptions[$rule];
  # for my $info (@lines) {
  #   printf $fh "%s\n\n", $info;
  # }
  printf $fh "| Parameter ";
  for my $row (1..$rows) {
    printf $fh "| "
  }
  printf $fh "|\n";

  for my $row (0..$rows) {
    printf $fh "|--------";
  }
  printf $fh ":|\n";

  printf $fh "| UUID ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{id}
  }
  printf $fh "|\n";

  printf $fh "| File position (from, to) ";
  for my $row (1..$rows) {
    printf $fh "| %d,%d ", $printlines[$row-1]->{filebefore},$printlines[$row-1]->{fileafter}
  }
  printf $fh "|\n";

  printf $fh "| List ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{list}
  }
  printf $fh "|\n";

  printf $fh "| Registrering Fra ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{regtimefra}
  }
  printf $fh "|\n";

  printf $fh "| Registrering Til ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{regtimetil}
  }
  printf $fh "|\n";

  printf $fh "| Virkning Fra ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{virktimefra}
  }
  printf $fh "|\n";

  printf $fh "| Virkning Til ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{virktimetil}
  }
  printf $fh "|\n";

  printf $fh "| Status ";
  for my $row (1..$rows) {
    printf $fh "| %s ", $printlines[$row-1]->{status}
  }
  printf $fh "|\n";
  printf $fh "\n";
}
sub reportTest{
  my $fh = shift;
  my $resultfile = shift;
  my $sumfile = shift;

  printf $fh "# Test Results\n\n";
  printf $fh "## Details\n\n";
  open(my $sumfh, $sumfile ) or die "Unable to open $sumfile";
  open(my $resfh, $resultfile) or die "Unable to open $resultfile";

  my $no = 0;
  my $oldincident = 0;
  my @lines = ();
  while (my $line=<$resfh>) {
    chomp($line); 
    # printf "%s\n", $line;
    my @record = split(/,/,$line);
    my $incidentno = int($record[0]);
    if ($oldincident == 0 ) {
      push(@lines, $line);
      $oldincident = $incidentno
    }
    elsif ($incidentno == $oldincident) {
      push(@lines,$line);
    }
    # printf "%d, %d, %s\n", $oldincident, $incidentno,$line;
    else {
      # printf "Incidets %d\n\n", scalar(@lines);
      printIncidents($fh,$oldincident,\@lines);
      @lines = ();
      $oldincident = $incidentno;
      push(@lines,$line)
    }
    last if $incidentno > $maxincidents
  }
  close($sumfh);
  close($resfh);
}

sub reportHeader{
  my $fh = shift;
  printf $fh "# Test Report\n\n";
  printf $fh "## Version\n";
  printf $fh "Version 1.0\n";

  printf $fh "Report generated %s\n", strftime("%Y-%m-%d %H:%M:%S", localtime());
  printf $fh "\n";
  
}
#
# Check the overall results
#
my %testsummary;
sub testresult{
  my $sumfile = shift;
  open(my $sumfh, $sumfile ) or die "Unable to open $sumfile";
  my $testfailed = 0;
  while ( my $line = <$sumfh>) {
    chomp($line);
    my ($list, $rule, $numbers) = split(/,/,$line);
    $testsummary{$list}{$rule} = $numbers;
    $testfailed += $numbers;
  }
  close($sumfh);
  return $testfailed
}
sub reportSummary{
  my $fh = shift;
  my $sumfile = shift;
  my $metadatajson = JSON->new->utf8->decode($metadata);
  my $miljoe             = $metadatajson->{miljoe};
  my $tjenestenavn       = $metadatajson->{AbonnementsOplysninger}[0]{tjenestenavn};
  my $register           = $tjenestenavn;
  if ($register =~ /(\w*)/) {
    $register = $1
  }
  my $result = testresult($sumfile);

  printf $fh "# Summary\n\n";

  printf $fh "| Parameter | |\n";
  printf $fh "|--------|-----------------:|\n";
  printf $fh "| Register | %s |\n", $register;
  printf $fh "| Service  | %s |\n", $tjenestenavn;
  printf $fh "| Environment  | %s |\n", $miljoe;
  printf $fh "| Executed  | %s |\n", strftime("%Y-%m-%d %H:%M:%S", localtime());
  printf $fh "| Result  | %s |\n", $result > 0 ? 'FAILED' : 'SUCCESS';
  printf $fh "\n";
  printf $fh "# Test Statistics\n\n";

  printf $fh "| Listname | Rule Id | Description |  Failed |\n";
  printf $fh "|----------|---------|-------------|--------:|\n";
  my $total = 0;
  for my $list (sort keys %testsummary) {
    for my $rs (keys %{$testsummary{$list}}) {
      printf $fh "| %s | %s | %s | %d |\n", $list, $rs, $ruledescriptions[$rs],$testsummary{$list}{$rs};
      $total += $testsummary{$list}{$rs}
    }
  }
  printf $fh "|  |  |  | %d |\n", $total;
  printf "\n\n"

}
sub usage{
  printf "Usage:\n";
  printf " testreport.pl --zip=<file> [--report=<file>] [--sum=<file>] [--result=<file>]"
}
$|=1;
my $zipfile = '';
my $reportfile = '';
my $sumfile = '';
my $resultfile = '';

GetOptions( "zip=s"    => \$zipfile,
            "report=s" => \$reportfile,
            "sum=s"    => \$sumfile,
            "result=s" => \$resultfile);

if ($zipfile eq '' or !-e $zipfile ) {
  printf "$zipfile does not exists.\n";
  usage();
  die();
}

my $basename = basename($zipfile,'.zip');
my $infofile = $basename.'.inf';

if ($reportfile eq '') {
  $reportfile = $basename.'.md';
}
if ($sumfile eq '') {
  $sumfile = $basename.'.sum';
}
if ($resultfile eq '') {
  $resultfile = $basename.'.res';
}

printf "Input file  %s\n", $zipfile;
printf "Info file   %s\n", $infofile;
printf "Sum file    %s\n", $sumfile;
printf "Result file %s\n", $resultfile;
printf "Report file %s\n", $reportfile;
#
# Get metadatafile information
#
open(my $reportfh, ">$reportfile") or die "Unable to open $reportfile";
open(my $infofh, $infofile ) or die "Unable to open $infofile";


getMetadata($zipfile);

reportHeader($reportfh);
reportSummary($reportfh, $sumfile);
reportFileInfo($zipfile, $reportfh);

reportMetadataJSON($reportfh);
getinfo($infofh);
reportInfo($reportfh);
reportTest($reportfh, $resultfile, $resultfile);

close($reportfh);
close($infofh);

