#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ChewPair;

use strict;
use warnings;
use Carp;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);
use TSH::PairingCommand;
use TSH::Player;

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::ChewPair - implement the C<tsh> ChewPair command

=head1 SYNOPSIS

  my $command = new TSH::Command::ChewPair;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ChewPair is a subclass of TSH::Command.

=cut

=head1 SUBROUTINES

=over 4

=cut

sub CountContenders ($$$$$);
sub FlightCapDefault ($);
sub FlightCapNone ($);
sub FlightCapNSC ($);
sub GetPrizeBand($$$);
sub GibsonEquivalent($$);
sub initialise ($$$$);
sub new ($);
sub PairContenders ($$$);
sub PairLeaders ($$$$$);
sub PairNonLeaders ($$);
sub Run ($$@);
sub RunInit ($$$);
sub SplitContenders ($$$);
sub Swiss ($$$$$);

=item ($n, $was_odd) = CountContenders($minrank, $maxrank, $psp, $sr0, $rounds_left)

Count the number of players in contention for a prize band
based on results up to $sr0 with $rounds_left remaining.
Round up to an even number.
Cap using the configured flight cap, if any.

=cut

sub CountContenders ($$$$$) {
  my $minrank = shift;
  my $maxrank = shift;
  my $psp = shift;
  my $sr0 = shift;
  my $rounds_left = shift;
  my $was_odd;

  return 0 unless @$psp;
  my $config = $psp->[0]->Division()->Tournament()->Config();
  my $cap = $config->FlightCap($rounds_left);

  Debug 'CP', 'Contending ranks %d-%d?  Plyrs left: %d.  Rds left: %d as of Rd %d. Cap: %d', $minrank, $maxrank, scalar(@$psp), $rounds_left, $sr0+1, $cap;
  my $capped_psp = $psp;
# if ($minrank == 1 && $sr0 >= 0 && @$capped_psp > $cap) { 
  my $bpf_psp = $psp;
  if ($sr0 >= 0 && @$capped_psp > $cap) { 
    $capped_psp = [@$psp[0..$cap-1]];
    $bpf_psp = [@$psp[0..$cap+1]];
    Debug 'CP', 'Optimizing by not calculating BPFs below cap(%d)+2.', $cap;
    }
  TSH::PairingCommand::CalculateBPFs $bpf_psp;
  
  my $max_flight_size = 0;
  for my $i (0..$#$capped_psp) {
    my $r = $capped_psp->[$i]->MaxRank();
#   Debug 'CP', '%s maxrank is %d', $psp->[$i]->TaggedName(), $r;
    if ($r <= $maxrank) {
      $max_flight_size = $i;
#     Debug 'CP', 'CC: %d <= %d, mfs=%d', $r, $maxrank, $i;
      }
    }
# TSH::Utility::Error "Assertion failed: only one contender" if $max_flight_size == 0; # this can happen, e.g., if #3 has clinched 3rd or higher
  $max_flight_size++; # now one-based
  Debug 'CP', 'There are %d contenders.', $max_flight_size;
  $was_odd = $max_flight_size % 2;
  $max_flight_size += $was_odd;
  if ($minrank == 1 && $max_flight_size > $cap && $sr0 >= 0) {
# if ($max_flight_size > $cap && $sr0 >= 0) {
    $max_flight_size = $cap;
    Debug 'CP', 'Capping to %d contenders.', $max_flight_size;
    }
  return ($max_flight_size, $was_odd);
  }

=item $cap = FlightCapDefault($rounds_left);

Apply the default algorithm for mapping rounds left to cap on
number of contenders.  Actual code has been moved to TSH::PairingCommand
because it is shared by any command that does Gibsonization.

=cut

sub FlightCapDefault ($) {
  my $rounds_left = shift;
  return TSH::PairingCommand::FlightCapDefault($rounds_left);
  }

=item $cap = FlightCapNone($rounds_left);

Apply the NSC algorithm for mapping rounds left to cap on
number of contenders.  Actual code has been moved to TSH::PairingCommand
because it is shared by any command that does Gibsonization.

=cut

