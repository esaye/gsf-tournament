#!/usr/bin/perl

# Copyright (C) 2005-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::KOTH;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Player;
use TSH::Utility qw(Debug);
use TSH::Utility qw(Debug DebugOn DebugOff);

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::KOTH - implement the C<tsh> KOTH command

=head1 SYNOPSIS

  my $command = new TSH::Command::KOTH;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::KOTH is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use the KOTH command to manually add a round of king-of-the-hill pairings
to a division, specifying the maximum number of allowable repeats,
and the round on whose standings the pairings are to be based.
Players are paired with opponents ranked as close as possible, with
ties broken by avoiding consecutive repeats, pairing starters with
repliers, and minimizing repeats.
EOF
  $this->{'names'} = [qw(koth)];
  $this->{'argtypes'} = [qw(RepeatsSince BasedOnRound Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

# also called by TSH::Command::DoubleElimination
sub PairComplete ($$) {
  my $setupp = shift;
  my $since0 = shift;
  my $track_firsts = $setupp->{'config'}->Value('track_firsts');
# warn join(', ', map { $_->ID() } grep { defined $_ } @{$setupp->{'players'}});
  return TSH::Player::PairGRT($setupp->{'players'},
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
      my $thisrep = $p->Repeats($oid);
      $thisrep -= $p->CountRoundRepeats($o, $since0) if defined $since0;
      my $sameopp = ($oid == $lastoid);
      my $distance = abs($_[1]-$_[2]);
      my $pairsvr = $track_firsts ? 2-abs(($p->{'p1'}-$p->{'p2'} <=> 0)  -($o->{'p1'}-$o->{'p2'} <=> 0)) : 0;

      Debug 'GRT', 'pref %d-%d rep=%d prev=%d svr=%d dist=%d', $pid, $oid, $thisrep, $sameopp, $pairsvr, $distance;
      pack('NCCNN',
	$distance, # prefer correctly positioned opponents
	$sameopp, # avoid previous opponent
	$pairsvr, # pair those due to start vs those due to reply
 	$thisrep, # minimize repeats
	$_[2], # to recover player ID
	)
      },
    # allowed opponent filter
    $setupp->{'filter'},
    # optional arguments to subs
    [],
    # target round
    $setupp->{'target0'},
    # do not optimize order in which player opponent search is
    # performed, as this may pessimize pairings, especially when
    # byes are involved
    { 'optimize' => scalar(@{$setupp->{'players'}}) },
    );
  }

sub PairIncomplete ($$$) {
  my $this = shift;
  my $setupp = shift;
  my $source0 = $setupp->{'source0'};
  my $target0 = $setupp->{'target0'};
  for my $p (@{$setupp->{'players'}}) {
    if (defined $p->Score($source0)) {
      $p->{'xwmax'} = $p->RoundWins($source0);
      $p->{'xss'} = $p->RoundSpread($source0);
      $p->{'xs'} = $p->RoundSpread($source0);
      }
    else {
      $p->{'xwmax'} = $p->RoundWins($source0) + $source0+1 - $p->CountScores();
      $p->{'xss'} = 1E9;
      $p->{'xs'} = undef;
      }
    }
  my (@ps) = sort { $a->{'xwmax'} <=> $b->{'xwmax'} || $a->{'xss'} <=> $b->{'xss'} } @{$setupp->{'players'}};
  my $repeats = $setupp->{'repeats'};
  for (my $i = 0; $i<@ps; $i++) {
    my $p = $ps[$i];
    my $opp = $ps[$i+1];
    if (!defined $opp) {
      Debug 'KOTH', "Assertion failed, %s is odd player out at end", $p->TaggedName();
      next;
      }
    Debug 'KOTH', "Consdering early-KOTHing %s and %s", $p->TaggedName(), $opp->TaggedName();
    if ($p->Repeats($opp->ID()) > $repeats) {
      Debug "KOTH", "%s and %s have played each other too often", $p->TaggedName(), $opp->TaggedName();
      next;
      }
    if ((!defined $p->{'xs'}) && $i+2 < @ps && $p->{'xwmax'} <= $ps[$i+2]->{'xwmax'}+1) {
      Debug "KOTH", "%s does not yet have a score and has uncertain rank", $p->TaggedName();
      next;
      }
    if ((!defined $opp->{'xs'}) && $i+2 < @ps && $opp->{'xwmax'} <= $ps[$i+2]->{'xwmax'}+1) {
      Debug "KOTH", "%s does not yet have a score and has uncertain rank", $opp->TaggedName();
      next;
      }
    my (@rest) = @ps;
    splice(@rest, $i, 2);
    if (!TSH::Player::CanBePaired($repeats, \@rest, 0, $setupp)) {
      Debug 'KOTH', "Remaining players would have to repeat too often";
      next;
      }
    Debug 'KOTH', "Pairing %s and %s.", $p->{'name'}, $opp->{'name'};
    $setupp->{'division'}->Pair($p->ID(), $opp->ID(), $target0, 1);
    }
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($repeats, $since1, $sr, $dp) = @_;
  my $sr0 = $sr-1;
  my $since0;
  $since0 = $since1 - 1 if defined $since1;

  my $class = $this->Processor()->Parser()->GetShared('class');
  {
    my $r0 = $dp->FirstUnpairedRound0();
    $dp->ComputeRanks($dp->FirstUnpairedRound0()-1) 
      if $r0 > -1;
  }
  my $setupp = $this->SetupForPairings(
#   'incomplete' => $since1 > 1 ? 0 : 1,
    'division' => $dp,
    'source0' => $sr0,
    'repeats' => $repeats,
    'repsince0' => $since0,
    'class' => $class,
    ) or return 0;
  
  $setupp->{'incomplete'} ||= $dp->LeastScores()-1 < $sr0;
  Debug 'KOTH', 'Computing KOTH pairings (repeats=%d sr0=%d incomplete=%s class=%s)', $repeats, $sr0, $setupp->{'incomplete'}, ($class//'undef');
  if ($setupp->{'incomplete'}
    ? $this->PairIncomplete($setupp)
    : PairComplete($setupp, $since0)) {
    $this->TidyAfterPairing($dp);
    }
  else {
#   warn $sr0.' '.$dp->{maxs};
    $tournament->TellUser('epfail');
    }
  }

=back

=cut

=head1 BUGS

Makes inappropriate use of private functions in TSH::Player.

Could just call newer FactorPair command, except FP doesn't support
"repeats since" or 'optimize'.

=cut

1;
