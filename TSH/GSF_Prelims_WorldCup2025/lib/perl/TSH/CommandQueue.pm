#!/usr/bin/perl

# Copyright (C) 2017-2022 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::CommandQueue;

use strict;
use warnings;
use v5.10.0; # for the // operator

use Carp;
use Fcntl qw(:flock :seek);
use File::Spec;
use TSH::Utility;

=pod

=head1 NAME

TSH::CommandQueue - manipulation of queues of TSH commands

=head1 SYNOPSIS

  # for systems that don't support signals
  my $queue = new TSH::CommandQueue(
    'directory' => $queue_directory,
    );
  # the following line should run in a separate thread/process
  $queue->Enqueue($data);
  sub ProcessData ($$$) {
    my $queue = shift;
    my $data = shift;
    my $parameter = shift;
    # do something
    }
  while (1) {
    $queue->Dequeue(
      'action' => \&ProcessData,
      'parameter' => $parameter,
      );
    sleep 1;
    }

  # for systems that support signals
  use POSIX ":sys_wait_h";
  my $queue = new TSH::CommandQueue(
    'directory' => $queue_directory,
    'send_signal' => 1, # only in the sending process
    'receive_signal' => 1, # only in the receiving process
    );
  # the following line should run in a separate thread/process
  $queue->Enqueue($data);
  sub ProcessData ($$$) {
    my $queue = shift;
    my $data = shift;
    my $parameter = shift;
    # do something
    }
  # very simplistic, probably unsafe way to respond to signal
  # should probably use AnyEvent to catch signal instead
  $::SIG{'USR1'} = sub {
    while (1) {
      eval {
	$queue->Dequeue(
	  'action' => \&ProcessData,
	  'parameter' => $parameter,
	  );
	};
      last if $@;
      }
    };
  
=head1 ABSTRACT

This Perl module manages FIFO queues of TSH commands, typically 
received asynchronously in one thread or process, and executed
during the event loop of another.

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

sub initialise ($);
sub new ($);

=item $parserp->initialise(optkey1 => $optvalue1, ...)

Used internally to (re)initialise the object.

Options:

directory - file directory containing files related to the queue

=cut

