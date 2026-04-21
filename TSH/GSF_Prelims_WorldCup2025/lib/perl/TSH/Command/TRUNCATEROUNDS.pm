#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TRUNCATEROUNDS;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::TRUNCATEROUNDS - implement the C<tsh> TRUNCATEROUNDS command

=head1 SYNOPSIS

  my $command = new TSH::Command::TRUNCATEROUNDS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TRUNCATEROUNDS is a subclass of TSH::Command.

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
Use the TRUNCATEROUNDS command to delete all data in a division
after a certain round number.  Use this command with caution;
if you delete too far, don't forget the journalled files in the
'old' subdirectory.  To delete all data in a division, specify
round 0.
EOF
  $this->{'names'} = [qw(truncaterounds)];
  $this->{'argtypes'} = [qw(Round0 Division)];
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
  my ($round, $dp) = @_;
  my $r0 = $round-1;
  $dp->Truncate($r0);
  if ($dp->Dirty()) {
    $tournament->TellUser('itruncs', $dp->Name(), $round);
    $this->Processor()->Flush();
    }
  else {
    $tournament->TellUser('wtruncf');
    }
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
