#!/usr/bin/perl

# Copyright (C) 2007-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::Pairing::Berger;

use strict;
use warnings;

use TSH::Utility qw(Debug);

=pod

=head1 NAME

TSH::Division::Pairing::Berger - Berger algorithm for round robin pairings

=head1 SYNOPSIS

  TSH::Division::Pairing::Clark::PairGroup(\@players, $opp1, \%options);

=head1 ABSTRACT

This module gives an implementation of the Berger algorithm for
scheduling round robin pairings.  It optionally permits the
assignment of final round pairings in the KOTH style preferred
by Scrabble players.

=cut

sub ComputeBergerRound ($);
sub MakeSchedule3 (\@);
sub PairGroup ($$;$);
sub PairGroups ($$);
sub PairGroups3 ($);

=head1 DESCRIPTION

=over 4

=cut
 
=item $pnsp = ComputeBergerRound(\%options);

Computes one round of a Berger-style round-robin pairing schedule,
returning a reference to a list of 1-based opponent numbers (0 for bye)
or undef on failure.  See C<PairGroup> for a usage example.
Options are as follows.

player_count: (required) number of players in schedule

first_opponent: (required) 1-based opponent number for first player

assign_firsts: (optional) if 0, do not care about starts and replies. If 1, ensure that starts and replies are balanced after every even round. If -1, do same but reverse starts and replies. If 2, make sure that player 2 starts vs. 1; if -2, make sure that player 2 replies vs. 1.

random: (required if assign_firsts is -1 or 1) a fixed random boolean value, used to
determine which side goes first.

=cut

sub ComputeBergerRound ($) {
  my $optionsp = shift;
  my $n = $optionsp->{'player_count'} || return undef;
  my $assign_firsts = $optionsp->{'assign_firsts'};
  my $opp1 = $optionsp->{'first_opponent'};
  my $random = $optionsp->{'random'} || 0;

  my $odd = $n % 2;
  if ($odd) { # if division is odd, pair as per n+1 and fix up as we go
    $n++;
    $opp1 = $n if $opp1 == 0; # allow user to specify 0 or $n in this case
    }
  if ($opp1 > $n) { warn "first opponent too big: $opp1 > $n"; return undef; }

  # Set up Berger Round 1
  my @table = ();
  # @table = (3 5 ... n-1 n ... 6 4 2)
# warn "@table"; for my $opp1 (2..$n) {
  for (my $i = $n; $i > 0; ) { push(@table, $i--); unshift(@table, $i--); }
  shift @table;
  my $opp1index = $opp1 % 2 ? int($opp1/2) - 1 : (@table - int($opp1/2));
# warn "$opp1 $opp1index";

  # Roll @table to get this round's pairings
  push(@table, splice(@table, 0, $opp1index));
  
  # Add in player 1
  if ($opp1index % 2) { push(@table, shift @table); unshift(@table, 1); }
  else { push(@table, 1); }
# warn "$opp1: @table"; @table = (); } die;

# print "RRPG 1: 1\@$p1index $opp1\@$o1index $table[$oppnindex]\@$oppnindex $n=$#table+1 @table\n";

  # Randomize starts and replies
  if ($assign_firsts && ( # don't bother unless assigning firsts
      # In both Scrabble and chess, the default arrangement has 1 start vs. 2
      ($assign_firsts > 0 # respect user's choice of assign_firsts sign
	xor (abs($assign_firsts) != 2 && $random)))) # but randomize if assign_firsts is +/-1 and random
    {
    @table = reverse @table;
#   print "RRPG 1a: @table\n";
    }

  return \@table;
  }

=item $schedule = MakeSchedule3(\@players);

Return a schedule for for C<@players> to play over three rounds.

=cut

