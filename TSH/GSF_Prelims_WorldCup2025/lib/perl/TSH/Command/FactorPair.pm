#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::FactorPair;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Player;
use TSH::Utility qw(Debug);

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::FactorPair - implement the C<tsh> FactorPair command

=head1 SYNOPSIS

  my $command = new TSH::Command::FactorPair;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::FactorPair is a subclass of TSH::Command.

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
Use the FactorPair command to manually add a round of pairings
in which players face opponents as close as possible to f
ranks apart, breaking ties to avoid consecutive repairings,
match starters vs. repliers, and minimize repeats.
EOF
  $this->{'names'} = [qw(factorpair fp)];
  $this->{'argtypes'} = [qw(RankDistance Repeats BasedOnRound Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($ideal_distance, $repeats, $sr, $dp) = @_;
  my $sr0 = $sr-1;
  my $config = $tournament->Config();
  my $track_firsts = $config->Value('track_firsts');

  return unless $dp->PromptIfNotLatestScoredRound0( $sr0 );

  my $setupp = $this->SetupForPairings(
    'division' => $dp, 'source0' => $sr0, 'repeats' => $repeats,
    'pairing_system_name' => "X+$ideal_distance factored pairings",
    ) or return 0;
  
  if (TSH::Player::PairGRT($setupp->{'players'},
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
      my $sameopp = ($oid == $lastoid);
      my $distance = abs($ideal_distance-abs($_[1]-$_[2]));
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
    )) {
    $this->TidyAfterPairing($dp);
    }
  else {
    $tournament->TellUser('epfail');
    }
  }

=back

=cut

=head1 BUGS

Makes inappropriate use of private functions in TSH::Player.

=cut

1;

