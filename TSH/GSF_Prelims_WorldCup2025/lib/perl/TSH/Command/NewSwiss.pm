#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::NewSwiss;

use strict;
use warnings;

use TSH::PairingCommand;

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::NewSwiss - implement the C<tsh> NewSwiss command

=head1 SYNOPSIS

  my $command = new TSH::Command::NewSwiss;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::NewSwiss is a subclass of TSH::Command.

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
Use the NewSwiss command to manually add a round of swiss pairings
to a division, specifying the maximum number of allowable repeats,
and the round on whose standings the pairings are to be based.
EOF
  $this->{'names'} = [qw(ns newswiss)];
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
  my $sr0 = $sr-1;
  return unless $dp->PromptIfNotLatestScoredRound0( $sr0 );
  my $setupp = $this->SetupForPairings(
    'division' => $dp, 'source0' => $sr0, 'repeats' => $repeats) or return 0;
  unless (@{$setupp->{'players'}}) { $tournament->TellUser('inullok'); }
  elsif ($dp->PairSwiss($setupp)) { $this->TidyAfterPairing($dp); }
  else { $tournament->TellUser('epfail'); }
  }

=back

=cut

1;
