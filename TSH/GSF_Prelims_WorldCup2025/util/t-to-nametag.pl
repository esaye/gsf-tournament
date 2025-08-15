#!/usr/bin/perl

use strict;
use warnings;

use lib './lib/perl';
use TFile;

sub Main ();
sub Munge ();

Main;

sub Main () {
  @::ARGV = ('a.t') unless @::ARGV;
  my $div = $::ARGV[0];
  print "First\tLast\tRating\tNumber\tDivision\tTeam\n";
  for my $fname (@::ARGV) {
    my $tf = new TFile $fname;
    my $divname = uc $fname;
    $divname =~ s/\..*//;
    $divname =~ s!^.*/!!;
    my (@ps) = (undef);
    while (my $p = $tf->ReadLine()) {
      push(@ps, $p);
      }
    $tf->Close();
    for my $i (1..$#ps) {
      my $p = $ps[$i];
      my ($last, $first) = split(/, /, $p->{'name'}, 2);
      print "$first\t$last\t$p->{'rating'}\t$i\t$divname\t";
      print ($p->{'etc'}{'team'}[0] || '');
      print "\n";
      }
    }
  }

