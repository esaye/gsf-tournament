#!/usr/bin/perl

use strict;
use warnings;

use lib '/Users/jjc/local/tsh/lib/perl';
use lib './lib/perl';
use Getopt::Long;
use TFile;

sub Main ();
sub Munge ();

Main;

sub Main () {
  my $event = 'swil2012';
  my $dn = 1;
  my $result = GetOptions(
    'e=s' => \$event,
    'd=s' => \$dn,
    );
  @::ARGV = ('a.t') unless @::ARGV;
  for my $fname (@::ARGV) {
    my $tf = new TFile $fname or die "Can't open $fname: $!";
    my (@ps) = (undef);
    while (my $p = $tf->ReadLine()) {
      push(@ps, $p);
      }
    $tf->Close();
    for my $i (1..$#ps) {
      my $p = $ps[$i];
      next if $p->{'etc'}{'off'};
      my ($last, $first) = split(/, /, $p->{'name'}, 2);
      warn "no first name for $p->{'name'}" unless $first;
      $first ||= '';
      print "given=$first\n";
      print "surname=$last\n";
      print "${event}pn=$i\n";
      print "${event}div=$dn\n";
      if ($p->{'etc'}{'team'}) {
	my $team = join(' ', @{$p->{'etc'}{'team'}});
	print "${event}c=$team\n";
	}
      print "\n";
      }
    $dn++;
    }
  }