sub MakeSchedule3 (\@) {
  my $groupp = shift;
  # TODO: think about avoiding giving byes to unrated players
# warn scalar(@$groupp);
  my $schedule = (
    undef,
    [[undef],[undef],[undef]],
    [[1,1,1],[0,0,0]],
    [[2,undef,0],[1,0,undef],[undef,2,1]],
    [[3,2,1,0],[2,3,0,1],[1,0,3,2]],
    [[4,3,undef,1,0],[2,4,0,undef,1],[1,0,3,2,undef]],
    [[5,2,1,4,3,0],[3,4,5,0,1,2],[1,0,3,2,5,4]],
    [[5,3,4,1,2,0,undef],[2,6,0,4,3,undef,1],[1,0,3,2,undef,6,5]]
    )[scalar(@$groupp)];
# warn join(';', map { join (',', @$_) } @$schedule);
  return $schedule;
  }

=item PairGroup(\@players, $opp1, \%options);

Add one round of pairings to the players listed in C<@players>.
The zeroth player in the list will be paired with the C<($opp1-1)>'th,
and calling this subroutine with C<$opp1> set successively to
each of C<2..@players> will result in a round robin.

If C<$options{'assign_firsts'}> and C<config assign_firsts> are both set,
starts or replies (white or black in the original chess terminology)
are assigned according to a fixed schedule.  You might not want to set
this option if you are not pairing a complete round robin.
If C<$options{'assign_firsts'}> is set to C<-1>, starts or replies
are assigned in the opposite way to what would normally be done,
so as to accommodate balanced multiple round robins.

If C<$options{'assign_firsts'}> is set to C<2> or C<-2>, starts and replies
are assigned so that player 2 respectively starts or replies versus 
player 1.  

If C<$options{'koth'}> is set, the round in which C<$opp1==2> will
be KOTH, and all other rounds will be adjusted accordingly.

=cut

# Replaced all of the following as it looked easier to replace
# the code rather than rewrite it to get balanced starts/replies.
#
# Here's the basic idea behind what we're doing, for the case $n == 8.
# 
# Seating: 7 5 3 1 2 4 6 (Scrabble)
# 
# R/S not working out here, still investigating. What order are these rounds in?!
# 
# 7r 8s   8r 2s   5r 8s   8r 4s   3r 8s   8r 6s   1r 8s
# 5s 6r   4s 1r   3s 7r   6s 2r   1s 5r   7s 4r   2s 3s
# 3r 4s   6r 3s   1r 6s   7s 1s   2s 7s   5s 2s   4s 5s
# 1s 2r   7s 5r   2s 4r   5s 3r   4s 6r   3s 1r   6s 7s
# 
# 8 vs. 7 1 6 3 4 5 2
# 1 vs. 2 8 3 5 7 6 4
# 
# To pair 8-2, roll to get 2467531, shift to leave 467:531 (4-1 6-3 7-5),
# 467 starting.  Because 2 is in the second half of 7531246, 8 starts.
# 
# 1-x when 8-y where y is equidistant from 1 and x in seating.
# 
# To find when 1-5, because their seating differs by an even number
# and 3 is halfway between them, pair 8-3.
# 
# To find when 1-6, who sit at positions 3 and 6, compute 
# ((3 + 6 + 7) / 2) % 7 = 1 and pair 8 with the one in the
# 1st position: 8-5.
# 
# Seating 1 2 3 4 5 6 7 (Chess)
# 
# 1 8   8 5   2 8   8 6   3 8   8 7   4 8
# 2 7   6 4   3 1   7 5   4 2   1 6   5 3
# 3 6   7 3   4 7   1 4   5 1   2 5   6 2
# 4 5   1 2   5 6   2 3   6 7   3 4   7 1
# 
# 8 vs. 1 5 2 6 3 7 4
# 1 vs. 8 2 3 4 5 6 7
# 
# To pair 8-2, roll to get 2345671, shift to leave 345:671 (3-1 4-7 5-6),
# 345 starting.  Because 2 is in the first half of 1234567, 2 starts.

