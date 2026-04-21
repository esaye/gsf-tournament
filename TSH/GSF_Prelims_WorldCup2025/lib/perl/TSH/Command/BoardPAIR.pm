#!/usr/bin/perl

# Copyright (C) 2011,2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::BoardPAIR;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::BoardPAIR - implement the C<tsh> BoardPAIR command

=head1 SYNOPSIS

  my $command = new TSH::Command::BoardPAIR;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BoardPAIR is a subclass of TSH::Command.

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
Use the BoardPAIR command to manually add pairings and specify a board at the same time.  To add a bye, 
give one player number as 0.
To add lots of manual pairings, use the PairMany command.
EOF
  $this->{'names'} = [qw(boardpair bpair)];
  $this->{'argtypes'} = [qw(Board PlayerOrZero PlayerOrZero Round Division)];
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
  my ($board, $p1, $p2, $round, $dp) = @_;
  $dp->Pair($p1, $p2, $round-1, 'repair');
  $dp->Player($p1)->Board($round-1, $board);
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