sub FlightCapNone ($) {
  my $rounds_left = shift;
  return TSH::PairingCommand::FlightCapNone($rounds_left);
  }

=item $cap = FlightCapNSC($rounds_left);

Apply the pre-2008 NSC algorithm for mapping rounds left to cap on
number of contenders.  Actual code has been moved to TSH::PairingCommand
because it is shared by any command that does Gibsonization.

=cut

sub FlightCapNSC ($) {
  my $rounds_left = shift;
  return TSH::PairingCommand::FlightCapNSC($rounds_left);
  }

=item $cap = FlightCapNSC2008($rounds_left);

Apply the 2008 NSC algorithm for mapping rounds left to cap on
number of contenders.  Actual code has been moved to TSH::PairingCommand
because it is shared by any command that does Gibsonization.

=cut

sub FlightCapNSC2008 ($) {
  my $rounds_left = shift;
  return TSH::PairingCommand::FlightCapNSC2008($rounds_left);
  }

=item ($minrank,$maxrank) = GetPrizeBand($prize_bands, $psp, $sr0)

Find the prize band that contains the rank for $psp->[0] in Round $sr0.

=cut

sub GetPrizeBand ($$$) {
  my $prize_bands = shift;
  $prize_bands = [] unless defined $prize_bands;
  my $psp = shift;
  my $sr0 = shift;
  my $p0 = $psp->[0];
  die "Assertion failed" unless defined $p0;
  my $max_rounds = $p0->Division()->MaxRound0() + 1;
  my $rank = $p0->RoundRank($sr0);
  my (@splits) = (0, @$prize_bands, $psp->[-1]->RoundRank($sr0));
# Debug 'CP', "GetPB: $rank, @splits";
  for my $i (1..$#splits) {
    my $minrank = $splits[$i-1]+1;
    my $maxrank = $splits[$i];
    if ($rank >= $minrank && $rank <= $maxrank) {
      return ($minrank, $maxrank);
      }
    }
  confess "Assertion failed with rank=$rank, splits=@splits, sr0=$sr0, psp=[".
    join(' ', map { $_->ID() . '@' . $_->RoundRank($sr0) } @$psp) . ']';
  }

=item $parserp->GibsonEquivalent($dname, $rank)

Return the highest rank equivalent for Gibson purposes to $rank.

=cut

