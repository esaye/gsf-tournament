#!/usr/bin/perl

## tsh - tournament shell
## Copyright (C) 1998-2012 by John J. Chew, III.

=head1 NAME

B<tsh> - Scrabble tournament management shell

=head1 SYNOPSIS

B<tsh> [directory|configuration-file]

=head1 DESCRIPTION

For user information, see the accompanying HTML documentation.
This builtin (pod) documentation is intended for program maintenance 
and development.

=cut

## Version history: moved to doc/news.html

require 5.008_001; # will not run in 5.8.0 because of an interpreter bug

## general pragmata
use warnings;
use strict;

## public libraries
use FileHandle;
# use File::Spec;
BEGIN {
  if (-f 'lib/threads.txt') { require threads; import threads; }
  }

## library search paths
BEGIN { unshift(@::INC, "$::ENV{'HOME'}/lib/perl") if defined $::ENV{'HOME'}; }
use lib './lib/perl';

## plug-ins
use TSH::PlugInManager;
our $gPlugInManager;
BEGIN { $gPlugInManager = new TSH::PlugInManager({'basedir' => './plugins', 'listfile' => 'lib/plugins.txt'}); }

## debug options
# use warnings FATAL => 'uninitialized';
# $::SIG{__WARN__} = sub { eval 'use Carp'; &confess($_[0]); };
# $::SIG{__DIE__} = sub { eval 'use Carp'; &confess($_[0]); };
# $::SIG{__WARN__} = sub { eval 'use Carp'; &Carp::cluck($_[0]); };

## private libraries
use TSH::Command;
use TSH::Config;
use TSH::PairingCommand;
use TSH::Processor;
use TSH::Player;
use TSH::Tournament;
use TSH::XCommand;
use TSH::Utility qw(Debug DebugOn DebugOff);

## global constants
our $gkVersion = '3.340';

## prototypes

sub CheckUpdates ($);
sub DefineExternal ($$$;$);
sub lint ();
sub LockFailed ($);
sub Main ();
sub Prompt ();
sub ReopenConsole ();
sub RunGUI ();
sub Use ($;$);

sub lint () {
  lint;
  }

=head1 SUBROUTINES

=over 4

=cut

=item CheckUpdates $processor;

In an interactive terminal session, prompt the user to update all
updatable items.

=cut

sub CheckUpdates ($) {
  my $processor = shift;
  for my $command (qw(UPDATE UPDATEPIX UPDATERATINGS)) {
    eval {
      $processor->GetCommandByName($command)->Load()->Check();
      };
    if ($@) {
      warn "Unexpected error trying to check for updates using $command:\n$@\n";
      }
    }
  }

=item DefineExternal $command_name, $script_path, $template, $default_args;

Add an external command (plug-in) to the user interface.

=cut

sub DefineExternal ($$$;$) {
  my $name = lc shift;
  my $script = shift;
  my $template = shift;
  my $default_args = shift;

  my $command = new TSH::XCommand($main::processor, "$main::path/$script",
    [$name], $template, $default_args);
  $main::processor->AddCommand($command);
# print " $name";
  return 1;
  }

=item LockFailed $reason;

Report that tsh could not open its lock file and abort.

=cut

sub LockFailed ($) {
  my $reason = shift;
  print <<"EOF";
System call failed: $reason

You should not run more than one copy of tsh using the same 
configuration file at the same time.  tsh uses a "lock file" called
tsh.lock to keep track of when it is running.  This copy of tsh
was unable to get access to the lock file.  The most likely reason
for this is that tsh is already in use.
EOF
  exit 1;
  }

=item Main;

Main entry point for tsh script.

=cut

