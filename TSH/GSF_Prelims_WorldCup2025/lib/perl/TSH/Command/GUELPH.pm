#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::GUELPH;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);

DebugOn('GUELPH');

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::GUELPH - implement the C<tsh> GUELPH command

=head1 SYNOPSIS

  my $command = new TSH::Command::GUELPH;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::GUELPH is a subclass of TSH::PairingCommand.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub PairSemifinals ($$);

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
This command is used internally to compute Guelph pairings for groups of
eight players playing a six-round schedule.  
In rounds 1-3, 1458 (A) and 2367 (B) each play a round robin.
In round 4: A1-B2 B1-A2 A3-B4 A4-B3.
In round 5: A1-B1 A2-B2 A3-B3 A4-B4.
In round 6: KOTH with infinite repeats and Gibsonization.
EOF
  $this->{'names'} = [qw(guelph)];
  $this->{'argtypes'} = [qw(Division)];
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
  my ($dp) = $this->{'dp'} = shift;
  my $target0 = $dp->FirstUnpairedRound0();
  my $target1 = $target0 + 1;
  my $source1 = $target1 <= 3 ? 0 : $target1 <= 5 ? 3 : 5;
  my $source0 = $source1 - 1;
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => $source0,
    'target0' => $target0,
    'gibson' => $target1 > 5,
    ) 
    or return 0;
  my $psp = $setupp->{'players'};
  if ($target1 == 1) {
    $this->Pair123($psp);
    }
  elsif ($target1 == 4) {
    $this->Pair45($psp);
    }
  elsif ($target1 == 6) {
    my $processor = $this->Processor();
    my $config = $tournament->Config();
    $config->Value('gibson', 1);
    my $dname = $dp->Name();
    $processor->Process("koth 5 5 $dname");
    }
  $this->Processor()->Flush();
  }

sub Pair123 ($$) {
  my $this = shift;
  my $psp = shift;
  my (@players) = TSH::Player::SortByInitialStanding @$psp;
  if (@players == 6) {
    $this->PairMany(\@players, 0, [0,5,1,4,2,3]);
    $this->PairMany(\@players, 1, [0,4,1,2,3,5]);
    $this->PairMany(\@players, 2, [0,3,1,5,2,4]);
    $this->PairMany(\@players, 3, [0,2,1,3,4,5]);
    $this->PairMany(\@players, 4, [0,1,2,5,3,4]);
    }
  elsif (@players == 10) {
    $this->PairMany(\@players, 0, [0,8,1,9,2,5,3,4,6,7]);
    $this->PairMany(\@players, 1, [0,7,1,6,2,3,4,8,5,9]);
    $this->PairMany(\@players, 2, [0,4,1,5,2,6,3,7,8,9]);
    $this->PairMany(\@players, 3, [0,3,2,1,4,5,6,9,7,8]);
    $this->PairMany(\@players, 4, [0,1,2,9,3,8,4,7,5,6]);
    }
  else {
    $this->PairMany(\@players, 0, [0,7,3,4,1,6,2,5]);
    $this->PairMany(\@players, 1, [0,4,3,7,1,5,2,6]);
    $this->PairMany(\@players, 2, [0,3,4,7,1,2,5,6]);
    }
  $this->Processor()->Flush();
  }

sub Pair45 ($$) {
  my $this = shift;
  my $psp = shift;
  my (@players) = TSH::Player::SortByInitialStanding @$psp;
  my (@A) = TSH::Player::SortByStanding(2, @players[0,3,4,7]);
  my (@B) = TSH::Player::SortByStanding(2, @players[1,2,5,6]);
  my (@AB) = (@A, @B);
  Debug('GUELPH', 'A: %d %d %d %d', map { $_->ID() } @A);
  Debug('GUELPH', 'B: %d %d %d %d', map { $_->ID() } @B);
  $this->PairMany(\@AB, 3, [0,5,1,4,2,7,3,6]);
  $this->PairMany(\@AB, 4, [0,4,1,5,2,6,3,7]);
  $this->Processor()->Flush();
  }

=back

=cut

1;
