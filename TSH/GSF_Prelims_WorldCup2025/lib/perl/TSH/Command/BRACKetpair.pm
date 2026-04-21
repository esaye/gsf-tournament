#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::BRACKetpair;

use strict;
use warnings;
use Carp;
use TSH::Division::Pairing::Berger;
use TSH::Division::Pairing::Bracket qw(GetSchedule);

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);

DebugOn('BRACK');

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::BRACKetpair - implement the C<tsh> BRACKetpair command

=head1 SYNOPSIS

  my $command = new TSH::Command::BRACKetpair;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BRACKetpair is a subclass of TSH::PairingCommand.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub CompareRecords ($$$);
sub FindContenders ($$);
sub initialise ($$$$);
sub new ($);
sub PairInitial ($$);
sub PairSorted ($$);
sub Run ($$@);
sub SetSeeds ($$);

sub BiggestPower2LE ($) {
  my $n = shift;
  my $power2 = 1;
  while ($power2 <= $n) { $power2 += $power2; }
  $power2 /= 2;
  return $power2;
  }

sub CompareRecords ($$$) {
  my $this = shift;
  my $p1 = shift;
  my $p2 = shift;
  my $first0 = $this->{'target0'} - $this->{'nrounds'} - 1;
  my $last0 = $this->{'target0'} - 1;
  
  return 
    $p1->RoundWins($last0) - $p1->RoundWins($first0)
    <=> $p2->RoundWins($last0) - $p2->RoundWins($first0)
    ||
    $p1->RoundSpread($last0) - $p1->RoundSpread($first0)
    <=> $p2->RoundSpread($last0) - $p2->RoundSpread($first0)
  }