sub Main () {
  srand; # harmless pre-5.004 legacy support

  DebugOff('Launch');
  Debug 'Launch', '[launch tracing enabled. plugins: '.join(', ', $gPlugInManager->Names()) . ']';
  DebugOff('Console');
  Debug 'Console', '[console I/O tracing enabled]';
  DebugOn('CBPF');
  DebugOn('CP');
  DebugOn('GIB');
  ReopenConsole if $^O eq 'MacOS'; # harmless legacy support
  if ($^O =~ /^(?:darwin|linux)$/) { # should probably do this for others
    binmode(STDIN, ':utf8');
    binmode(STDOUT, ':utf8');
    }
  $| = 1;
  if (-e 'lib/gui/config.tsh') {
    Debug 'Launch', '[GUI mode]';
    RunGUI;
    exit 0;
    }
  my $dir = @::ARGV ? shift @::ARGV : undef;
  Debug 'Launch', "[creating tournament object, dir=".((defined $dir) ? $dir : '(undefined)') . "]";
  my $tournament = new TSH::Tournament($dir);
  {
    my $error = $tournament->Lock();
    LockFailed $error if $error;
  }
  Debug 'Launch', "[loading configuration]";
# warn "@{$tournament->Config()->{'external_path'}}";
  eval { $tournament->LoadConfiguration(); };
  if ($@) {
    unless ($tournament->TellUser('econfigerr', $@)) {
      print "Configuration error: $@\n";
      print "Press enter (return) to exit.\n";
      }
    scalar(<>);
    exit 1;
    }
  Debug 'Launch', "[creating command processor]";
  # A processor receives commands from its user and executes them in the context of the tournament. It has to be created after the configuration is loaded (see LoadConfiguration above), because it needs to know where to find its external commands (in external_path).
  my $processor = new TSH::Processor($tournament);
  my $config = $tournament->Config();
  $tournament->TellUser('iwelcome', $gkVersion);
  # invite any plug-ins to do their own initialisation
  $gPlugInManager->InitialiseAll({'tournament' => $tournament});
  # event 'directory' is actually an archive file
  if ((defined $dir) && -f $dir) {
    Debug 'Launch', "[loading attached division data]";
    $tournament->LoadDivisionsAttached();
    }
  else {
    Debug 'Launch', "[loading division data]";
    $tournament->LoadDivisions();
    }
  if ($tournament->CountDivisions() == 0) {
    $tournament->TellUser('enodivs');
    exit(1);
    }
  Debug 'Launch', "[post division load init]";
  $config->DivisionsLoaded();
  $config->Export(); # deprecated, but must come after DivisionsLoaded
  my $event_name = $config->Value('event_name');
  if (defined $event_name) {
    my $date = $config->Value('event_date');
    my $namedate = $event_name;
    $namedate .= ", " . $date if defined $date;
    $tournament->TellUser('ievtname', $namedate);
    if (-t STDOUT) {
      if ($::ENV{'TERM'} && $::ENV{'TERM'} =~ /^xterm/) {
	# set window title in xterm-compatible sessions
	print "\e]0;tsh $gkVersion - $event_name\a";
	}
      CheckUpdates $processor;
      }
    }
  if ($config->Value('unix_socket_path') || $config->Value('port')) {
    Debug 'Launch', "[launching server]";
    $processor->RunServer(); 
    }
  else { 
    Debug 'Launch', "[launching interactive session]";
    $processor->RunInteractive(); 
    Debug 'Launch', "[interactive session exited]";
    }
  $tournament->Unlock();
  if (defined $event_name) {
    if ($::ENV{'TERM'} && $::ENV{'TERM'} =~ /^xterm/ && -t STDOUT) {
      print "\e]0;\a";
      }
    }
  }

sub Prompt () { 
  TSH::Utility::PrintColour 'yellow on blue', 'tsh>';
  print ' ';
  }

sub ReopenConsole () {
  close(STDOUT);
  close(STDERR);
  close(STDIN);
  open(STDOUT, "+>dev:console:tsh console") || die;
  open(STDERR, "+>dev:console:tsh console") || die;
  open(STDIN, "<dev:console:tsh console") || die;
  }

sub RunGUI () {
  Debug 'Launch', '[launching GUI]';
  @::ARGV = ();
# unlink 'lib/gui/html/tsh.css';
  my $tournament = new TSH::Tournament({'path'=>'lib/gui','search'=>0});
  eval { $tournament->LoadConfiguration(); };
  if ($@) { warn $@; }
  my $processor = new TSH::Processor($tournament);
  # invite any plug-ins to do their own initialisation
  $gPlugInManager->InitialiseAll({'tournament' => $tournament, 'mode' => 'gui'});
  my $config = $tournament->Config();
  $config->DivisionsLoaded();
  $config->Export(); # deprecated, but must come after DivisionsLoaded
  $processor->RunServer();
  }

=item Use $module or die

Carefully evaluate "use $module" and try to explain to a naive user
the meaning of failure.

=cut

sub Use ($;$) {
  my $module = shift;
  my $quiet = shift;
  eval "use $module";
  if ($@) {
    exit 1 if $quiet;
    die "Couldn't load $module, most likely because your tsh software distribution\nis incomplete.  Please download it again.  Here is what Perl says caused\nthe problem:\n$@";
    }
  return 1;
  }

=back

=cut

END { 
  sleep 10 if $^O eq 'MSWin32'; # to prevent error messages from disappearing
  }

## main code
Main;


=head1 BUGS

=over 4

=item Use() should be moved to TSH::Utility, so that it is accessible by code like tshview.pl

=back

=cut
