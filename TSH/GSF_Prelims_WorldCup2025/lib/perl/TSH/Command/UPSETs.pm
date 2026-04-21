#!/usr/bin/perl

# Copyright (C) 2005-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::UPSETs;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremeGames;

our (@ISA) = qw(TSH::ReportCommand::ExtremeGames);

=pod

=head1 NAME

TSH::Command::UPSETs - implement the C<tsh> UPSETs command

=head1 SYNOPSIS

  my $command = new TSH::Command::UPSETs;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UPSETs is a subclass of TSH::Command.

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
Use the UPSETs command to list biggest ratings upsets in a division.
If you specify an integer, it indicates the number of scores you
would like to see.  If not, 20 scores are shown.
EOF
  $this->{'names'} = [qw(upset upsets)];
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
  my $max_entries = shift @_;
  my $rating_system = $dp->RatingSystem();

  # list the rated player upsets first
  my $setupp = $this->SetupReport(
    'comparator' => sub ($$) { $rating_system->CompareRatings(
      $rating_system->RatingDifference($_[1][6]-$_[1][5]),
      $rating_system->RatingDifference($_[0][6]-$_[0][5])) },
      # big ratings differences first
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => \&TSH::ReportCommand::ExtremeGames::IsUpset,
    'type' => 'upsets',
    );
  my @types;
  push(@types, qw(p2-rating-advantage p1-winner-rating p2-loser-rating round p1-winning-score p2-losing-score));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p1-class');
    }
  push(@types, qw(p1-winner p2-loser));
  $this->SetupColumns(@types);
  $this->WriteDataNoClose(@types);

  # then list the unrated player upsets
  $this->SetOption('selector', \&TSH::ReportCommand::ExtremeGames::IsUnratedUpset);
  $this->FindEntries();
  $this->WriteData(@types);
  }

=back

=cut

1;
