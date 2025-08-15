#!/usr/bin/perl

use strict;
use warnings;

use lib qw(./lib/perl);
use TSH::Utility::CSV;

sub Main ();

Main;

sub Main () {
  $/ = undef;
  my $slurp = <>;
  my ($rowsp) = TSH::Utility::CSV::Decode $slurp, {};
  my (@out);
  for my $i (1..$#$rowsp) {
    my $rowp = $rowsp->[$i];
    my ($pid, $names, $team, $score) = @$rowp;
    die "duplicate ID $pid" if $out[$pid];
    my (@names) = split(/\s*,\s*/, $names);
    die "Too many players: $names" unless @names < 3;
    my @givens;
    for my $name (@names) {
      my (@words) = split(/\s+/, $name);
      my $surname = pop @words if @words > 1;
      push(@givens, "@words");
      }
    my $board = int(($pid-1)/2) + 1;
    my $oid = $board*4 - 1 - $pid;
    $oid = 0 if $i == $#$rowsp && $oid > $pid;
    $score ||= '';
#   warn "Added $pid $oid $board $score";
    $out[$pid] = join(', ', @names) . " 0 $oid ; $score ; board $board ; team $team ; pname " . join(", ", @givens) . "\n";
#   warn "Added $pid";
    }
# binmode STDOUT, ':encoding(cp874)';
  for my $i (1..$#out) {
    if (my $out = $out[$i]) {
      print $out;
      }
    else {
      my $board = int(($i-1)/2) + 1;
      my $oid = $board*4 - 1 - $i;
      print "MISSING PLAYER 0 $oid ; -999\n";
      }
    }
  }

