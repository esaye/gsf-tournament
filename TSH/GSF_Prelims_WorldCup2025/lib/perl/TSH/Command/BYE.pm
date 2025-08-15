#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::BYE;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::BYE - implement the C<tsh> BYE command

=head1 SYNOPSIS

  my $command = new TSH::Command::BYE;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BYE is a subclass of TSH::Command.

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
This command is now deprecated.
It was formerly used to set up byes, but has been
replaced by the PAIR and Addscore commands.
It will be removed entirely in a future version of this program.
EOF
  $this->{'names'} = [qw(bye)];
  $this->{'argtypes'} = [qw(Player Score Round Division)];
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
  my ($pn1, $score, $round, $dp) = @_;

  TSH::Utility::Error "The BYE command has replaced by PAIR and A.\n";
  my $round0 = $round - 1;

  my $p1 = $dp->Player($pn1);
  my $p2 = $p1->Opponent($round0);

  printf "%s used to be paired to %s\n", 
    (TSH::Utility::TaggedName $p1),
    (TSH::Utility::TaggedName $p2)
    if $p2;
  $dp->Pair($pn1, 0, $round0);
  $p1->Score($round0, $score);
  $dp->Dirty(1);
  $dp->DirtyRound($round0);
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

This command should be removed from C<tsh>.

Opponents of the new bye player should be assigned byes.

=cut

1;
