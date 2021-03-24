#!/usr/bin/perl
#
# timecheck.pl - test the handling of date time
use strict;
my @datestring;
#
# dateLT - compare to timestamp as text string return 1 if the ts1 is less than to t2 
#
sub dateLT {
  my $ts1 = shift;
  my $ts2 = shift;
  #
  # If ts2 is undefined or zero, this is oo
  #
  if ($ts2 eq '' or $ts2 eq 0 ) {
    return 1
  }
  #
  # String compare
  #
  if ($ts1 lt $ts2) {
    return 1
  }
  return 0;
}
#
# dateGT - compare to timestamp as text string return 1 if the ts1 is greather than to t2 
#
sub dateGT {
  my $ts1 = shift;
  my $ts2 = shift;

  return dateLT($ts2,$ts1)
}
#
# CompareRangeOverlap
#
# Range1 [a1..a2]
# Range2 [b1..b2]
#
sub compareRangeOverlap{
  my $a1 = shift;
  my $a2 = shift;
  my $b1 = shift;
  my $b2 = shift;
  if (dateLT($a1,$b1) && dateLT($a2,$b2))

}

$datestring[0] = "1968-10-15T12:18:33.000000+02:00";
$datestring[1] = "2020-06-25T08:06:31.879708+02:00";

$datestring[2] = "1998-10-15T12:18:33.000000+02:00";
$datestring[3] = "2012-06-25T08:06:31.879708+02:00";

if (dateLT($datestring[0],$datestring[1])) {
  printf "OK\n"
}

if (!dateLT($datestring[3],$datestring[2])) {
  printf "Not OK\n"
}