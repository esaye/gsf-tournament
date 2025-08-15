#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::DRYrun;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::DRYrun - implement the C<tsh> DRYrun command

=head1 SYNOPSIS

  my $command = new TSH::Command::DRYrun;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::DRYrun is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub ShowAlphaPairings ($$$);
sub ShowBye ($$$);
sub ShowHeader ($$$);
sub ShowUnpaired ($$$);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;

  $this->{'help'} = <<'EOF';
Use this command to do a dry run simulating how the tournament
might play out in a division, to ensure for example that your
pairings commands are correctly set up.
EOF
  $this->{'names'} = [qw(dry dryrun)];
  $this->{'argtypes'} = [qw(OptionalRound Division)];

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
  my ($dp) = pop @_;
  my $round = (scalar(pop(@_)) || 0);
  my $round0 = $round-1;
  my $dname = $dp->Name();
  my $config = $tournament->Config();
  my $processor = $this->Processor();

  if ($dp->LastPairedRound0() != $round0) {
#   my $last0 = $dp->LastPairedRound0();
    $tournament->TellUser('edryne');
    return 0;
    }
  my $max_rounds = $dp->MaxRound0();
  if (!$max_rounds) {
    $tournament->TellUser('eneed_max_rounds');
    return 0;
    }
  $max_rounds++;

  if ($round0 < 0) {
    $config->RunBegin();
    }
  my $pr1 = $round;
  my $sr1 = $dp->LeastScores();
  my $dryrun_quiet = $config->Value('dryrun_quiet');
  my $savenpo = $config->Value('no_pairings_output', 1) if $dryrun_quiet;
  while ($sr1 < $max_rounds) {
#   warn "sr1=$sr1 mr=$max_rounds pr1=$pr1\n";
    if ($pr1 < $max_rounds) {
      $processor->Process("sp ".($pr1+1)." $dname");
#     if ($dp->LastPairedRound0()+1 > $pr1) {
      if ($dp->FirstUnpairedRound0() > $pr1) {
	$pr1++;
	next;
        }
      }
    $processor->Process("rand $dname");
    if ($dp->LeastScores() > $sr1) {
      $sr1++;
      $processor->Process("rrat $sr1 $dname") unless $dryrun_quiet;
      next;
      }

    $tournament->TellUser('edryapf', $pr1+1);
    $config->Value('no_pairings_output', $savenpo) if $dryrun_quiet;
    return 0;
    }
  $config->Value('no_pairings_output', $savenpo);
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
