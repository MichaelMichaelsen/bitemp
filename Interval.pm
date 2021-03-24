
package Interval;
  use strict;
  use warnings;
  use Carp;
  use Time::ParseDate;
  require Exporter;
  my @ISA = qw(Exporter);
  my @EXPORT = qw(range start end timestart timeend timerange overlap );
  sub new {
    my $class = shift;
    my $self  = { @_ };
    croak "bad arguments" unless defined $self->{start} and defined $self->{end}; 
    return bless $self, $class; #this is what makes a reference into an object
  }
  sub range {
    my $self = shift;
    return "$self->{start}..$self->{end}";
  }
  sub start {
    my $self = shift;
    return $self->{start};
  }
  sub end {
    my $self = shift;
    return $self->{end};
  }
  sub timestart {
    my $self = shift;
    my $value = 0;
    if ($self->{start} ne "") {
      $value = parsedate($self->{start});
    }
    return $value
  }
  sub timeend {
    my $self = shift;
    my $value = 0;
    if ($self->{end} ne "") {
      $value =  parsedate($self->{end});
    }
    return $value
  }
  sub timerange {
    my $self = shift;
    return $self->timestart . ".." . $self->timeend 
  }
  sub overlap {
    my $self = shift;
    my $int  = shift;
    #
    # Open interval - always OK
    #
    if ($self->timestart() == 0 and $self->timeend() == 0) {
      return 0
    }
    my $rangecheck1 = ( $int->timestart() < $self->timeend() and $int->timeend() > $self->timeend() );
    if ($rangecheck1) {
      return 1
    }
    my $rangecheck2 = ( $self->timestart() < $int->timeend() and $self->timeend() > $int->timeend() );
    if ($rangecheck2) {
      return 2
    }
  }

1;


