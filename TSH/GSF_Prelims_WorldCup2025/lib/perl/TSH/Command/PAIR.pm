#!/usr/bin/perl

# Copyright (C) 2005-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::PAIR;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::PAIR - implement the C<tsh> PAIR command

=head1 SYNOPSIS

  my $command = new TSH::Command::PAIR;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PAIR is a subclass of TSH::Command.

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
Use the PAIR command to manually add pairings.  To add a bye, 
give one player number as 0.
To add lots of manual pairings, use the PairMany command.
EOF
  $this->{'names'} = [qw(pair)];
  $this->{'argtypes'} = [qw(PlayerOrZero PlayerOrZero Round Division)];
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
  my $config = $tournament->Config();
# my $c_seats = $config->Value('seats');
  my ($p1, $p2, $round, $dp) = @_;
  $dp->Pair($p1, $p2, $round-1, 'repair');
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
