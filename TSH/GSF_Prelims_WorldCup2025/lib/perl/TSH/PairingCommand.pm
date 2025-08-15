#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::PairingCommand;

use strict;
use warnings;
use threads::shared;
use TSH::Utility;
use Carp;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);

our (@ISA) = qw(TSH::Command);

my %debug_ids = map { $_ => 1 } qw(1..6);

=pod

=head1 NAME

TSH::PairingCommand - abstraction of a C<tsh> pairing command

=head1 SYNOPSIS

This class supports features common to pairings commands, and
is also used to test class membership.
See its parent class C<TSH::Command> for usage.
  
=head1 ABSTRACT

$setup = $command->SetupForPairing(%options);
$command->TidyAfterPairing($dp);

=cut

sub BPFCategorizePlayers ($$$$);
sub BPFFindMyRank ($$);
sub BPFInit ($);
sub BPFPairGroup ($$$$$$);
sub BPFScoreMe ($$$);
sub CalculateBPFs ($);
sub CalculateBestPossibleFinish ($$);
sub CountGibsons ($$);
sub FlightCapDefault ($);
sub FlightCapNone ($);
sub FlightCapNSC ($);
sub MaxSpread ($;$$);
sub PairAllGibsons ($$$$);
sub PairEvenGibsons ($$);
sub PairOneGibson ($$$$);
sub SetupForPairings ($%);
sub TidyAfterPairing ($$);

=head1 DESCRIPTION

=over 4

=item ($prank, \@high_winners, \@low_winners, \@high_losers, \@low_losers) = BPFCategorizePlayers($r0, $cap, $p, \@players);

For a given player C<$p> belonging to a list of players C<@players>,
find where he is in the list and categorize his opponents according
to whether he would prefer them to win or lose, by a high or low
margin, depending on whether they are ranked above or below him and
above or below the cap.  Omit players who have scores in zero-based
round $r0.

=cut

sub BPFCategorizePlayers ($$$$) {
  my $r0 = shift;
  my $cap0 = shift;
  my $me = shift;
  my $psp = shift;
  my $cap1 = $cap0+1;

  my $myrank = undef;
  my @hi_winners;
  my @lo_winners;
  my @hi_losers;
  my @lo_losers;
  for my $i (0..$#$psp) { 
    my $p = $psp->[$i];
#   Debug 'CBPF', "i=%d pid=%d me=%s r0=%d score=%d scores=%d", $i, $p->ID(), $me->ID(), $r0, ($p->Score($r0)||0), $p->CountScores();
    if ($me eq $p) { $myrank = $i; next; } 
    next if defined $p->Score($r0); # already has a score this round
#   Debug 'CBPF', "Ranking %s (final=%g %+g). Comparing to %s (current=%g %+g).", $me->Name(), $me->{'xfw'}, $me->{'xfs'}, $p->Name(), $p->{'xw'}, $p->{'xs'}; # if $me->ID() eq 100;
    my $cmp = ($p->{'xw'} <=> $me->{'xfw'} - 1) 
      || ($p->{'xs'} <=> $me->{'xfs'});
    # If they can't catch up to my best final record this round, they win
    if ($cmp < 0) {
      if ($i <= $cap0) { 
	unshift(@hi_winners, $p); # from bottom ranked to top
	}
      else { 
	unshift(@lo_winners, $p); # from bottom ranked to top
	}
      }
    else {
      $cmp = ($p->{'xw'} <=> $me->{'xfw'}) 
	|| ($p->{'xs'} <=> $me->{'xfs'});
      # else if they are already past my best they might as well win
      if ($cmp > 0) {
	if ($i <= $cap0) { 
	  unshift(@hi_winners, $p); # from bottom ranked to top
	  }
	else { 
	  unshift(@lo_winners, $p); # from bottom ranked to top
	  }
	}
      # else they can catch up to me now so they had better lose
      else {
	if ($i <= $cap0) { 
	  push(@hi_losers, $p); # from top ranked to bottom
	  }
	else { 
	  push(@lo_losers, $p); # from top ranked to bottom
	  }
	}
      }
    }

#   Debug 'CBPF', '%s. MR: %d. HW: %s. LW: %s. HL: %s. LL: %s.', $me->Name(), $myrank, (join(';',map {$_->{'id'}} @hi_winners)), (join(';',map {$_->{'id'}} @lo_winners)), (join(';',map {$_->{'id'}} @hi_losers)), (join(';',map {$_->{'id'}} @lo_losers)) if $debug_ids{$me->ID()};
  return ($myrank, \@hi_winners, \@lo_winners, \@hi_losers, \@lo_losers);
  }

=item $rank = BPFFindMyRank ($index, \@players);

Find the C<$index>th player in C<@players>'s 1-based rank among them when
sorted by simulated final rank.

=cut

sub BPFFindMyRank ($$) {
  my $index = shift;
  my $psp = shift;
  my $rank = undef;
  my $me = $psp->[$index];
  my @ps = sort { $b->{'xw'}<=>$a->{'xw'} || $b->{'xs'}<=>$a->{'xs'}||($a eq $me ? -1 : $b eq $me ? 1 : 0)} @$psp;
  for my $i (0..$#ps) {
    if ($me eq $ps[$i]) { 
      $rank = $i + 1;
#     my $behind = $i > 0 ? sprintf("%s %g %+d", $ps[$i-1]->TaggedName(), $ps[$i-1]->{'xw'}, $ps[$i-1]->{'xs'}) : 'nobody'; my $after = $i < $#ps ? sprintf("%s %g %+d", $ps[$rank]->TaggedName(), $ps[$rank]->{'xw'}, $ps[$rank]->{'xs'}) : 'nobody'; Debug 'CBPF', '%s can finish ranked %d, %g %+d, behind %s, ahead of %s.', $me->TaggedName(), $rank, $me->{'xfw'}, $me->{'xfs'}, $behind, $after;
      last; 
      }
    }
  Debug 'CBPF', "%3d=>%3d%5.1f%+5d %s #%d", $index+1, $rank, $me->{'xfw'}, $me->{'xfs'}, $me->Name(), $me->ID();
  return $rank;
  }

