#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::VCommand;

use strict;
use warnings;

use TSH::Utility;
use TSH::Command;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::VCommand - a virtual stub of an unloaded tsh command

=head1 SYNOPSIS

  my $command = new TSH::VCommand($name, $tournament);
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);

  # static methods
  TSH::VCommand::LoadAll($processor);
  
=head1 ABSTRACT

To reduce memory usage and load time, C<tsh> commands which are
defined in modules are not loaded until they are needed.
Commands which are not yet loaded are represented by VCommands
in the tournament command dispatch system.
The command's names are inferred from the name of the module:
the full name is the name of the module, the abbreviated name
consists of the capitalised letters in the module name.
When a call is made to the command's 
ArgumentTypes(), Help() or Run() methods,
the appropriate module is loaded and a new object created
to replace the VCommand in the dispatch system.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub ArgumentTypes($);
sub Help ($);
sub Load ($);
sub LoadAll($);
sub initialise ($$$);
sub new ($$$);
sub Run ($$@);

=item $argtypesp = $command->ArgumentTypes()

Should return a reference to a
list of argument types understood by TSH::ParseArgs.
A subclass may set $this->{'argtypes'} to a reference to a list of
names rather than overriding this method.

=cut

sub ArgumentTypes ($) {
  my $this = shift;
# print "VCommand::ArgumentTypes, name=$this->{'name'}\n";
  return $this->Load()->ArgumentTypes();
  }


=item $command->Help()

Should return the detailed help text for the command.

=cut

sub Help ($) {
  my $this = shift;
  return $this->Load()->Help();
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$) {
  my $this = shift;
  my $name = shift;
  my $processor = shift;

  $this->{'name'} = $name;
  $this->{'processor'} = $processor;
  $this->{'tournament'} = $processor->Tournament();
  my $n = $name;
  $n =~ tr/a-z//d;
  $name = lc $name;
  $n = lc $n;
  $this->{'names'} = $n eq $name ? [$name] : [$n,$name];

  return $this;
  }

sub Load ($) {
  my $this = shift;
# warn "Loading $this->{'name'}\n";
  my $class = "TSH::Command::$this->{'name'}";
  eval "use $class";
  my $processor = $this->{'processor'};
  if ($@) {
    $processor->Tournament()->TellUser('enomod', "$class.pm", $@);
    exit 1;
    }
# warn "Activated $class.\n";
  my $command = $class->new('processor' => $processor);
  # Not all TSH::Command subclasses have the necessary line
  #   $this->SUPER::initialise(@_);
  # in their initialise() method to accept the processor above, so:
  $command->Processor($processor); 
  $processor->ReplaceCommand($command);
  return $command;
  }

sub LoadAll ($) {
  my $processor = shift;
# print "VCommand::LoadAll\n";
  my %seen;
  for my $path (@::INC) {
    unless (opendir(DIR, "$path/TSH/Command/")) {
      next;
      }
    while(my $file = readdir(DIR)) {
      next unless $file =~ s/\.pm$//;
      next if $seen{$file}++;
      my $command = new TSH::VCommand($file, $processor);
  #   print "VLoaded $file.\n";
      $processor->AddCommand($command);
      }
    closedir(DIR);
    }
  }

sub new ($$$) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) {
  my $this = shift;
# print "VCommand::Run\n";
  return $this->Load()->Run(@_);
  }

=back

=cut

1;
