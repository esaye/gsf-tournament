#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <poslfit@gmail.com>
#
# This module initially developed by G. Vincent Castellano
#
# All Rights Reserved

package TSH::Command::setESBMeSsaGe;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::setESBMeSsaGe - implement the C<tsh> setESBMeSsaGe command

=head1 SYNOPSIS

  my $command = new TSH::Command::setESBMeSsaGe;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::setESBMeSsaGe is a subclass of TSH::Command.

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
Use this command to control messages on all
ESBs, optionally hiding the display until the message is
turned off.  setESBsetMeSsaGe recognizes the subcommands "set" to set
the text of a message, "mode" with the argument "hide" or "reveal"
to control whether results are hidden or revealed while a
message is displayed, and "off" to disable the message.
Without any subcommand setESBsetMeSsaGe shows the current message 
and mode.

EOF
  $this->{'names'} = [qw(setesbmessage esbmsg)];
  $this->{'argtypes'} = [qw(OptionalExpression)];

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, $cmd, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my (@argv) = split(/\s+/, shift);
  my $cmd = shift @argv;
  defined($cmd) or $cmd = "";
  $cmd =~ s/\s+$//;
  $cmd =~ s/^\s+//;

  my $mode = $tournament->{'esb'}{'message'}{'mode'};
  my $message = $tournament->{'esb'}{'message'}{'text'};

  if ($cmd eq "mode") {
    $mode = lc(join(" ", @argv));
    if ($mode !~ /^(?:hide|reveal)$/) {
      $tournament->TellUser('ebadesbmsgcmd', "$cmd $mode" );
      return;
      }
    }
  elsif ($cmd eq "off") { $message = ""; }
  elsif ($cmd eq "set") { $message = join(" ", @argv); }
  elsif ($cmd)
    { $tournament->TellUser('ebadesbmsgcmd', $cmd ); return; }
  
  my $result = $cmd ? $tournament->SetESBMessage($mode, $message) : $message;

  if ($result) {
    $tournament->TellUser('iesbmsg',
			  "is now set to mode $mode, msg '$message'");
    }
  else { $tournament->TellUser('iesbmsg', "is now disabled, mode $mode" ); }
  $tournament->SaveJSON();
  }

=back

=cut

=head1 BUGS

None known

=cut

1;
