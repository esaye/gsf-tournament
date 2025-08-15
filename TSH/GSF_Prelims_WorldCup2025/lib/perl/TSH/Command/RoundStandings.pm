#!/usr/bin/perl

# Copyright (C) 2005-2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::RoundStandings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);
use TSH::Command::RoundRATings;

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RoundStandings - implement the C<tsh> RoundStandings command

=head1 SYNOPSIS

  my $command = new TSH::Command::RoundStandings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RoundStandings is a subclass of TSH::Command.

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
Use this command to display standings as of a specific round.
You may also optionally specify another round number, whose pairing
bars will be displayed with config pairing_bars = 1.
EOF
  $this->{'names'} = [qw(rs roundstandings)];
  $this->{'argtypes'} = [qw(BasedOnRound Division OptionalRound)];
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
  my ($r1, $dp, $pairings_round) = @_;
  my $r0 = $r1 - 1;
  my $use_ratings = $tournament->Config()->Value('standings_with_ratings');
  $dp->ComputeRatings($r0) if $use_ratings;
  TSH::Command::RoundRATings::RenderTable(
    $dp, 
    $r0,
    {
      'no_ratings' => ! $use_ratings,
      'newrh' => 'New_Rating',
      'newrt' => 'New_R',
      'filename' => 'standings',
    },
    0,
    $pairings_round,
    );
  return 0;
  }

=back

=cut

=head1 BUGS

RoundRATings::RenderTable etc. should be moved to TSH::Report::Ratings.pm.

=cut

1;

