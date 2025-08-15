#!/usr/bin/perl

use threads;
use threads::shared;

my @foo : shared;
my $bar : shared = \@foo;

$foo[0] = 1;
print "M1: ref($bar) $foo[0]\n";
bless $bar, 'BAR';

my $thr = threads->new(\&tsub);

$foo[0] = &share([2]);

while (1) {
  print "M*\n";
  sleep 1;
  }

sub tsub () {
  for my $i (1..100) {
    print "T$i: ref($bar) $foo[0]\n";
    sleep 1;
    }
  }