sub GibsonEquivalent($$) {
  my $dname = shift;
  my $rank = shift;

  return ($config::gibson_equivalent{$dname}[$rank] || $rank);
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to compute Chew pairings for a division.
EOF
  $this->{'names'} = [qw(cp chewpair)];
  $this->{'argtypes'} = [qw(BasedOnRound Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { 
  return TSH::Utility::new(@_); 
  }

=item my $success = $parserp->PairContenders($dp, $faint_hope_rank);

Pair all contenders at the top of C<$this->{'cp_tobepaired'}>.
Return boolean success.

=cut

sub PairContenders ($$$) {
  my $this = shift;
  my $dp = shift;
  my $config = $this->{'a_config'};
  my $faint_hope_rank = shift;
  my $prize_bands = $this->{'cp_current_prize_bands'};
  my $round0 = $this->{'cp_round0'};
  my $sr0 = $this->{'cp_sr0'};
  my $rounds_left = $this->{'cp_rounds_left'};
  my $tobepaired = $this->{'cp_tobepaired'};
  # find the highest remaining prize band
  my ($minrank, $maxrank) = GetPrizeBand($prize_bands, $tobepaired, $sr0);
  Debug 'CP', 'prize_band: [%d,%d]', $minrank, $maxrank;
  # count prize band contenders
  my ($ncontenders, $was_odd);
  # the bottom "prize band" runs from the highest rank that doesn't get a prize
  # down to the bottom of the field
  my $at_bottom = ($maxrank == $tobepaired->[-1]->RoundRank($sr0));
  if ($at_bottom) {
    Debug 'CP', 'No prizes being contended (faint_hope_rank=%d).', $faint_hope_rank;
    if ($faint_hope_rank) {
      # When a faint hope rank has been specified, we permit players currently ranked
      # below the last prize place to contend for prizes if they can theoretically
      # catch up to last place.  We often don't, because it is computatively intensive
      # to pair contenders.
      $was_odd = 0;
      my $first_player_rank = $tobepaired->[0]->RoundRank($sr0);
      $ncontenders = $faint_hope_rank - $first_player_rank;
      if ($ncontenders % 2) {
	$ncontenders++;
	$was_odd = 1;
        }
      if ($ncontenders < 0) {
	$ncontenders= 0;
        }
      Debug 'CP', 'Faint hope rank is %d, first player rank is %d: %d hopefuls.', $faint_hope_rank, $first_player_rank, $ncontenders;
      my $cap = $config->FlightCap($rounds_left);
      if ($ncontenders > $cap) {
	$ncontenders = $cap;
	Debug 'CP', 'Capped to: %d.', $cap;
        }
      if ($ncontenders) {
	Debug 'CP', 'Faint contenders: %d', $ncontenders;
        }
      else {
	$ncontenders = @$tobepaired;
	Debug 'CP', 'Not even faint contenders among remaining players: %d', $ncontenders;
        }
      }
    else {
      $ncontenders = @$tobepaired;
      $was_odd = 0;
      }
    }
  else {
    ($ncontenders, $was_odd)
      = CountContenders($minrank,$maxrank,$tobepaired,$sr0,$rounds_left); 
    }
  if ($ncontenders > @$tobepaired) {
    warn "soft assertion failed, reducing \$ncontenders: $ncontenders > ".@$tobepaired;
    $ncontenders = @$tobepaired;
    }
  # check to see if the non-contenders are going to have to repeat
  # pairings because they are too small a group
  {
    my $nnoncontenders = @$tobepaired - $ncontenders;
    if ($ncontenders > 2*$nnoncontenders && $nnoncontenders <= 6) {
      my (@rest) = @$tobepaired[$ncontenders..$#$tobepaired];
      unless (TSH::Player::CanBePaired 0, \@rest, 0, $this->{'cp_setupp'}) {
	$ncontenders += @rest;
	Debug 'CP', "Adding back last %d players, who can't be paired without repeats", scalar(@rest);
	if ($tobepaired->[-1]->MaxRank()) {
	  Debug 'CP', "At least we don't have to re-recalculate BPFs!";
	  }
	else {
	  Debug 'CP', 'Recalculating BPFs (so much for the optimization)';
	  TSH::PairingCommand::CalculateBPFs $tobepaired;
	  }
	}
      }
  }
  # in team play, it may be possible that the (non)contenders can't play each other
  if ($this->{'cp_setupp'}{'exagony'}) {
    my $changed;
    until (TSH::Player::CanBePaired($round0+1, [@$tobepaired[0..$ncontenders-1]], 0, $this->{'cp_setupp'})
      && TSH::Player::CanBePaired($round0+1, [@$tobepaired[$ncontenders..$#$tobepaired]], 0, $this->{'cp_setupp'})) {
      Debug 'CP', '%d contenders cannot be paired with exagony, trying %d.', $ncontenders, $ncontenders+2;
      $ncontenders += 2;
      $changed++;
      if ($ncontenders > @$tobepaired) {
	warn ("Remaining ".scalar(@$tobepaired)." players cannot be paired without violating exagony.\n");
	return 0;
        }
      }
    if ($changed) {
      Debug 'CP', "Recalculating BPFs (so much for the optimization)";
      TSH::PairingCommand::CalculateBPFs $tobepaired;
      }
    }

  # compute the smallest number of repeats 'minrep' needed to pair band
  my $minrep = 0;
  my (@flight) = @$tobepaired[0..$ncontenders-1];
  Debug 'CP', 'Calculating minrep for %d player(s).', scalar(@flight);
  until (TSH::Player::CanBePaired $minrep, \@flight, !$at_bottom, $this->{'cp_setupp'}) { 
    if (++$minrep > $round0) {
      Debug 'CP', 'No number of repetitions suffice.';
      if ($at_bottom) {
	Debug 'CP', "This shouldn't happen, please send John the .t and config.tsh files";
        }
      else {
	Debug 'CP', 'Trying again without requiring players to be able to catch up to their opponents.';
	$minrep = 0;
	until (TSH::Player::CanBePaired $minrep, \@flight, 0, $this->{'cp_setupp'} ) { 
	  if (++$minrep > $round0) {
	    Debug 'CP', 'That failed too, please send John the .t and config.tsh files';
	    last;
	    }
	  }
        }
      last;
      }
    }
  Debug 'CP', 'Flight can be paired with repeats=%d.', $minrep;
  # if everyone is still a contender, Swiss-pair them
  if ($ncontenders == @$tobepaired && !$config->Value('chew_no_swiss_all')) { Debug 'CP', 'Everyone is a contender, will pair Swiss.';
    Swiss $dp, \@flight, $minrep, $sr0, $round0;
    }
  # else there are some contenders and some noncontenders
  else {
    # TODO: There is a bad but subtle bug here.  If the number of contenders
    # is odd, we have to include a noncontender among them.  The noncontender
    # should be paired as low as possible; currently he might play #1.
    # SOLUTION?: find a way to force the noncontender to be the last choice
    # for every other player, even if they normally are excluded by filter.

    # find the highest split into two groups pairable in minrep
    my $split = $this->SplitContenders(\@flight, $minrep);
#     DebugOn('GRT');
    # pair the flight leaders 
    $this->PairLeaders([@flight[0..$split-1]], $minrep, $sr0, $was_odd);
    # pair the rest Swiss
    if ($split <= $#flight) {
      Debug 'CP', 'Pairing %d non-leaders.', $#flight-$split+1;
# OLD PairNonLeaders [@flight[$split..$#flight]], $minrep if $split <= $#flight;
      Swiss $dp, [@flight[$split..$#flight]], $minrep, $sr0, $round0;
      }
#     DebugOff('GRT');
    }
# splice(@$tobepaired, 0, $ncontenders); # splices are not thread-safe
  TSH::Utility::SpliceSafely(@$tobepaired, 0, $ncontenders);
  return 1;
  }

=item $command->PairLeaders(\@players, $repeats, $source_round0, $wasodd)

  - \@players: reference to list of players to pair
  - $repeats: do not exceed this number of repeats
  - $source_round0: pair based on this 0-based round
  - $wasodd: last player in list was not actually a contender

Pair an even number of flight leaders with decreasing priority given to
with decreasing priority given to

  - matching leaders with opponents who could catch up to them
    - BUG/TODO: this may not be desirable in a qualifying match for a finals;
      we should consider pairing leaders with opponents who can catch up
      to their Gibson group (cf. WESPAC 2017)
  - not exceeding repeats (ever)
  - minimizing repeats
  - avoiding consecutive rematches (where possible)
  - pairing highest with lowest

=cut

sub PairLeaders ($$$$$) {
  my $this = shift;
  my $psp = shift;
  my $repeats = shift;
  my $sr0 = shift;
  my $wasodd = shift;
  unless (@$psp) {
    Debug 'CP', 'PairLeaders called with no players to pair.';
    return;
    }
  my $p0 = $psp->[0] || confess "assertion failed";
  my $r0 = $p0->CountOpponents();
  my $max_rounds = $p0->Division()->MaxRound0() + 1;
  my $exagony = $this->{'cp_setupp'}{'exagony'};
  while (@$psp) {
    Debug 'CP', 'Pairing leaders, %d remain.', scalar(@$psp);
    # most of the time we should be able to resolve pairings thus
    last if TSH::Player::PairGRT($psp,
      sub { # opponent preference ranking, @_ = ($psp, $pindex, $oppindex);
	my $p = $_[0][$_[1]];
	my $pid = $p->ID();
	my $o = $_[0][$_[2]];
	my $oid = $o->ID();
	my $lastoid = ($p->OpponentID(-1)||-1);
	my $repeats = $p->Repeats($oid); 
	my $sameopp = ($oid == $lastoid);
	my $ketchup = (($o->MaxRank()||1E6) > $p->RoundRank($max_rounds-1));
#	my $pairsvr = $config::track_firsts ? 2-abs(($p->{'p1'}-$p->{'p2'} <=> 0)  -($o->{'p1'}-$o->{'p2'} <=> 0)) : 0;

#	Debug 'GRT', 'pref %d-%d rep=%d prev=%d can=%d (svr=%d)', $pid, $oid, $repeats, $sameopp, $ketchup, $pairsvr;
 	Debug 'GRT', 'pref %d-%d rep=%d prev=%d can=%d', $pid, $oid, $repeats, $sameopp, $ketchup;
	pack('NCCNN',
	  $ketchup, # prefer those who can catch up
	  $repeats, # minimize repeats
	  $sameopp, # avoid previous opponent
#	  $pairsvr, # pair those due to start vs those due to reply
	  999999-$_[2], # prefer lower-ranked opponents
	  $_[2], # for ID recovery
	  )
        },
      sub { # allowed opponent filter
	my $psp = $_[0];
	my $pn1 = $_[1];
	my $pn2 = $_[2];
	my $p1 = $psp->[$pn1];
	my $p2 = $psp->[$pn2];
	my $this_repeats = $p1->Repeats($p2->ID());
	my $pkn1; # index of higher-ranked player
	my $pkn2; # index of lower-ranked player
	# check to see which player is higher ranked
	if ($pn1 < $pn2) { $pkn1 = $pn1; $pkn2 = $pn2; }
	else { $pkn1 = $pn2; $pkn2 = $pn1; }
	# may play if lower-ranked can catch higher-ranked
	my $ketchup = ($psp->[$pkn2]->MaxRank()||1E6) <= $psp->[$pkn1]->RoundRank($max_rounds-1);
 	Debug 'GRT', 'filter: %s vs %s %d ?<= %d, can="%s"', $p1->TaggedName(), $p2->TaggedName(), $this_repeats, $repeats, $ketchup;
	# do not exceed repeats (should this be part of the setupp filter?)
        $this_repeats <= $repeats &&
	# satisfy catching-up criterion
	$ketchup &&
	# exagony (can't use setupp filter, which relies on fixed repeats)
	( $exagony ?  $p1->Team() ne $p2->Team() : 1);
        },
      [],
      $r0,
      );
    Debug 'CP', '%d Leaders could not be paired, relaxing catch-up constraint.', scalar(@$psp);
    # if we had to relax the ketchup constraint, we might need to do this
    last if TSH::Player::PairGRT($psp,
      sub { # opponent preference ranking, @_ = ($psp, $pindex, $oppindex);
	my $p = $_[0][$_[1]];
	my $pid = $p->ID();
	my $o = $_[0][$_[2]];
	my $oid = $o->ID();
	my $lastoid = ($p->OpponentID(-1)||-1);
	my $repeats = $p->Repeats($oid); 
	my $sameopp = ($oid == $lastoid);
 	Debug 'GRT', 'pref %d-%d rep=%d prev=%d', $pid, $oid, $repeats, $sameopp;
	pack('CCNN',
	  $repeats, # minimize repeats
	  $sameopp, # avoid previous opponent
#	  $pairsvr, # pair those due to start vs those due to reply
	  999999-$_[2], # prefer lower-ranked opponents
	  $_[2], # for ID recovery
	  )
        },
      sub { # allowed opponent filter
	my $psp = $_[0];
	my $pn1 = $_[1];
	my $pn2 = $_[2];
	my $p1 = $psp->[$pn1];
	my $p2 = $psp->[$pn2];
	my $this_repeats = $p1->Repeats($p2->ID());
	# may play if lower-ranked can catch higher-ranked
 	Debug 'GRT', 'filter: %s vs %s %d ?<= %d', $p1->TaggedName(), $p2->TaggedName(), $this_repeats, $repeats;
	# do not exceed repeats
        $this_repeats <= $repeats
	&& ( $exagony ?  $p1->Team() ne $p2->Team() : 1);
        },
      [],
      $r0,
      );
    Debug 'CP', 'Leaders still could not be paired, something is seriously wrong.';
    if (@$psp == 1) { 
      my $p1 = pop @$psp;
      TSH::Utility::Error 
	"Assertion failed: only one leader to be paired, forced to assign a bye to " 
	. $p1->TaggedName();
      }
    else {
      TSH::Utility::Error 
	"Assertion failed: can't resolve leader pairings for: " 
	. join(', ', map { $_->TaggedName() } @$psp);
      my $p1 = pop @$psp;
      my $p2 = splice(@$psp, $#$psp/2, 1);
      Debug 'CP', 'Blindly pairing %s and %s', $p1->Name(), $p2->Name();
      $p1->Division()->Pair($p1->ID(), $p2->ID(), $r0, 0);
      }
    }
  return;
  }

=item PairNonLeaders($$)

This routine is not currently used, as nonleaders are now paired Swiss.

Pair an even number of flight non-leaders with decreasing priority given to
with decreasing priority given to

  - not exceeding minrep (ever)
  - minimizing rematches
  - avoiding consecutive rematches
  - matching players due to go first with those due to go second
  - keeping rank differences close to half the group size

=cut

sub PairNonLeaders ($$) {
  my $psp = shift;
  my $minrep = shift;
  Debug 'CP', 'Pairing %d non-leaders.', scalar(@$psp);
  return unless @$psp;
  my $r0 = $psp->[0]->CountOpponents();
  unless (
    TSH::Player::PairGRT($psp,
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
	my $distance = abs(@{$_[0]}-abs(2*($_[1]-$_[2])));
	my $pairsvr = $config::track_firsts ? 2-abs(($p->{'p1'}-$p->{'p2'} <=> 0)  -($o->{'p1'}-$o->{'p2'} <=> 0)) : 0;

 	Debug 'GRT', 'pref %d-%d rep=%d prev=%d dist=%d svr=%d', $pid, $oid, $repeats, $sameopp, $distance, $pairsvr;
	pack('NCCNN',
	  $repeats, # minimize repeats
	  $sameopp, # avoid previous opponent
	  $pairsvr, # pair those due to start vs those due to reply
	  $distance,# prefer opponents close to half the group size away in rank
	  # provide index for GRT to extract, effectively prefer higher opps
	  $_[2],
	  )
        },
      # allowed opponent filter
      sub {
#	Debug 'GRT', 'filter %d %d', $_[1], $_[2];
  	Debug 'GRT', 'filter: %s vs %s %d ?<= %d', $_[0][$_[1]]->TaggedName(), $_[0][$_[2]]->TaggedName(), $_[0][$_[1]]->Repeats($_[0][$_[2]]->ID()), $minrep;
	# do not exceed minrep
        $_[0][$_[1]]->Repeats($_[0][$_[2]]->ID()) <= $minrep
        },
      [],
      $r0,
      )
    ) # unless
    {
    TSH::Utility::Error "Assertion failed: can't resolve non-leader pairings for: " 
      . join(', ', map { $_->TaggedName() } @$psp);
    }
  return;
  }

=item $command->Run($tournament, @parsed_args);

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $this->{'a_config'} = $tournament->Config();
  my ($sr, $dp) = @_;
  my $sr0 = $this->{'cp_sr0'} = $sr - 1;
  my @default_bands : shared = (1..(int($dp->CountPlayers/4)||1));
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'required' => { 'max_rounds' => 1 },
    'gibson' => 1,
    'source0' => $sr0,
    'wanted_div' => { 'prize_bands' => \@default_bands },
    ) or return 0;
  
  my $start = time;

  return unless $this->RunInit($tournament, $setupp);
  my $round0 = $this->{'cp_round0'};
  my $tobepaired = $this->{'cp_tobepaired'};
  my $full_tobepaired = [@{$this->{'cp_tobepaired'}}];
  for my $p (@$tobepaired) { $p->MaxRank(0); }
  $dp->ComputeRanks($round0);
  Debug 'CP', 'Beginning Chew Pairings for %d players in round %d based on round %d.', $#$tobepaired+1, $round0+1, $sr0+1;
  my $last_prize_rank = $config->LastPrizeRank($dp->Name());
  # in the last round, players who are within a win of last_prize_rank
  # should be paired in capped flights, not free Swiss
  my $faint_hope_rank = $config->FlightCap($this->{'cp_rounds_left'}-1); # added 2010-05-10
  if ($this->{'cp_rounds_left'} <= 4) { # experimentally switched from 1 on 2009-05-17, and then from 2 as a result of 2016 Cape Town
    $faint_hope_rank = $last_prize_rank;
    # This isn't quite right, because we're counting $last_prize_rank
    # from the top of the remaining unpaired players, which might no
    # longer include Gibsons. All we lose is a little efficiency though,
    # and no one is going to complain about being paired capped.
    my $faint_hope_wins 
      = $tobepaired->[$last_prize_rank-1]->RoundWins($round0) - 1;
    while ($tobepaired->[$faint_hope_rank+1] 
      && $tobepaired->[$faint_hope_rank+1]->RoundWins($round0) 
      >= $faint_hope_wins) {
      $faint_hope_rank++;
      }
    $faint_hope_rank++;
    $faint_hope_rank = scalar(@$tobepaired) if $faint_hope_rank > scalar(@$tobepaired); # Ross Brown pointed out that this can happen if config prize_bands is set to the lowest possible rank
    Debug 'CP', 'Player with faintest hope (has at least %d wins): %s, ranked %d', $faint_hope_wins, $tobepaired->[$faint_hope_rank-1]->Name(), $faint_hope_rank;
  }

  # while we still have players left to pair
  while (@$tobepaired) { 
    Debug 'CP', 'Number of players still unpaired: %d', scalar(@$tobepaired);
    # pair anyone in contention for the top prize still available
    $this->PairContenders($dp, $faint_hope_rank) or last;
# for my $p (@$tobepaired) { warn "$p->{'name'} $p->{'maxrank'}"; } 
    # perform any necessary gibsonization
    last unless @$tobepaired;
    my $p0 = $tobepaired->[0];
    my $toprank = $p0->RoundRank($round0);
    my $maxrank = $p0->MaxRank();
    unless ($maxrank) {
      Debug 'CP', 'Recalculating BPFs: so much for the optimization!';
      TSH::PairingCommand::CalculateBPFs $full_tobepaired;
      $maxrank = $p0->MaxRank();
      }
    Debug 'CP', 'top player %s has rank %d, could rise to %d', $p0->TaggedName(), $toprank, $maxrank;
    if ($toprank > $last_prize_rank) {
      Debug 'CP', 'Below last prize rank (%d > %d), not rechecking gibsonization', $toprank, $last_prize_rank;
      }
    elsif ($p0->MaxRank() && $p0->MaxRank() < $toprank) {
      Debug 'CP', 'Top remaining player might still climb rank, not eligible for gibsonization';
      }
    else {
      Debug 'CP', 'Not below last prize rank (%d <= %d), rechecking gibsonization', $toprank, $last_prize_rank;
      $this->PairAllGibsons($this->{'cp_tobepaired'}, $this->{'cp_sr0'},
	$this->{'cp_rounds_left'}, $this->{'cp_current_prize_bands'}[-1]);
      }
    # assign a bye if necessary (should never happen)
    if (@$tobepaired % 2) { Debug 'CP', 'need a bye';
      $dp->ChooseBye($sr0, $round0, $tobepaired);
      }
    }
  $dp->Dirty(1);
  $this->Processor()->Flush();
  $tournament->TellUser('idone');
  Debug('CP', '%d second(s) runtime', time - $start);
  0;
  }

=item $ok = $cmd->RunInit($tournament, $dp);

Perform initialisation necessary prior to running the command.

=cut

sub RunInit ($$$) {
  my $this = shift;
  my $tournament = shift;
  my $setupp = shift;
  my $config = $tournament->Config();
  my $dp = $setupp->{'division'};
  my $sr0 = $this->{'cp_sr0'};
  my $max_rounds = $dp->MaxRound0() + 1;
# $this->{'cp_rounds_left'} = $max_rounds - ($sr0+1); # see *20060430
  $this->{'cp_current_prize_bands'} = $config::prize_bands{$dp->Name()};
# $dp->ComputeRanks($this->{'cp_sr0'});
  $dp->ComputeRanks($max_rounds-1);
  my $round0 = $this->{'cp_round0'} =  $setupp->{'target0'};
  $this->{'cp_setupp'} = $setupp;
  $this->{'cp_rounds_left'} = $max_rounds - $round0; # *20060430
  my $tobepaired = $dp->GetUnpairedRound($round0);
  unless (@$tobepaired) { 
    # could happen if only players remaining unpaired were Gibsons/victims
    $tournament->TellUser('ealpaird', $round0+1); 
    return 0; 
    }
  @$tobepaired = TSH::Player::SortByStanding($this->{'cp_sr0'}, @$tobepaired);
# warn "cp_tobepaired has length ".scalar(@$tobepaired)." and cp_sr0 is $this->{'cp_sr0'}";
  $this->{'cp_tobepaired'} = $tobepaired;

  return 1;
  }

=item $nleaders = $parser->SplitContenders(\@contenders, $repeats);

Decide where to split those players still in contention into two
pairings groups.  The cut goes as high as possible (that is,
keeping together the fewest leaders) subject to not exceeding the
number of repeats required to pair all the contenders as one group
(and as of 2009-05-17 keeping at least four above the cut).
The return value is the number of leaders who will be split off
from the nonleading contenders.  If the contenders cannot be split
into two groups without increasing repeats, then the number of leaders
is equal to the number of contenders.

=cut

sub SplitContenders ($$$) {
  my $this = shift;
  my $contendersp = shift;
  my $repeats = shift;
  my $split = @$contendersp >= 4 ? 2 : 0; # 0 before 2009-05-17
  while (($split += 2) < @$contendersp) {
    if (TSH::Player::CanBePaired $repeats, [@$contendersp[0..$split-1]], 1, $this->{'cp_setupp'}) {
      Debug 'CP', 'Top %d can be paired with rep=%d.', $split, $repeats;
      }
    else {
      Debug 'CP', 'Top %d cannot be paired with rep=%d.', $split, $repeats;
      next;
      }
    if (TSH::Player::CanBePaired $repeats, [@$contendersp[$split..$#$contendersp]], 1, $this->{'cp_setupp'}) {
      Debug 'CP', 'Rest can also be paired with rep=%d.', $repeats;
      last;
      }
    else {
      Debug 'CP', 'Rest cannot be paired with rep=%d.', $repeats;
      next;
      }
    }
  Debug 'CP', 'split is %d.', $split;
  return $split;
  }

=item @pairlist = Swiss($dp, \@ps, $repeats, $sr0, $round0);

Compute and save Swiss pairings for some set of players.

=cut

sub Swiss ($$$$$) {
  my $dp = shift;
  my $psp = shift;
  my $repeats = shift;
  my $sr0 = shift;
  my $round0 = shift;

# Debug 'CP', 'Swiss(%s,%d,%d,%d,%d)', $dp->Name(), $#$psp+1, $repeats,$sr0,$round0;
  my (@pair_list) = TSH::Division::PairSomeSwiss($psp, $repeats, $sr0);
  unless (@pair_list) {
    warn "Pairings failed for IDs ".join(',', map { $_->ID() } @$psp).".\n" .
      "For more information, try rerunning with: debug RSw 1\n";
    return;
    }
# confess "assertion failed: ".join(',', map { $_->ID() } @$psp) unless @pair_list;
# die "assertion failed: " . join(',', @pair_list) if @pair_list % 2;
  while (@pair_list) {
    my $p1 = shift @pair_list;
    my $p2 = shift @pair_list;
# die "assertion failed for $p1" unless TSH::Utility::IsASafely($p1, 'TSH::Player');
# die "assertion failed for $p2" unless TSH::Utility::IsASafely($p2, 'TSH::Player');
    $dp->Pair($p1->ID(), $p2->ID(), $round0);
    }
  }
=back

=cut

=head1 BUGS

None known.

=cut

1;