=item $nrounds = BPFInit(\@players);

Initialise provisional wins, provisional spread and maximum spread
per round for each player in \@players.
Return the maximum number of unscored rounds.

=cut

sub BPFInit ($) {
  my $psp = shift;
  my $nrounds = 0;
  my $config = $psp->[0]->Division()->Tournament()->Config();
  my $max_rounds = $config->Value('max_rounds');
  my $sum_before_spread = $config->Value('sum_before_spread');
  for my $p (@$psp) {
    # current wins
    $p->{'xw'} = $p->Wins();
    # current spread
    $p->{'xs'} = $sum_before_spread ? $p->RoundSum($max_rounds) : $p->Spread();
    # maximum spread per round, number of games left to play
    $p->{'xms'} = MaxSpread ($p->{'xleft'} = $p->UnscoredGames(), $config);
    $nrounds = $p->{'xleft'} if $nrounds < $p->{'xleft'};
    }
# Debug 'CBPF', "np=%d nrounds=%d.", $#$psp+1, $nrounds;
  return $nrounds;
  }

=item BPFPairGroup($groupp, $groupsp, $name, $direction, $me, $bye_spread);

Pair the members of group C<@$groupp> against members of the groups in
C<@$groupsp>, where the groups are listed in preference order.
Within an opponent group, opponents are listed in forward or reverse
preference order depending on the value of C<$direction>.
C<$name> is used only in debugging output.
C<$me> is the player whose best possible finish is currently being computed,
and whose best final finish data may be used to choose pairings.
C<$bye_spread> is assigned to players who are assigned byes.

=cut

sub BPFPairGroup($$$$$$) {
  my $tbps = shift;
  my $grouppp = shift;
  my $name = shift;
  my $direction = shift;
  my $me = shift;
  my $bye_spread = shift;

#   Debug 'CBPF', 'Pairing group %s', $name if $debug_ids{$me->ID()};

  while (@$tbps) {
    my $p = $direction ? shift @$tbps : pop @$tbps;
#     Debug 'CBPF', "Scoring %s (%g %+g)\n", $p->TaggedName(), $p->{'xw'}, $p->{'xs'} if $debug_ids{$me->ID()};
    my $opp;
    for my $groupp (@$grouppp) 
      { if (@$groupp) { $opp = shift @$groupp; last; } }
    if (!$opp) { 
      $p->{'xw'}++;
      $p->{'xleft'}--;
      $p->{'xs'} += $bye_spread; 
      next; 
      }
#     Debug 'CBPF', "... vs. %s (%g %+g)", $opp->TaggedName(), $opp->{'xw'}, $opp->{'xs'} if $debug_ids{$me->ID()};
    # make sure $p is higher-ranked than $opp
    if (($p->{'xw'}<=>$opp->{'xw'}||$p->{'xs'}<=>$opp->{'xs'})<0)
      { ($p, $opp) = ($opp, $p); }
    # $p and $opp have more wins than I can get
    if ($opp->{'xw'} > $me->{'xfw'})
      # who cares: give opp a big win
      { $opp->{'xw'}++; $opp->{'xs'}+=$opp->{'xms'}; $p->{'xs'}-=$p->{'xms'}; }
    # $p has more wins than I can get
    elsif ($p->{'xw'} > $me->{'xfw'}) 
      # write $p off: give him a big win
      { $p->{'xw'}++;$p->{'xs'}+=$p->{'xms'};$opp->{'xs'}-=$opp->{'xms'}; }
    # $p and $opp both have my max wins
    elsif ($opp->{'xw'}== $me->{'xfw'}) 
      # write $p off: give him a big win
      { $p->{'xw'}++;$p->{'xs'}+=$p->{'xms'};$opp->{'xs'}-=$opp->{'xms'}; }
    # $p has <= my max ; $opp has my max -1
    elsif ($opp->{'xw'} == $me->{'xfw'}-1) {
      # if $opp would overtake me by winning
      if ($opp->{'xs'} >= $me->{'xfs'}) {
	# give a big win to whichever one has more spread already
	if ($p->{'xs'} > $opp->{'xs'}) 
      { $p->{'xw'}++;$p->{'xs'}+=$p->{'xms'};$opp->{'xs'}-=$opp->{'xms'}; }
	else 
      { $opp->{'xw'}++;$opp->{'xs'}+=$opp->{'xms'};$p->{'xs'}-=$p->{'xms'}; }
	}
      # give $opp as big a win as possible without overtaking
      else {
	my $spread = $me->{'xfs'} - $opp->{'xs'};
	$opp->{'xw'}++; $opp->{'xs'} += $spread; $p->{'xs'} -= $spread;
	}
      }
    # $p has my max wins, $opp <= my max -2
    elsif ($p->{'xw'} == $me->{'xfw'}) {
      my $delta = $p->{'xs'} - $me->{'xfs'};
      # $p is ahead on spread, but maybe we can bring him down
      if ($delta > 0 && $delta <= $p->{'xms'} * $p->{'xleft'}) 
	# give opp a big win
      { $opp->{'xw'}++;$opp->{'xs'}+=$opp->{'xms'};$p->{'xs'}-=$p->{'xms'}; }
      else 
      # write $p off: give him a big win
      { $p->{'xw'}++;$p->{'xs'}+=$p->{'xms'};$opp->{'xs'}-=$opp->{'xms'}; }
      }
    # $p has <= my max-1, $opp <= my max-2
    else { # give opp the biggest win that doesn't overtake p, to make them easier to overtake
      my $spread;
      # opp is behind p on wins
      if ($opp->{'xw'} < $p->{'xw'}) { 
	# ... by more than 1 win
	if ($opp->{'xw'} < $p->{'xw'} - 1) # so give him max spread
  	  { $spread = $p->{'xms'} }
	# ... by just one win
	else {
	  if ($opp->{'xs'} > $p->{'xs'}) # and is in fact ahead on spread
	    { $spread = 1; } # and should get a tiny win
	  else # but trails on spread, so help him even up
	    { $spread = int((1 + $p->{'xs'} - $opp->{'xs'})/2); $spread = $p->{'xms'} if $p->{'xms'} < $spread }
	  }
        }
      else # opp has same wins but less spread, so help them even out
	{ $spread = int((1 + $p->{'xs'} - $opp->{'xs'})/2); $spread = $p->{'xms'} if $p->{'xms'} < $spread }
      $opp->{'xw'}++; $opp->{'xs'}+=$spread; $p->{'xs'}-=$spread; 
      }
    $opp->{'xleft'}--;
    $p->{'xleft'}--;
    } # while @$tbps
  }

