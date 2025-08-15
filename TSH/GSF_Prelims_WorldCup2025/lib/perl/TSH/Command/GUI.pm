#!/usr/bin/perl

# Copyright (C) 2006 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::GUI;

use strict;
use warnings;

use TSH::Utility;
use File::Spec;
use Cwd qw(abs_path);

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::GUI - implement the C<tsh> GUI command

=head1 SYNOPSIS

  my $command = new TSH::Command::GUI;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::GUI is a subclass of TSH::Command.

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
Use this command to launch your web browser to view the tsh GUI.
EOF
  $this->{'names'} = [qw(gui)];
  $this->{'argtypes'} = [qw()];
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
  my $port = $config->Value('port');
  unless (defined $port) {
    $tournament->TellUser('eneedport');
    return 0;
    }
  my $url = "http://localhost:$port";
  if ($^O eq 'darwin') {
    system 'open', $url;
    }
  elsif ($^O eq 'MSWin32') {
    unless (fork) { exec "rundll32 url.dll,FileProtocolHandler $url"; }
    }
  else {
    print "I don't know how to launch the browser for '$^O'. Please contact John Chew.\n";
    # xdg-open? gnome-open?
    }
  0;
  }

=back

=cut

1;
