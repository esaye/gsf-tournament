#!/usr/bin/perl

# Copyright (C) 2005-2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::RoundHandiCaps;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);
use TSH::Command::RoundRATings;

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RoundHandiCaps - implement the C<tsh> RoundHandiCaps command

=head1 SYNOPSIS

  my $command = new TSH::Command::RoundHandiCaps;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RoundHandiCaps is a subclass of TSH::Command.

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
Use this command to display handicaps as of a round or range of rounds (e.g. 4-7).
EOF
  $this->{'names'} = [qw(rhc roundhandicaps)];
  $this->{'argtypes'} = [qw(RoundRange Division)];
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
  my ($firstr1, $lastr1, $dp) = @_;
  my $firstr0 = $firstr1 - 1;
  my $lastr0 = $lastr1 - 1;

  $dp->CountPlayers() or return 0;
  $dp->CheckRoundHasResults($lastr0) or return 0;

  my $optionsp = { 'filename' => 'handicaps', 'order' => 'handicap', };
  for my $r1 ($firstr1..$lastr1-1) {
    my $r0 = $r1 - 1;
    $tournament->TellUser('irratok', $r1);
    $dp->ComputeRatings($r0);
    TSH::Command::RoundRATings::RenderTable($dp, $r0, $optionsp, 1);
    }
  $dp->ComputeRatings($lastr0, $this->{'noconsole'}) if $lastr0 >= 0;
  TSH::Command::RoundRATings::RenderTable($dp, $lastr0, $optionsp, $this->{'noconsole'});
  return 0;
  }

=back

=cut

=head1 BUGS

RoundRATings::RenderTable etc. should be moved to TSH::Report::Ratings.pm.

=cut

1;
