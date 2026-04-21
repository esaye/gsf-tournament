#!/usr/bin/perl

# Copyright (C) 2007-2015 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Processor;

use strict;
use warnings;
use Fcntl;
use TSH::ParseArgs;
use TSH::Utility qw(Debug);
use TSH::VCommand;

=pod

=head1 NAME

TSH::Processor - interprets text commands related to a tournament

=head1 SYNOPSIS

This class interprets text commands received from a user and applies
them with reference to a TSH::Tournament object.

This is the easiest way to use this class:

  my $p = new TSH::Processor($tournament)
  $p->RunInteractive();

User commands are typically dispatched to a call to the Run method
of a subclass of TSH::Command.

  sub TSH::Command::Whatever::Run ($$@) {
    my $this = shift;
    my $tournament = shift;
    my (@argv) = @_;
    }

A "quit" command should inform the Processor that it is time to quit:

  $this->Processor()->QuittingTime(1);

If more than one user is using the same tournament, they should each
have their own Processor.  Note that at present users are not 
automatically notified if data that they are interested in has been
changed by another user.

A modal command may transfer focus to a subclass of Processor:

  sub TSH::Command::Whatever::Run ($$@) {
    my $this = shift;
    my $tournament = shift;
    my (@argv) = @_;

    my $subprocessor = new TSH::Processor::Whatever($this, @argv);
    $this->Processor()->Push($subprocessor);
    }

The subprocessor must define its own user prompt using either of
the following techniques:

  sub Prompt ($) { my $this = shift; return time . '> '; }
  $this->{'prompt'} = 'tsh> ';

The subprocessor will eventually relinquish control:

  $this->Command()->Processor->Pop();

There are several methods used to interact with members of
TSH::Command.

  $p->AddCommand($command); # add command to the list that we handle
  @c = $p->CommandNames(); # list of commands we know
  $p->GetCommandByName($); # return reference to command object, given name
  $p->ReplaceCommand($command); # replace command (typically a VCommand stub)


=head1 ABSTRACT

This Perl module is a class for objects that receive text commands
from users, interprets them and applies them with reference to
a TSH::Tournament structure.

=cut

=head1 DESCRIPTION

=head2 Variables

=over 4

=item $p->{'child'}

Reference to TSH::Processor object that has been pushed on top of us.

=item $p->{'cmdhash'}

Reference to hash mapping command name to TSH::Command object.

=item $p->{'cmdlist'}

Reference to list of known TSH::Command objects.

=item $p->{'parent'}

Reference to the TSH::Processor object that is below us on the stack.

=item $p->{'parser'}

Reference to TSH::ParseArgs parser object.

=item $p->{'prompt'}

Prompt displayed to elicit response from user.

=item $p->{'quit'}

Boolean, true if we want to stop receiving input.

=item $p->{'tournament'}

Reference to TSH::Tournament object associated with this Processor.

=back

=head2 Methods

The following methods are defined in this module.

=over 4

=cut

sub AddCommand ($$);
sub CommandNames ($);
sub GetCommandByName ($$);
sub initialise ($$);
sub new ($$);
sub Parser ($;$);
sub Pop ($);
sub Process ($$;$$);
sub Push ($$);
sub QuittingTime ($;$);
sub ReplaceCommand ($$);
sub RunInteractive ($);
sub RunServer ($;$);

=item $t->AddCommand($c)

Add a command to the processor.

=cut

sub AddCommand ($$) { 
  my $this = shift;
  my $command = shift;
  for my $name ($command->Names()) {
    if (exists $this->{'cmdhash'}{$name}) {
      $this->{'tournament'}->TellUser('econfcmd', $name);
      }
    $this->{'cmdhash'}{$name} = $command;
    }
  # clear the command list so that CommandNames will rebuild it
  $this->{'cmdlist'} = [];
  }

=item @d = $p->CommandNames()

Return a list of a processor's command names.

=cut

sub CommandNames ($) { 
  my $this = shift;
  my $csp = $this->{'cmdlist'};
  return @$csp if $csp && @$csp;
  $csp = $this->{'cmdlist'} = [sort keys %{$this->{'cmdhash'}}];
  return @$csp;
  }

=item $p->Flush();

Write out all volatile data to disk.

=cut

