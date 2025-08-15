#!/usr/bin/perl

# Copyright (C) 2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::HighRatingChange;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremePlayers;

our (@ISA) = qw(TSH::ReportCommand::ExtremePlayers);

=pod

=head1 NAME

TSH::Command::HighRatingChange - implement the C<tsh> HighRatingChange command

=head1 SYNOPSIS

  my $command = new TSH::Command::HighRatingChange;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::HighRatingChange is a subclass of TSH::Command.

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
Use the HighRatingChange command to list the players whose
ratings have changed the most. (ABSP players will be ranked
based on the difference between their tournament rating and
their input rating.)
EOF
  $this->{'names'} = [qw(hrc highratingchange)];
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

  my $r0 = $dp->MostScores() - 1;
  $dp->ComputeRatings($r0);

  # list the rated players first
  my $setupp = $this->SetupReport(
    'comparator' => \&TSH::ReportCommand::ExtremePlayers::CompareBiggerValues,
    'evaluator' => \&TSH::ReportCommand::ExtremePlayers::EvaluatePlayerRatingChange,
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => \&TSH::ReportCommand::ExtremePlayers::IsActiveRatedPlayer,
    'type' => 'rating_changes',
    );
  my @types;
  push(@types, qw(rank p-rating-change p-old-rating p-new-rating));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p-class');
    }
  push(@types, qw(p-name));
  $this->SetupColumns(@types);
  $this->WriteDataNoClose(@types);

  # then list the unrated players
  $this->SetOption('selector', \&TSH::ReportCommand::ExtremePlayers::IsActiveUnratedPlayer);
  $this->FindEntries();
  $this->WriteData(@types);
  }

=back

=cut

1;