=item BPFScoreMe($me, $opp, $bye_spread);

Assign C<$me> (the current player of interest) and my opponent C<$opp>
ideal scores for the purpose of calculating my best possible finish.

=cut

sub BPFScoreMe ($$$) {
  my $me = shift;
  my $opp = shift;
  my $bye_spread = shift;

#   Debug 'CBPF', 'Scoring me, %s (%g %+g)', $me->TaggedName(), $me->{'xw'}, $me->{'xs'} if $debug_ids{$me->ID()};
  if ($opp) {
    $me->{'xw'}++; $me->{'xs'} += $me->{'xms'}; 
    $me->{'xleft'}--;
    $opp->{'xleft'}--;
    # following is an approximation, should check when 
    # $me->{'xms'} != $opp->{'xms'} (TODO)
    # See several similar cases below. 
    $opp->{'xs'} -= $opp->{'xms'}; 
#     Debug 'CBPF', "... vs. %s (%g %+g)", $opp->TaggedName(), $opp->{'xw'}, $opp->{'xs'} if $debug_ids{$me->ID()};
    }
  else {
    $me->{'xw'}++; 
    $me->{'xleft'}--;
    $me->{'xs'} += $bye_spread;
    $me->{'xfs'} += $bye_spread - $me->{'xms'};
    }
  }

=item CalculateBPFs($psp)

Calculate best possible finishes for everyone in @$psp, which
must be sorted according to current standing.

=cut

sub CalculateBPFs($) {
  my $psp = shift;

  Debug 'CBPF', 'Now=>Fnl Wins Sprd Player (theoretical best finishes)';
  unless (@$psp) {
    TSH::Utility::Error 'Assertion failed: $psp is empty';
    return;
    }
  my $toprank = $psp->[0]->RoundRank($psp->[0]->CountScores()-1);
  for my $i (0..$#$psp) {
    my $r = CalculateBestPossibleFinish $psp, $i;
    $psp->[$i]->MaxRank($r+$toprank-1);
    }
  }

=item CalculateBestPossibleFinish($psp, $index);

Calculate what the highest possible finishing rank is for the
${index}th player in $psp.  
The rank is relative to the players in @$psp.

=cut

