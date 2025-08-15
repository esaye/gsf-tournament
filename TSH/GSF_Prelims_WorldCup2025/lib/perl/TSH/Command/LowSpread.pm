#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::LowSpread;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremeGames;

our (@ISA) = qw(TSH::ReportCommand::ExtremeGames);

=pod

=head1 NAME

TSH::Command::LowSpread - implement the C<tsh> LowSpread command

=head1 SYNOPSIS

  my $command = new TSH::Command::LowSpread;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::LowSpread is a subclass of TSH::Command.

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
Use this command to list the low spreads in a division.
If you specify an integer, it indicates the number of scores you
would like to see.  If not, 20 scores are shown.
EOF
  $this->{'names'} = [qw(ls lowspread)];
  $this->{'argtypes'} = [qw(OptionalInteger Division)];


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
    'comparator' => sub ($$) { $_[0][0]-$_[0][1] <=> $_[1][0]-$_[1][1] }, # small spreads first
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => sub ($) { (defined $_[0][0]) && (defined $_[0][1]) && (($_[0][0] <=> $_[0][1]) || $_[0][2]->ID() > $_[0][3]->ID()) > 0 }, # count each game once
    'type' => 'lowspread',
    );
  my @types;
  push(@types, qw(round spread p1-winning-score p2-losing-score));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p1-class');
    }
  push(@types, qw(p1-winner p2-loser));
  $this->SetupColumns(@types);
  $this->WriteData(@types);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;


