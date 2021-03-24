#!/usr/bin/perl
#
# Read from SQLITE DB
#
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Fcntl qw(:seek);
use DBI;
use POSIX qw(strftime);

my $database = "";
my $table    = ""; 

sub usage{
  my $message = shift;
  printf "%s\n", $message;
  printf "Usage:\n";
  printf "  dbreadpl --database=<filename> --table=<tablename>\n";
}

GetOptions( "database=s"      => \$database,
            "table=s"         => \$table);

if ($database eq "") {
  usage('No database given');
  die()
}

if ($table eq "") {
  usage('No table given');
  die()
}

printf "Database %s\n", $database;
printf "Table    %s\n", $table;
my $driver   = "SQLite";
my $uuiddsn  = "DBI:$driver:dbname=$database";
my $userid   = "";
my $password = "";
my $dbh      = DBI->connect($uuiddsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;
my $stmt     = qq(select * from $table order by 1);
my $sth      = $dbh->prepare( $stmt );
my $rowno    = 0;
$sth->execute();
while (my @row = $sth->fetchrow_array()) {
  my $uuid        = $row[0];
  my $lineno      = $row[3];
  my $listname    = $row[4];
  my $regtimefra  = $row[5] || 0;
  my $regtimetil  = $row[6] || 0;
  my $virktimefra = $row[7] || 0;
  my $virktimetil = $row[8] || 0;
  my $status      = $row[9] || 0;
  my $regfra      = $regtimefra;
  my $regtil      = $regtimetil;
  my $virkfra     = $virktimefra;
  my $virktil     = $virktimetil;
  printf "%10d:%s\n", ++$rowno, join(",", @row)
}

$dbh->disconnect();