sub CalculateBestPossibleFinish ($$) {
  my $psp = shift;
  my $index = shift;
  return undef if $index > $#$psp;
  return 1 if @$psp == 1;
  my $me = $psp->[$index];
  my $dp = $me->Division();
  my $config = $dp->Tournament()->Config();
  my $max_rounds = $dp->MaxRound0() + 1;
  my $bye_spread = $config->Value('bye_spread');
  $bye_spread = 50 unless defined $bye_spread; # should not happen
# DebugOn('CBPF');
  # set scratch variables
  my $nrounds = BPFInit($psp);
  # if no games left to play, rank won't change
  return 1+$index if $nrounds == 0;
  # assign wins as favourably to me as possible
  for my $r (1..$nrounds) {
    # maximum final wins and spread
    $me->{'xfw'} = $me->{'xw'} + $me->{'xleft'};
    $me->{'xfs'} = $me->{'xs'} + $me->{'xleft'} * $me->{'xms'};
#     Debug 'CBPF', 'Round %d', $max_rounds-$nrounds+$r if $debug_ids{$me->ID()};
    # everyone ranked up to the cap must play each other
    my $rounds_left = $nrounds - $r + 1; # a rough approximation
    my $cap0 = $config->FlightCap($rounds_left) - 1;
#   Debug 'CBPF', 'flight_cap for %d round(s) left is %d.', $rounds_left, $cap0 + 1 if $debug_ids{$me->ID()};
    $cap0 = $#$psp if $cap0 > $#$psp;
    # TODO: if ($cap0 < $#$psp) { provisionally pair within flights instead }
    # while there are flights not containing us
    #   pair a flight 1:n, 2:n-1, ... and have the lower player win
    # if we're in the top half of a flight
    #   then pair the same way, and the lower player wins unless they play us
    #   else pair me with top in flight, rest as above
    # byes?
    my $r0 = $max_rounds - $rounds_left + $r - 1; # +1 -1 = 0
    # divide players into five groups: preferred W/L above/below cap, me
    my ($myrank, $hwp, $lwp, $hlp, $llp) = BPFCategorizePlayers $r0, $cap0, $me, 
      [ sort { $b->{'xw'}<=>$a->{'xw'} || $b->{'xs'}<=>$a->{'xs'}
	||($a eq $me ? -1 : $b eq $me ? 1 : 0)} @$psp ];
    # if I can play, I always win with the largest possible spread
    if (!defined $me->Score($r0)) { 
      # find me an opponent, preferably on the same side of the cap
      my $opp;
      for my $groupp ($myrank <= $cap0 
	? ($hlp, $hwp, $llp, $lwp) : ($llp, $lwp, $hlp, $hwp)) 
        { if (@$groupp) { $opp = shift @$groupp; last; } }
      BPFScoreMe $me, $opp, $bye_spread;
      }
#   Debug 'CBPF', 'HL is now (1): %s', join(';', map { $_->TaggedName() } @$hlp);
    BPFPairGroup $hwp, [$hlp,$hwp,$lwp,$llp], 'HW', 0, $me, $bye_spread;
    BPFPairGroup $hlp, [$hwp,$hlp,$llp,$lwp], 'HL', 1, $me, $bye_spread;
    BPFPairGroup $lwp, [$llp,$lwp,$hlp,$hwp], 'LW', 0, $me, $bye_spread;
    BPFPairGroup $llp, [$lwp,$llp,$hwp,$hlp], 'LL', 1, $me, $bye_spread;
    }
  return BPFFindMyRank $index, $psp;
  }

sub CheckSeats ($$) {
  my $this = shift;
  my $quiet = shift;
  my $tournament = $this->Processor()->Tournament();
  my $config = $tournament->Config();
  unless ($config->Value('seats')) {
    $tournament->TellUser('ethsbncfg') unless $quiet;
    return 0;
    }
  return 1;
  }

=item $n = CountGibsons($sr0, $psp)

Count the number of Gibsons in @$psp based on round $sr0 standings.
You must call CalculateBPFs and Division::ComputeRanks($sr0) before
calling this sub.  Gibsonization is done based on wins and spread,
with the assumption that a player can catch up a certain number of
points per game represented in MaxSpread().

=cut

sub CountGibsons ($$) {
  my $sr0 = shift;
  my $psp = shift;
  my $sr = $sr0 + 1;
  my $p0 = $psp->[0];
  return 0 unless defined $p0;
  my $dp = $p0->Division();
  my $config = $dp->Tournament()->Config();
  my $dname = $dp->Name();
  my $max_rounds = $dp->MaxRound0() + 1;
  my $rounds_left = $max_rounds - $sr;
  my $round_spread = 2 * MaxSpread($rounds_left, $config);
  my $spread_allowed = $rounds_left * $round_spread;
  unless (@$psp) {
    Debug 'GIB', 'CountGibsons called with empty list';
    return 0;
    }

  # Determine how many ranks are equivalent for Gibsonization:
  # if 1st and 2nd are equivalent and #1 and #2 are the only ones
  # who can finish as high as second place, they are both Gibsonized.
  # If 1st and 2nd are not equivalent, they are not Gibsonized.
  #
  # Example:
  #
  # MaxRanks 
  #
  # 1,1,2,2... (no Gibsons)
  # 1,2,3,3... (Gibsonize 1 and 2)
  # 1,2,3,4,4... (Gibsonize 1, 2 and 3)
  # 1,2,2,3... (Gibsonize 1)
  # 1,1,3,3... (1,2[,3] equiv: Gibsonize 1,2; else no Gibsons)
  # 1,1,1,4,5... (1,2,3 equiv: Gibsonize 1,2,3; else no Gibsons)
  #
  my $gibson_equivalent = $config->Value('gibson_equivalent')->{$dname};
  my $cursor = 0;
  my $ngibsons = 0;
  my $top_rank = $psp->[0]->RoundRank($sr0);
  if ($gibson_equivalent) {
    # $gibson_equivalent tells us which ranks are equivalent,
    # usually either #1 and #2 or none
    my $rank = $top_rank;
    my $here = $gibson_equivalent->[$rank] || $rank;
#   warn "here=$here rank=$top_rank ge=".join(',',@$gibson_equivalent);
    if ($here) {
      while (1) {
	my $next = $gibson_equivalent->[++$rank];
#	warn "next=$next";
	last unless $next && $next == $here;
	$cursor++;
        }
      }
#   die $cursor;
    }
  Debug 'GIB', 'Gibson-equivalent ranks: %d starting at %d', $cursor+1, $psp->[0]->RoundRank($sr0);
  if ($cursor) {
    my $maxrank = $psp->[$cursor+1]->MaxRank();
    if ($maxrank >= $cursor+$top_rank) {
      $ngibsons = $maxrank - 1;
      Debug 'GIB', '%s, currently at rank %d, has maximum final rank %d, ngibsons >= %d', $psp->[$cursor+1]->TaggedName(), $cursor+$top_rank+1, $maxrank, $ngibsons;
      }
    else {
      Debug 'GIB', '%s, currently at rank %d, has maximum final rank %d, so nobody in the top gibson-equivalent band is Gibsonized', $psp->[$cursor+1]->TaggedName(), $cursor+$top_rank+1, $maxrank;
      }
    }
# Debug 'GIB', 'cursor=%d $#$psp=%d', $cursor, $#$psp;
  while ($cursor <= $#$psp - 1) { # -1 because the last Gibson needs an opponent
    my $maxrank = $psp->[$cursor+1]->MaxRank();
#   warn join(',', $cursor, $maxrank, ($cursor+$top_rank + 1));
    if ($maxrank == $cursor+$top_rank + 1) {
      $ngibsons = ++$cursor;
      Debug 'GIB', 'Player %s ranked %d cannot rise past %d, so gibsons >= %d', $psp->[$cursor]->TaggedName(), $ngibsons+1, $maxrank, $ngibsons;
      }
    else {
      Debug 'GIB', 'Player ranked %d can rise to %d, so player ranked %d is not a Gibson.', $cursor+2, $maxrank, $maxrank;
      last;
      }
    }
# for my $i (0..6) { Debug 'GIB', 'psp[%d]=%s', $i, $psp->[$i]->TaggedName(); }
  Debug 'GIB', 'Gibsons found: %d', $ngibsons;
  return $ngibsons;
  }

