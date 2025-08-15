#!/usr/bin/perl

# Copyright (C) 2007-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::HighCombined;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremeGames;

our (@ISA) = qw(TSH::ReportCommand::ExtremeGames);

=pod

=head1 NAME

TSH::Command::HighCombined - implement the C<tsh> HighCombined command

=head1 SYNOPSIS

  my $command = new TSH::Command::HighCombined;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::HighCombined is a subclass of TSH::Command.

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
Use this command to list the high combined scores in a division.
If you specify an integer, it indicates the number of scores you
would like to see.  If not, 20 scores are shown.
EOF
  $this->{'names'} = [qw(hc highcombined)];
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

  my $setupp = $this->SetupReport(
    'comparator' => sub ($$) { $_[1][0]+$_[1][1] <=> $_[0][0]+$_[0][1] }, # big totals first
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => sub ($) { (defined $_[0][0]) && (defined $_[0][1]) && (($_[0][0] <=> $_[0][1]) || $_[0][2]->ID() > $_[0][3]->ID()) > 0 }, # count each game once
    'type' => 'highcomb',
    );
  my @types;
  push(@types, qw(round combined-score p1-winning-score p2-losing-score));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p1-class');
    }
  push(@types, 'p1-winner');
  if ($setupp->{'has_classes'}) {
    push(@types, 'p2-class');
    }
  push(@types, 'p2-loser');
  $this->SetupColumns(@types);
  $this->WriteData(@types);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;

