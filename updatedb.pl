#!/usr/bin/perl
#
# updatedb.pl - 
#
# SYNOPSIS
# ========
#  updatedb.pl --database=<filename> --table=<tablename> [--log=<logfilename>] [--info=<infofilename>] [--sum=<summaryfile>]
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

my $logfile;
my $updatefile='';
my $database ='';
my $table = 'DAR';
GetOptions( "database=s" => \$database,
            "table=s"    => \$table,
            "update=s"   => \$updatefile);

if ($database eq "") {
  die "Database is missing\n"
}

my $basename = basename($database,'.db');

if ($updatefile eq "") {
  die "Update file is missing\n"
}
if ($table eq "") {
  die "Table is missing\n"
}
$logfile = $basename.'.log';

printf "Database       %s\n", $database;
printf "Table          %s\n", $table;
printf "Update         %s\n", $updatefile;

my $driver   = "SQLite";
my $uuiddsn  = "DBI:$driver:dbname=$database";
my $userid   = "";
my $password = "";
my $dbh      = DBI->connect($uuiddsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;
# my $stmt     = qq(select count(*) from $table where uuid=?);
my $stmt = qq(select count(*) from $table
where
	UUID=?
	and REGTIMETIL  =  ""
  and VIRKTIMETIL =  ""
  and LISTNAME    <> "AdressepunktList"
	and REGTIMEFRA  = (select max(REGTIMEFRA) from $table where  UUID=?)
  and VIRKTIMEFRA = (select max(VIRKTIMEFRA) from $table where  UUID=?));

my $sth      = $dbh->prepare( $stmt );

open(my $upfh, $updatefile) or die "Unable to open $updatefile";
my $recno = 0;
while (my $line = <$upfh>) {
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
  #
  $sth->execute($uuid, $uuid, $uuid);
  while (my @row = $sth->fetchrow_array()) {
    # my $newline = join(",",@row);
    # next if ($row[5] eq "AdressepunktList");
    my $count = $row[0];
    printf "%s: %d\n", $uuid, $count if $count > 0
  }

}
close($upfh);