=item $cap = FlightCapDefault($rounds_left);

Apply the default algorithm for mapping rounds left to cap on
number of contenders:, 2, 4, 8, 12, 12, 12, ....

=cut

sub FlightCapDefault ($) {
  my $rounds_left = shift;
  return $rounds_left <= 1 ? 2 :
    $rounds_left >= 4 ? 12 :
    ($rounds_left - 1) * 4;
  }

=item $cap = FlightCapNone($rounds_left);

Apply no cap to the number of contenders.

=cut

sub FlightCapNone ($) {
  my $rounds_left = shift;
  return 1000000;
  }

=item $cap = FlightCapNSC($rounds_left);

Apply the pre-2008 NSC algorithm for mapping rounds left to cap on
number of contenders: 4, 8, 12, 12, 12, ....

=cut

sub FlightCapNSC ($) {
  my $rounds_left = shift;
  return $rounds_left > 3 ? 12 : $rounds_left * 4;
  }

sub FlightCapTSSC2010 ($) {
  my $rounds_left = shift;
  return $rounds_left == 3 ? 29 : $rounds_left == 2 ? 15 : $rounds_left == 1 ? 2 : 58;
  }

=item $cap = FlightCapNSC2008($rounds_left);

Apply the 2008 NSC algorithm for mapping rounds left to cap on
number of contenders: 2, 4, 6, 12, 12, 12, ....

=cut

sub FlightCapNSC2008 ($) {
  my $rounds_left = shift;
  return $rounds_left > 3 ? 12 : $rounds_left * 2;
  }

=item $s = MaxSpread ($nr[, $config[, $command]]);

Return the maximum likely spread that a player can earn per round
over $nr rounds.

NSA rules were 500 points of spread in 1 round, 700 in 2, 900 in 3.
We generalise to 300*n for n>=3.

Based on a NASPA AB ruling on 2016-10-25, these numbers are changed
to 1000 per round for all n.

If C<$config> is specified, allow an override of these values.

If C<$command> is specified, allow values to be cached.

=cut

sub MaxSpread ($;$$) {
  my $nr = shift;
  my $this = shift;
  use Carp qw(cluck); cluck "bad argument to MaxSpread" unless defined $nr;
  $this->{xpcmsc} ||= TSH::Utility::ShareSafely([]);
  if ($this and $this->{'xpcmsc'}[$nr]) { return $this->{'xpcmsc'}[$nr]; }
  my $config = shift;
  my $nr0 = $nr - 1;
# my (@max_per_round) = (250, 175, 150);
  my (@max_per_round) = (500);
  if ($config) {
    if (my $gibson_spread = $config->Value('gibson_spread')) {
      @max_per_round = ref($gibson_spread) eq 'ARRAY' ? @$gibson_spread : ($gibson_spread);
      }
    }
  my $max = $nr0 > $#max_per_round ? $max_per_round[-1] : $max_per_round[$nr0];
# warn "MaxSpread for $nr0+1 rounds: $max";
  if ($this) { $this->{'xpcmsc'}[$nr] = $max; }
  return $max;
  }

=item $boolean = $parser->PairAllGibsons($psp, $sr0, $rounds_left, $last_prize_rank);

Pair all Gibsons at the top of @$psp.  Return true if pairings were made.

=cut

sub PairAllGibsons ($$$$) {
  my $this = shift;
  my $tobepaired = shift;
  my $sr0 = shift;
  my $rounds_left = shift;
  my $last_prize_rank = shift;
  Debug 'GIB', 'PairAllGibsons(%d,%d,%d,%d)', scalar(@$tobepaired), $sr0, $rounds_left, $last_prize_rank;
  $tobepaired->[0]->Division()->ComputeRanks($sr0);

  my $did_something = 0;
  while (1) {
    my $possible_gibsons = $tobepaired;
    if (@$possible_gibsons > $last_prize_rank+3) {
      Debug 'GIB', 'Optimizing by computing BPFs only down to %d.', $last_prize_rank+3;
      $possible_gibsons = [ @$possible_gibsons[0..$last_prize_rank+2] ];
      }
    last unless @$tobepaired;
    CalculateBPFs $possible_gibsons;
    my $ngibsons = CountGibsons($sr0, $tobepaired);
    Debug 'GIB', '%d gibson%s.', $ngibsons, ($ngibsons == 1 ? '' : 's');
    last unless $ngibsons;
    $did_something = 1;
    # if there is an even number of gibsons
    if ($ngibsons % 2 == 0) {
      # then pair them KOTH but minimize rematches
      PairEvenGibsons($tobepaired, $ngibsons); 
      }
    # else there is an odd number of gibsons
    else { 
      # pair all but the lowest ranked gibson KOTH minimizing rematches
      PairEvenGibsons($tobepaired, $ngibsons-1);
      # pair the last one with a low-ranked victim
      PairOneGibson($tobepaired, $last_prize_rank, $sr0, $rounds_left);
      }
    }
  return $did_something;
  }

