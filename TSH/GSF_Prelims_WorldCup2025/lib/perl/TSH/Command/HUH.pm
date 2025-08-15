#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::HUH;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::HUH - implement the C<tsh> HUH command

=head1 SYNOPSIS

  my $command = new TSH::Command::HUH;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::HUH is a subclass of TSH::Command.

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
Many of the messages that tsh displays have a message code shown in
square brackets identifying them.  You can use the 'huh' command
to ask for a more detailed explanation of these messages.  'huh'
by itself explains the most recent message; 'huh whatever' explains
the message that ended with '[whatever]'.  If you are dissatisfied
with an explanation, please contact John Chew, who will amplify it.
EOF
  $this->{'names'} = [qw(huh)];
  $this->{'argtypes'} = [qw(OptionalMessage)];
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
  my $message = shift;
  $message = '' unless defined $message;
  $tournament->Explain(lc $message);
  }

=back

=cut

1;