sub PairGroupOld ($$;$) {
  my $psp = shift;
  my $opp1 = shift;
  my $options = shift || {};

  my $dp = $psp->[0]->Division();
  my $round0 = $psp->[0]->CountOpponents();
  my $config = $dp->Tournament()->Config();
  my $assign_firsts 
    = $config->Value('assign_firsts') && $options->{'assign_firsts'};
  my $koth = $options->{'koth'};
  my $n = scalar(@$psp);
# print "N=$n\n";

  my $odd = $n % 2;
  if ($odd) { # if division is odd, pair as per n+1 and fix up as we go
    $n++;
    $opp1 = $n if $opp1 == 0; # allow user to specify 0 or $n in this case
    }
  die "opp1 too big: $opp1 > $n" if $opp1 > $n;

  # Set up Berger Round 1
  my @table = ();
  my $p1index;
  my $o1index;
  if ($koth) { # Scrabble style
    # @table = (n-1... 7 5 3 1 2 4 6 8 ...n-2)
    for (my $i = 1; $i < $n; ) {
      unshift(@table, $i++);
      push(@table, $i++);
      }
    pop @table;
    $p1index = int(@table/2);
    $o1index = $opp1 % 2 
      ? $p1index - int($opp1/2) 
      : $p1index + int($opp1/2);
    }
  else { # Chess style
    @table = 1..($n-1);
    $p1index = 0;
    $o1index = $opp1 - 1;
    }

  # Find who plays $n
  my $oppnindex;
  if ($opp1 == $n) { $oppnindex = $p1index; }
  else {
    $oppnindex = $p1index + $o1index;
    $oppnindex += $n - 1 if $oppnindex % 2;
    $oppnindex = ($oppnindex / 2) % ($n - 1);
    }

  # Roll @table to get this round's pairings
  push(@table, splice(@table, 0, $oppnindex));
  
  # Add in player n
  if ($oppnindex % 2) {
    push(@table, shift @table);
    unshift(@table, $n);
    }
  else {
    push(@table, $n);
    }
# warn "$opp1: @table";

# print "RRPG 1: 1\@$p1index $opp1\@$o1index $table[$oppnindex]\@$oppnindex $n=$#table+1 @table\n";

  # Randomize starts and replies
  if ($assign_firsts 
    && (
      abs($assign_firsts) == 2
        # In both Scrabble and chess, the default arrangement has 1 start vs. 2
        ? ($assign_firsts > 0)
	: ($assign_firsts > 0 xor $config->Value('random') > 0.5 xor (ord($dp->Name()) % 2 == 0)))) {
    @table = reverse @table;
#   print "RRPG 1a: @table\n";
    }

  while (@table) {
    my (@p) = (shift @table, pop @table);
    my (@pid);
    for my $i (0..1) {
      if ($odd && $p[$i] == $n) { 
	$p[$i] = undef;
	$pid[$i] = 0;
        }
      else { 
	$p[$i] = $psp->[$p[$i]-1];
	$pid[$i] = $p[$i]->ID();
        }
      }
#   print "RRPG 3: pairing $pid[0] $pid[1] $assign_firsts $round0\n";
    $dp->Pair($pid[0], $pid[1], $round0);
    if ($assign_firsts) {
      if ($p[0] && $p[1]) {
	$p[0]->First($round0, 1);
	$p[1]->First($round0, 2);
#	print "RRPG 3a: $p[0]{'id'} first\n";
        }
      elsif ($p[0]) {
	$p[0]->First($round0, 0);
        }
      elsif ($p[1]) {
	$p[1]->First($round0, 0);
        }
      }
    }

  $dp->Synch();
  }

