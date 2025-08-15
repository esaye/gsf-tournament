#!/usr/bin/perl

# Copyright (C) 2009-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::showRankedWallChart;

use strict;
use warnings;

use TSH::Report::WallChart;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::showRankedWallChart - implement the C<tsh> showRankedWallChart command

=head1 SYNOPSIS

  my $command = new TSH::Command::showRankedWallChart;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::showRankedWallChart is a subclass of TSH::Command.

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
This command displays a report similar to the showWallChart command,
but sorted by current standing.  If you specify a round number, the
wall chart starts with that round; if you don't, it starts at round
1.
EOF
  $this->{'names'} = [qw(rwc showrankedwallchart)];
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

  my $from = 1;
  if (ref($_[0]) eq '') {
    $from = shift;
    }
  $from--;
  for my $dp (@_) {
    my (@players) = $dp->Players();
    next unless @players;
    @players = TSH::Player::SortByCurrentStanding @players;
    my $wcp = new TSH::Report::WallChart(
      'first_round0' => $from,
      'players' => \@players,
      'type' => 'rankedwallchart',
      );
    $wcp->Compose();
    }
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;

