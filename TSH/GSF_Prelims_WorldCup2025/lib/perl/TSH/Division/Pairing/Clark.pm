#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::Pairing::Clark;

use strict;
use warnings;

=pod

=head1 NAME

TSH::Division::Pairing::Clark - Clark algorithm for round robin pairings

=head1 SYNOPSIS

  TSH::Division::Pairing::Clark::Pair($division, $index);

=head1 ABSTRACT

This module gives the Clark algorithm for computing round robin pairings in
a tournament.

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

=item PairGroup($psp, $index)

Add the $index round of Clark pairings to the players listed in @psp.

=cut

sub PairGroup ($$) {
  my $psp = shift;
  my $opp1 = shift;

  my $dp = $psp->[0]->Division();
  my $round0 = $psp->[0]->CountOpponents();
  my $n = scalar(@$psp);
# print "N=$n\n";

  my $odd = $n % 2;
  if ($odd) { # if division is odd, pair as per n+1 and fix up as we go
    $n++;
    $opp1 = $n if $opp1 == 0; # allow user to specify 
    }

  if ($odd && $opp1 == $n) {
    $dp->Pair($psp->[0]->ID(), 0, $round0);
#   print "gave bye to " . $psp->[0]->ID() . " in $round0\n";
    }
  else {
    $dp->Pair($psp->[0]->ID(), $psp->[$opp1-1]->ID(), $round0);
#   print "paired " . $psp->[0]->ID() . " and " . $psp->[$opp1-1]->ID() . " in $round0\n";
    }
  for my $id (2..$n - $odd) {
    next if $id == $opp1;
    my $oppid = (2*$opp1 - $id + $n - 1) % ($n - 1);
    $oppid += $n-1 if $oppid <= 1;
#   print "id=$id oppid=$oppid opp1=$opp1 n=$n\n";
    die "Assertion failed (id=$id opp1=$opp1 n=$n oppid=$oppid)" 
      unless $oppid > 1 && $id != $oppid && $oppid <= $n;
    $oppid = 0 if $odd && $oppid == $n;
    $dp->Pair($psp->[$id-1]->ID(), 
      $oppid == 0 ? 0 : $psp->[$oppid-1]->ID(), $round0) 
      if $id > $oppid;
#   print "paired " . $psp->[$id-1]->ID() . " and " . ($oppid == 0 ? 0 : $psp->[$oppid-1]->ID()) . " in $round0\n";
    }
  $dp->Synch();
  }

=back

=cut

=head1 BUGS

The quality of the pairings could be improved substantially 
by rearranging the order
in which players sit in their Clark circle so that when #1 plays #2,
KOTH pairings result.

=cut

1;
