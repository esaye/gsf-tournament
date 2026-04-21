#!/usr/bin/perl

# Copyright (C) 2025 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::PerformanceRATings;

use strict;
use warnings;

# use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::PerformanceRATings - implement the C<tsh> RATings command

=head1 SYNOPSIS

  my $command = new TSH::Command::PerformanceRATings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PerformanceRATings is a subclass of TSH::Command.

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
Use this command to display ratings estimates based on current standings
within a division.
EOF
  $this->{'names'} = [qw(prat performanceratings)];
  $this->{'argtypes'} = [qw(Division)];
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
  my ($dp) = @_;

  my $dname = $dp->Name();
  my $round = $dp->MostScores();

  $this->Processor()->Process("rprat $round $dname");
  return 0;
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
