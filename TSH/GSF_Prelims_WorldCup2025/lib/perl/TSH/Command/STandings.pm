#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::STandings;

use strict;
use warnings;

# use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::STandings - implement the C<tsh> STandings command

=head1 SYNOPSIS

  my $command = new TSH::Command::STandings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::STandings is a subclass of TSH::Command.

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
Use this command to display standings as of the most recent round
with scores.  To see earlier rounds, use the RoundStandings command.
You may optionally specify a round number, whose pairing
bars will be displayed with config pairing_bars = 1.
EOF
  $this->{'names'} = [qw(st standings)];
  $this->{'argtypes'} = [qw(Division OptionalRound)];
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
  my $dp = shift;
  my $pairings_round;
  $pairings_round = "" unless defined ($pairings_round =  shift);

  my $dname = $dp->Name();
  my $round = $dp->MostScores();

  $this->Processor()->Process("rs $round $dname $pairings_round");
  return 0;
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
