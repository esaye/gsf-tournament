#!/usr/bin/perl

# Copyright (C) 2015 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::BRacketCHart;

use strict;
use warnings;

use TSH::Report::BracketChart;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::BRacketCHart - implement the C<tsh> BRacketCHart command

=head1 SYNOPSIS

  my $command = new TSH::Command::BRacketCHart;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BRacketCHart is a subclass of TSH::Command.

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
Use this command to create a chart showing pairings and
standings for a bracket-paired event.

If you specify a round number, results will not be shown
after that round number.  Otherwise, all available results
will be included.
EOF
  $this->{'names'} = [qw(brch bracketchart)];
  $this->{'argtypes'} = [qw(OptionalRound Divisions)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
# my $round = $config->Value('max_rounds');
# unless (defined $round) {
#   $tournament->TellUser("eneed_max_rounds");
#   return 0;
#   }
  
  my $round;
  $round = shift if '' eq ref $_[0];
  my $dp = shift;

# warn $round;
  $round = $dp->MostScores() unless $round;
# warn $dp->MostScoresPlayer()->{name};
# warn $dp->MostScores();
# warn $round;
  my $bcp = new TSH::Report::BracketChart(
    'last_round0' => $round - 1,
    'dp' => $dp,
    );
  $bcp->Compose();
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;