sub FindContenders ($$) {
  my $this = shift;
  my $psp = shift;
  my (@contenders);
  # look for the players who have the most recent positive bracketseed values
  my $r0 = 0;
  for my $p (@$psp) {
#   warn $p->Name();
    my $bracketseedsp = $p->GetOrSetEtcVector('bracketseed');
    for my $r00 ($r0..$#$bracketseedsp) {
      next unless ($bracketseedsp->[$r00]||0) > 0;
      if ($r00 > $r0) {
	# found a later one than the previous set
	@contenders = ();
	$r0 = $r00;
        }
      push(@contenders, $p);
      }
    }
  $this->{'brack_prev_r0'} = $r0;
  return @contenders;
  }

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to pair a seeded single-elimination ('bracket') tournament.
The number of rounds specified gives the number of consecutive times players in the
tournament should be paired with each other. 
Players no longer in the bracket are left unpaired; you may wish to use
another pairing system to pair them, such as Swiss.
EOF
  $this->{'names'} = [qw(brack bracketpair)];
  $this->{'argtypes'} = [qw(NumberOfRounds Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub PairInitial ($$) {
  my $this = shift;
  my $psp = shift;
  my $config = $this->{'tournament'}->Config();
  my $prelims = $config->Value('bracket_prelims') || 0; # number of preliminary non-bracket rounds
  my $order = $config->Value('bracket_order');
  my $cap = $config->Value('bracket_cap');
  my (@sorted) = @$psp;
  if ($prelims) {
    # Eliminate by prelim standing
    (@sorted) = TSH::Player::SortByStanding($prelims-1, @sorted);
    if ($cap) { 
      $#sorted = $cap - 1;
      }
    $#sorted = BiggestPower2LE(scalar(@sorted))-1;
    }
  elsif ($order eq 'rating') {
    # Seed by rating
    (@sorted) = TSH::Player::SortByInitialStanding @sorted;
    if ($cap) { 
      $#sorted = $cap - 1;
      }
    }
  else { # ordered by ID
    (@sorted) = sort { $a->ID() <=> $b->ID() } @sorted;
    if ($cap) { 
      $#sorted = $cap - 1;
      }
    }

  # initially assign seeds to players
  $this->SetSeeds(\@sorted);
  if ($prelims) {
    (@sorted) = grep { $_->GetOrSetEtcVectorMember('bracketseed',$this->{'target0'}) } @sorted;
    }
# print map { ($_+1). '. ' . $sorted[$_]->TaggedName() . "\n"; } 0..$#sorted;
  $this->PairSorted(\@sorted);
  }

sub PairSorted ($$) {
  my $this = shift;
  my $psp = shift;
  my $dp = $this->{'dp'};

  confess "no players" unless @$psp;
  my $schedulep = GetSchedule(scalar(@$psp));
# Carp::cluck "schedule: @$schedulep";
  while (@$schedulep) {
    my $i = shift @$schedulep;
    my $j = shift @$schedulep;
    if ($j) {
      my $p1 = $psp->[$i-1];
      my $p2 = $psp->[$j-1];
      Debug 'BRACK', '%d-%d: %s vs. %s', $i, $j, $p1->TaggedName(), $p2->TaggedName();
      for my $r0 ($this->{'target0'}..$this->{'target0'}+$this->{'nrounds'}-1) {
	$dp->Pair($p1->ID(), $p2->ID(), $r0);
	}
      }
    else {
      my $p1 = $psp->[$i-1];
      Debug 'BRACK', '%d bye: %s', $i, $p1->TaggedName();
      for my $r0 ($this->{'target0'}..$this->{'target0'}+$this->{'nrounds'}-1) {
	$dp->Pair($p1->ID(), 0, $r0);
	$p1->Score($r0, 0);
	}
      }
    }
  }

sub PairSubsequent ($$) {
  my $this = shift;
  my $psp = shift;
  my $config = $this->{'tournament'}->Config();
  my $noncon_pairing_system = $config->Value('bracket_noncon_pairings') || 'none';

  my (@sorted) = sort { 
    $a->GetOrSetEtcVectorMember('bracketseed',$this->{'brack_prev_r0'}) <=> $b->GetOrSetEtcVectorMember('bracketseed',$this->{'brack_prev_r0'}) 
    } @$psp;
  my $schedulep = GetSchedule(scalar(@sorted));
  my @advancers;
  my @dropouts;
  my $first0 = $this->{'target0'} - $this->{'nrounds'} - 1;
  my $last0 = $this->{'target0'} - 1;
  while (@$schedulep) {
    my $i = shift @$schedulep;
    my $j = shift @$schedulep;
    if ($j) {
      my $comp = $this->CompareRecords($sorted[$i-1], $sorted[$j-1]) 
        || $sorted[$i-1]->Wins() <=> $sorted[$j-1]->Wins()
        || $sorted[$i-1]->Spread() <=> $sorted[$j-1]->Spread()
        || $sorted[$i-1]->Rating() <=> $sorted[$j-1]->Rating()
	|| $i <=> $j
	;
      my ($li, $wi) = $comp > 0 ? ($j, $i) : ($i, $j);
      my $advancer = $sorted[$wi-1];
      my $dropout = $sorted[$li-1];
      Debug 'BRACK', '%d>%d: %s advances %g-%g %+d, %s does not', $wi, $li, $advancer->TaggedName(), $advancer->RoundWins($last0)-$advancer->RoundWins($first0), $advancer->RoundLosses($last0)-$advancer->RoundLosses($first0), $advancer->RoundSpread($last0)-$advancer->RoundSpread($first0), $dropout->TaggedName();
      push(@advancers, $advancer);
      push(@dropouts, $dropout);
      }
    else {
      push(@advancers, $sorted[$i-1]);
      }
    }
  if (@advancers == 2 && @dropouts == 2) {
    Debug 'BRACK', 'Two advancers, two dropouts: putting semifinal dropouts back in bracket.';
    @advancers = ($advancers[0], @dropouts, $advancers[1]);
    }
  if ($noncon_pairing_system eq 'nasc') {
    if (@advancers == 4 && @dropouts == 4) {
      Debug 'BRACK', 'NASC playoffs: losing quarterfinalists play a double RR';
      for my $oppi (2..4) {
	for my $j (1..2) {
	  TSH::Division::Pairing::Berger::PairGroup 
	    \@dropouts,
	    $oppi,
	    {
	      'assign_firsts' => $j % 2 ? 1 : -1,
	      'koth' => 1,
	    }
	  }
	}
      }
    }

  # reassign seeds only to advancers, clear all others
  $this->SetSeeds(\@advancers);
  $schedulep = GetSchedule(scalar(@advancers));
  $this->PairSorted(\@advancers);
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = $this->{'tournament'} = shift;
  my $config = $this->{'tournament'}->Config();
  my $nrounds = $this->{'nrounds'} = shift;
  my ($dp) = $this->{'dp'} = shift;
  my $target0 = $this->{'target0'} = $dp->FirstUnpairedRound0();
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => $target0-1,
    'target0' => $target0,
    'nobye' => 1,
    ) 
    or return 0;
  my $psp = $setupp->{'players'};
  my $prelims = $config->Value('bracket_prelims') || 0; # number of preliminary non-bracket rounds

  if ($target0 == $prelims) {
    # this assigns each player's etc/bracketseed field
    $this->PairInitial($psp);
    }
  else {
    # this looks for players who have etc/bracketseed fields
    my (@contenders) = $this->FindContenders($psp);
    # this pairs players with etc/bracketseed fields, and unseeds losers
    $this->PairSubsequent(\@contenders);
    }

# $dp->Dirty(1); # handled by $dp->Pair();
  $this->Processor()->Flush();
  }

sub SetSeeds ($$) {
  my $this = shift;
  my $psp = shift;
  my $config = $this->{'tournament'}->Config();
  my $prelims = $config->Value('bracket_prelims') || 0; # number of preliminary non-bracket rounds

  for my $p ($this->{'dp'}->Players()) {
    $p->GetOrSetEtcVectorMember('bracketseed',$this->{'target0'}, 0);
#   warn "zeroed $p->{'name'}";
    }
  my $imax = $#$psp;
  if ($prelims) {
    $imax = BiggestPower2LE($imax+1) - 1;
    }
# warn "Only $imax+1 get seeds.\n";
  for my $i (0..$imax) {
#   warn $psp->[$i];
    $psp->[$i]->GetOrSetEtcVectorMember('bracketseed',$this->{'target0'}, $i+1);
    }
  }

=back

=cut

=head1 BUGS

Should use TSH::PairingCommand::PairMany here and elsewhere.

=cut

1;