sub PairGroup ($$;$) {
  my $psp = shift;
  my $opp1 = shift;
  my $options = shift || {};
# warn join ("\n", map { $_->Name() } @$psp);
  # We always specify RR pairings cooked to end up with a final KOTH
  # If you don't, we're not responsible.
  if (!$options->{'koth'}) { return PairGroupOld($psp, $opp1, $options); }

  my $dp = $psp->[0]->Division();
  my $round0 = $psp->[0]->CountOpponents();
  my $config = $dp->Tournament()->Config();
  my $assign_firsts = $config->Value('assign_firsts') && $options->{'assign_firsts'};

  my $n = scalar(@$psp);
# print "N=$n\n";

  my (@table) = @{ComputeBergerRound({
    'assign_firsts' => $assign_firsts,
    'first_opponent' => $opp1,
    'player_count' => $n,
    # note () around xor necessary due to very low operator precedence
    'random' => ($config->Value('random') > 0.5 xor (ord($dp->Name()) % 2 == 0)),
    })};

  my $odd = $n % 2; $n += $odd;
# warn "@table";
  my $swap;
  while (@table) {
    my (@p) = (shift @table, pop @table);
    if (defined $swap) { 
      $swap = 1 - $swap; 
      if ($swap) {
	@p[0,1] = @p[1,0];
#	warn "Swapped @p[0,1]";
	}
      }
    else { $swap = 1; }
    my (@pid);
    for my $i (0..1) {
      if ($odd && $p[$i] == $n) { 
	$p[$i] = undef;
	$pid[$i] = 0;
        }
      else { 
	$p[$i] = $psp->[$p[$i]-1];
	$pid[$i] = $p[$i]->ID();
        }
      }
#   print "RRPG 3: pairing $pid[0] $pid[1] $assign_firsts $round0\n";
    $dp->Pair($pid[0], $pid[1], $round0);
    if ($assign_firsts) {
      if ($p[0] && $p[1]) {
	$p[0]->First($round0, 1);
	$p[1]->First($round0, 2);
#	print "RRPG 3a: $p[0]{'id'} first\n";
        }
      elsif ($p[0]) {
	$p[0]->First($round0, 0);
        }
      elsif ($p[1]) {
	$p[1]->First($round0, 0);
        }
      }
    }

  $dp->Synch();
  }

=item PairGroups(\@groups, $nrounds);

Given a list C<@groups> of references to sublists of players,
pair each sublist within itself for C<$nrounds> rounds, using
a possibly depleted round-robin schedule.

=cut

sub PairGroups ($$) {
  my $groupsp = shift;
  my $nrounds = shift;

  if ($nrounds == 1) {
    my $dp = $groupsp->[0][0]->Division();
    for my $groupp (@$groupsp) {
      my $p1 = $groupp->[0];
      my $p2 = $groupp->[1];
      $dp->Pair($p1?$p1->ID():0, $p2?$p2->ID():0, $p1->CountOpponents(), 1);
      }
    $dp->Synch();
    return;
    }
  if ($nrounds == 3) {
    return PairGroups3 $groupsp;
    }
  my (@rboard) = (0) x $nrounds;
  return unless @$groupsp;
  my $dp = $groupsp->[0][0]->Division();
  my %reserved = map { $_ => 1 } $dp->ReservedBoards();
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $orderp = $config->Value('round_robin_order') || [reverse(2..$nrounds+1)];
  my $reservations = $config->Value('reserved');
  $reservations = $reservations->{$dp->Name()} if $reservations;
  $reservations = [] unless $reservations;
  Debug 'BERGER', 'PairGroups(%d group(s))', scalar(@$groupsp);
# for my $gp (@$groupsp) { print $gp, "\n"; }
  for my $group (sort { ($a ? $a->[0]->ID() : 0) <=> ($b ? $b->[0]->ID() : 0); } @$groupsp) {
    for my $r0 (0..$nrounds-1) {
      if ($#$group == $nrounds) {
        Debug 'BERGER', '$#$group=%d, $nrounds=%d, $r0=%d', $#$group, $nrounds, $r0;
	TSH::Division::Pairing::Berger::PairGroup(
	  $group,
	  $orderp->[$r0],
	  {
	    'assign_firsts' => 1,
	    'koth' => 1,
	  },
	  );
	}
      else {
	# Earlier version had 2 for 2.5 and gave freaky floating-point conversion errors for 19 players and 19 rounds
	my $rrround = int(2.5+(@$group+(@$group%2)-2)*(1-$r0/($nrounds-1)));
        Debug 'BERGER', '$#$group=%d, $nrounds=%d, $r0=%d, $rrround=%d', $#$group, $nrounds, $r0, $rrround;
	# should be 2 when $r0 == $nrounds - 1
	# should be @$group (rounded up to even) when $r0 == 0
#	warn "r0=$r0 rrr=$rrround\n";
	TSH::Division::Pairing::Berger::PairGroup(
	  $group,
	  $rrround,
	  {
	    'assign_firsts' => 0,
	    'koth' => 1,
	  },
	  );
        }

      for my $i (0..$#$group) {
	my $p = $group->[$i];
	my $pid = $p->ID();
	my $opp = $p->Opponent($r0);
	my $oid = $p->OpponentID($r0);
	next if $oid && $pid > $oid;
#	Debug 'BERGER', "$pid vs $oid in %d at ?%d", $r0+1, $rboard[$r0]+1;
	if ($oid) {
	  my $board;
	  my $presboard = $reservations->[$pid];
	  my $oresboard = $reservations->[$oid];
	  if ($presboard) {
	    if ($oresboard && $presboard != $oresboard) {
	      $tournament->TellUser('eresconf', $p->PrettyName(), $opp->PrettyName());
	      }
	    $board = $presboard;
	    }
	  elsif ($oresboard) {
	    $board = $oresboard;
	    }
	  else {
	    while ($reserved{$board = ++$rboard[$r0]}) { }
	    }
	  $group->[$i]->Board($r0, $board);
	  $opp->Board($r0, $board) if $opp;
	  }
	}
      }
    }
  }