sub initialise ($) {
  my $this = shift;
  my (%options) = @_;
  confess if @_ % 2;
  while (my ($key, $value) = each %options) {
    $this->{$key} = $value;
    }
  $this->RegisterFifo() if $this->{'receive_fifo'};
  $this->RegisterSignal() if $this->{'receive_signal'};
  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $q->CreateData($cursor, $data)

Used internally to create a queued command file.

=cut

sub CreateData ($$$) {
  my $this = shift;
  my $cursor = shift;
  my $data = shift;
  my ($fh, $fname) = $this->OpenQueueFile('>', "$cursor.txt");
  $fh // die "creat($cursor.txt) failed: $!";
  local($/) = undef;
  print $fh $data or die "write($fname) failed: $!";
  close $fh or die "close($fname) failed: $!";
  }

sub DeleteData ($$) {
  my $this = shift;
  my $cursor = shift;
  my $full_fn = $this->GetFilename("$cursor.txt");
  unlink $full_fn or die "unlink($cursor.txt) failed: $!";
  }

=item $error = $q->Dequeue(%options);

Dequeue the oldest queued data and act on it. Dies if there is
no remaining unqueued ata. Required parameters:

action: reference to sub to be called with arguments ($this, $data, $parameter)

parameter: third argument passed to action

=cut

sub Dequeue ($@) {
  my $this = shift;
  my (%options) = @_;
  eval {
    $this->DoLockedAction(
      'action' => \&DequeueCallback,
      'increment' => 1,
      'initial_value' => 1,
      'lock_filename' => '_dequeue.txt',
      'parameter' => \%options,
      );
    };
  return $@;
  }

=item $p = $c->DequeueCallback($cursor, $optionsp);

Used internally by Dequeue as a callback for DoLockedAction.
Dequeue the oldest queued data and act on it. 

=cut

sub DequeueCallback ($$$) {
  my $this = shift;
  my $cursor = shift;
  my $optionsp = shift;
  my $data = $this->ReadData($cursor);
  &{$optionsp->{'action'}}($this, $data, $optionsp->{'parameter'});
  $this->DeleteData($cursor);
  }

=item $p = $q->Directory();

=item $q->Directory($p);

Get/set a queue's directory name.

=cut

sub Directory ($;$) { TSH::Utility::GetOrSet('directory', @_); }

=item $q->DoLockedAction(%options);

Internally used to perform an action while a file is locked.

Required parameter options:

action: reference to sub that performs the action (wrap in eval to allow die)

increment: if true, post-increment the value found in the lock file unless the action dies

initial_value: if set, a new lock file should contain this value

lock_filename: relative filename for cursor file

parameter: third parameter passed to action (after $this and cursor value)

set_value: if set, overwrite any existing value with this value

=cut

sub DoLockedAction (%) {
  my $this = shift;
  my (%o) = @_;
  my ($lockvalue, $fh);
  my $lock_filename = $o{'lock_filename'};
  my $fqcfn = $this->GetFilename($lock_filename);
  # load or create the lock file
  if (defined $o{'set_value'}) {
    # cannot combine next two lines (or $fh gets assigned wrong value)
    ($fh) = $this->OpenQueueFile('>', $lock_filename);
    $fh // die "creat($fqcfn) failed: $!";
    flock($fh, LOCK_EX | LOCK_NB) or die "flock($fqcfn) failed: $!";
    $lockvalue = $o{'set_value'};
    print $fh "$lockvalue\n" or die "write($fqcfn) failed: $!";
    }
  elsif (-e $fqcfn) {
    # cannot combine next two lines (or $fh gets assigned wrong value)
    ($fh) = $this->OpenQueueFile('+<', $lock_filename);
    $fh // die "open($fqcfn) failed: $!";
    flock($fh, LOCK_EX | LOCK_NB) or die "flock($fqcfn) failed: $!";
    $lockvalue = <$fh>;
    $lockvalue // die "empty lock file $fqcfn\n";
    chomp $lockvalue or die "lock value not followed by newline in $fqcfn";
    }
  elsif (defined $o{'initial_value'}) {
    # cannot combine next two lines (or $fh gets assigned wrong value)
    ($fh) = $this->OpenQueueFile('>', $lock_filename);
    $fh // die "creat($fqcfn) failed: $!";
    flock($fh, LOCK_EX | LOCK_NB) or die "flock($fqcfn) failed: $!";
    $lockvalue = $o{'initial_value'};
    print $fh "$lockvalue\n" or die "write($fqcfn) failed: $!";
    }
  else {
    die "missing lock file $fqcfn\n";
    }
  # perform the action
  &{$o{'action'}}($this, $lockvalue, $o{'parameter'}) if $o{'action'};
  if ($o{'increment'}) {
    seek $fh, 0, SEEK_SET or die "seek($fqcfn) failed: $!";
    $lockvalue++;
    # lock value (c|sh)ould be string; if not, it could overflow
    die "lock value overflow" if $lockvalue =~ /^(0$|-)/;
    print $fh "$lockvalue\n" or die "write($fqcfn) failed: $!";
    }
  # let file unlock when it closes as it goes out of scope
  }

=item $q->Enqueue($data);

Add the given data as an element of the queue.

=cut

sub Enqueue ($$) {
  my $this = shift;
  my $data = shift;

  eval {
    $this->DoLockedAction(
      'action' => \&EnqueueCallback,
      'increment' => 1,
      'initial_value' => 1,
      'lock_filename' => '_enqueue.txt',
      'parameter' => $data,
      );
    $this->SendSignal() if $this->{'send_signal'};
    $this->SendFifo() if $this->{'send_fifo'};
    };
  return $@;
  }

=item $q->EnqueueCallback($cursor, $data);

Used internally by Enqueue as a callback for DoLockedAction.

=cut

sub EnqueueCallback ($$$) {
  my $this = shift;
  my $cursor = shift;
  my $data = shift;

  # in theory, we could just use CreateData, but we do this in case because
  # we're not sure we won't change the API for DoLockedAction
  $this->CreateData($cursor, $data);
  }

=item $fqfn = $q->GetFilename($relative_filename);

Used internally to return a fully qualified version of a filename given
relative to the queue data directory.

=cut

sub GetFilename ($$) {
  my $this = shift;
  my $relative_fn = shift;
  my $directory = $this->Directory() // die "directory not defined";
  mkdir $directory unless -d $directory;
  my $full_fn = File::Spec->catfile($directory, $relative_fn);
  return $full_fn;
  }

=item $q->OpenQueueFile($mode, $relative_file_name)

Used internally to open a file in the queue directory.

=cut

sub OpenQueueFile ($$) {
  my $this = shift;
  my $mode = shift;
  my $relative_fn = shift;
  my $full_fn = $this->GetFilename($relative_fn);
  open my $fh, $mode, $full_fn or return undef;
  return ($fh, $full_fn);
  }

=item $q->ReadData()

Used internally to read a queued command file.

=cut

sub ReadData ($$) {
  my $this = shift;
  my $cursor = shift;
  my ($fh, $fname) = $this->OpenQueueFile('<', "$cursor.txt");
  $fh // die "open($cursor.txt) failed: $!";
  local($/) = undef;
  my $data = scalar(<$fh>) or die "read($fname) failed: $!";
  close $fh;
  return $data;
  }

=item $error = $q->RegisterFifo()

Used internally to register a fifo that can be written to indicate
when new data has been queued.  

=cut

sub RegisterFifo ($$) {
  my $this = shift;
  $this->{'receive_fifo'} or die;
  my $fn = $this->GetFilename('_fifo.txt');
  unless (-p $fn) { 
    eval qq{use POSIX qw(mkfifo); mkfifo \$fn, 0777 or die \$!};
    die "Cannot create fifo $fn: $@" if $@;
    }
  }

=item $error = $q->RegisterSignal()

Used internally to register the pid of a process that can receive
signals when new data has been queued.  

=cut

sub RegisterSignal ($$) {
  my $this = shift;
  die unless $this->{'receive_signal'};
  eval {
    $this->DoLockedAction(
      'set_value' => $$,
      'lock_filename' => '_signal.txt',
      );
    };
  die $@ if $@;
  }

=item $error = $q->SendFifo()

Used internally to message the registered dequeuing process that 
new data has been queued.

=cut

sub SendFifo ($$) {
  my $this = shift;
  die unless $this->{'send_fifo'};
  eval {
    my $fn = $this->GetFilename('_fifo.txt');
    open my $fh, '>>', $fn or die "Error opening $fn: $!";
    print $fh "\n" or die "Error writing to $fn: $!";
    close $fh or die "Error closing $fn: $!";
    };
  die $@ if $@;
  }

=item $error = $q->SendSignal()

Used internally to signal the registered dequeuing process that 
new data has been queued.

=cut

sub SendSignal ($$) {
  my $this = shift;
  die unless $this->{'send_signal'};
  eval {
    $this->DoLockedAction(
      'action' => \&SendSignalCallback,
      'initial_value' => 0,
      'lock_filename' => '_signal.txt',
      );
    };
  die $@ if $@;
  }

=item $p = $c->SendSignalCallback($cursor, $optionsp);

Used internally by SendSignal as a callback for DoLockedAction.
Sends a USR1 signal to the process whose pid is in _signal.txt.

=cut

sub SendSignalCallback ($$$) {
  my $this = shift;
  my $pid = shift;
  my $optionsp = shift;
# warn "USR1 $pid";
  kill 'USR1', $pid or die "kill(USR1, $pid) failed: $!";
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