=item $cmd->PairMany(\@psp, $round0, \@pairings);

Pair $psp->[$pairings[$n]] with $psp->[$pairings[$n+1]] in $round0 
for each possible even $n.

=cut

sub PairMany ($$$$) {
  my $this = shift;
  my $psp = shift;
  my $round0 = shift;
  my $pairingsp = shift;

  return unless @$psp;
  my $dp = $psp->[0]->Division();
  for (my $i = 0; $i <= $#$pairingsp; $i += 2) {
    my $id1 = $pairingsp->[$i];
    $id1 = (defined $id1) ? $psp->[$id1]->ID() : 0;
    my $id2 = $pairingsp->[$i+1];
    $id2 = (defined $id2) ? $psp->[$id2]->ID() : 0;
    $dp->Pair($id1, $id2, $round0);
#   warn "$id1 $id2 $round0";
    }
  }

=item PairEvenGibsons($psp, $ngibsons)

Pair an even number of gibsons with each other,
with decreasing priority given to

  - minimizing rematches
  - avoiding consecutive rematches (where possible)
  - pairing each player with the one ranked closest possible

=cut

sub PairEvenGibsons ($$) {
  my $psp = shift;
  my $ngibsons = shift;
  return unless $ngibsons && @$psp;
  Debug 'GIB', 'Pairing %d gibsons.', scalar($ngibsons);
  my $r0 = $psp->[0]->CountOpponents();
  my $track_firsts = $psp->[0]->Division()->Tournament()->Config()->Value('track_firsts');
  if (
    TSH::Player::PairGRT([@$psp[0..$ngibsons-1]],
      # opponent preference ranking
      # $psp is arg 0
      # $pindex is arg 1
      # $oppindex is arg 2
      sub {
	my $p = $_[0][$_[1]];
	my $pid = $p->ID();
	my $o = $_[0][$_[2]];
	my $oid = $o->ID();
	my $lastoid = ($p->OpponentID(-1)||-1);
	my $repeats = $p->Repeats($oid); 
	my $sameopp = ($oid == $lastoid);
	my $distance = abs($_[1]-$_[2]);
	my $pairsvr = $track_firsts ? 2-abs(($p->{'p1'}-$p->{'p2'} <=> 0)  -($o->{'p1'}-$o->{'p2'} <=> 0)) : 0;

 	Debug 'GRT', 'pref %d-%d rep=%d prev=%d svr=%d dist=%d', $pid, $oid, $repeats, $sameopp, $pairsvr, $distance;
	pack('NCCNN',
	  $repeats, # minimize repeats
	  $sameopp, # avoid previous opponent
	  $pairsvr, # pair those due to start vs those due to reply
	  $distance, # prefer closer-ranked opponents
	  $_[2], # to recover player ID
	  )
        },
      # allowed opponent filter
      sub {
	# allow any
	1,
        },
      [],
      $r0,
      )
    ) # if
    {
#   DebugDumpPairings 'GIB', $psp->[0]->CountOpponents()-1, [splice(@$psp, 0, $ngibsons)]; # splices are not thread-safe
    my @paired = TSH::Utility::SpliceSafely(@$psp, 0, $ngibsons);
    DebugDumpPairings 'GIB', $psp->[0]->CountOpponents()-1, \@paired; 
    }
  else
    {
    TSH::Utility::Error "Assertion failed: can't resolve even gibson pairings for: " 
      . join(', ', map { $_->TaggedName() } @$psp);
    }
  return;
  }

=item PairOneGibson($psp, $last_prize_rank, $sr0, $rounds_left)

Pair one gibson.  If the bottom prize band (of players who have 
nothing at stake but ratings and pride) is occupied, the victim is
the highest ranked among those who have played the gibson least often.
If not, then it's the lowest ranked overall (including higher ranked
players who may still be concerned with reaching prize money or
qualification status) among those who have played the gibson least often.

=cut