sub Flush ($$) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  if (my @DIVS = $tournament->UpdateDivisions()) {
    my $config = $tournament->Config();
    my $cmds = $tournament->Config()->Value('hook_division_update') 
      or return;
    # if only one division was dirty (so the hook might not need
    #   to explicity identify the only division in the tournament), 
    # or the command was division-independent (e.g., stats)
    if (@DIVS == 1 or $cmds =~ /\$d\b/ ) {
      # if the command cares what round it is, figure that out
      my (@roundInfo);
      if ($cmds =~ /\$r\b/) {
	@roundInfo = ('r', $DIVS[0]->LeastScores());
	}
      # Run the command for each division, either because there's only
      # one, or because the command depends on the division
      foreach my $dp (@DIVS) {
	$this->RunHook('hook_division_update', $cmds, 
	  { 'nohistory' => 1,
	    'no_console_output' => $config->Value('quiet_hooks') },
	  {'d' => $dp->Name(), @roundInfo } );
	}
      }
    # else run the command just once even though multiple divisions are dirty
    else {
      $this->RunHook('hook_division_update', $cmds,
	 { 'nohistory' => 1,
	   'no_console_output' => $config->Value('quiet_hooks') },
	);
      }
    }
  }

=item $c = $p->GetCommandByName($cn);

Obtain a Command pointer given a command name.

=cut

sub GetCommandByName ($$) {
  my $this = shift;
  my $cname = shift;
  my $c = $this->{'cmdhash'}{lc $cname};
  return $c;
  }

=item $c->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$) {
  my $this = shift;
  $this->{'tournament'} = shift;
  $this->{'child'} = undef;
  $this->{'cmdhash'} = undef;
  $this->{'cmdlist'} = undef;
  $this->{'parent'} = undef;
  $this->{'parser'} = new TSH::ParseArgs($this);
  $this->{'prompt'} = 'tsh> ';
  $this->{'quit'} = undef;
  $this->{'active_hooks'} = {}; # keep track, to avoid recursion
  TSH::VCommand::LoadAll($this);
  $this->LoadExternals();
  return $this;
  }

=item $c->LoadExternals();

Load external commands: use this later on if you have to create
your Processor object before the external_path is defined.

=cut

sub LoadExternals ($) {
  my $this = shift;
  my $xpath = $this->{'tournament'}->Config()->Value('external_path');
# warn "LoadExternals: @$xpath";
  if ($xpath && @$xpath) {
    eval "use TSH::XCommand" unless defined &TSH::XCommand::LoadAll;
    TSH::XCommand::LoadAll($this, $xpath);
    }
  }

=item $c = new TSH::Processor($tournament);

Creator method.

=cut

sub new ($$) { return TSH::Utility::new(@_); }

=item $parser = $p->Parser();

=item $p->Parser($parser);

Get/set the parser object associated with us.

=cut

sub Parser ($;$) { TSH::Utility::GetOrSet('parser', @_); }

=item $command->Pop();

Pops our child off the processor stack.
Dies if the child is not at the top of the stack.

=cut

sub Pop ($) {
  my $this = shift;
  my $child = $this->{'child'};
  die "Stack empty" unless defined $child;
  die "Can't pop from middle of stack" if $child->{'child'};
  $child->{'parent'} = undef;
  $this->{'child'} = undef;
  }

=item $p->RunHook($hook_name, @process_arguments);

Respond to a triggered hook by passing arguments to Process, 
unless we're already running this hook.

=cut

sub RunHook ($$@) {
  my $this = shift;
  my $hook_name = shift;

# warn $hook_name;
  return if $this->{'tournament'}->IsInSandbox();
  return if $this->{'active_hooks'}{$hook_name};
# warn $hook_name . ' is running';
  unless ($this->{'active_hooks'}{$hook_name}) {
    $this->{'active_hooks'}{$hook_name} = 1;
    $this->Process(@_);
    $this->{'active_hooks'}{$hook_name} = 0;
    }
  }

=item $p->Process($text) or print "Huh?\n";

Process a command line.

=cut

