#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::Pairing::Clark;

use strict;
use warnings;

=pod

=head1 NAME

TSH::Division::Pairing::Clark - Modified Clark algorithm for round robin pairings

=head1 SYNOPSIS

  TSH::Division::Pairing::Clark::Pair($division, $index);

=head1 ABSTRACT

This module gives a modification of Clark algorithm for computing
round robin pairings in a tournament.  The modification consists 
of reordering the players so that when players 1 and 2 face each
other, the rest of the players play in KOTH fashion.

=cut

sub Pair ($$);

=head1 DESCRIPTION

=over 4

=cut
 
=item Pair($dp, $index)

Add the $index round of Clark pairings to Division $dp.

Deprecated in favour of PairGroup, because Pair does not check
player activity status.

# Add one round of Clark pairings to a division.  Clark pairings are
# described in the NSA Directors' Manual, and are a way of generating
# not especially high-quality round robin pairings.  This subroutine
# takes two arguments: a division reference and the opponent number for
# player #1.  Enumerating all the possible opponents for player #1 will
# result in a complete round robin schedule.

=cut

sub Pair ($$) {
  my $dp = shift;
  my $opp1 = shift;
  PairGroup([$dp->Players()], $opp1);
  }

=item PairGroup($psp, $index[, $assign_firsts])

Add one round of pairings to the players listed in C<@$psp>.
The zeroth player in the list will be paired with the C<($index-1)>'th,
and calling this subroutine with C<$index> set successively to
each of C<2..@$psp> will result in a round robin.
If C<$assign_firsts> and C<config assign_firsts> are both set,
assign starts or replies according to a fixed schedule.
(You might not want to do so in the last 'KOTH' round, or if
you are pairing a depleted RR.)

=cut

sub PairGroup ($$;$) {
  my $psp = shift;
  my $opp1 = shift;
  my $assign_firsts = shift;

  my $dp = $psp->[0]->Division();
  my $round0 = $psp->[0]->CountOpponents();
  my $config = $dp->Tournament()->Config();
  $assign_firsts &&= $config->Value('assign_firsts');
  my $n = scalar(@$psp);
# print "N=$n\n";

  my $odd = $n % 2;
  if ($odd) { # if division is odd, pair as per n+1 and fix up as we go
    $n++;
    $opp1 = $n if $opp1 == 0; # allow user to specify 0 or $n in this case
    }

  my @table = ();
  for (my $i = $n; $i > 2; ) {
    push(@table, $i--);
    unshift(@table, $i--);
    }
  push(@table, 2);
  # @table now reads 3 5 7 9 ... 8 6 4 2
# print "RRPG 1: @table\n";
  # roll @table so that $opp1 is at the end
  my $offset;
  if ($opp1 % 2) {
    # roll left
    $offset = int($opp1/2);
    push(@table, splice(@table, 0, $offset));
    }
  elsif ($offset = int($opp1/2) - 1) {
    # roll right
    unshift(@table, splice(@table, -$offset));
    }
  unshift(@table, 1);
  # @table now reads p1 p2 p3 ... o3 o2 o1
# print "RRPG 2: $offset, @table\n";

  my (@which_starts) = $offset % 2 ? (1,2) : (2,1);
  while (@table) {
    my (@p) = (shift @table, pop @table);
    my (@pid);
    for my $i (0..1) {
      if ($odd && $p[$i] == $n) { 
	$p[$i] = undef;
        }
      else { 
	$p[$i] = $psp->[$p[$i]-1];
	$pid[$i] = $p[$i]->ID();
        }
      }
#   print "RRPG 3: pairing $pid[0] $pid[1] $round0\n";
    $dp->Pair($pid[0], $pid[1], $round0);
    if ($assign_firsts) {
#     print "RRPG 4: $pid[0] $which_starts[0] $pid[1] $which_starts[1]\n";
      $p[0]->First($round0, $which_starts[0]);
      $p[1]->First($round0, $which_starts[1]);
      }
    }

  $dp->Synch();
  }

=back

=cut

1;
