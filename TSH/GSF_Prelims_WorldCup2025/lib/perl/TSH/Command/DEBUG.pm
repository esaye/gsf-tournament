#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::DEBUG;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::DEBUG - implement the C<tsh> DEBUG command

=head1 SYNOPSIS

  my $command = new TSH::Command::DEBUG;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::DEBUG is a subclass of TSH::Command.

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
This command turns debugging output on and off.
Scattered throughout the code are calls to the Debug() subroutine.
Each one reports some information to you, but only if debugging is
turned on for its particular debug code.
To turn debugging on, set the debug level for the debug code you're
interested in to 1. To turn it off, set it to 0.
EOF
  $this->{'names'} = [qw(debug)];
  $this->{'argtypes'} = [qw(DebugCode DebugLevel)];
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
  my ($code, $level) = @_;
  
  TSH::Utility::Debug('debug', 'code=%s level=%s', $code, $level);
  if ($level) {
    TSH::Utility::DebugOn($code);
    $tournament->TellUser('idebug1', $code);
    }
  else {
    TSH::Utility::DebugOff($code);
    $tournament->TellUser('idebug0', $code);
    }
  }

=back

=cut

=head1 BUGS

If we knew where the bugs were, we wouldn't need this command.

=cut

1;
