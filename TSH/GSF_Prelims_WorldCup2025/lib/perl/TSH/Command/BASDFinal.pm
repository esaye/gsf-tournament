#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::BASDFinal;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);

DebugOn('BASD');

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::BASDFinal - implement the C<tsh> BASDFinal command

=head1 SYNOPSIS

  my $command = new TSH::Command::BASDFinal;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BASDFinal is a subclass of TSH::PairingCommand.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub PairFinal ($$);

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to compute the final rounds of the 
Big Apple Scrabble Showdown, where the top two players
from round 12 play a best-of-five series while the remaining
18 players play four rounds of something resembling factored pairings.
The round number you specify, unlike with most commands, gives
the round to be paired, not the round based on whose results
pairings are to be computed.
EOF
  $this->{'names'} = [qw(basdf basdfinal)];
  $this->{'argtypes'} = [qw(Round Division)];
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
  my $round1 = shift;
  my ($dp) = $this->{'dp'} = shift;
  my $round0 = $round1 - 1;
  if ($round1 < 13 || $round1 > 17) {
    $tournament->TellUser('ebasdfr', $round1);
    return 0;
    }
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => $round0-1,
    'target0' => $round0,
    ) 
    or return 0;
  my $psp = $setupp->{'players'};
# for my $p (@$psp) { warn $p->TaggedName(); }
  @$psp = TSH::Player::SortByStanding(11, @$psp);
  $dp->Pair((shift @$psp)->ID(), (shift @$psp)->ID(), $round0);
  @$psp = TSH::Player::SortByCurrentStanding(@$psp);
  my (%schedules) = (
    13 => [1,6, 2,5, 3,4, 7,12, 8,11, 9,10, 13,18, 14,17, 15,16],
    14 => [1,4, 2,3, 5,8, 6,7, 9,12, 10,11, 13,18, 14,17, 15,16],
    15 => [1,3, 2,4, 5,7, 6,8, 9,11, 10,12, 13,16, 14,17, 15,18],
    );
  if (my $sched = $schedules{$round1}) {
    while (@$sched) {
      my $pi1 = shift @$sched;
      my $oi1 = shift @$sched;
      my $pp = $psp->[$pi1-1];
      my $op = $psp->[$oi1-1];
      Debug('BASD', 'A: %d-%d %s vs. %s', $pi1, $oi1, $pp->TaggedName(), $op->TaggedName());
      $dp->Pair($pp->ID(), $op->ID(), $round0);
      }
    }
  elsif ($round1 == 16) {
    my $processor = $this->Processor();
    my $config = $tournament->Config();
    $config->Value('gibson', 1);
    my $dname = $dp->Name();
    Debug('BASD', 'Round 16: KOTH with unlimited repeats and Gibsonization');
    $processor->Process("koth 15 15 $dname");
    }
  else {
    for my $p (@$psp) {
      $dp->Pair($p->ID(), 0, $round0);
      $p->Score($round0, 0);
      }
    }
# $dp->Dirty(1); # handled by $dp->Pair();
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

Should use TSH::PairingCommand::PairMany here and elsewhere.

=cut

1;