=item PairGroups3(\@groups);

Called to handle the specific case C<$nrounds==3> in C<PairGroups>
more carefully.

=cut

sub PairGroups3 ($) {
  my $groupsp = shift;
  my (@rboard) = (0,0,0);
  return unless @$groupsp;
  my $dp = $groupsp->[0][0]->Division();
  my %reserved = map { $_ => 1 } $dp->ReservedBoards();
  my $tournament = $dp->Tournament();
  my $reservations = $tournament->Config()->Value('reserved');
  $reservations = $reservations->{$dp->Name()} if $reservations;
  $reservations = [] unless $reservations;
# for my $gp (@$groupsp) { print $gp, "\n"; }
  for my $group (sort { ($a ? $a->[0]->ID() : 0) <=> ($b ? $b->[0]->ID() : 0); } @$groupsp) {
    my $schedule = MakeSchedule3(@$group);
    my $base_r0 = $group->[0]->CountOpponents();
# warn "@$schedule";
    for my $r0 (0..2) {
      my $roundsched = $schedule->[$r0];
      for my $i (0..$#$roundsched) {
	my $opp;
	my $oid;
	my $p = $group->[$i];
	my $pid = $p->ID();
	if (defined(my $oii = $roundsched->[$i])) {
	  $opp = $group->[$oii];
	  $oid = $opp->ID();
	  }
	else {
	  $opp = undef;
	  $oid = 0;
	  }
	next if $oid && $pid > $oid;
 	Debug 'BERGER', "$pid vs $oid in %d at ?%d", $r0+1, $rboard[$r0]+1;
	$dp->Pair($pid, $oid, $base_r0+$r0, 0);
	if ($oid) {
	  my $board;
	  my $presboard = $reservations->[$pid];
	  my $oresboard = $reservations->[$oid];
	  if ($presboard) {
	    if ($oresboard && $presboard != $oresboard) {
	      $tournament->TellUser('eresconf', $p->PrettyName(), $opp->PrettyName());
	      }
	    $board = $presboard;
	    }
	  elsif ($oresboard) {
	    $board = $oresboard;
	    }
	  else {
	    while ($reserved{$board = ++$rboard[$r0]}) { }
	    }
	  $group->[$i]->Board($r0, $board);
	  $opp->Board($r0, $board) if $opp;
	  }
	}
      }
    }
  }

=back

=cut

1;