sub Process ($$;$$) {
  my $this = shift;
  my $text = shift;
  my $optionsp = shift || {};
  my $contextp = shift;
  my $config = $this->{'tournament'}->Config();
  my $save_no_console_output = $config->Value('no_console_output') || 0;
  my $save_no_console_input = $config->Value('no_console_input') || 0;
  my $save_nohistory = $config->Value('nohistory') || 0;

  unless (ref($optionsp)) { # backward compatibility hack
    $optionsp = { 'nohistory' => $optionsp ? 1 : 0 };
    }
  my $no_console_output = $optionsp->{'no_console_output'};
  my $nohistory = $optionsp->{'nohistory'};
  my $save_stdout;
  $save_stdout = select $optionsp->{'output'} if exists $optionsp->{'output'};
  if ($this->{'child'}) { 
    $config->Value('no_console_output', $no_console_output);
    $config->Value('nohistory', $nohistory);
    my $status = $this->{'child'}->Process($text); 
    $config->Value('nohistory', $save_nohistory);
    $config->Value('no_console_output', $save_no_console_output);
    return $status;
    }
  $text =~ s/^\s+//; 
  return 1 unless $text =~ /\S/;
  # TODO: better line parser that could pair quotes in: eval "$x;$y"
  my (@subcommands) = $text =~ /^eval\s+/i ? # ugly hack to permit eval "$x;$y"
    ($text) : split(/\s*;\s*/, $text);
  my $ok = 1;
  for my $subcommand (@subcommands) {
    my(@argv) = split(/\s+/, $subcommand);
    if ($contextp) {
      for my $argv (@argv) {
	if ($argv =~ s/\$(\w+)/\$contextp->{'$1'}/g) {
	  $argv = eval $argv;
	  }
        }
      }
    my $arg0 = lc $argv[0];
    my $commandsp = $this->{'cmdhash'};
    my $command = $commandsp->{$arg0};
    unless ($command) {
      $this->{'tournament'}->TellUser('ebadcmd', $arg0);
      $ok = 0;
      next;
      }
    my (@parsed_argv)= $this->{'parser'}->Parse(\@argv, $command->ArgumentTypes());
    if ($this->{'parser'}->Error()) {
      print $command->Usage();
      $ok = 0;
      next;
      }
    $command = $commandsp->{$arg0}; # ArgumentTypes() might have called VCommand::Load()
    $config->Value('no_console_output', $no_console_output);
    $config->Value('nohistory', $nohistory);
    eval { # trap expected and unexpected errors
      # to throw an expected error: die ['error-code', @argv]
      if ($optionsp->{'remote'} and $command->IsModal()) {
	die ['enomodal', $arg0];
        }
      $command->Run($this->{'tournament'}, @parsed_argv);
      };
    if ($@) {
      $this->{'tournament'}->TellUser(
        (ref($@) and ref($@) eq 'ARRAY') 
	  ? @{$@}
	  : ('emisc', "$@")
	);
      }
    $config->Value('nohistory', $save_nohistory);
    $config->Value('no_console_output', $save_no_console_output);
    if ($optionsp->{'remote'} and ($arg0 eq 'q' or $arg0 eq 'quit')) {
      $optionsp->{'remote'}->Quit();
      last;
      }
    }
  select $save_stdout if $save_stdout;
  return $ok;
  }

=item $p->Prompt()

Return the current text prompt.

=cut

sub Prompt ($) {
  my $this = shift;

  if ($this->{'child'}) { return $this->{'child'}->Prompt(); }
  return $this->{'prompt'};
  }

=item $p->Push($subprocessor)

Push a processor onto the stack.
Dies if we are not at the top of the stack.

=cut

sub Push ($$) {
  my $this = shift;
  my $child = shift;

  die "Can't push into middle of stack" if $this->{'child'};
  $this->{'child'} = $child;
  $this->{'child'}->{'parent'} = $this;
  }

=item $boolean = $p->QuittingTime();

=item $p->QuittingTime($boolean);

Get/set whether or not it's time to quit.

=cut

sub QuittingTime ($;$) { TSH::Utility::GetOrSet('quit', @_); }

=item $t->ReplaceCommand($d)

Replace a command in the tournament's user interface,
either because a new version has been downloaded or
because the command has been invoked for the first
time and a stub command object is being replaced.

=cut

sub ReplaceCommand ($$) { 
  my $this = shift;
  my $command = shift;
  for my $name ($command->Names()) {
    unless (exists $this->{'cmdhash'}{$name}) {
      TSH::Utility::Error "Adding '$name' to the command list, replacing nothing?!\n";
      }
    $this->{'cmdhash'}{$name} = $command;
#   print "ReplaceCommand: $name.\n";
    }
  # 'cmdlist' will be rebuilt by the 'help' command.
  # Could insert here, but probably faster to rebuild once when help is
  # asked for rather than insert each time a command is added
  $this->{'cmdlist'} = []; 
  }

=item $p->RunInteractive();

Run an interactive tsh session with the user, return when the
user exits.

=cut

