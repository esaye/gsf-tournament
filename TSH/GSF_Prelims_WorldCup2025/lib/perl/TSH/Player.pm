#!/usr/bin/perl

# Copyright (C) 2005-2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Player;

use strict;
use warnings;

use Carp;
use TSH::Utility qw(Debug DebugDumpPairings);
use Scalar::Util qw(looks_like_number);
use JavaScript::Serializable;
use threads::shared;
# NEVER DO THIS: it causes Term::ReadLine to fail trying to load Gnu.pm.
# $::SIG{__DIE__} = sub { Carp::cluck $_[0]; sleep 10; exit 1; };
$::SIG{__DIE__} = sub { confess $_[0]; };

our (@ISA);
@ISA = qw(JavaScript::Serializable);
sub EXPORT_JAVASCRIPT () { return map { $_ => $_ } qw(etc id name newr pairings photo photomood rating scores); }

=pod

=head1 NAME

TSH::Player - abstraction of a Scrabble player within C<tsh>

=head1 SYNOPSIS

  $p = new TSH::Player();
  $n = $p->CountBackToBack($r0);
  $boolean = CanBePaired $repeats, \@players, $must_catchup, $setupp
  $s = $p->CountOpponents();
  $s = $p->CountScores();
  $n = $p->CountRepeats();
  $s = $p->DeleteLastScore();
  $s = $p->Division();
  $p12 = $p->First($r0);
  $oldp12 = $p->First($r0, $p12);
  $n = $p->Firsts();
  $oldn = $p->Firsts($n);
  $oldp12p = $p->FirstVector($newp12p);
  $p12p = $p->FirstVector();
  $s = $p->FullID();
  $s = $p->GamesPlayed();
  $s = $p->ID();
  $s = $p->Initials();
  $r = $p->LatestScoredRound();
  $r = $p->MaxRank();
  $p->MaxRank($r);
  $s = $p->Name();
  $r = $p->NewRating();
  $p->NewRating($r);
  $p->NextLocation();
  $s = $p->Opponent($round0);
  $s = $p->OpponentID($round0);
  $s = $p->OpponentScore($round0);
  $success = PairGRT($grtsub, $psp, $grtargs, $round0);
  $s = $p->PrettyName();
  $r = $p->Random();
  $p->Random($r);
  $r = $p->Rating();
  $p->Rating($r);
  $r = $p->Repeats($oppid);
  $p->Repeats($oppid, $r);
  $boolean = ResolvePairings $unpairedp[, \%options]
  $s = $p->RoundLosses($round0);
  $s = $p->RoundRank($round0);
  $p->RoundRank($round0, $rank);
  $s = $p->RoundSpread($round0);
  $s = $p->RoundWins($round0);
  $s = $p->Score($round0);
  $old = $p->Score($round0, $score);
  $n = $p->Seconds();
  $oldn = $p->Seconds($n);
  $n = $p->Time();
  $oldn = $p->Time($n);
  @p = TSH::Player::SortByCurrentStanding(@p);
  @p = TSH::Player::SortByInitialStanding(@p);
  @p = TSH::Player::SortByStanding($sr0, @p);
  TSH::Player::SpliceInactive(@ps, $nrounds, $round0);
  $s = $p->TaggedName();
  $s = $p->Team();
  $j = $p->ToJavaScript();
  $success = $p->UnpairRound($round0);
  $n = $p->UnscoredGames();
  $n = $p->Wins();

=head1 ABSTRACT

This Perl module is used to manipulate players within C<tsh>.

=head1 DESCRIPTION

A Player has (at least) the following member fields, none of which
ought to be accessed directly from outside the class.

  byes        number of byes, last time we counted
  class       class for prizes
  cspread     cumulative spread, capped (see rcspread)
  division    pointer to division
  etc         supplementary player data (see below)
  ewins1      rated wins earned in the first half of a split tournament
  ewins2      rated wins earned in the second half of a split tournament
  id          player ID (1-based) # not sure this is still here
  initials    two letters to help identify a player
  losses      number of losses
  maxrank     highest rank still attainable by player in this tournament
  name        player name
  noscores    # of undefined values in scores, up to $config::max_rounds
  nscores     number of defined values in scores
  opp         provisional opponent used within pairing routines
  p1          number of firsts (starts)
  p2          number of seconds (replies)
  p3          number of indeterminates (starts/replies)
  pairings    list of 1-based opponent IDs by 0-based round
  photo       URL for player photo
  prettyname  player name formatted for human eyes
  ratedgames  number of rated games
  ratedwins   number of rated wins
  rating      pre-tournament rating
  rcspread    cumulative spread by round, capped by standings_spread_cap
  repeats     data structure tracking repeat pairings
  rnd         pseudorandom value used to break ties in standings
  rlosses     cumulative losses by round
  rspread     cumulative spread by round
  rwins       cumulative wins by round
  scores      list of this player's scores by round (0-based)
  spread      cumulative spread
  tspread     temporary spread variable used by some routines
  twins       temporary wins variable used by some routines
  wins        number of wins
  x*          keys beginning x are for scratch data

Supplementary player data is currently as follows:

  board       0-based list indicating board at which player played each 
              round. A value of 0 indicates that no board is assigned.
  off         exists if player is inactive, single value indicates
              type of byes (-50/0/50) to be assigned
  newr        0-based list indicating player's interim rating after each round.
  penalty     0-based list indicating spread penalty applied to player 
              in each round. A value of 0 indicates no penalty,
	      a negative value indicates spread deducted.
  p12         0-based list, 1 if went first, 2 if second, 0 if neither
              (bye), 3 if must draw, 4 if indeterminate
  rcrank      1-based capped rank by 1-based round (round 0 = preevent)
  rmood       0-based list of player moods
  rprov       list of provisional game results not yet confirmed by opponent;
  rrank       1-based rank by 1-based round (round 0 = preevent)
  rtime       Seconds since Unix epoch when player data was last changed, by 0-based round
  seat        0-based list indicating seat assigned to player in Thai pairings.
  team        Team name
  time        Seconds since Unix epoch when player data was last changed
              each game is represented by a triple of integers: 1-based round,
	      player score, opponent score

The following member functions are currently defined.

=over 4

=cut

sub Active ($);
sub Board ($$;$);
sub Byes ($;$);
sub CanBePaired ($$$$);
sub CountOpponents ($);
sub CountScores ($);
sub DeleteLastScore ($);
sub Division ($;$);
sub First ($$;$);
sub Firsts ($;$);
sub FirstVector ($;$);
sub FullID ($);
sub GamesPlayed ($);
sub GetOrSetEtcScalar ($$;$);
sub GetOrSetEtcVector ($$;$);
sub ID ($;$);
sub Initials ($);
sub initialise ($);
sub LatestScoredRound($);
sub LifeGames ($;$);
sub Losses ($);
sub MinRank ($;$);
sub MaxRank ($;$);
sub new ($);
sub Name ($;$);
sub NewRating ($$;$);
sub NextLocation($);
sub OffSpread ($);
sub Opponent ($$);
sub OpponentID ($$;$);
sub OpponentScore ($$);
sub PairGRT ($$$$$;$);
sub Password ($;$);
sub PrettyName ($;$);
sub Rating ($;$);
sub Repeats ($$;$);
sub ResolvePairings ($$);
sub RoundCappedRank ($$;$$);
sub RoundRank ($$;$$);
sub RoundSpread ($$);
sub RoundSum ($$);
sub RoundTime ($$;$);
sub RoundWins ($$);
sub Score ($$;$);
sub Seat ($$);
sub Seconds ($;$);
sub SortByCappedStanding ($@);
sub SortByCurrentStanding (@);
sub SortByHandicap ($@);
sub SortByInitialStanding (@);
sub SortByStanding ($@);
sub SpliceInactive (\@$$);
sub Spread ($);
sub TaggedHTMLName ($;$);
sub TaggedName ($;$);
sub Time ($;$);
sub UnpairRound ($$);
sub Wins ($);

=item $n = $p->Active();

Return true if the player is active for pairings.

=cut

sub Active ($) { 
  my $this = shift;
  return !exists $this->{'etc'}{'off'};
  }

=item $p->Activate();

Activate the player for pairings.

=cut

sub Activate ($) {
  my $this = shift;
  delete $this->{'etc'}{'off'};
  my $dp = $this->Division();
  # remove any trailing byes back to where last regular pairing is
  while ($#{$this->{'pairings'}} > $dp->LastPairedRound0()
    && !$this->{'pairings'}[-1]) {
    pop(@{$this->{'pairings'}});
    if ($this->CountScores() > $this->CountOpponents()) {
      $this->Truncate($this->CountOpponents()-1);
      }
#	printf "removed, now (%d,%d,%d).\n", $#{$this->{'pairings'}}, $dp->LastPairedRound0(), $this->{'pairings'}[-1];
    }
  $dp->Dirty(1);
  }

=item $n = $p->Byes();
=item $newn = $p->Byes($n);

Set or get the number of byes a player has had.

=cut

sub Byes ($;$) { TSH::Utility::GetOrSet('byes', @_); }

=item $n = $p->Board($r0);

Set/get the board number at which the player played in zero-based round $r0.

=cut

