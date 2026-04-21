#!/usr/bin/perl

# Copyright (C) 2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::TRUNCATESCORES;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::TRUNCATESCORES - implement the C<tsh> TRUNCATESCORES command

=head1 SYNOPSIS

  my $command = new TSH::Command::TRUNCATESCORES;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TRUNCATESCORES is a subclass of TSH::Command.

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
Use the TRUNCATESCORES command to delete all scores in a division
after a certain round number.  Use this command with caution;
if you delete too far, don't forget the journalled files in the
'old' subdirectory.  To delete all scores in a division, specify
round 0.  To delete pairings as well, see TRUNCATEROUNDS.
EOF
  $this->{'names'} = [qw(truncatescores)];
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
  $dp->TruncateScores($r0);
  if ($dp->Dirty()) {
    $tournament->TellUser('itruncss', $dp->Name(), $round);
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