sub RunInteractive ($) {
  my $this = shift;
  if (-t STDIN && -t STDOUT) {
    my $config = $this->Tournament()->Config();
    Debug 'Console', 'loading Term::ReadLine';
    eval "use Term::ReadLine";
    Debug 'Console', 'initialising Term::ReadLine';
    my $term;
    if ($config->Value('accept_remote_commands')) {
      $this->{'with_remote_commands'} = 0;
      eval "use AnyEvent; use Term::ReadLine::Event; use TSH::CommandQueue";
      if ($@) {
	warn "Cannot enable accept_remote_commands: $@";
        }
      else {
	# initialise remote command data structures
	unless ($this->{'remote_queue'}) {
	  $this->{'remote_queue'} = TSH::CommandQueue->new(
	    'directory' => $config->MakeRootPath('remote_queue'),
	    'receive_signal' => 1,
	    'receive_fifo' => 1,
	    );
	  }
	unless ($this->{'remote_callback'}) {
	  $this->{'remote_callback'} = sub {
	    eval {
	      for my $try (1..10) { # Dequeue will die out if queue empty
		$this->{'remote_queue'}->Dequeue(
		  'action' => sub {
		    my $queue = shift;
		    my $command = shift;
		    if ($command =~ /^\s*aps\s+/i) {
		      $command = $config->DecodeConsoleInput($command);
		      $command =~ s/\s+$//;
		      print "\e7\e[H\e[K\e[7m[remote: $command]\n";
		      $this->Process($command) or $this->Tournament()->TellUser('ienterhelp');
		      print "\e8\e[m";
		      }
		    else {
  #		    warn "Ignoring remote command: $command\n";
		      }
		    }
		  );
		}
	      };
	    if ($@) {
	      warn "command dequeue failed: $@";
	      }
	    };
	  }
	# check for queued commands every 60 seconds in case signal failed
	unless ($this->{'anyevent_timer'}) {
	  $this->{'anyevent_timer'} = AnyEvent->timer(
	    after => 60.0,
	    interval => 60.0,
	    cb => $this->{'remote_callback'},
	    );
	  }
	# check for queued commands on SIGUSR1
	unless ($this->{'anyevent_signal'}) {
	  $this->{'anyevent_signal'} = AnyEvent->signal(
	    signal => 'USR1',
	    cb => $this->{'remote_callback'},
	    );
	  }
	# check for queued commands on writes to fifo
	unless ($this->{'anyevent_io'}) {
	  sysopen my $fifofh, $config->MakeRootPath('remote_queue/_fifo.txt'),
	    O_RDONLY | O_NONBLOCK;
	  my $cb;
	  $cb = sub {
	    my $buffer = '';
	    sysread $fifofh, $buffer, 1024;

	    # added 2023
	    close $fifofh;
	    $fifofh = undef;
	    sysopen $fifofh, $config->MakeRootPath('remote_queue/_fifo.txt'),
	      O_RDONLY | O_NONBLOCK;
	    # warn "Waking up for fifo";

	    &{$this->{'remote_callback'}}();

	    # added 2023
	    # kill and recreate listener, because otherwise some systems
	    # grind CPU as they keep returning read ready if we don't completely
	    # close and reopen the fifo
	    $this->{anyevent_io} = AnyEvent->io(
	      fh => $fifofh,
	      poll => 'r',
	      cb => $cb,
	      );
	    };
	  $this->{'anyevent_io'} = AnyEvent->io(
	    fh => $fifofh,
	    poll => 'r',
	    cb => $cb,
	    );
	  }
	$this->{'with_remote_commands'} = 1;
	}
      $main::term_rtsh_kludge =
      $term = Term::ReadLine::Event->with_AnyEvent("tsh $::gkVersion");
      binmode STDOUT, ':utf8' if $^O =~ /^(?:darwin|linux)$/; # necessary for some linux
      }
    else {
      $main::term_rtsh_kludge =
      $term = Term::ReadLine->new("tsh $::gkVersion", \*STDIN, \*STDOUT);
      binmode STDOUT, ':utf8' if $^O =~ /^(?:darwin|linux)$/; # necessary for some linux
      # print join(',', PerlIO::get_layers('STDIN')), "\n";
      # print join(',', PerlIO::get_layers('STDOUT')), "\n";
      # my $ofh = $term->OUT || \*STDOUT;
      }
    while (1) {
      Debug 'Console', 'prompting for input';
      my $s = $term->readline($this->Prompt());
      last unless defined $s;
      Debug 'Console', 'decoding input';
      $_ = $config->DecodeConsoleInput($s);
      Debug 'Console', 'processing input';
      $this->Process($_) or $this->Tournament()->TellUser('ienterhelp');
      last if $this->QuittingTime();
      }
    }
  else {
    while (<>) {
      $this->Process($_) or $this->Tournament()->TellUser('ienterhelp');
      last if $this->QuittingTime();
      }
    }
  }

