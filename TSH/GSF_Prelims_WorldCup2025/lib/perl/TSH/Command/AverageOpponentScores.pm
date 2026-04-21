#!/usr/bin/perl

# Copyright (C) 2013 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::AverageOpponentScores;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremePlayers;

our (@ISA) = qw(TSH::ReportCommand::ExtremePlayers);

=pod

=head1 NAME

TSH::Command::AverageOpponentScores - implement the C<tsh> AverageOpponentScores command

=head1 SYNOPSIS

  my $command = new TSH::Command::AverageOpponentScores;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::AverageOpponentScores is a subclass of TSH::ReportCommand::ExtremePlayers.

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
Use this command to list average opponent scores for each player in a division.
If you specify an integer, it indicates the number of scores you
would like to see.  If not, all are shown.
EOF
  $this->{'names'} = [qw(aos averageopponentscores)];
  $this->{'argtypes'} = [qw(OptionalInteger Division)];
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
  my $dp = pop @_;
  my $max_entries = @_ ? shift @_ : 20;

  my $setupp = $this->SetupReport(
    'comparator' => \&TSH::ReportCommand::ExtremePlayers::CompareSmallerValues,
    'evaluator' => \&TSH::ReportCommand::ExtremePlayers::EvaluatePlayerAverageOpponentScore,
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => \&TSH::ReportCommand::ExtremePlayers::IsActivePlayer,
    'type' => 'aos',
    );
  my @types;
  push(@types, qw(rank o-average p-wl p-spread));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p-class');
    }
  push(@types, qw(p-name));
  $this->SetupColumns(@types);
  $this->WriteData(@types);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;


