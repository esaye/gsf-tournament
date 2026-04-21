#!/usr/bin/perl

# make-rr: make round-robin tables
# Copyright (C) 2003 by John J. Chew, <jjchew@math.utoronto.ca>
# 
# This Perl script generates round-robin pairing tables, given the number
# of players and any round pairings that are required to be in the tables
# (either because you want to omit them (see example), or because you've
# already gone ahead and blithely paired them).
#
# Combinatorialists refer to this procedure as "completing Latin squares",
# and computational combinatorialists know that it is an "NP-complete"
# (time-intensive) problem.

use strict;
use warnings;

use lib "$ENV{HOME}/lib/perl";
use lib './lib/perl';
use TFile;

require 'getopts.pl';
use vars qw($opt_q $count);
$opt_q = 0;
$count = 0;

### configuration information - change these lines as you please
# $n is the number of players.  
my $n = 10;

# I wrote this script because Craig Rowland asked me for reasonable
# pairings for a 7-round tournament for 9 players.  Yeesh.  So we pretend
# that we have ten players, and anyone that is paired with player #9 gets
# a bye.  This ensures that no one gets more than one bye in the tournament.
# We then try to think of two more rounds that we could omit in order to
# fit the schedule, and choose pairings in which the top two players get
# byes, and everyone else plays Swissily.  
#
# So each of the rows of numbers below is a list of opponents in player
# number order.  The first number in each row is who player #0 plays,
# the second number is who player #1 plays, and so on.  If you don't want
# the two omittable* rounds that I mentioned, then delete the last two
# lines.  Keeping the first line is a good idea though, if you don't want
# players to be paired with themselves!
my (@table) = (
# [0,1,2,3,4,5,6,7,8,9], # identity round 
# [9,5,6,7,8,1,2,3,4,0], # omit for 8 rounds, 9 players
# [5,9,7,8,6,0,4,2,3,1], # omit for 7 or 8 rounds, 9 players
# [0..11],
# [1,0,3,2,5,4,7,6,11,10,9,8],
# [map { $_ - 1} qw()],
[0..9],
[7,2,1,4,3,6,5,0,9,8],
[6,3,8,1,7,9,0,4,2,5],
[5,8,7,9,6,0,4,2,1,3],
  );
### end configuration information
BEGIN {
  }

sub Main ();
sub Print (\@);
sub Recursion (\@;\@);
sub Usage ();

Main;

sub Main () {
  &Getopts('q-:') or Usage;
  $| = 1 if $opt_q;
  Recursion @table;
  print "\n" if $opt_q;
  }

sub Print (\@) {
  if ($opt_q) { 
    ++$count;
    print "$count\r";
    return;
    }
  my $tablep = shift;
  for my $player (0..$n-1) {
    for my $round (0..$#$tablep) {
      printf "%3d ", $tablep->[$round][$player]+1;
      }
    print "\n";
    }
  print "\n";
  }

# if we can add another round to the table
#   if that completes the table, then print it
#   else apply recursion 
sub Recursion (\@;\@) {
  my $tablep = shift;
  my $unpairedp = shift;

# print "recursion applied, \$#\$tablep=$#$tablep\n";

  # calculate which pairings are available for each player, if not given
  unless ($unpairedp) {
    for my $player (0..$n-1) {
      my (%unpaired) = map { $_ => 1 } (0..$n-1);
      for my $round (0..$#$tablep) {
        delete $unpaired{$tablep->[$round][$player]};
        }
      push(@$unpairedp, \%unpaired);
#     print "$player has not yet played: ", join(' ', keys %unpaired), "\n";
      }
    }

  # now try filling out the round table with allowed pairings
  my (@round) = ();
  my $cursor = 0; # points to player that next needs work
  my %available = map { $_ => 1 } (0..$n-1);
  my (@opps_to_try) = ([]) x $n;
  while (1) {
#   print "start of big loop, cursor=$cursor\n";
    # find out who's left that $cursor can play
    my $opps_to_try = $opps_to_try[$cursor];
    # if we don't have an opp list ready, because we just got to this
    # player, then generate it
    unless (@$opps_to_try) {
      $opps_to_try = $opps_to_try[$cursor] = [keys %{$unpairedp->[$cursor]}];
      }
    # skip over anyone that has already been paired this round
    while (@$opps_to_try && !$available{$opps_to_try->[0]}) {
      shift @$opps_to_try;
      }
    # try the next available opponent for $cursor
    my $opp = shift @$opps_to_try;
    # if there is an opponent for $cursor, pair them
    if (defined $opp) { 
#     if (@$opps_to_try) { print "$cursor can play $opp (or @$opps_to_try).\n"; } else { print "$cursor can only play $opp.\n"; }
      delete $available{$cursor};
      delete $available{$opp};
      $round[$cursor] = $opp;
      $round[$opp] = $cursor;
      while (defined $round[++$cursor]) { }
      # if we've reached the end of the player list, 
      # use recursion to find another round
      if ($cursor >= $n) {
	push(@$tablep, \@round);
	for my $player (@round) {
	  delete $unpairedp->[$player]{$round[$player]};
	  }
	Print @$tablep if $#$tablep == $n-1;
	Recursion @$tablep, @$unpairedp;
#	print "returned from recursion.\n";
	for my $player (@round) {
	  $unpairedp->[$player]{$round[$player]} = 1;
	  }
	pop(@$tablep);
	}
      # if we're not at the end of the player list, try the next player
      else {
        next;
        }
      }
    else { 
#     print "$cursor can't play anyone.\n";
      }
    # backtrack, either because we ran of opponents for an opponent,
    # or because we successfully paired everyone and want another
    # possible set of pairings
    while (1) {
      if ($cursor == 0) {
#	print "backtracked past player 0.\n";
	return;
	}
      $cursor--;
      last if @{$opps_to_try[$cursor]};
      }
#   print "backtracking to player $cursor.\n";
    $opp = $round[$cursor];
    $available{$cursor} = 1;
    $available{$opp} = 1;
    $round[$cursor] = undef;
    $round[$opp] = undef;
    }
  }

sub Usage () {
  die "Usage: $0 [-q]\n";
  }