sub Board ($$;$) { 
  my $this = shift;
  my $r0 = shift;
  my $newboard = shift;
  my $boardp = $this->{'etc'}{'board'};
  my $dp = $this->Division();
  my $tourney = $dp->Tournament();
  unless (defined $boardp) { $this->{'etc'}{'board'} = $boardp = &share([]); }
  my $oldboard = $boardp->[$r0] || 0;
  my $dirty = 0;
# warn "$this->{id} $oldboard->$newboard" if defined $newboard;
  if (defined $newboard) {
    # first check our current board
    # then check our opponent's board
    if ($newboard != $oldboard) {
      if ($r0 > $#$boardp + 1) {
	push(@$boardp, (0) x ($r0 - $#$boardp - 1));
	}
      $boardp->[$r0] = $newboard;
      # check to see if anyone else is using was board
      # TODO: see if we need to do better than linear search here
      my $oid = $this->OpponentID($r0) || 0;
      my $thisid = $this->ID();
      for my $p ($dp->Players()) {
	next unless ($p->Board($r0) || '') eq $newboard;
	my $pid = $p->ID();
	next if $pid == $thisid || $pid == $oid;
	$tourney->TellUser('wreboard', $p->TaggedName(), $newboard);
	# if so, move other player to board 0
	$p->Board($r0, 0);
	}
      }
    my $opp = $this->Opponent($r0);
#   if ($newboard && !$opp) {
#     $tourney->TellUser('enosoloboard', $this->TaggedName(), $newboard);
#     Carp::cluck "we are here";
#     return $oldboard;
#     }
    if ($newboard && $opp) {
      $opp->Board($r0, $newboard) if $opp->Board($r0) != $newboard;
      }
    # store new board
    $dp->Dirty(1) if $dirty;
    }
  return $oldboard;
  }

sub Boards ($) {
  my $this = shift;
  return $this->{'etc'}{'board'};
  }

=item $boolean = CanBePaired $repeats, \@players, $ketchup, $setupp

Returns true iff @players can be paired without exceeding C<$repeats>.

If $ketchup is true, the top players can only be paired with those who
can catch up to them.

If $setupp->{'exagony'} is true, players from the same team cannot
play each other.

This routine is a bottleneck, and we've tried doing the following

OPT-A: Rearranging (1,2,3,4,...,n) to (1,n,2,n-1,3,n-2,4,n-3,...)
improves runtime by two orders of magnitude in bad cases, as looking
first at the top and bottom players typically works on the toughest
cases first.  We don't use this anymore because of the reduction
in pairings quality.  (Huh? This routine is just testing for pairability.)

OPT-B: Randomly rolling player opponent preferences will somewhat
improve mean runtime, and substantially improve runtime when 
low-numbered players are in high demand.  The worst-case runtime
is still terrible, though.  We don't use this anymore because of
the reduction in pairings quality, and the poor worst-case behaviour.

We currently do the optimization in ResolvePairings, where
we sort players by how difficult they are to pair, so that for
example players who have only one possible opponent are all paired
first.  

=cut

sub CanBePaired ($$$$) { 
  my $repeats = shift;
  my $psp = shift;
  my $must_catchup = shift;
  my $setupp = shift;

  return 1 unless @$psp;
  my (@ps) = (@$psp);
  my @shuffled;
# OPT-A while (@ps) {
# OPT-A   push(@shuffled, shift @ps);
# OPT-A   push(@shuffled, pop @ps) if @ps;
# OPT-A   }
  @shuffled = @ps;
  for my $i (0..$#shuffled) {
    my @prefs : shared
      = grep { 
	# must not exceed repeats criterion
	$shuffled[$i]->Repeats($_->ID()) <= $repeats 
	# must be able to catch up
        && ($must_catchup ? do {
	  my $p1 = $shuffled[$i];
	  my $p2 = $_;
	  if ($p1->RoundRank(-2) > $p2->RoundRank(-2)) {
	    ($p2, $p1) = ($p1, $p2);
	    }
	  Debug 'CBP', '%s %d ?>= %d %s', $p1->Name(), $p1->RoundRank(-2), $p2->MaxRank(), $p2->Name();
	  $p1->RoundRank(-2) >= $p2->MaxRank();
	  } : 1) 
	&& ($setupp->{'exagony'}
	  ? $shuffled[$i]->Team() ne $_->Team() 
	  || $shuffled[$i]->Team() eq ''
	  : 1)
        }
      (@shuffled[0..$i-1,$i+1..$#shuffled]);
    # randomly roll preferences
# OPT-B  unshift(@prefs, splice(@prefs, rand(@prefs))); # not thread-safe
#   Debug 'CBP', "prefs[%d]: %s", $i, join(',',map { $_->Name() } @prefs);
    $shuffled[$i]{'pref'} = \@prefs;
    }
# Debug 'CBP', "Resolving pairings";
  return ResolvePairings \@shuffled, {'target'=>undef};
  }

=item $c = $p->Class();

=item $p->Class($c);

Set or get the player's class (which could be a comma-separated list).

See also ClassMatch.

=cut

sub Class ($;$) { 
  my $this = shift;
  my $new = shift;
# warn "$new;$this->{'etc'}{'class'}[0];$this->{'name'};" if $this->{'id'} == 54;
  return $this->GetOrSetEtcScalar('class', $new);
  }

=item $boolean = $p->ClassMatch($pattern);

Return true if a player belongs to a class matching a pattern.

=cut

sub ClassMatch ($$) { 
  my $this = shift;
  my $pattern = shift;
  my $pclass = $_->Class() || 'noclass';
  return ($pclass =~ /\b$pattern\b/i or $pattern =~ /$pclass/i);
  }

=item $n = $p->CountBackToBack($r0 [, $oid]);

Number of consecutive rounds prior to $r0 this player has been paired with
his $r0 opponent, or with opponent #$oid if specified.

See also CountConsecutiveRepeats.

=cut

sub CountBackToBack($$;$) {
  my $this = shift;
  my $r0 = shift;
  my $oid = shift;
  my $backtobackcount = 0;
  $oid = ${$this->{'pairings'}}[$r0] unless defined $oid;
  return 0 unless defined $oid;
  for my $r (reverse 0..$r0-1) {
    if ( ${$this->{'pairings'}}[$r] == $oid ) {
      $backtobackcount++;
      }
    else
      {
	last;
      }	
  }
  return $backtobackcount;
}

=item $n = $p->CountOpponents();

Returns the number of the last round in which this player has a
scheduled pairing (including byes).

=cut

sub CountOpponents ($) { 
  my $this = shift;
  return scalar(@{$this->{'pairings'}});
  }

=item $n = $p->CountRepeats($opp);

Returns the correct number of repeat pairings between two players,
even before Division::Synch is called.

=cut

sub CountRepeats ($$) { 
  my $this = shift;
  my $opp = shift;
  my $oid = $opp->{'id'};
  my $repeats = 0;
  for my $aid (@{$this->{'pairings'}}) {
    $repeats++ if (defined $aid) && $aid == $oid;
    }
  return $repeats;
  }

=item $n = $p->CountConsecutiveRepeats($opp);

Returns the number of consecutive repeat pairings between two players,
at the end of the C<$p>'s currently determined pairings.
Returns 1 if players have played once, 2 if they have played twice, etc.

See also CountBackToBack.

=cut

sub CountConsecutiveRepeats ($$) { 
  my $this = shift;
  my $opp = shift;
  my $r0 = shift;
  my $oid = $opp->{'id'};
  my $repeats = 0;
  my $pairingsp = $this->{'pairings'};
  for (my $i=$#$pairingsp;
    $i >= 0 and ($pairingsp->[$i]||-1) == $oid;
    $i--) {
    $repeats++;
    }
  return $repeats;
  }

=item $n = $p->CountRoundRepeats($opp, $r0);

Returns the number of repeat pairings between two players,
up to and including zero-based round C<$r0>.
Returns 1 if players have played once, 2 if they have played twice, etc.

=cut

sub CountRoundRepeats ($$) { 
  my $this = shift;
  my $opp = shift;
  my $r0 = shift;
  my $oid = $opp->{'id'};
  my $repeats = 0;
  my $pairingsp = $this->{'pairings'};
  for my $i (0..$#$pairingsp) {
    last if $i > $r0;
    my $aid = $pairingsp->[$i];
    $repeats++ if (defined $aid) && $aid == $oid;
    }
  return $repeats;
  }

=item $n = $p->CountScores();

Returns the number of the last round in which this player has a
recorded score.

Compare with LatestScoredRound, which does not count zero as a
recorded score.

=cut

sub CountScores ($) { 
  my $this = shift;
  return scalar(@{$this->{'scores'}});
  }

sub CountStreak ($$) {
  my $this = shift;
  my $r0 = shift;

  my $type = undef;
  my $streak = 0;
  
  eval {
    die if $r0 < 0;
    my $oid = $this->OpponentID($r0);
    die unless defined $oid;
    my $os = $oid ? $this->OpponentScore($r0) : 0;
    die unless defined $os;
    my $ms = $this->Score($r0);
    die unless defined $ms;
    $type = $ms <=> $os;
    $streak = 1;
    while (--$r0 >= 0) {
      $oid = $this->OpponentID($r0);
      die unless defined $oid;
      $os = $oid ? $this->OpponentScore($r0) : 0;
      die unless defined $os;
      $ms = $this->Score($r0);
      die unless defined $ms;
      die unless $type == ($ms <=> $os);
      $streak++;
      }
    };
  return ($type, $streak);
  }

=item $p->Deactivate($spread);

Deactivate the player for pairings.

=cut

sub Deactivate ($$) {
  my $this = shift;
  my $spread = shift;
  $this->GetOrSetEtcScalar('off', $spread);
  }

=item $n = $p->DeleteLastScore();

Deletes the player's last score. 
Should be used with extreme caution, and only after checking with
the player's opponent if any.

=cut

sub DeleteLastScore ($) { 
  my $this = shift;
  return pop @{$this->{'scores'}};
  }

=item $old = $p->Division([$new]);

Return the player's division.

=cut

sub Division ($;$) { TSH::Utility::GetOrSet('division', @_); }

=item $e = $p->Expiry();
=item $p->Expiry($e);

Set or get the player's expiry, a rating system-dependent value.

=cut

sub Expiry ($;$) { TSH::Utility::GetOrSet('expiry', @_); }

=item $n = $p->First($round0[, $newvalue]);

Returns a number indicating whether the player did or will go
first in a zero-based round.

  0: did not play this round
  1: went first (started)
  2: went second (replied)
  3: must draw
  4: unknown pending earlier firsts/seconds or other information

=cut

sub First ($$;$) { 
  my $this = shift;
  my $round0 = shift;
  my $newp12 = shift;
  my $p12sp = $this->{'etc'}{'p12'};
  if (!defined $p12sp) {
    $p12sp = $this->{'etc'}{'p12'} = &share([]);
    }
  my $oldp12 = $p12sp->[$round0];
  $oldp12 = 4 unless defined $oldp12;
  if (defined $newp12) {
    if ($round0 < 0 || $round0 > $#$p12sp+1) {
      $this->Division()->Tournament->TellUser('eplyrror',
	'p12', $this->TaggedName(), $round0+1, $newp12);
      }
    elsif ($newp12 !~ /^[0-4]$/) {
      $this->Division()->Tournament->TellUser('eplyrbv',
	'p12', $this->TaggedName(), $round0+1, $newp12);
      }
    else {
      $p12sp->[$round0] = $newp12;
#     print "set p12 for $this->{'id'} in r0 $round0 to $newp12\n";
      }
    }
  return $oldp12;
  }

=item $n = $p->Firsts();

=item $newn = $p->Firsts($n);

Set or get the number of firsts a player has had.
Is called to set value in TSH::Division::SynchFirsts.

=cut

sub Firsts ($;$) { TSH::Utility::GetOrSet('p1', @_); }

=item $n = $p->FullID();

Return the player's 1-based ID number, formatted by
prepending either the division name (if there is more than
one division) or a number sign.

=cut

sub FullID ($) { 
  my $this = shift;
  my $dname = '';
  my $tournament = $this->Division()->Tournament();
  if ($tournament->CountDivisions() > 1) {
    $dname = $this->Division()->Name();
    $dname .= '-' if $dname =~ /\d$/;
    }
  my $fmt = $tournament->Config()->Value('player_number_format');
  return sprintf("%s$fmt", uc($dname), $this->{'id'});
  }

=item $p12p = $p->FirstVector();

=item $oldp12p = $p->Firsts($newp12p);

Returns a reference to a list of values (0-indexed by round)
as described in First(), or stores the list.

=cut

sub FirstVector ($;$) { 
  my $this = shift;
  my $newp12sp = shift;
  my $p12sp = $this->{'etc'}{'p12'};
  if (!defined $p12sp) {
    $p12sp = $this->{'etc'}{'p12'} = [];
    }
  if (defined $newp12sp) {
    $this->{'etc'}{'p12'} = $newp12sp;
    }
  return $p12sp;
  }

=item $n = $p->GamesPlayed();

Return the number of games a player has played, not including byes,
forfeits or unscored games.

=cut

sub GamesPlayed ($) { 
  my $this = shift;
  my $n = 0;
  my $pairingsp = $this->{'pairings'};
  my $scoresp = $this->{'scores'};
  for my $r0 (0..$#$scoresp) {
#   if ((defined $scoresp->[$r0]) && (defined $pairingsp->[$r0])) {
    if ((defined $scoresp->[$r0]) && $pairingsp->[$r0]) {
      $n++;
      }
    }
  return $n;
  }

=item $n = $p->GetOrSetEtcScalar($key[, $value]);

Get or set a miscellaneous scalar data field.

=cut

sub GetOrSetEtcScalar ($$;$) { 
  my $this = shift;
  my $key = shift;
  my $new = shift;
  my $old = $this->{'etc'}{$key};
  if (ref($old)) {
    $old = $old->[0];
    if (defined $new) {
      $this->{'etc'}{$key}[0] = $new;
      $this->Division()->Dirty(1);
      }
    }
  else {
    if (defined $new) {
      my @new : shared = ($new);
      $this->{'etc'}{$key} = \@new;
      $this->Division()->Dirty(1);
      }
    $old = undef;
    }
  return $old;
  }

=item $l = $p->GetOrSetEtcVector($key[, $value]);

Get or set a miscellaneous vector data field.

=cut

sub GetOrSetEtcVector ($$;$) { 
  my $this = shift;
  my $key = shift;
  my $new = shift;
  my $old = $this->{'etc'}{$key};
  if (ref($old)) {
    if (defined $new) {
      @{$this->{'etc'}{$key}} = @$new;
      }
    }
  else {
    if (defined $new) {
      my @new : shared = @$new;
      $this->{'etc'}{$key} = \@new;
      }
    $old = undef;
    }
  return $old;
  }

=item $l = $p->GetOrSetEtcVectorMember($key, $index, [, $value]);

Get or set a miscellaneous vector data field.

=cut

sub GetOrSetEtcVectorMember ($$$;$) { 
  my $this = shift;
  my $key = shift;
  my $index = shift;
  my $new = shift;
  my $old = $this->{'etc'}{$key};
  Carp::confess "assertion failed: \$index undefined" unless defined $index;
  if (defined $new && !defined $this->{'etc'}{$key}) {
    my @data : shared;
    $this->{'etc'}{$key} = \@data;
    }
  Carp::confess "assertion failed: array too short" if (defined $new) && $index < -@{$this->{'etc'}{$key}};
  if (ref($old)) {
    $old = $old->[$index];
    if (defined $new) {
      $this->{'etc'}{$key}[$index] = $new;
      }
    }
  else {
    if (defined $new) {
      my @new : shared;
      Carp::confess "assertion failed: index is nonnegative: $index" if $index < 0;
      $new[$index] = $new;
      $this->{'etc'}{$key} = \@new;
      }
    $old = undef;
    }
  return $old;
  }

=item $n = $p->ID();

Set or get the player's 1-based ID.

=cut

sub ID ($;$) { TSH::Utility::GetOrSet('id', @_); }

=item $old = $p->InitialRecord([$wins, $losses, $spread, $cspread, $sum]);

Get or set the player's life (career) games.

=cut

sub InitialRecord ($) {
  my $this = shift;
  my $new = shift;
  return $this->GetOrSetEtcVector('initrec', $new);
  }

=item $s = $p->Initials();

Return the player's initials

=cut

sub Initials ($) { 
  my $this = shift;
  unless ($this->{'initials'}) {
    my ($last, $first);
    my $name = uc $this->{'name'};
    if ($name =~ /,/) { ($last, $first) = split(/,\s*/, $name, 2); }
    else { ($first, $last) = $name =~ /^(.*\S)(?:\s+)(.*)$/; }
    $first =~ s/^.*?([A-Z]).*/$1/;
    $first = ' ' unless $first;
    $last =~ s/^.*?([A-Z]).*/$1/;
    $last = ' ' unless $last;
    $this->{'initials'} = "$first$last";
    }
  return $this->{'initials'};
  }

=item $d->initialise();

(Re)initialise a Player object, for internal use.

=cut

sub initialise ($) {
  my $this = shift;
  $this->{'name'} = '';
  $this->{'etc'} = &share({});
  }

=item $p->LatestScoredRound();

Report the latest 0-based round in which the player has a score
(assuming no gaps).

Compare with CountScores(), which includes defined zero scores.

=cut

sub LatestScoredRound ($) { 
  my $this = shift; 
  my $div = $this->Division();

  foreach my $r0 (0..$div->MaxRound0()) {
    next if $this->Score($r0);
    return $r0-1;
  }
  return $div->MaxRound0();
}

=item $s = $p->LocaliseName();

Return a player's name in suitably localised format.

=cut

sub LocaliseName ($) {
  my $this = shift;
  my $name = $this->Name();
  if (my $team = $this->Team()) {
    if ($team eq 'THA') {
      $name =~ s/.*, //;
      }
    }
  return $name;
  }

=item $old = $p->LifeGames([$games]);

Get or set the player's life (career) games.

=cut

sub LifeGames ($;$) { 
  my $this = shift;
  my $new = shift;
  return $this->GetOrSetEtcScalar('lifeg', $new);
  }

=item $n = $p->Losses();

Return the player's total losses so far this tournament.

=cut

sub Losses ($) { 
  my $this = shift;
  return ($this->{'losses'} || 0);
  }

=item $r = $p->MaxRank();

=item $p->MaxRank($r);

Set or get the player's maximum attainable ranking.

=cut

sub MaxRank ($;$) { TSH::Utility::GetOrSet('maxrank', @_); }

=item $r = $p->MinRank();

=item $p->MinRank($r);

Set or get the player's worst-case attainable ranking.

=cut

sub MinRank ($;$) { TSH::Utility::GetOrSet('minrank', @_); }

=item $d = new Player;

Create a new Player object.  

=cut

sub new ($) { return TSH::Utility::newshared(@_); }

=item $n = $p->Name();

Return the player's name.

=cut

sub Name ($;$) { 
  my $this = shift;
  my $new = shift;
  my $old = ($this->{'name'} || '?');
  $old =~ s/,\s*$//; # kludge to allow names ending in digits
  if (defined $new) {
    if ($new !~ /\S/) { warn "name must not be empty"; }
#   elsif ($new =~ /;|[^ -~]/) { warn "bad characters in name"; }
    elsif ($new =~ /;/) { warn "bad characters in name"; }
    else { 
      $new =~ s/\d$/$&,/;
      $this->{'name'} = $new;
      }
    delete $this->{'prettyname'};
    }
  return $old;
  }

=item $r = $p->NewRating($r0);

=item $p->NewRating($r0, $r);

Set or get the player's newly calculated rating estimate

=cut

sub NewRating ($$;$) { my $this = shift; $this->GetOrSetEtcVectorMember('newr', @_); }


=item $p->NextLocation();

Report the location the player is assigned to in the next round (earliest for
which they do not have a score). 

Does not yet support seats or i18n.

=cut

sub NextLocation ($) { 
  my $this = shift; 
  my $div = $this->Division();

  foreach my $r0 (0..$div->MaxRound0()) {
    next if $this->Score($r0);
    if ( $this->Board( $r0 ) ) {
      if ( $div->{'tournament'}->Config()->{'tables'} ) {
	return " (Round " . ($r0+1) . " at Table " . $div->BoardTable( $this->Board( $r0 ) ) . ")";
      } elsif ( $this->Board( $r0 ) ) {
	return " (Round " . ($r0+1) . " at Board " . $this->Board( $r0 ) . ")";
      } else {
	return "";
      }
    }
    return "";
  }
  return "";
}

=item $n = $p->OffSpread();

Return the spread being assigned to an inactive player's games.

=cut

sub OffSpread ($) {
  my $this = shift;
  return $this->{'etc'}{'off'}[0];
  }

=item $n = $p->Opponent($round0);

Return the player's opponent in 0-based
round $round0.

=cut

sub Opponent ($$) {
  my $this = shift;
  my $round0 = shift;
  my $oppid = $this->OpponentID($round0);
  if ($oppid) {
    return $this->Division()->Player($oppid);
    }
  else {
    return undef;
    }
  }

=item $n = $p->OpponentID($round0[, $newid]);

Return the 1-based ID number of the player's opponent in 0-based
round $round0, or undef if the pairing has yet been assigned.

Can be used in unusual circumstances to set the opponent ID, such
as when reading division data from an external source player by
player; if all players are already defined, use C<TSH::Division::Pair()>
instead.

=cut

sub OpponentID ($$;$) { 
  my $this = shift;
  my $round0 = shift;
  my $new = shift;
  unless (defined $this->{'pairings'}) {
    $this->{'pairings'} = &share([]);
    }
  my $old = $this->{'pairings'}[$round0];
  if (defined $new) {
    $this->{'pairings'}[$round0] = $new;
    }
# confess unless defined $round0;
  return $old;
  }

sub OpponentIDs ($) {
  my $this = shift;
  return $this->{'pairings'};
  }

=item $n = $p->OpponentScore($round0);

Return the player's opponent's score in 0-based
round $round0.

=cut

sub OpponentScore ($$) {
  my $this = shift;
  my $round0 = shift;
  my $opp = $this->Opponent($round0);
  if ($opp) {
    return $opp->Score($round0);
    }
  else {
    return undef;
    }
  }

=item $success = PairGRT($psp, $grtsub, $filter, \@grtargs, $round0[, \%rpopts]);

Pair the players listed in @$psp allowing each player to be paired
only with the opponents that pass &$filter, ranking them in preference
order according to the Guttman-Rosler Transform sub $grtsub, which
must pack player index in $psp as an 'N' at the end of its output
string.  $grtsub and $filter are passed the following arguments:

  - $psp 
  - index of current player in $psp
  - index of opponent in $psp
  - @grtargs

If $round0 is defined, pairings are stored in that zero-based round.
If $round0 is undefined, pairings are not stored, but status is still
returned based on whether or not pairings could be computed.

Arguments in %rpopts are passed to ResolvePairings.

=cut

sub PairGRT ($$$$$;$) { 
  my $psp = shift;
  my $grt = shift;
  my $filter = shift;
  my $argsp = shift;
  my $r0 = shift;
  my $rpopts = shift;
  return 1 unless @$psp;
# Debug 'GRT', 'PGRT psp: %s', join(',',map { $_->ID() } @$psp);
  for my $i (0..$#$psp) {
    my $p = $psp->[$i];
    my @opps : shared =
      # Guttman-Rosler Transform
      map { $psp->[unpack('N', substr($_, -4))] }
      sort 
      map { &$grt($psp, $i, $_, @$argsp) }
      grep { &$filter($psp, $i, $_, @$argsp) }
      (0..$i-1,$i+1..$#$psp);
#   printf 'pref %d: %s', $p->ID(), join(',',map { defined $_ ? $_->ID() : '???'; } @opps);
    Debug 'GRT', 'pref %d: %s', $p->ID(), join(',',map { 
	defined $_ ? $_->ID() : '???';
#	$_->ID() 
      } @opps);
    $psp->[$i]{'pref'} = \@opps;
    }
  my (%rpopts) = $rpopts ? %$rpopts : ();
  $rpopts{'target'} = $r0 unless exists $rpopts{'target'};
  if (ResolvePairings($psp, \%rpopts)) {
    DebugDumpPairings 'GRT', $psp->[0]->CountOpponents()-1, $psp
      if defined $r0;
    return 1;
    }
  else {
    return 0;
    }
  }

=item $old = $p->Password([$password]);

Get or set the player's data entry password.

=cut

sub Password ($;$) { 
  my $this = shift;
  my $new = shift;
  return $this->GetOrSetEtcScalar('password', $new);
  }

=item $n = $p->Penalty($r0[, -$x]);

Set/get the spread penalty applied to the player played in zero-based round $r0.

=cut

sub Penalty ($$;$) { 
  my $this = shift;
  my $r0 = shift;
  my $newpenalty = shift;
  my $penaltyp = $this->{'etc'}{'penalty'};
  unless (defined $penaltyp) { $this->{'etc'}{'penalty'} = $penaltyp = &share([]); }
  my $oldpenalty = $penaltyp->[$r0] || 0;
  if (defined $newpenalty) {
    if ($r0 > $#$penaltyp + 1) {
      push(@$penaltyp, (0) x ($r0 - $#$penaltyp - 1));
      }
    $penaltyp->[$r0] = $newpenalty;
    $this->Division()->Dirty(1);
    $this->Division()->DirtyRound($r0);
    }
  return $oldpenalty;
  }

=item $p = $p->PrettyName();

Return the player's name formatted for human eyes.  The raw name
as stored in the .t file should be in "surnames, given names" format
for easy conversion to NSA ratings list format (which is "surnames
given_names", with no indication of how the names should be separated.
The "pretty name" will be "given_names surnames" if there is a comma
in the raw name and "config surname_last" is set,
else the raw name unprocessed.

=cut

sub PrettyName ($;$) {
  my $this = shift;
  my $optionsp = shift;

  my $cache_key = 'prettyname';
  my $surname_last = $optionsp->{'surname_last'} || $this->Division()->Tournament->Config()->Value('surname_last');
  $cache_key .= 'l' if $optionsp->{'localise'};
  $cache_key .= 'p' if $optionsp->{'use_pname'};
  $cache_key .= 'b' if $optionsp->{'pname_from_sbname'};
  $cache_key .= 's' if $surname_last;
  if (!exists $this->{$cache_key}) {
    # When adding any new conditionals below, be sure to add cache_key tags above
    my $name;
    if ($optionsp->{'use_pname'} && defined($this->{'etc'}{'pname'})) {
      $name = join(' ', @{$this->{'etc'}{'pname'}}) 
      }
    elsif ($optionsp->{'pname_from_sbname'} && defined($this->{'etc'}{'sbname'})) {
      # pname_from_sbname implies use_pname
      $name = join(' ', @{$this->{'etc'}{'sbname'}}) 
      }
    else {
      $name = $optionsp->{'localise'} ? $this->LocaliseName() : $this->Name();
      $name =~ s/^Zxqkj, Winter$/Winter/;
      $name =~ s/^Nana, Kaia/Kaia/;
      if ($surname_last) {
	my ($surname, $given, $suffix) = split(/\s*,\s*/, $name, 3);
	$name = $surname;
	$name = "$given $name" if (defined $given) and $given ne '';
	$name = "$name, $suffix" if (defined $suffix) and $suffix ne '';
	}
      }
    $this->{$cache_key} = $name;
    }
  return $this->{$cache_key};
  }

=item $u = $p->PhotoMoodURL($mood);
=item $p->PhotoMoodURL($mood,$u);

Set or get the player's mood photo URL

=cut

sub PhotoMoodURL ($$;$) { my $this = shift; $this->GetOrSetEtcVectorMember('photomood', @_); }

=item $usp = $p->PhotoMoodURLs();
=item $p->PhotoMoodURLs($usp);

Set or get the player's mood photo URL vector

=cut

sub PhotoMoodURLs ($$;$) { TSH::Utility::GetOrSetEtcVector('photomood', @_); }

=item $u = $p->PhotoURL();
=item $p->PhotoURL($u);

Set or get the player's photo URL

=cut

sub PhotoURL ($;$) { TSH::Utility::GetOrSet('photo', @_); }

=item $r = $p->Random();
=item $p->Random($r);

Set or get the player's random value.

=cut

sub Random ($;$) { TSH::Utility::GetOrSet('rnd', @_); }

=item ($text, $html) = $p->RenderLocation($r0);

Return strings identifying where the player should be in zero-based
round C<$r0>.  Depending on configuration, this could be their seat,
board, table or undefined values.

There is similar but subtly different code in ShowPairings.pm.

=cut

sub RenderLocation ($$) {
  my $this = shift;
  my $r0 = shift;

  my $dp = $this->Division();
  my $config = $dp->Tournament()->Config();
  if ($config->Value('seats')) {
    my $seat = $this->Seat($r0) || '?';
    return ($seat, $seat);
    }
  my $no_boards = $config->Value('no_boards');
  my $board = $this->Board($r0);
  if ($dp->HasTables()) {
    my $table_format = $config->Value('table_format');
    my $table = $dp->BoardTable($board);
    if ((defined $no_boards) and $no_boards == 0) {
      return (sprintf("$table_format/%s", $table, $board), "$table/$board");
      }
    return (sprintf($table_format, $table), $table);
    }
  elsif ($no_boards) { return (undef, undef); }
  else { return ($board, $board); }
  }

=item $r = $p->Rating();
=item $p->Rating($r);

Set or get the player's rating

=cut

sub Rating ($;$) { TSH::Utility::GetOrSet('rating', @_); }

=item $n = $p->Repeats($oppid);

=item $n = $p->Repeats($oppid, $n);

Set or get the number of repeat pairings of this player with $oppid.

=cut

sub Repeats ($$;$) { 
  my $this = shift;
  my $oppid = shift;
  my $newrepeats = shift;
  my $repeatsp = $this->{'repeats'};
  unless (defined $repeatsp) { $this->{'repeats'} = $repeatsp = []; }
  my $oldrepeats = $repeatsp->[$oppid];
  if (defined $newrepeats) {
    if ($oppid < 0) {
      TSH::Utility::Error("Can't set repeats for " 
	. $this->TaggedName() 
	. " vs #$oppid to $newrepeats: round number is out of range."
        );
      }
    else {
      $repeatsp->[$oppid] = $newrepeats;
      }
    }
  if ((!defined $oldrepeats) && !defined $newrepeats) {
    TSH::Utility::Error("Can't get repeats for " 
      . $this->TaggedName() 
      . " vs #$oppid: repeats are not yet computed."
      );
    $oldrepeats = 0;
    }
  return $oldrepeats;
  }

=item $boolean = ResolvePairings $unpairedp[, \%options]

Given a division and a list of unpaired players who have their
'pref' field set to a list of opponent preferences, find a reasonable
pairing of all the players.  Return success.  
Sets the 'opp' field of each player paired to the
opponent's ID.  The following options are currently used:

optimize: sort players to optimize for runtime at the cost of
pairings quality (by default, do so if more than 12 players are
involved).

target: zero-based round in which to store pairings, if not
defined, set 'opp' and return status but do not store pairings in
'pairings'.

=cut

sub ResolvePairings ($$) {
  my $unpairedp = shift;
  my $optionsp = shift;
  my $just_checking = !defined $optionsp->{'target'};
  my $optimization_threshold = (defined $optionsp->{'optimize'})
    ? $optionsp->{'optimize'} : 12;
# Debug 'RP', "--- begin run ---";

  for my $p (@$unpairedp) {
#   Debug ('RP', ("$p->{'name'} ($p->{'id'}): " . join(' ', map { $_->{'id'} } @{$p->{'pref'}})));
    }
# print "# finding optimal pairing\n";
  # pruning dead branches saves us two orders of magnitude or so
  my %dead;

  my @sorted;
  # another (slight) speed optimization
  # don't use the following line: when doing Swiss pairings, we may explore
  # pairings and then expect to extract good values from 'opp'
# if ($just_checking || @$unpairedp > $optimization_threshold) {
  if (@$unpairedp > $optimization_threshold) {
#   Debug 'RP', "above optimization threshold $optimization_threshold, sorting players";
    @sorted = @$unpairedp[sort {
      # prefer players with fewer choices
      @{$unpairedp->[$a]{'pref'}} <=> @{$unpairedp->[$b]{'pref'}} ||
      # ties broken according to input ordering
      $a <=> $b;
      } 0..$#$unpairedp
      ];
    for my $p (@sorted) { Debug 'RP', $p->Name().': '.scalar(@{$p->{'pref'}}); }
    }
  else { @sorted = @$unpairedp; }

  { # block for scope isolation only
    my(@choice, $opp, $oppid);

    # mark all players as initially unpaired
    # 'opp' points to the provisional opponent
    for my $p (@sorted) { 
      $p->{'opp'} = -1; 
      # check quickly to see if pairings are impossible
      unless (@{$p->{'pref'}}) {
#	TSH::Utility::Error "No candidate opponents for " . $p->{'name'};
	return 0;
        }
      }

    # find best opp for each player, favoring top of field
    for (my $i=0; $i<=$#sorted; ) {
      my $p = $sorted[$i];
      if ($p->{'opp'} >= 0)
        { $i++; next; } # player has already been paired - skip
      my $key = join('', grep { $_->{'opp'} < 0 } 
	@sorted[$i..$#sorted]);
      if ($dead{$key}) {
	# this code is duplicated below and should be merged 
	# when fully debugged
        for ($choice[$i]=undef; $i>=0 && !defined $choice[$i]; $i--) { }
# print "$i.\n";
        if ($i < 0) {
	  TSH::Utility::Error "Walked entire tree, couldn't find acceptable pairing.\n"
	    unless $just_checking;
          return 0;
          }

        # find last paired player's opponent, which now has to be unpaired
        my $opp = $sorted[$i]{'pref'}[$choice[$i]];
        # un-pair opponent from that player
        $opp->{'opp'} = -1;
        # un-pair that player from the opponent
        $sorted[$i]{'opp'} = -1;
        next;
        }

      # go to head of preference list if visiting player for first time
      $choice[$i] = -1 unless defined $choice[$i];

      # try the next preferred opp for this player.
      $opp = $p->{'pref'}[++$choice[$i]];
#     warn ((defined $opp) ? "$p->{'name'}: trying $opp->{'name'}" : "$p->{'name'}: no opps\n");

      if (!defined $opp) {
#       Debug 'RP', "$p->{'name'} ($p->{'id'})can't be paired, backtracking";
	$dead{$key}++;
        for ($choice[$i]=undef; $i>=0 && !defined $choice[$i]; $i--) { }
# print "$i.\n";
        if ($i < 0) {
	  TSH::Utility::Error "Walked entire tree, couldn't find acceptable pairing.\n"
	    unless $just_checking;
          return 0;
          }

        # find last paired player's opponent, which now has to be unpaired
        my $opp = $sorted[$i]{'pref'}[$choice[$i]];
        # un-pair opponent from that player
        $opp->{'opp'} = -1;
        # un-pair that player from the opponent
        $sorted[$i]{'opp'} = -1;
        next;
        } # if (!defined $opp) - we've run out of opps, back up

#      Debug ('RP', ("$p->{'name'} ($p->{'id'}) has pairing vector: ".join(',', map { $_->ID() } @{$p->{'pref'}})));
#      Debug 'RP', (" trying to pair $p->{'name'}, choice $choice[$i] is " . (defined $opp ? "$opp->{'name'} ($opp->{'id'})" : 'undef'));

      if ($opp->{'opp'} >= 0) {
#	Debug 'RP', " but $opp->{'name'} has already been paired.\n";
        next;
        }

      # looks good so far, let's try to keep going
      $p->{'opp'} = $opp->{'id'};
      $opp->{'opp'} = $p->{'id'};
      $i++;
      } # for $i
    }
  # copy provisional opponents to pairings
  unless ($just_checking) {
    my $r0 = $optionsp->{'target'};
    for my $i (0..$#sorted) {
      my $p = $sorted[$i];
      my $old = $p->{'pairings'}[$r0];
      if (defined $old) {
	$p->Division()->Tournament->TellUser('erpowp', $p->TaggedName(), $old,
	  $r0+1, $p->{'opp'});
        }
      $p->{'pairings'}[$r0] = $p->{'opp'};
#     push(@{$p->{'pairings'}}, $p->{'opp'});
      }
    }
  1;
  } # sub ResolvePairings

=item $n = $p->RoundCappedSpread($round0);

Return the player's cumulative spread as of 0-based round $round0,
capped per round according to config standings_spread_cap.

=cut

sub RoundCappedSpread ($$) { 
  my $this = shift;
  my $round0 = shift;
  if ($round0 < 0) {
    if (my $initrec = $this->{'etc'}{'initrec'}) {
      return $initrec->[3] || 0;
      }
    return 0;
    }
  return 
    exists $this->{'rcspread'}[$round0] 
      ? $this->{'rcspread'}[$round0]
      : $this->{'cspread'};
  }

sub RoundFirsts ($;$) {
  my $this = shift;
  my $round0 = shift;
  my $n = 0;
  for my $r0 (0..$round0) {
    $n += ($this->First($r0)||0) == 1;
    }
  return $n;
  }

=item $n = $p->RoundLosses($round0);

Return the player's cumulative losses as of 0-based round $round0.

=cut

sub RoundLosses ($$) { 
  my $this = shift;
  my $round0 = shift;
  if ($round0 < 0) {
    if (my $initrec = $this->{'etc'}{'initrec'}) {
      return $initrec->[1] || 0;
      }
    return 0;
    }
  return 
    exists $this->{'rlosses'}[$round0] 
      ? $this->{'rlosses'}[$round0]
      : ($this->{'losses'} || 0);
  }

=item $n = $p->RoundCappedRank($round0, $rank);

Set or get the player's rank in 0-based round $round0.

=cut

sub RoundCappedRank ($$;$$) { 
  my $this = shift;
  my $round0 = shift;
  my $newrank = shift;
  my $quiet = shift;
  my $ranksp = $this->{'etc'}{'rcrank'};
  unless (defined $ranksp) { $this->{'etc'}{'rcrank'} = $ranksp = &share([]); }
  # Normally we work internally with zero-based indexing for round numbers.
  # Here we use one-based indexing and reserve the 'round 0 ranking' for
  # preevent ranking.  We therefore also do not use GetOrSetEtcVectorMember() here.
  my $round = $round0 + 1;
  my $oldrank = $ranksp->[$round];
# printf STDERR "r=%d new=%d old=%d\n", $round, ($newrank||-1), ($oldrank||-1);
  if (defined $newrank) {
    if ($round < 0) {
      $this->Division()->Tournament->TellUser('eplyrror',
	'rank', $this->TaggedName(), $round, $newrank);
      }
    else {
      $ranksp->[$round] = $newrank;
      }
    }
  if ((!$quiet) && (!defined $newrank) && !defined $oldrank) {
    $this->Division()->Tournament->TellUser('enorank', 
      $this->TaggedName(), $round);
    $oldrank = 0;
    }
  return $oldrank;
  }

=item $n = $p->RoundMood($round0, $mood);

Set or get the player's mood (0 = saddest, 100 = happiest) in 0-based round $round0.
C<$round0 = -1> will give you the current mood.

=cut

sub RoundMood ($$;$$) { 
  my $this = shift;
  my $round0 = shift;
  my $newmood = shift;
  my $quiet = shift;
  my $moodsp = $this->{'etc'}{'rmood'};
  unless (defined $moodsp) { $this->{'etc'}{'rmood'} = $moodsp = &share([]); }
  my $oldmood = $moodsp->[$round0];
# printf STDERR "r=%d new=%d old=%d\n", $round, ($newmood||-1), ($oldmood||-1);
  if (defined $newmood) {
    if ($round0 < 0) {
      $this->Division()->Tournament->TellUser('eplyrror',
	'mood', $this->TaggedName(), $round0+1, $newmood);
      }
    else {
      $moodsp->[$round0] = $newmood;
      }
    }
  if ((!$quiet) && (!defined $newmood) && !defined $oldmood) {
#   Carp::cluck;
    $this->Division()->Tournament->TellUser('enomood', 
      $this->TaggedName(), $round0);
    $oldmood = 0;
    }
  return $oldmood;
  }

=item ($ms, $os) = $p->RoundProvisionalScore($round0, $ms, $os);

Set or get the player's and their opponent's provisional score for zero-based
round C<$round0>.

=cut

sub RoundProvisionalScore ($$;$$) { 
  my $this = shift;
  my $round0 = shift;
  my ($ms, $os) = @_;
  my $provsp = $this->{'etc'}{'rprov'};
  unless (defined $provsp) { $this->{'etc'}{'rprov'} = $provsp = &share([]); }

  my @oldprov;
  my $r1 = $round0 + 1;
  for (my $i=0; $i<$#$provsp; $i+=3) {
#   warn "i=$i r=$provsp->[$i]";
    if ($provsp->[$i] == $r1) { 
      (@oldprov) = @$provsp[$i+1,$i+2];
      if (@_ == 2) {
	if ((defined $ms) and (defined $os)) {
	  (@$provsp[$i+1,$i+2]) = ($ms, $os);
	  }
	else {
	  splice(@$provsp, $i, 3);
	  }
        }
      last;
      }
    }

  if (@_ == 2) {
    if (!@oldprov) {
      if ((defined $ms) and (defined $os)) {
	push(@$provsp, $r1, $ms, $os);
	}
      }
    $this->Division()->Dirty(1);
    }

# warn "id=$this->{id} nscores=@{[$#_+1]} scores=@_ prov=@{$this->{etc}{rprov}} oldprov=@oldprov";
  return @oldprov;
  }

=item $n = $p->RoundRank($round0, $rank);

Set or get the player's rank in 0-based round $round0.
C<$round0 = -1> will give you the current rank.

=cut

sub RoundRank ($$;$$) { 
  my $this = shift;
  my $round0 = shift;
  my $newrank = shift;
  my $quiet = shift;
  my $ranksp = $this->{'etc'}{'rrank'};
  unless (defined $ranksp) { $this->{'etc'}{'rrank'} = $ranksp = &share([]); }
  # Normally we work internally with zero-based indexing for round numbers.
  # Here we use one-based indexing and reserve the 'round 0 ranking' for
  # preevent ranking.
  my $round = $round0 + 1;
  my $oldrank = $ranksp->[$round];
# printf STDERR "id=%d r=%d new=%d old=%d\n", $this->ID(),  $round, ($newrank||-1), ($oldrank||-1);
  if (defined $newrank) {
    if ($round < 0) {
      $this->Division()->Tournament->TellUser('eplyrror',
	'rank', $this->TaggedName(), $round, $newrank);
      }
    else {
      $ranksp->[$round] = $newrank;
      }
    }
  if ((!$quiet) && (!defined $newrank) && !defined $oldrank) {
#   Carp::cluck;
    $this->Division()->Tournament->TellUser('enorank', 
      $this->TaggedName(), $round);
    $oldrank = 0;
    }
  return $oldrank;
  }

sub RoundSeconds ($;$) {
  my $this = shift;
  my $round0 = shift;
  my $n = 0;
  for my $r0 (0..$round0) {
    $n += ($this->First($r0)||0) == 2;
    }
  return $n;
  }

=item $n = $p->RoundGameSpread($round0);

Return the player's single-game spread in 0-based round $round0.
Use this method rather than comparing scores because (1) spread_cap
might be in effect, and (2) player might not have an opponent, either
because of a bye or a single-player competition.

=cut

sub RoundGameSpread ($$) {
  my $this = shift;
  my $r0 = shift;
  return $this->RoundSpread($r0) - $this->RoundSpread($r0-1);
  }

=item $n = $p->RoundSpread($round0);

Return the player's cumulative spread as of 0-based round $round0.

=cut

sub RoundSpread ($$) { 
  my $this = shift;
  my $round0 = shift;
  if ($round0 < 0) {
    if (my $initrec = $this->{'etc'}{'initrec'}) {
      return $initrec->[2] || 0;
      }
    return 0;
    }
  return 
    exists $this->{'rspread'}[$round0] 
      ? $this->{'rspread'}[$round0]
      : $this->{'spread'};
  }

=item $n = $p->RoundSum($round0);

Return the player's cumulative points scored as of 0-based round $round0.

=cut

sub RoundSum ($$) { 
  my $this = shift;
  my $round0 = shift;
  if ($round0 < 0) {
    if (my $initrec = $this->{'etc'}{'initrec'}) {
      return $initrec->[4] || 0;
      }
    return 0;
    }
  return 
    exists $this->{'rsum'}[$round0] 
      ? $this->{'rsum'}[$round0]
      : $this->{'sum'};
  }

=item $t = $p->RoundTime($r0);

=item $p->RoundTime($r0, $t);

Set or get the player's round modification time.

=cut

sub RoundTime ($$;$) { my $this = shift; $this->GetOrSetEtcVectorMember('rtime', @_); }

=item $n = $p->RoundWins($round0);

Return the player's cumulative wins as of 0-based round $round0.

=cut

sub RoundWins ($$) { 
  my $this = shift;
  my $round0 = shift;
  if ($round0 < 0) {
    if (my $initrec = $this->{'etc'}{'initrec'}) {
      return $initrec->[0] || 0;
      }
    return 0;
    }
  return 
    exists $this->{'rwins'}[$round0] 
      ? $this->{'rwins'}[$round0]
      : ($this->{'wins'} || 0);
  }

=item $n = $p->Score($round0[, $score]);

Return or set the player's score in 0-based round $round0.
Should always be used when modifying scores.

=cut

sub Score ($$;$) { 
  my $this = shift;
  my $round0 = shift;
  my $newscore = shift;
  # warn "Set $this->{'name'} score in round $round0+1 to $newscore\n";
  my $scoresp = $this->{'scores'};
  if (!defined $scoresp) {
    $scoresp = $this->{'scores'} = &share([]);
    }
  my $oldscore = $scoresp->[$round0];
# Debug 'SCORE', 'r=%d ns=%d s=%d ds1=%d ds2=%d n=%s', $round0+1, scalar(@$scoresp), $oldscore, (defined $oldscore), (defined $scoresp->[$round0]), $this->{'id'};
  if (defined $newscore) {
    my $dp = $this->Division();
    if ($round0 < 0 
      || ($config::allow_gaps 
	? $round0 >= ($dp->MaxRound0()||0)+1
	: $round0 > @$scoresp)) {
      $dp->Tournament->TellUser('eplyrror',
	'score', $this->TaggedName(), $round0+1, $newscore);
      }
    else {
      $scoresp->[$round0] = $newscore;
      $this->RoundTime($round0, time);
      $dp->DirtyRound($round0);
      }
    }
  return $oldscore && ($oldscore == 9999 ? undef : $oldscore);
  }

sub Scores ($) {
  my $this = shift;
  return $this->{'scores'};
  }

=item $t = $p->Seat($r0);

Get the player's seat in 0-based round C<$r0>.
Return C<0> if the player has a forfeit or bye.
Return C<'00'> if the player has no opponent number (even 0).
Return C<undef> if the player has a pairing but no board assignment.

Do not use this function to determine the notional seat of a player
with a forfeit or bye; see TSH::Division::RoundSeatPlayer() instead.

=cut

sub Seat ($$) { 
  my $this = shift; 
  my $r0 = shift;

  my $oid = $this->OpponentID($r0);
  return '00' unless defined $oid;
  return 0 unless $oid;
  my $board = $this->Board($r0);
  return undef unless $board;
  return $this->ID() > $oid ? 2*$board : 2*$board - 1;
  }

=item $n = $p->Seconds();

=item $newn = $p->Seconds($n);

Set or get the number of seconds a player has had.
Is called to set value in TSH::Division::SynchFirsts.

=cut

sub Seconds ($;$) { TSH::Utility::GetOrSet('p2', @_); }

=item SortByBracket($round0, @players)

Sorts players according to where they stand in a bracket pairing system.

=cut

sub SortByBracket ($@) {
  my $sr0 = shift;

  return @_ unless @_;
  my $dp = $_[0]->Division();
  my $config = $dp->Tournament()->Config();
  if (($config->Value('bracket_noncon_pairings') || '') ne 'nasc') {
    warn "Bracket rankings only currently available for config bracket_noncon_pairings = 'nasc'";
    return SortByStanding($sr0, @_);
    }

  # determine starting round of current bracket
  my $prelims0 = ($config->Value('bracket_prelims')||0) - 1;
  if ($sr0 <= $prelims0) {
    warn "Bracket rankings revert to regular rankings during prelims";
    return SortByStanding($sr0, @_);
    }
  
  if ($sr0 <= 24) {
    my (@bracketed, @rest);
    for my $p (@_) {
      if ($p->GetOrSetEtcVectorMember('bracketseed', 21)) {
	push(@bracketed, $p);
#	warn "bracketed: $p->{'id'}";
        }
      else {
	push(@rest, $p);
        }
      }
    for my $p (@bracketed) {
      $p->{tlosses} = $p->RoundLosses(24) - $p->RoundLosses(20);
      $p->{twins} = $p->RoundWins(24) - $p->RoundWins(20);
      $p->{tspread} = $p->RoundSpread(24) - $p->RoundSpread(20);
      }
    return (
      (sort { $b->{twins} <=> $a->{twins} or $a->{tlosses} <=> $b->{tlosses} or $b->{tspread} <=> $a->{tspread} } 
	@bracketed),
      (SortByStanding($sr0, 
	@rest))
      );
    }

  if ($sr0 <= 28) {
    my (@bracketed, @qflosers, @rest);
    for my $p (@_) {
      if ($p->GetOrSetEtcVectorMember('bracketseed', 25)) {
	push(@bracketed, $p);
	warn "bracketed: $p->{'id'}";
        }
      elsif ($p->GetOrSetEtcVectorMember('bracketseed', 21)) {
	push(@qflosers, $p);
	warn "qfloser: $p->{'id'}";
        }
      else {
	push(@rest, $p);
        }
      }
    for my $p (@bracketed, @qflosers) {
      $p->{tlosses} = $p->RoundLosses(28) - $p->RoundLosses(24);
      $p->{twins} = $p->RoundWins(28) - $p->RoundWins(24);
      $p->{tspread} = $p->RoundSpread(28) - $p->RoundSpread(24);
      }
    return (
      (sort { $b->{twins} <=> $a->{twins} or $a->{tlosses} <=> $b->{tlosses} or $b->{tspread} <=> $a->{tspread} } 
	@bracketed),
      (sort { $b->{twins} <=> $a->{twins} or $a->{tlosses} <=> $b->{tlosses} or $b->{tspread} <=> $a->{tspread} } 
	@qflosers),
      (SortByStanding($sr0, 
	@rest))
      );
    }

  if ($sr0 <= 34) {
    my (@bracketed, @qflosers, @sflosers, @rest);
    for my $p (@_) {
      if (my $bracketseed = $p->GetOrSetEtcVectorMember('bracketseed', 29)) {
	if ($bracketseed =~ /^[14]$/) {
	  push(@bracketed, $p);
	  warn "bracketed: $p->{'id'}";
	  }
	else {
	  push(@sflosers, $p);
	  warn "sfloser: $p->{'id'}";
	  }
        }
      elsif ($p->GetOrSetEtcVectorMember('bracketseed', 21)) {
	push(@qflosers, $p);
	warn "qfloser: $p->{'id'}";
        }
      else {
	push(@rest, $p);
        }
      }
    for my $p (@bracketed, @sflosers) {
      $p->{tlosses} = $p->RoundLosses(33) - $p->RoundLosses(28);
      $p->{twins} = $p->RoundWins(33) - $p->RoundWins(28);
      $p->{tspread} = $p->RoundSpread(33) - $p->RoundSpread(28);
      }
    for my $p (@qflosers) {
      $p->{tlosses} = $p->RoundLosses(33) - $p->RoundLosses(24);
      $p->{twins} = $p->RoundWins(33) - $p->RoundWins(24);
      $p->{tspread} = $p->RoundSpread(33) - $p->RoundSpread(24);
      }
    return (
      (sort { $b->{twins} <=> $a->{twins} or $a->{tlosses} <=> $b->{tlosses} or $b->{tspread} <=> $a->{tspread} } 
	@bracketed),
      (sort { $b->{twins} <=> $a->{twins} or $a->{tlosses} <=> $b->{tlosses} or $b->{tspread} <=> $a->{tspread} } 
	@sflosers),
      (sort { $b->{twins} <=> $a->{twins} or $a->{tlosses} <=> $b->{tlosses} or $b->{tspread} <=> $a->{tspread} } 
	@qflosers),
      (SortByStanding($sr0, 
	@rest))
      );
    }
  die "$sr0 $prelims0";
  }

=item SortByCappedStanding($round0, @players)

Sorts players according to their standings as of zero-based round
$round0, capped according to standings_spread_cap and returns the sorted list.

=cut

sub SortByCappedStanding ($@) {
  my $sr0 = shift;

  return @_ unless @_;
  my $dp = $_[0]->Division();
  my $config = $dp->Tournament()->Config();
  my $sum_before_spread = $config->Value('sum_before_spread');
  my $rating_system = $dp->RatingSystem();

# local($^W) = 0;
  return sort { 
#  die ("Incomplete player $a->{'name'} ($a):\n  ".join(', ',keys %$a)."\n") unless defined $a->{'wins'} && defined $a->{'spread'} && defined $a->{'rating'} && defined $a->{'rnd'};
    $sr0 >= 0 ? 
      ($b->{'left_after'}||0) <=> ($a->{'left_after'}||0) ||
      ((defined ($b->{'rwins'}[$sr0]) ? $b->{'rwins'}[$sr0] : $b->{'wins'})<=>(defined ($a->{'rwins'}[$sr0]) ? $a->{'rwins'}[$sr0] : $a->{'wins'}) ||
      ((defined ($a->{'rlosses'}[$sr0]) ? $a->{'rlosses'}[$sr0] : $a->{'losses'})<=>(defined ($b->{'rlosses'}[$sr0]) ? $b->{'rlosses'}[$sr0] : $b->{'losses'})) ||
      ($sum_before_spread ? 
        (defined ($b->{'rsum'}[$sr0]) ? $b->{'rsum'}[$sr0] : $b->{'sum'})<=>(defined ($a->{'rsum'}[$sr0]) ? $a->{'rsum'}[$sr0] : $a->{'sum'}) 
	: 0) ||
      ((defined ($b->{'rcspread'}[$sr0]) ? $b->{'rcspread'}[$sr0] : $b->{'cspread'})<=>(defined $a->{'rcspread'}[$sr0] ? $a->{'rcspread'}[$sr0] : $a->{'cspread'})) || 
      $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) ||
      $b->{'rnd'}<=>$a->{'rnd'} || $a->{'id'} <=> $b->{'id'})
    : $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) || $b->{rnd} <=> $a->{rnd} || $a->{'id'} <=> $b->{'id'}
    ; } @_;
  }

=item @sorted = SortByCurrentStanding(@players)

Sorts players according to their current standings and returns the sorted list.

=cut

sub SortByCurrentStanding (@) {
  return @_ unless @_;
  my $dp = $_[0]->Division();
  my $config = $dp->Tournament()->Config();
  my $sum_before_spread = $config->Value('sum_before_spread');
  my $rating_system = $dp->RatingSystem();

  return sort {
    ($b->{'left_after'}||0) <=> ($a->{'left_after'}||0) ||
    $b->{wins} <=> $a->{wins} ||
    $a->{losses} <=> $b->{losses} ||
    ($sum_before_spread ? 
      $b->{sum} <=> $a->{sum}
      : 0) ||
    $b->{spread} <=> $a->{spread} ||
    $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) ||
    $b->{rnd} <=> $a->{rnd} || $a->{'id'} <=> $b->{'id'};
    } @_;
  }

=item SortByHandicap($round0, @players)

Sorts players according to their handicap points as of zero-based round
$round0 and returns the sorted list.

=cut

sub SortByHandicap ($@) {
  my $sr0 = shift;

  return @_ unless @_;
  my $dp = $_[0]->Division();
  my $config = $dp->Tournament()->Config();
  my $sum_before_spread = $config->Value('sum_before_spread');
  my $rating_system = $dp->RatingSystem();

  for my $p (@_) {
    if (!defined $p->{'etc'}{'handicap'}) {
      $p->{'etc'}{'handicap'} = &share([]);
      $p->{'etc'}{'handicap'}[0] = 0;
      }
    }

# local($^W) = 0;
  # TODO: this crashes with invalid value for shared scalar if someone doesn't have a handicap
  return sort { 
#  die ("Incomplete player $a->{'name'} ($a):\n  ".join(', ',keys %$a)."\n") unless defined $a->{'wins'} && defined $a->{'spread'} && defined $a->{'rating'} && defined $a->{'rnd'};
#   warn $b->{'name'} . ' ' . $b->{'etc'}{'handicap'}+2*$b->{'rwins'}[$sr0];
    $sr0 >= 0 ? 
      ((defined ($b->{'rwins'}[$sr0]) ? ($b->{'etc'}{'handicap'}[0]||0)+2*$b->{'rwins'}[$sr0] : ($b->{'etc'}{'handicap'}[0]||0)+2*$b->{'wins'})<=>(defined ($a->{'rwins'}[$sr0]) ? ($a->{'etc'}{'handicap'}[0]||0)+2*$a->{'rwins'}[$sr0] : ($a->{'etc'}{'handicap'}[0]||0)+2*$a->{'wins'}) ||
      ($sum_before_spread ? 
        (defined ($b->{'rsum'}[$sr0]) ? $b->{'rsum'}[$sr0] : $b->{'sum'})<=>(defined ($a->{'rsum'}[$sr0]) ? $a->{'rsum'}[$sr0] : $a->{'sum'}) 
	: 0) ||
      # 2017-07-09: noticed that wins came ahead of spread in PRiZes, reordered next three lines to match
      (defined ($b->{'rwins'}[$sr0]) ? $b->{'rwins'}[$sr0] : $b->{'wins'})<=>(defined ($a->{'rwins'}[$sr0]) ? $a->{'rwins'}[$sr0] : $a->{'wins'}) ||
      ((defined ($a->{'rlosses'}[$sr0]) ? $a->{'rlosses'}[$sr0] : $a->{'losses'})<=>(defined ($b->{'rlosses'}[$sr0]) ? $b->{'rlosses'}[$sr0] : $b->{'losses'})) ||
      ((defined ($b->{'rspread'}[$sr0]) ? $b->{'rspread'}[$sr0] : $b->{'spread'})<=>(defined $a->{'rspread'}[$sr0] ? $a->{'rspread'}[$sr0] : $a->{'spread'})) || 
      $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) ||
      $b->{'rnd'}<=>$a->{'rnd'} || $a->{'id'} <=> $b->{'id'})
    : (($b->{'etc'}{'handicap'}[0]||0)<=> ($a->{'etc'}{'handicap'}[0]||0) ||
      $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) ||
      $b->{rnd} <=> $a->{rnd} || $a->{'id'} <=> $b->{'id'})
    ; } @_;
  }

=item SortByInitialStanding(@players)

Sorts players according to their initial standings and returns the sorted list.

=cut

sub SortByInitialStanding (@) {
  my $dp = $_[0]->Division();
  my $config = $dp->Tournament()->Config();
  my $rating_system = $dp->RatingSystem();
  return sort {
    my $air = $a->{'etc'}{'initrec'};
    my $bir = $b->{'etc'}{'initrec'};
    if ($air || $bir) {
      my (@air) = $air ? @$air : ();
      my (@bir) = $bir ? @$bir : ();
      my $cmp = 
        ($bir[0] || 0) <=> ($air[0] || 0) || # wins
        ($air[1] || 0) <=> ($air[1] || 0) || # losses
        ($bir[3] || 0) <=> ($air[3] || 0) || # capped spread (TODO: offer choice)
        ($bir[2] || 0) <=> ($air[2] || 0)    # uncapped spread 
      ;
      return $cmp if $cmp;
      }
    $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) ||
    $b->{rnd} <=> $a->{rnd} ||
    $a->{id} <=> $b->{id}
    } @_;
  }

=item SortByName(@players)

Sorts players according to their names and returns the sorted list.
Sort order is affected by configuration value C<sort_by_first_name>.

=cut

sub SortByName (@) {
  return @_ unless @_ > 1;
  my $config = $_[0]->Division()->Tournament()->Config();
  if ($config->Value('sort_by_first_name')) {
    return sort { $a->PrettyName() cmp $b->PrettyName() } @_;
    }
  elsif ($config->Value('localise_names')) {
    return sort { $a->LocaliseName() cmp $b->LocaliseName() } @_;
    }
  else {
    return sort { $a->{'name'} cmp $b->{'name'} } @_;
    }
  }

sub MakeStandingComparator ($$) {
  my $sr0 = shift @_;
  my $dp = shift @_;
  my $config = $dp->Tournament()->Config();
  my $spread_bad = $config->Value('spread_bad') ? -1 : 1;
# warn $spread_bad;
  my $sum_before_spread = $config->Value('sum_before_spread');
  my $rating_system = $dp->RatingSystem();
  return sub ($$) { 
    my $a = shift @_;
    my $b = shift @_;
#  die ("Incomplete player $a->{'name'} ($a):\n  ".join(', ',keys %$a)."\n") unless defined $a->{'wins'} && defined $a->{'spread'} && defined $a->{'rating'} && defined $a->{'rnd'};
    ($b->{'left_after'}||0) <=> ($a->{'left_after'}||0) ||
    ((defined ($b->{'rwins'}[$sr0]) ? $b->{'rwins'}[$sr0] : $b->{'wins'})<=>(defined ($a->{'rwins'}[$sr0]) ? $a->{'rwins'}[$sr0] : $a->{'wins'}) ||
    ((defined ($a->{'rlosses'}[$sr0]) ? $a->{'rlosses'}[$sr0] : $a->{'losses'})<=>(defined ($b->{'rlosses'}[$sr0]) ? $b->{'rlosses'}[$sr0] : $b->{'losses'})) ||
    ($sum_before_spread ? 
      (defined ($b->{'rsum'}[$sr0]) ? $b->{'rsum'}[$sr0] : $b->{'sum'})<=>(defined ($a->{'rsum'}[$sr0]) ? $a->{'rsum'}[$sr0] : $a->{'sum'}) 
      : 0) ||
    ($spread_bad*((defined ($b->{'rspread'}[$sr0]) ? $b->{'rspread'}[$sr0] : $b->{'spread'})<=>(defined $a->{'rspread'}[$sr0] ? $a->{'rspread'}[$sr0] : $a->{'spread'}))) || 
    $rating_system->CompareRatings($b->{'rating'}, $a->{'rating'}) ||
    $b->{'rnd'}<=>$a->{'rnd'} || 
    $a->{'id'} <=> $b->{'id'} )
    ; };
  }

=item SortByStanding($round0, @players)

Sorts players according to their standings as of zero-based round
$round0 and returns the sorted list.

=cut

sub SortByStanding ($@) {
  my $sr0 = shift;

  return @_ unless @_;
  return SortByInitialStanding @_ if $sr0 < 0;

  my $comparator = MakeStandingComparator($sr0, $_[0]->Division());
  return sort $comparator @_;
  }

=item SpliceInactive(@ps, $nrounds, $round0)

Removes all inactive players from C<@ps>
and assigns them byes for the next $nrounds$ rounds
beginning with round $round0
unless they already have pairings/scores for those rounds.

=cut

sub SpliceInactive (\@$$) {
  my $psp = shift;
  my $count = shift;
  my $round0 = shift;

# warn $round0;
# return if $round0 < 0;
# warn scalar(@$psp);
  for (my $i=0; $i<=$#$psp; $i++) {
    my $p = $psp->[$i];
#   warn "trying $i";
    my $off = $p->{'etc'}{'off'};
#   warn join(',', keys %{$p->{'etc'}});
    next unless defined $off;
#   warn "splicing $p->{'name'}";
    TSH::Utility::SpliceSafely(@$psp, $i--, 1);
    
    next if $round0 < 0;
    my $pairingsp = $p->{'pairings'};
    next if $#$pairingsp < $round0-1;
    my $scoresp = $p->{'scores'};
    for my $j ($round0..$round0+$count-1) {
      $pairingsp->[$j] = 0 unless defined $pairingsp->[$j];
      $scoresp->[$j] = $off->[0] unless defined $scoresp->[$j];
      }
    }
  }

sub CappedSpread ($) { 
  my $this = shift;
  return $this->{'cspread'};
  }

=item $n = $p->Spread();

Return the player's cumulative spread so far this tournament.

=cut

sub Spread ($) { 
  my $this = shift;
  my $cume;
  $cume = $this->{'etc'}{'cume'}[0] if exists $this->{'etc'}{'cume'};
  unless (defined $cume) {
    $cume = $this->{'spread'} || 0;
    }
  return $cume;
  }

=item $n = $p->SRDiff($r0);

Net number of timesprior to $r0 this player has been gone first against his 
$r0 opponent.

=cut

sub SRDiff($$) {
  my $this = shift;
  my $r0 = shift;
  my $sr_diff = 0;
  my $opp = $this->Opponent($r0);
  return 0 unless defined $opp;
  for my $r (reverse 0..$r0-1) {
    if ( ${$this->{'pairings'}}[$r] == $opp->ID() ) {
      my $opp_p12 = ${$opp->{'etc'}{'p12'}}[$r];
      my $p_p12   = ${$this->{'etc'}{'p12'}}[$r];
      if ( $opp_p12  < 1 
           || $p_p12 < 1
           || $opp_p12 > 2 
           || $p_p12   > 2
           || $p_p12 == $opp_p12 )
      {
        warn "Nonsensical SR data for " . $this->TaggedName() . " vs. " . $opp->TaggedName() . " in Round " . $r+1 . ":  $p_p12 $opp_p12";
          return 0;
      }
      $sr_diff += ${$opp->{'etc'}{'p12'}}[$r] - ${$this->{'etc'}{'p12'}}[$r];
    }
  }

  if ( $sr_diff ) 
    {
      Debug 'H2H', "Non-zero H2H SR for " . $this->TaggedName() . " vs. " . $opp->TaggedName() . ":  $sr_diff";
    }
  return $sr_diff;
}

=item $s = $p->StrippedName();

Return the player's name, stripped of any attached membership number.

=cut

sub StrippedName ($) {
  my $this = shift;
  my $name = $this->{'name'};
  if ($this->Division()->RatingSystemName() =~ /nsa|naspa|nssc/) {
    $name =~ s/:(?:[A-Z]{2}\d{6})?(?:\/\d+)?,?$//;
    }
  return $name;
  }

=item $n = $p->SupplementaryRatingsData($system_type, $subfield[, $value]);

Get or set supplementary ratings data. 
C<$system_type> should be a valid rating system name.
C<$subfield> should be one of the keys shown in C<%subfield_types> below.

=cut

{
my %subfield_types = (
  'old' => 0, # pretournament rating
  'games' => 1, # career game total
  'new' => 2, # post-tournament rating
  'perf' => 3, # tournament performance rating
  'nseg' => 4, # number of split segments for rating purposes
  'mid1' => 5, # rating after first split
  'perf1' => 6, # performance during first segment
  'mid2' => 7, # rating after second split
  'perf2' => 8, # performance during second segment
  'perf3' => 9, # performance during third segment
  'games1' => 10, # games played during first segment
  'games2' => 11, # games played during second segment
  'games3' => 12, # games played during third segment
  );
sub SupplementaryRatingsData($$$;$) {
  my $this = shift;
  my $type = shift;
  my $subfield = shift;
  my $new = shift;
# warn "$this->{'name'} $type $subfield $new";
  unless ($subfield =~ /^\d+$/) {
    my $n = $subfield_types{$subfield};
    die "bad subfield id: $subfield" unless defined $n;
    $subfield = $n;
    }
  $type = lc $type;
  $type =~ s/\W/_/g;
  my $key = "rating_$type";
  my $ref = $this->GetOrSetEtcVector($key);
  my $old = $ref ? $ref->[$subfield] : undef;
  if (defined $new) {
    if (defined $ref) {
      $ref->[$subfield] = $new;
      }
    else {
      $ref = &share([]);
      $ref->[$subfield] = $new;
      $this->GetOrSetEtcVector($key, $ref);
      }
    $this->Division()->Dirty(1);
    }
# warn "$this ".($old||'undef');
  return $old;
  }
}

=item $p->GameTag($round0, $tag);

Specify a game tag (typically owl/csw in NASPA use) for a game
played.

=cut

sub GameTag ($$$) { my $this = shift; $this->GetOrSetEtcVectorMember('tag', @_); }

=item $n = $p->TaggedHTMLName($optionsp);

As TaggedName, but <span>-labels parts of name.

=cut

sub TaggedHTMLName ($;$) { 
  my $this = shift;
  my $optionsp = shift;
  my $config = $this->Division()->Tournament()->Config();

  # backward compatibility
  if ($optionsp) {
    if (!ref($optionsp)) {
      $optionsp = {'style' => $optionsp};
      }
    }
  else {
    $optionsp = {};
    }

  my $style = $optionsp->{'style'} || '';
  my $noid = $optionsp->{'noid'};
  my $noteam = $optionsp->{'noteam'};
  my (%options) = %$optionsp;
  $options{'use_pname'} ||= $style eq 'print';
  $options{'pname_from_sbname'} = $config->Value('pname_from_sbname');
  my $clean_name = $this->PrettyName(\%options);
  my $fullid = '';
  $fullid = '<span class=id>' . $this->FullID() . '</span>' unless $noid;
  if ((!$noteam) && $config->Value('show_teams')) {
    $fullid .= '<span class=team>/' 
      . ($style eq 'print' && $this->{'etc'}{'pteam'} ? join(' ', @{$this->{'etc'}{'pteam'}}) : $this->Team()) 
      . '</span>';
    }
  if (length($fullid)) {
    $fullid = qq{ <span class=lp>(</span>$fullid<span class=rp>)</span>};
    }
  my $s = (defined $this) && length($clean_name)
    ? $config->Value('player_id_first')
      ? "$fullid<span class=name>$clean_name</span>" 
      : "<span class=name>$clean_name</span>$fullid"
    : 'nobody';
  if ($config->{'scoreboard_links'}) {
    my $dname = $this->Division()->Name();
    my $id0 = $this->ID()-1;
    $s = qq(<a href="$dname-enhanced-scoreboard.html?selflink=true&offset=$id0&rows=1&columns=1&style=card&order=id" class=sbplink title=Scorecard>$s</a>);
    }
  return $s;
  }

=item $n = $p->TaggedName(\%options);

Return a formatted version of the player's name, including
their player number.  You should call the wrapper TSH::Utility::TaggedName
unless you are 100% sure that the player pointer is valid.

How tricky can it be to format a player's name? Here are the current options.

localise - display THA team players such as Nemitrmansuk, Pakorn as Pakorn

noid - do not display player ID

noteam - do not display player team even if config show_teams

player_id_first - (A1) Nigel Richards rather than Nigel Richards (A1)

style => 'print' - use pname and pteam rather than regular name and team

surname_last - display Chew, John as John Chew (||ed with config surname_last value)

use_pname - use player's pname extension field rather than their main name (||ed with style => 'print')

=cut

sub TaggedName ($;$) { 
  my $this = shift;
  return 'nobody' unless defined $this;
  my $optionsp = shift;

  # backward compatibility
  if ($optionsp) {
    if (!ref($optionsp)) {
      $optionsp = {'style' => $optionsp};
      }
    }
  else {
    $optionsp = {};
    }

  my $style = $optionsp->{'style'} || '';
  my $noid = $optionsp->{'noid'};
  my $noteam = $optionsp->{'noteam'};
  my (%options) = %$optionsp;
  $options{'use_pname'} ||= $style eq 'print';
  my $clean_name = $this->PrettyName(\%options);
#   die $clean_name . '/' . join(',', %$optionsp) if $clean_name =~ /,/ && $this->Team() =~ /THA/;
#  warn "$this->{'etc'}{'team'}[0]:$clean_name:".':'.join(",", %$optionsp) if $this->{'etc'}{'team'}[0] =~ /THA/ && $clean_name =~ /,/;
  return 'nobody' unless length($clean_name);
  my $fullid = $noid ? '' : $this->FullID();
  my $team = '';
  my $config = $this->Division()->Tournament()->Config();
  if ((!$noteam) && $config->Value('show_teams')) {
    $fullid .= '/' . ($style eq 'print' && $this->{'etc'}{'pteam'} ? join(' ', @{$this->{'etc'}{'pteam'}}) : $this->Team());
    }
  return $clean_name unless length($fullid);
  return $config->Value('player_id_first')
    ? "($fullid) $clean_name"
    : "$clean_name ($fullid)";
  }

=item $s = $p->Team();

Get or set the player's team name.

=cut

sub Team ($;$) { 
  my $this = shift;
  my $new = shift;
  my $old = $this->{'etc'}{'team'} ? join(' ', @{$this->{'etc'}{'team'}}) : '';
  if (defined $new) {
    my (@new) : shared = ($new);
    $this->{'etc'}{'team'} = \@new;
    $this->Division()->Dirty(1);
    }
  return $old;
  }

=item $t = $p->Time([$time]);

Get or set the player's update time.

=cut

sub Time ($;$) { 
  my $this = shift;
  my $new = shift;
  return $this->GetOrSetEtcScalar('time', $new);
  }

=item $changed = $p->Truncate($r0);

Remove all player data after round $r0.

=cut

sub Truncate ($$) {
  my $this = shift;
  my $r0 = shift;
  my $changed = 0;
  for my $key (qw(board p12 penalty seat)) {
    next if exists $this->{'etc'}{$key};
    $this->{'etc'}{$key} = &share([]);
    $changed = 1;
    }
  # 0-based round lists: start with data about first round
  for my $ip (
    $this->{'scores'},
    $this->{'pairings'},
    $this->{'etc'}{'board'},
    $this->{'etc'}{'newr'},
    $this->{'etc'}{'p12'},
    $this->{'etc'}{'penalty'},
    $this->{'etc'}{'rmood'},
    $this->{'etc'}{'rtime'},
    $this->{'etc'}{'seat'},
    $this->{'etc'}{'time'},
    ) {
    if ($ip && $#$ip >= $r0) { 
#     $#$ip = $r0; # splices are not thread-safe
      my @truncated : shared = @$ip[0..$r0];
      $ip = \@truncated;
      $changed = 1;
      }
    }
  # 1-based round lists: start with one preevent datum
  for my $ip (
    $this->{'etc'}{'rcrank'},
    $this->{'etc'}{'rrank'},
    ) {
    if ($ip && $#$ip > $r0+1) { 
#     $#$ip = $r0; # splices are not thread-safe
      my @truncated : shared = @$ip[0..$r0+1];
      $ip = \@truncated;
      $changed = 1;
      }
    }
  # TODO: should probably truncate etc/rprov as well
  if ($r0 < 0) {
    delete $this->{'etc'}{'bracketseed'};
    delete $this->{'etc'}{'excwins'};
    delete $this->{'etc'}{'off'};
    }
  $changed ||= $this->TruncateStats($r0);
  return $changed;
  }

=item $changed = $p->TruncateScores($r0);

Remove all player score data after round $r0.

=cut

sub TruncateScores ($$) {
  my $this = shift;
  my $r0 = shift;
  my $changed = 0;
  for my $key (qw(penalty)) {
    next if exists $this->{'etc'}{$key};
    $this->{'etc'}{$key} = &share([]);
    $changed = 1;
    }
  for my $ip (
    $this->{'scores'},
    $this->{'etc'}{'penalty'},
    $this->{'etc'}{'rcrank'},
    $this->{'etc'}{'rrank'},
    $this->{'etc'}{'rtime'},
    $this->{'etc'}{'time'},
    ) {
    if ($ip && $#$ip > $r0) { 
#     $#$ip = $r0; # splices are not thread-safe
      my @truncated : shared = @$ip[0..$r0];
      $ip = \@truncated;
      $changed = 1;
      }
    }
  if ($r0 < 0) {
    delete $this->{'etc'}{'excwins'};
    }
  $changed ||= $this->TruncateStats($r0);
  return $changed;
  }

sub ScoreBoardNames ($) {
  my $this = shift;
  my $new = shift;
  return $this->GetOrSetEtcVector('sbname', $new);
  }

=item $changed = $p->TruncateStats($r0);

Remove secondary player statistics after round $r0.

=cut

sub TruncateStats ($$) {
  my $this = shift;
  my $r0 = shift;
  my $changed = 0;
  for my $key (qw(newr rcrank rrank)) {
    next unless exists $this->{'etc'}{$key};
    my $this_r0 = $r0;
    $this_r0++ if $key =~ /rank$/;
    if (my $ip = $this->{'etc'}{$key}) {
      if ($#$ip > $this_r0) { 
  #     $#$ip = $this_r0; # splices are not thread-safe
	my @truncated : shared = @$ip[0..$this_r0];
	$this->{'etc'}{$key} = \@truncated;
	$changed = 1;
	}
      }
    else {
      $this->{'etc'}{$key} = &share([]);
      }
    }
  return $changed;
  }

=item $p->TweetDM($message);

Send a Twitter Direct Message to the player.  Note Twitter's per account limit of
250 DMs per day and 50 status updates per half hour.

=cut

sub TweetDM ($$) {
  my $this = shift;
  my $message = shift;

  my $handle = $this->TwitterName();
  my $tournament = $this->Division()->Tournament();
  my $config = $tournament->Config();
  unless (defined $handle) {
    $tournament->TellUser('enotwit', $this->PrettyName());
    return 0;
    }

  my $command = $config->Value('twitter_dm_command');
  unless (defined $command) {
    $tournament->TellUser('ecfgreq', 'twitter_dm_command');
    return '';
    }

  $command = sprintf($command, $handle, $message);
  print "Trying to tweet DM: $command\n";
  system $command;
  }

=item $p->TwitterName($c);

Set or get the player's twittername.

=cut

sub TwitterName ($;$) { 
  my $this = shift;
  my $new = shift;
  return $this->GetOrSetEtcScalar('twitter', $new);
  }

=item $success = $p->UnpairRound($r0);

Remove pairings for player in round $r0, return success.
If the player was paired with an opponent, you must call this
method again for the opponent.

Looking for a function to pair players? See TSH::Division.

=cut

sub UnpairRound ($$) { 
  my $this = shift;
  my $r0 = shift;
  my $tourney = $this->{'division'}->Tournament();

  my $opp = $this->{'pairings'}[$r0];
  if ($config::allow_gaps) {
    if ($opp && defined $this->{'scores'}[$r0]) {
      $tourney->TellUser('euprhas1s', $this->{'id'}, $r0+1);
      return 0;
      }
    $this->{'etc'}{'board'}[$r0] = 0 if $this->{'etc'}{'board'}[$r0];
    $this->{'etc'}{'p12'}[$r0] = 4 if $config::track_firsts;
    $this->{'scores'}[$r0] = undef;
    $this->{'pairings'}[$r0] = undef;
    }
  else {
    my $pairingsp = $this->{'pairings'};
    if ($r0 > $#$pairingsp) { # already unpaired
      return 1;
      }
    if ($r0 < $#$pairingsp) { # not final round
      $tourney->TellUser('iupr1bad', $this->{'name'}, $r0+1);
      return 0;
      }
    if ($pairingsp->[-1] and defined $this->{'scores'}[$#$pairingsp]) {
      $tourney->TellUser('iupr1bad2', $this->{'name'}, $r0+1);
      return 0;
      }
    pop @$pairingsp;
    if ($this->{'etc'}{'board'} && $#{$this->{'etc'}{'board'}} >= $r0) {
#     $#{$this->{'etc'}{'board'}} = $r0 - 1; # splices are not thread-safe
      my @board : shared = @{$this->{'etc'}{'board'}}[0..$r0-1];
      $this->{'etc'}{'board'} = \@board;
      }
    if ($this->{'etc'}{'p12'} && $#{$this->{'etc'}{'p12'}} >= $r0) {
#     $#{$this->{'etc'}{'p12'}} = $r0 - 1; # splices are not thread-safe
      my @p12 : shared = @{$this->{'etc'}{'p12'}}[0..$r0-1];
      $this->{'etc'}{'p12'} = \@p12;
      }
#   warn "$#{$this->{'pairings'}} $#{$this->{'scores'}} $r0";
    return 0 if $#{$this->{'pairings'}} != $r0 - 1;
    if ($#{$this->{'scores'}} >= $r0) {
#     $#{$this->{'scores'}} = $r0 - 1; # splices are not thread-safe
      my @scores : shared = @{$this->{'scores'}}[0..$r0-1];
      $this->{'scores'} = \@scores;
      }
    }
  $tourney->TellUser('iupr1ok', $this->{'id'}, $opp) if defined $opp;
  return $opp ? 2 : 1;
  }

=item $n = $p->UnscoredGames();

Return the number of games that the player has not yet recorded a score in.

=cut

sub UnscoredGames ($) { 
  my $this = shift;
  return $this->{'noscores'};
  }

=item $n = $p->UpdateRatingData(\%rating_data_hash, \%options);

Used by TSH::Division::LoadRatingsFile() to update a player's
rating, expiry and games played from a hashed rating list.

=cut

sub UpdateRatingData ($$) {
  my $this = shift;
  my $pdhp = shift;
  my $arghp = shift;
  my $dp = $this->Division();
  my $tourney = $dp->Tournament();
  my $rating_system = $dp->RatingSystem();
  my $rating_list = $arghp->{'list'} || $dp->RatingList();
  my $colons_optional = $dp->RatingSystemName() =~ /nsa|naspa|nssc/;
  my $q_unrate = ($tourney->Config()->Value('rating_system') || 'none') eq 'pak';

# warn "updating: $this->{'name'}";
  my (@names) = 
    $rating_system->CanonicaliseName($rating_list, uc $this->Name());
  my (@expiry) = split(/\+/, $this->Expiry() || '');
  my (@games) = split(/\+/, $this->LifeGames() || '');
  my (@rating) = split(/\+/, $this->Rating() || '');
  my $rating_term_count = $rating_system->RatingTermCount();
  for my $i (0..$#names) {
    my $name = uc $names[$i];
    $name =~ s/,//g; # TODO: should maybe move to CanonicaliseName()
    my $offset = $i*$rating_term_count;
    my $pdp = $pdhp->{$name};
#   warn "$name/$rating_list: ".join(',', %{$pdp->{'rd'}}) if $pdp && $pdp->{'rd'} && $name =~ /CHEW/;
#   warn "$name: ".join(',', %$pdp);# if $name =~ /CHEW/;
    if ($colons_optional && !$pdp->{'rd'} && $name =~ s/:.*//) {
      $name =~ s/:.*//;
      $pdp = $pdhp->{$name};
#     warn $name;
      }
    if (my $rthis = ($pdp && $pdp->{'rd'})) {
      my $update = 0;
#     warn "$name is known in $rating_list";
      if ($rating[$offset]) {
#	warn "$name is rated @rating in $rating_list";
        # player has both new and old ratings: update unless fallback
	# (in which case the primary rating system has already updated)
	if ($arghp->{'fallback'}) { 
#	  warn "$name: was $rating[$offset], so not updating to $rthis->{'rating'} from $rating_list";
	  }
	else {
	  $update = 1;
	  #  warn "$name: was $rating[$offset], updating to $rthis->{'rating'} from $rating_list";
	  }
        }
      else {
	# player has new but not old rating: update but warn
	local($") = '|';
	$update = 1;
	$tourney->TellUser('wuserrat',
	  $this->TaggedName() . " ($names[$i])", $rthis->{'rating'})
        }
      if ($update) {
	my (@new_rating) = split(/\+/, $rthis->{'rating'});
	@rating[$offset..$offset+$rating_term_count-1] = @new_rating;
	$expiry[$i] = $rthis->{'expiry'} || '';
	$games[$i] = $rthis->{'games'} || '' unless $arghp->{'fallback'};
	$this->GetOrSetEtcScalar('rating_date', $rthis->{'rating_date'}) if $rthis->{'rating_date'};
        }
      }
    elsif ($rating[$offset]) { # player has old but not new rating: 
#     warn "$name is not known in $rating_list";
      # delete old rating if 'unrate', else warn
      if ($arghp->{'unrate'} or $q_unrate) {
	@rating[$offset..$offset+$rating_term_count-1]
	  = (0) x $rating_term_count;
#  	warn "$name: was $rating[$offset], deleting rating based on $rating_list";
	$expiry[$i] = '';
	$games[$i] = 0;
        }
      elsif (!$arghp->{'fallback'}) {
	$tourney->TellUser('wuserunr',$this->TaggedName()." ($name)", join('+',
	  map { $_ || 0 } @rating[$offset..$offset+$rating_term_count-1]));
        }
      }
    else {
      # player has neither new nor old rating
#      warn "$name: was unrated, is not in $rating_list";
      $rating[$offset] = 0; # in case a trailing multi-term rating is missing
      }
    }
  die "assertion failed" unless @rating; 
  my $rating = join('+', map { $_ || 0 } @rating);
  my $expiry = join('+', map { $_ || 0 } @expiry) || 'not an expiry';
  my $games  = join('+', map { $_ || 0 } @games);
  if ($expiry ne ($this->Expiry($expiry)||'not an expiry')) {
    $dp->Dirty(1);
    }
  if ($rating ne $this->Rating($rating)) {
    $dp->Dirty(1);
    $dp->DirtyRound(-1);
    }
  if (defined($games) && length($games) && ($games ne ($this->LifeGames($games)||-1))) {
    $dp->Dirty(1);
    $dp->DirtyRound(-1);
    }
  }

=item $n = $p->Wins();

Return the player's total wins so far this tournament.

=cut

sub Wins ($) { 
  my $this = shift;
  return ($this->{'wins'} || 0);
  }

=back

=cut

=head1 BUGS

Rather than calling C<Division::Synch()> when the C<.t> file is
loaded (which substantially delays the loading of large files),
the relevant statistics that it computes should be computed only
as needed.

Not all routines call TSH::Division::Dirty(1) when needed yet.

Team() should look more like Board().

First() should check consistency with opponent.

ResolvePairings is currently the critical sub, and should be optimized,
or rewritten in C.

ResolvePairings should set an alarm and time out?

Should replace wins with rwins[-1], passim losses and spread.

=cut

1;

