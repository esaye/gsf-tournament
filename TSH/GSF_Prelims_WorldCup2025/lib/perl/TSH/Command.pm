#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command;

use strict;
use warnings;
use Carp;
use TSH::Utility;

=pod

=head1 NAME

TSH::Command - abstraction of a C<tsh> user command

=head1 SYNOPSIS

This is a pure virtual class that needs to be overridden as follows:

  my $command = new TSH::Command::Foo;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  my $p = $command->Processor();
  $command->Processor($p);
  $command->Run($tournament, @parsed_arguments);
  my $usage = $command->Usage();
  
=head1 ABSTRACT

This Perl module is a virtual superclass for classes that provide
user commands for C<tsh>.

=cut

=head1 DESCRIPTION

=head2 Variables

The following (member) variables are defined in this module.
To avoid collision with future names, subclasses should prefix
their variable name keys with a short lower case version of their
invocation name followed by an underscore.  E.g., "cp_foo".

=over 4

=item $command->{'argtypes'}

Optional list of argument types for TSH::ParseArgs.
See ArgumentTypes().

=item $command->{'help'}

Optional help text for the command.
See Help();

=item $command->{'names'}

Optional list of names by which this command can be invoked.
See Names();

=item $command->{'processor'}

TSH::Processor object that will dispatch to us.

=item $command->{'usage'}

Optional string giving command-line syntax (usage) for this command.
See Usage();

=back

=head2 Methods

The following methods are defined in this module.

=over 4

=cut

sub ArgumentTypes($);
sub Help ($);
sub initialise ($);
sub Names ($);
sub new ($);
sub Processor ($;$);
sub Run ($$@);
sub Usage ($);

=item $argtypesp = $command->ArgumentTypes()

Should return a reference to a
list of argument types understood by TSH::ParseArgs.
A subclass may set $this->{'argtypes'} to a reference to a list of
names rather than overriding this method.

=cut

sub ArgumentTypes ($) {
  my $this = shift;
  my $class = ref($this);
  if (exists $this->{'argtypes'}) {
    return $this->{'argtypes'};
    }
  if ($class eq 'TSH::Command') {
    die "A generic TSH::Command was created and tried to invoke ArgumentTypes";
    }
  else {
    die "$class did not override ArgumentTypes";
    }
  }

=item $command->Help()

Should return the detailed help text for the command.
A subclass may set $this->{'help'} to the help text
rather than overriding this method.

=cut

sub Help ($) {
  my $this = shift;
  if (exists $this->{'help'}) {
    return $this->{'help'};
    }
  return "Help is not yet available for this command.";
  }

=item $boolean = $command->IsModal()

Returns true if this command takes modal command of an input stream,
and is therefore not currently suitable for use over Unix domain sockets.

=cut

sub IsModal ($) {
  my $this = shift;

  return $this->{'modal'};
  }

=item $command->Load();

Exists in case someone mistakes this command for an unloaded VCommand,
should always be a NOP.

=cut

sub Load() { }

=item $command->Names()

Should return the list of names by which this command can be invoked.
A subclass may set $this->{'names'} to a reference to a list of
names rather than overriding this method.

=cut

sub Names ($) {
  my $this = shift;
  my $class = ref($this);
  if (exists $this->{'names'}) {
    return @{$this->{'names'}};
    }
  warn "$class cannot be used because it has no names.\n";
  return ();
  }

=item $parserp->initialise(optkey1 => $optvalue1, ...)

Used internally to (re)initialise the object.

Options:

noconsole - if true, advise command not to output to console

=cut

sub initialise ($) {
  my $this = shift;
  my (%options) = @_;
  confess if @_ % 2;
  while (my ($key, $value) = each %options) {
    $this->{$key} = $value;
    }
  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $p = $c->Processor();

=item $c->Processor($p);

Get/set a command's processor

=cut

sub Processor ($;$) { TSH::Utility::GetOrSet('processor', @_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.
The $tournament argument is in theory no longer necessary,
as its value can be recovered as $command->Processor()->Tournament(),
but is retained for now for backward code compatibility.

=cut

sub Run ($$@) {
  my $this = shift;
  my $class = ref($this);
  if ($class eq 'TSH::Command') {
    die "A generic TSH::Command was created and tried to invoke Run";
    }
  else {
    die "$class did not override Run";
    }
  }

=item $command->Usage()

Should return the command-line syntax (usage) for this command.
A subclass may set $this->{'usage'} to override this method, but
usually the default method is fine.

=cut

sub Usage ($) {
  my $this = shift;
  if (exists $this->{'usage'}) {
    return $this->{'usage'};
    }
  my $usage = 'Usage: ' . ($this->Names())[0];
  for my $argt (@{$this->ArgumentTypes()}) {
    my $ausage = $this->Processor()->Parser()->ArgumentParser($argt)->Usage();
    $usage .= " $ausage" if $ausage;
    }
  $usage .= "\n";
  $this->{'usage'} = $usage;
  return $usage;
  }

=back

=cut

=head1 BUGS

Run() should not expect its $tournament argument.

=cut

1;
