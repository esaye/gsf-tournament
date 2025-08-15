#!/usr/bin/perl

# Copyright (C) 2005-2021 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::RandomPair;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Player;
use TSH::Utility qw(Debug);
use TSH::Division::Pairing::Random qw(PairRandom);

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::RandomPair - implement the C<tsh> RandomPair command

=head1 SYNOPSIS

  my $command = new TSH::Command::RandomPair;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RandomPair is a subclass of TSH::Command.

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
Use the RandomPair command to add a round of random pairings.
Although it might seem that you might not need to specify a round
on which to base the pairings, that value is required in case we
need to decide who gets a bye.
EOF
  $this->{'names'} = [qw(rp randompair)];
  $this->{'argtypes'} = [qw(Repeats BasedOnRound Division)];
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
  my ($repeats, $sr, $dp) = @_;
  my $sr0 = $sr - 1;
  my $config = $tournament->Config();

  my $class = $this->Processor()->Parser()->GetShared('class');
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => $sr0,
    'repeats' => $repeats,
    'class' => $class,
    ) or return 0;

  if (PairRandom($setupp->{'players'}, {
    'filter' => $setupp->{'filter'},
    'target0' => $setupp->{'target0'},
    'track_firsts' => $config->Value('track_firsts'),
    })) {
    $this->Processor()->Flush();
    $tournament->TellUser('idone');
    }
  else {
    $tournament->TellUser('epfail');
    }
  }

=back

=cut

1;