=item $p->RunServer();

If possible and specified, run a tsh HTTP server and a TSH
Unix domain socket server.  If neither is launched, fall back
to an interactive tsh session.  If threads are enabled, run the
server in a separate thread until the interactive session exits.

=cut

sub RunServer ($;$) {
  my $this = shift;
  my $argh = shift;
  my $tournament = $this->Tournament();
  my $config = $tournament->Config();

  my $http_port = $config->Value('port');
  my $unix_path = $config->Value('unix_socket_path');

  # carefully load necessary modules
  &::Use("Poslfit::MultiServer");
  &::Use("TSH::Server") if $http_port;
  &::Use("TSH::Server::Unix") if $unix_path;

  # try setting up an inter-thread event queue
  # - not sure that this needs to be done here, but afraid to move it
  my $queue = eval {
    &::Use('Thread::Queue');
    Thread::Queue->new();
    };

  # create a server log file unless we're virtual
  my $logfh;
  if ($tournament->Virtual()) {
    $logfh = *STDERR;
    }
  else {
    my $logfn = $tournament->Config()->MakeRootPath("server-log.txt");
    # Do not specify an encoding here or else threads->new below will die
    open $logfh, '>', $logfn or die "Can't create $logfn: $!";
    $logfh->autoflush(1);
    }

  # create the multiserver
  my $msp = Poslfit::MultiServer->new(
    'event_queue' => $queue,
    'log_handle' => $logfh,
    );

  # create the HTTP server
  if ($http_port) {
    # ignore return value, server can be found through multiserver
    TSH::Server->new($http_port, $tournament,
      {
	'multiserver' => $msp,
      });
    }

  # create the Unix server
  if ($unix_path) {
    # ignore return value, server can be found through multiserver
    TSH::Server::Unix->new(
      'connection_class' => 'TSH::Server::Unix::Connection',
      'multiserver' => $msp,
      'path' => $unix_path,
      'processor' => $this,
      );
    }

  # try starting the multiserver
  unless (eval { $msp->Start() }) {
    # on failure, inform user and fall back to interactive mode
    $tournament->TellUser('etshtpon', $@);
    $this->RunInteractive();
    return;
    }
  # multiserver was successfully started

  # open the GUI window 
  if ($http_port) {
    my $sub = ($argh && $argh->{'start_hook'}) || sub { $this->Process('GUI') };
    &$sub({'multiserver'=>$msp});
    }

  # if threads are available, run multiserver and interactive session in separate
  # threads until interactive session exits
  eval { threads->list(); };
  my $has_threads = $@ eq '';
  if ($has_threads) {
    # Obscure Perl bug: the following line will die with a segmentation fault
    # if there are any open file handles with encodings binmoded onto them.
    my $serverthread = threads->new(sub {
      while ($msp->Run()) { }
      $msp->Stop();
      });
    $this->RunInteractive();
    if ($queue) {
      print "\nSending shutdown event to server.\n";
      $queue->enqueue('shutdown');
      $serverthread->join; 
      }
    else {
      print "\nServer has no event queue; sending kill signal.\n";
      $serverthread->kill('SIGKILL');
      $serverthread->join; 
      }
    }
  # else just run multiserver without interactive session
  else {
    while ($msp->Run()) { }
    $msp->Stop();
    }
  }

# =item $p->RunUnixDomainServer();
# 
# Run a tsh Unix domain socket server session along with a plain
# (no Term::Readline) interactive session.  If one can't be
# launched, fall back to just the interactive session.  
# 
# =cut
# 
# sub RunUnixDomainServer ($;$) {
#   my $this = shift;
#   my $argh = shift;
#   my $tournament = $this->Tournament();
#   &::Use("TSH::Server::Unix");
#   my $server = TSH::Server::Unix->new(
#     $tournament->Config()->Value('unix_socket_path'), $this, {});
#   unless ($server->Start()) {
#     $tournament->TellUser('eusst', $server->Error());
#     $this->RunInteractive();
#     return;
#     }
#   while ($server->Run()) { }
#   $server->Stop();
#   }

=item $t = $p->Tournament();

=item $p->Tournament($t);

Get/set the TSH::Tournament associated with the processor.

=cut

sub Tournament ($;$) { TSH::Utility::GetOrSet('tournament', @_); }

=back

=cut

=head1 BUGS

Commands should arguably not receive $tournament as their second
argument, as this can be retrieved from the command object.
On the other hand, they always need the tournament object,
so it saves a little coding and execution time, and it would be
a lot of work to recode all the command code.

=cut

1;