sub PairOneGibson ($$$$) {
  my $psp = shift;
  my $last_prize_rank = shift;
  my $sr0 = shift;
  my $rounds_left = shift;
  Debug 'GIB', 'Pairing one gibson from %d players, lpr=%d.', scalar(@$psp), $last_prize_rank;
  my $gibson = $psp->[0];
  my $gid = $gibson->ID();
  my $config = $gibson->Division()->Tournament->Config();
  my $gibson_class = $config->Value('gibson_class');
  my $exagony = $config->Value('exagony');
  $gibson_class = uc $gibson_class if defined $gibson_class;
  
  if (@$psp % 2) {
    Debug 'GIB', 'Gibson gets the bye.';
    $gibson->Division()->Pair($gid, 0, $gibson->CountOpponents());
    shift(@$psp);
    return;
    }

  Debug 'GIB', 'Earlier optimization computing BPFs only down to %d failed, recomputing all BPFs.', $last_prize_rank+1;
  CalculateBPFs $psp;

  my $victim = undef;
  my $minrep = undef;
  my $hopeless_victim = undef;
  my $ignore_reps = ($config->Value('gibson')||1) eq 'strict';
  my $gibson_team = $gibson->Team()||'';
  for (my $i = $#$psp; $i > 0; $i--) {
    my $poss_victim = $psp->[$i];
    if (defined $gibson_class) {
      my $this_class = $poss_victim->Class() || '_no_such_class';
      unless (uc($this_class) eq $gibson_class) {
	Debug 'GIB', "... skipping (class $this_class is not $gibson_class) %s", $poss_victim->TaggedName();

	next;
        }
      }
    if ($exagony && ($poss_victim->Team()||'') eq $gibson_team) {
      Debug 'GIB', "... skipping %s (is on same team)", $poss_victim->TaggedName();
      next;
      }
    my $rep = $poss_victim->Repeats($gid);
    my $is_hopeless = $poss_victim->MaxRank() > $last_prize_rank;
    if ($is_hopeless && $ignore_reps) {
      $hopeless_victim = $i;
      }
    elsif (!defined $minrep) {
      Debug 'GIB', '... victim (rep=%d) = %s', $rep, $poss_victim->TaggedName();
      $minrep = $rep;
      $victim = $i;
      $hopeless_victim = $victim if $is_hopeless;
      }
    elsif ($minrep > $rep) {
      Debug 'GIB', '... better victim (rep %d<%d) = %s', $minrep, $rep, $poss_victim->TaggedName();
      $minrep = $rep;
      $victim = $i;
      $hopeless_victim = $victim if $is_hopeless;
      }
    elsif ($is_hopeless && $minrep == $rep) {
      Debug 'GIB', '... better victim (rep %d=%d) = %s', $minrep, $rep, $poss_victim->TaggedName();
      $hopeless_victim = $i;
      }
    }
   
  $victim = $hopeless_victim if defined $hopeless_victim;
  unless (defined $victim) {
    $victim = $#$psp;
    Debug 'GIB', "No acceptable victim found, choosing lowest-ranked player: %s", $psp->[$victim]->TaggedName();
    }
  Debug 'GIB', "Pairing Gibson %s and victim %s", $gibson->TaggedName(), $psp->[$victim]->TaggedName();
  $gibson->Division()->Pair($gid, $psp->[$victim]->ID(),
    $gibson->CountOpponents());
  TSH::Utility::SpliceSafely(@$psp, $victim, 1);
  shift @$psp;
  return;
  }

=item $setup = $command->SetupForPairing(%options);

Check and set up variables prior to performing pairings. 
%options is modified as necessary and a reference is returned.
Supported options:

bad_class_endagony: (output) true if players can only play members of the same class - this is a bad idea (hence the name), and you should always put them in different divisions instead

consecutive_repeats: (input) number of consecutive repeats allowed

division: (input) reference to a TSH::Division

exagony: (output) true if players from same team should not play each other

filter: (output) reference to an opponent filter to pass to PairGRT

incomplete: (input) if true, do not fail when source round data incomplete

incomplete: (output) if true, source round data was incomplete

nobye: (input) true if odd player groups should be left as is without
  assigning a bye, say because of a subsequent complex Gibson calculation,
  or because we're getting ready to do multiround pairings

pairing_system_name: (input) name of the pairing system, for diagnostic
  messages, defaults to command name

required: (input) names of required configuration options

repeats: (input) number of repeats allowed

repsince0: (input) 0-based round after which repeats should be counted
source0: (input) 0-based round on which to base standings

target0: (input) 0-based round in which to store pairings

=cut

