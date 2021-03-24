#!/usr/bin/perl
#
# count - count the number of objects
#
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Data::Dumper;
use REST::Client;
use JSON;
use POSIX qw(strftime);

my %requests = (  "DAR" => {
                      "methods" =>                   
                      {
                        "Adresse"         => "/DAR/DAR/1/rest/adresse",
                        "Husnummer"       => "/DAR/DAR/1/rest/husnummer",
                        "Postnummer"      => "/DAR/DAR/1/rest/postnummer",
                        "Navngivenvej"    => "/DAR/DAR/1/rest/navngivenvej",
                        "Navngivenvejkommunedel"
                                          => "/DAR/DAR/1/rest/navngivenvejkommunedel",
                        "Supplerendebynavn"
                                          => "/DAR/DAR/1/rest/supplerendebynavn?"
                      },
                      "authorization"     => "",
                      "defaultparameter"  => "?format=json&count=True",
                      "historikparameter" => "&VirkningFra=0001-01-01T00:00:00&VirkningTil=9999-01-01T00:00:00"
                  },
                  "BBR" => {
                    "methods"             => {
                        "Bygning"         => "/BBR/BBRPublic/1/rest/bygning",
                        "BBRSag"          => "/BBR/BBRPublic/1/REST/bbrsag",
                        "Ejendomsrelation"=> "/BBR/BBRPublic/1/rest/ejendomsrelation",
                        "Enhed"           => "/BBR/BBRPublic/1/rest/enhed",
                        "Grund"           => "/BBR/BBRPublic/1/rest/grund",
                        "Tekniskanlaeg"   => "/BBR/BBRPublic/1/rest/tekniskanlaeg"
                    },
                      "authorization"     => "?username=ONCVAXSNFU&password=Nuga10s..",
                      "defaultparameter"  => "&format=json&count=True",
                      "historikparameter" => "&VirkningFra=0001-01-01T00:00:00&VirkningTil=9999-01-01T00:00:00"
                   }
                );
my $defaultparameter    = "?format=json&count=True";
my $historikparameters  = "&VirkningFra=0001-01-01T00:00:00&VirkningTil=9999-01-01T00:00:00";
my %hosts = ( "Prod01" => "https://services.datafordeler.dk",
              "Test03" => "https://test03-services.datafordeler.dk",
              "Test04" => "https://test04-services.datafordeler",
              "Test06" => "https://test06-services.datafordeler");
#
# Main
#

sub buildRequest{
  my $register = shift;
  my $method   = shift;
  my $mode     = shift || 0; # Mode 0 - aktuel, 1 - history
  if ($mode == 0 ) {
    return $requests{$register}{methods}{$method}.
           $requests{$register}{authorization}.
           $requests{$register}{defaultparameter}
  }
  else {
    return $requests{$register}{methods}{$method}.
           $requests{$register}{authorization}.
           $requests{$register}{defaultparameter}.
           $requests{$register}{historikparameter}
  }
}

$|=1;
my $register = "DAR";
my $countfile= "";
my $env      = "Prod01";

GetOptions( "register=s"          => \$register,
            "countfile=s"         => \$countfile,
            "env=s"               => \$env);

if ($countfile eq "" ) {
  $countfile = $register.".cnt";
}
if ( ! defined $hosts{$env} ) {
  die "Unknown environment\n"
}
my $host = $hosts{$env};

if (! defined($requests{$register})) {
  die "$register is not supported\n"
}
open(my $cntfh, ">$countfile") or die "Unable to create $countfile";

my $client = REST::Client->new();
$client->setHost($host);

for my $method ( sort keys %{$requests{$register}{methods}}) {
  my @result;
  my $datetime = strftime("%F %X",localtime);
  for my $mode (0..1) {
    my $request = buildRequest($register,$method,$mode);
    printf "Request %s\n", $request;
    $client->GET( $request);
    $result[$mode] = decode_json $client->responseContent();

  }
  printf $cntfh "%s,%s,%s,%s\n", $datetime, $method, $result[0]->{count} ,$result[1]->{count};
  printf        "%s,%s,%s,%s\n", $datetime, $method, $result[0]->{count} ,$result[1]->{count};

}

close $cntfh