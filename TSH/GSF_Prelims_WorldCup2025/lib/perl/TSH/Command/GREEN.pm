#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::GREEN;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);

DebugOn('GREEN');

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::GREEN - implement the C<tsh> GREEN command

=head1 SYNOPSIS

  my $command = new TSH::Command::GREEN;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::GREEN is a subclass of TSH::PairingCommand.

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
This command is used internally to compute Green pairings for groups of
6-8 players playing a fixed 5-round schedule followed by a KOTH.
EOF
  $this->{'names'} = [qw(green)];
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
  if ($target0 != 0) {
    print "This command cannot be used if pairings already exist for a division.\n";
    return;
    }
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => -1,
    'target0' => 0,
    'gibson' => 0,
    'nobye' => 1,
    ) 
    or return 0;
  my $psp = $setupp->{'players'};
  my (@players) = TSH::Player::SortByInitialStanding @$psp;
  if (@players == 6) {
    $this->PairMany(\@players, 0, [0,1,2,5,3,4]);
    $this->PairMany(\@players, 1, [0,2,1,3,4,5]);
    $this->PairMany(\@players, 2, [0,3,2,4,1,5]);
    $this->PairMany(\@players, 3, [0,4,3,5,1,2]);
    $this->PairMany(\@players, 4, [0,5,1,4,2,3]);
    }
  elsif (@players == 7) {
    $this->PairMany(\@players, 0, [0,undef,1,6,2,5,3,4]);
    $this->PairMany(\@players, 1, [0,1,2,undef,3,6,4,5]);
    $this->PairMany(\@players, 2, [0,2,1,3,4,undef,5,6]);
    $this->PairMany(\@players, 3, [0,4,1,undef,2,6,3,5]);
    $this->PairMany(\@players, 4, [0,5,1,2,3,undef,4,6]);
    }
  elsif (@players == 8) {
    $this->PairMany(\@players, 0, [0,7,1,6,2,5,3,4]);
    $this->PairMany(\@players, 1, [0,1,2,7,3,6,4,5]);
    $this->PairMany(\@players, 2, [0,2,1,3,4,7,5,6]);
    $this->PairMany(\@players, 3, [0,4,1,7,2,6,3,5]);
    $this->PairMany(\@players, 4, [0,5,1,2,3,7,4,6]);
    }
  else {
    print "This command can only be used for divisions of 6-8 players.\n";
    }
  $this->Processor()->Flush();
  }

=back

=cut

1;
