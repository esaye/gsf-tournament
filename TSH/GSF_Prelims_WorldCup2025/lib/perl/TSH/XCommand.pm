#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::XCommand;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::XCommand - abstraction of an external C<tsh> user command (plug-in)

=head1 SYNOPSIS

  my $command = new TSH::XCommand($processor, $path, $namesp, $argsp);
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  TSH::XCommand::LoadAll($processor, $path);
  
=head1 ABSTRACT

External C<tsh> user commands (plug-ins) belong to this 
subclass of TSH::Command.
One instance object of this class is required for each supported command.
External commands are typically utilities written separately from C<tsh>
that generate reports based on C<.t> files.
=cut

=head1 DESCRIPTION

=over 4

=cut

sub Help ($);
sub initialise ($$$$$;$);
sub LoadAll ($$);
sub new ($$$$$;$);
sub Run ($$@);

=item $command->Help()

Should return the detailed help text for the command.

=cut

sub Help ($) {
  my $this = shift;
  my $helppath = $this->{'path'};
  $helppath =~ s/\.\w+$/\.hlp/ 
    or ($helppath .= '.hlp');
  my $fh = TSH::Utility::OpenFile("<", $helppath) 
    or return "I can't load the help file for this command.";
  local($/) = undef;
  $this->{'help'} = <$fh>;
  close $fh;
  return $this->{'help'};
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$$;$) {
  my $this = shift;
  my $processor = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;
  my $default_args = shift;

  $this->{'path'} = $path;
  $this->{'processor'} = $processor;
  $this->{'names'} = $namesp;
  $this->{'argtypes'} = $argtypesp;
  $this->{'default_args'} = $default_args;
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

=item TSH::XCommand::LoadAll($processor, $path);

Load all the external commands in the directory named by $path.
Associate them with the TSH::Processor $processor.

=cut

sub LoadAll ($$) {
  # some contortions with local() to make sure variables
  # are accessible within do()
  package main;
  local($main::processor) = shift;
  my $paths = shift;
  local($main::path);
  my $tournament = $main::processor->Tournament();
  for $main::path (@$paths) {
    my $dofile = "$main::path/tshxcfg.txt";
    if (-r $dofile) {
      my $rv = do $dofile;
      if ($@) { $tournament->TellUser('eloadxcmd', $dofile, "\@$@"); }
      if ($!) { $tournament->TellUser('eloadxcmd', $dofile, "\!$!"); }
      unless ($rv) { $tournament->TellUser('eloadxcmd', $dofile, "X"); }
      }
    elsif (-e $dofile) {
      $tournament->TellUser('eloadxcmd', $dofile, "no read access");
      }
    }
  }

sub new ($$$$$;$) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) {
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my (@argv) = @_;
  for my $arg (@argv) {
    $arg = $config->MakeRootPath($arg->{'file'})
      if ref($arg) eq 'TSH::Division';
    }
  unshift(@argv, @{$this->{'default_args'}}) if $this->{'default_args'};
  unshift(@argv, $this->{'path'});
  unshift(@argv, 'perl') if $^O eq 'MSWin32';
  if (-1 == system @argv) {
    print "I had trouble invoking the external command: @argv\nThe system reported the following error: $!\n";
    }
  }

=back

=cut

1;