sub SetupForPairings ($%) {
  my $this = shift;
  my (%setup) = @_;
  my $dp = $setup{'division'};
  my $sr0 = $setup{'source0'};
  my $repeats = $setup{'repeats'};
  my $repsince0 = $setup{'repsince0'};
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $dname = $dp->Name();
  my $consecutive_repeats = $setup{'consecutive_repeats'} 
    //= $config->Value('consecutive_repeats');

  $setup{'config'} = $config unless exists $setup{'config'};

  if ($dp->CheckRoundHasResults($sr0)) {
    $setup{'incomplete'} = 0;
    }
  else {
    unless ($setup{'incomplete'}) {
      $setup{'incomplete'} = 1;
      return 0;
      }
    }

  $setup{'target0'} = $dp->FirstUnpairedRound0();
  my $max_round0 = $dp->MaxRound0();
  if ((defined $max_round0) && $max_round0 < $setup{'target0'}) {
    $tournament->TellUser('ebigrd', $setup{'target0'}+1, $max_round0+1);
    return 0;
    }

  # check for required configuration options
  if ($setup{'required'}) {
    my $failed = 0;
    for my $key (keys %{$setup{'required'}}) {
      next if defined $config->Value($key);
      $tournament->TellUser("eneed_$key");
      $failed++;
      }
    return 0 if $failed;
    }
  # check for wanted configuration options
  if ($setup{'wanted_div'}) {
    for my $key (keys %{$setup{'wanted_div'}}) {
      my $ref = $config->Value($key);
      if (defined $ref) {
	if (ref($ref) eq 'HASH') {
	  # required option exists
	  next if $ref->{$dname};
	  }
	else {
	  # user might have entered prize_bands = [1,2,3] 
	  # instead of prize_bands{'A'} = [1,2,3]
	  warn "Looking for config '$key'{$dname} but found only config $key";
	  $config->Value($key, $ref = {});
	  }
	}
      # if not found, warn and apply default value
      $tournament->TellUser("wwant_$key");
      if (!defined $ref) {
	$config->Value($key, ($ref = &share({})));
        }
      $ref->{$dname} = $setup{'wanted_div'}{$key};
      $config->Export();
      }
    }

  # Remind user what pairings these are
  if (my $psn = $setup{'pairing_system_name'}) {
    $tournament->TellUser("igpcok", $psn, $dp->Name(),
      $setup{'target0'}+1, $sr0+1, $repeats);
    }
  else {
    $tournament->TellUser("i$this->{'names'}[0]ok", $dp->Name(), 
      $setup{'target0'}+1, $sr0+1, $repeats);
    }
  
  # If consecutive_repeats is set, say so
  if ($consecutive_repeats) 
    { $tournament->TellUser('iconsrep', $consecutive_repeats); }

  # If exagony is set, players from the same team cannot play each other
  if ($setup{'exagony'} = $config->Exagony($setup{'target0'})) 
    { $tournament->TellUser('irsem'); }

  # If hypexagony is set, players from the same team have restricted repeats
  if ($setup{'hypexagony'} = $config->Value('hypexagony'))
    { $tournament->TellUser('iprhyp', $setup{'hypexagony'}); }

  # If bad_class_endagony is set, players from different classes cannot play each other
  if ($setup{'bad_class_endagony'} = $config->Value('bad_class_endagony')) 
    { $tournament->TellUser('iprsc'); }

  # Build player list
  my $psp = $dp->GetUnpairedRound($setup{'target0'});
  if (defined $setup{'class'}) {
    my $class = $setup{'class'};
    $tournament->TellUser('iprclass', $class);
    $class =~ s/,/|/g;
    $psp = [ grep { $_->ClassMatch($class) } @$psp ];
    }
  unless (@$psp) {
    $tournament->TellUser('ealpaird', $setup{'target0'}+1);
    return 0; 
    }

  @$psp = TSH::Player::SortByCurrentStanding @$psp;
  {
    my $did_something = 0;
    # perform any necessary gibsonization
    if ($config->Value('gibson') || $setup{'gibson'}) {
      if (!defined $max_round0) {
	$tournament->TellUser('eneed_max_rounds');
	return 0;
	}
      my $rounds_left = $max_round0 + 1 - $setup{'target0'};
      if ($this->PairAllGibsons($psp, $sr0, $rounds_left, $config->LastPrizeRank($dname))) {
	$did_something = 1;
	}
      }
    if (@$psp % 2 && !$setup{'nobye'}) {
      $dp->ChooseBye($sr0, $setup{'target0'}, $psp);
      $did_something = 1;
      }
    $dp->Synch() if $did_something;
  }
  $setup{'players'} = $config->Value('spread_cap')
    ? [TSH::Player::SortByCappedStanding $sr0, @$psp]
    : [TSH::Player::SortByStanding $sr0, @$psp];

  # check for impossible exagony
  if ($setup{'exagony'}) {
    my $nplayers = scalar(@$psp);
    my $limit = int($nplayers/2);
    my %teams;
    for my $p (@$psp) {
      if ($limit < ++$teams{$p->Team()}) {
	$tournament->TellUser('ersf', $dname);
	return 0;
	}
      }
    }

  # Set up opponent filter
  {
    my $code = 'sub { my $p1=$_[0][$_[1]]; my $p2=$_[0][$_[2]]; return (1';
#   my $code = 'sub { my $p1=$_[0][$_[1]]; my $p2=$_[0][$_[2]]; my $rv= (1';
    $code .= ' and ( $p1->Team() ne $p2->Team() or $p1->Team() eq "")'
      if $setup{'exagony'};
    $code .= ' and ( $p1->Class() eq $p2->Class())'
      if $setup{'bad_class_endagony'};
    if (defined $repsince0) {
      $code .= ' and $p1->Repeats($p2->ID()) '
	. '- $p1->CountRoundRepeats($p2, $repsince0) <= $repeats';
      }
    else {
      $code .= ' and $p1->Repeats($p2->ID()) <= $repeats';
      }
    $code .= ' and $p1->CountConsecutiveRepeats($p2) <= $consecutive_repeats'
      if $consecutive_repeats;
    $code .= ' and (( $p1->Team() ne $p2->Team() or $p1->Team() eq "")'
      . 'or $p1->Repeats($p2->ID()) <= $setup{"hypexagony"})'
      if $setup{'hypexagony'};
    $code .= ');}';
#   $code .= '); warn "$p1->{id} vs $p2->{id} filter=$rv"; return $rv}';
    Debug 'PCC', "filter code: %s", $code;
    $setup{'filter'} = eval $code;
    if ($@) { warn "Assertion failed: $@"; }
  }

  return \%setup;
  }

=over 4

=item $command->TidyAfterPairing($dp);

=cut

sub TidyAfterPairing ($$) {
  my $this = shift;
  my $dp = shift;

  $dp->Dirty(1);
  $this->Processor()->Flush();
  $dp->Tournament()->TellUser('idone');
  }

=back

=cut

=head1 BUGS

- Gibsonization should consider results from partially scored rounds.

- The current algorithm assumes (e.g.) that if the top eight players
  are paired with each other to contend for the top two places, then
  the ninth-ranked player cannot finish higher than ninth place, and
  is paired with other such players.

- The Gibsonization algorithm doesn't work when there is more than one
  final gibsonization position and only some of the contenders should
  be Gibsonized.

- The algorithm should probably be rewritten to search for the worst
  possible final rank for each player, rather than the best.  Then
  for example, if after the penultimate round players are at 
  0, -1, -2, -2, -2 with four Gibson-equivalent ranks being contended,
  the leader can be Gibsonized because his worst possible rank is 2nd,
  still in the top 4.

- We still need to know the best possible ranks, for contender determination

=cut

1;
