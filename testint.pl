use strict;
use lib '.';
use Interval;
sub cmpstarttime {
  if ($a->timestart != $b->timestart) {
    $a->timestart <=> $b->timestart
  }
  else {
    $a->timeend <=> $b->timeend
  }
}
my $i1 = new Interval( start => "2019-07-15T10:11:40.502587+02:00", end => "2020-07-15T10:11:40.502587+02:00");
my $i2 = new Interval( start => "2020-07-13T10:11:40.502587+02:00", end => "2020-06-02T10:11:40.502587+02:00");
my $i3 = new Interval( start => "2020-07-13T10:11:40.502587+02:00", end => "2020-06-02T10:11:40.502587+02:00");
my $i4 = new Interval( start => "2020-07-13T10:11:40.502587+02:00", end => "");
printf "Range %s\n", $i1->range();
printf "Timerange %s\n", $i1->timerange();
printf "(%s,%s)\n", $i1->start, $i1->end; 
printf "%s\n", $i2->range();
printf "Timerange %s\n", $i2 ->timerange();
printf "%s\n", $i3->range();
printf "Timerange %s\n", $i3 ->timerange();
printf "Range %s\n", $i4->range();
printf "Timerange %s\n", $i4->timerange();
printf "(%s,%s) (%d, %d)\n", $i4->start, $i4->end, $i4->timestart(), $i4->timeend(); 

my @range;
push(@range, $i4);
push(@range, $i2);
push(@range, $i1);
push(@range, $i3);

my $i=0;
for my $r (@range) {
  printf "%d (%s,%s)\n", $i++, $r->start(),$r->end()
}

my @sortrange = sort cmpstarttime @range; 
$i=0;
for my $r (@sortrange) {
  printf "%d (%s,%s)\n", $i++, $r->start(),$r->end()
}

my $overlap = $i1->overlap($i2);
if ($overlap) {
  printf "Overlap (i1,i2) (%d)\n", $overlap
}
$overlap = $i2->overlap($i3);
if ($overlap) {
  printf "Overlap (i2,i3) (%d)\n", $overlap
}