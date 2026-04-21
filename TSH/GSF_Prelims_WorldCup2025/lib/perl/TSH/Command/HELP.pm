#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::HELP;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::HELP - implement the C<tsh> HELP command

=head1 SYNOPSIS

  my $command = new TSH::Command::HELP;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::HELP is a subclass of TSH::Command.

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
Use this command to view built-in documentation.  For fuller details,
please enter 'doc' to browse the reference manual.  Enter 'help index' to see a
list of available commands, and 'help' followed by a command name
to find out more about that command.
EOF
  $this->{'names'} = [qw(help)];
  $this->{'argtypes'} = [qw(Topic)];
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
  my $topic = shift;
  my $processor = $this->Processor();
  if ($topic !~ /^index$/i) {
    my $command = $processor->GetCommandByName($topic);
    unless ($command) {
      $tournament->TellUser('enohelp', $topic);
      return;
      }
    print $command->Usage();
    print "\n";
    print TSH::Utility::Wrap(0, $command->Help());
    return;
    }

  print TSH::Utility::Wrap(0, <<'EOS');
Detailed online help is available for the following commands
(type "help" followed by one of these command names):
EOS
  my (@commands) = $processor->CommandNames();
  print TSH::Utility::Wrap(2, @commands);
  }

=back

=cut

1;
