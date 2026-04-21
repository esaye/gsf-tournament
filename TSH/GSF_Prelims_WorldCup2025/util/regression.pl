#!/usr/bin/perl

# regression test suite for tsh

use strict;
use warnings;

use Getopt::Long;
use IPC::Open3;
use IO::Select;
use POSIX ":sys_wait_h";

our($opt_preserve, @opt_plugins);

sub Clean ($);
sub CompareReceived ($$$$);
sub IterateSubsets ($$&);
sub Main ();
sub ResetTestInfo ($);
sub RunTest ($);
sub RunTestWithPlugins ($$);
sub RunTSH ($$$$$);
sub Usage ();
sub SplitLines ($);
sub WriteConfig ($$);
sub WriteIFile ($$$);

Main;

sub Clean ($) {
  my $dir = shift;
  return if $opt_preserve;
  unlink <$dir/old/*>, <$dir/html/*>, <$dir/*>;
  rmdir "$dir/old";
  rmdir "$dir/html";
  rmdir $dir or die "Cannot rmdir $dir: $!";
  }

sub CompareReceived ($$$$) {
  my $expect = shift;
  my $gotp = shift;
  my $nonl = shift;
  my $filename = shift;
  my $error = 0;

  my (@expect) = split(/\015?\012/, $expect . ' ');
  pop @expect;
  my $diff = @expect - @$gotp;
  if (@expect > @$gotp) {
    print STDERR "\n" unless $nonl;
    printf STDERR "* Expected %d more line%s than received (%d) for %s:\n", $diff,
      $diff > 1 ? 's' : '', scalar(@$gotp), $filename;
#   print STDERR map { "$_\n" } @expect[0..$#$gotp];
#   print STDERR "--- and then ---\n";
    print STDERR map { "$_\n" } @expect[@$gotp..$#expect];
    $error++;
    }
  elsif (@expect < @$gotp) {
    print STDERR "\n" unless $nonl;
    printf STDERR "* Received %d more line%s than expected (%d)  for %s:\n", -$diff,
      $diff < -1 ? 's' : '', scalar(@expect), $filename;
    print STDERR map { "$_\n" } @{$gotp}[@expect..$#$gotp];
    $error++;
    }
  for my $i (0..(@expect > @$gotp ? @$gotp : @expect)-1) {
    if ($expect[$i] ne $gotp->[$i]) {
      my $col = '?';
      my $gotchars = '[none]';
      my $expectchars = '';
      for my $j (0..length($expect[$i])) {
	if ($j > length($gotp->[$i])) { 
	  $col = $j + 1;
	  last;
	  }
	elsif (substr($expect[$i], $j, 1) ne substr($gotp->[$i], $j, 1)) {
	  $col = $j + 1;
	  $gotchars = substr($gotp->[$i], $j, 80);
	  $expectchars = substr($expect[$i], $j, 80);
	  last;
	  }
        }
      print STDERR "\n" unless $nonl;
      $gotchars = sprintf('0x%02x', ord($gotchars)) unless $gotchars =~ /[ -~]/;
      $expectchars = sprintf('0x%02x', ord($expectchars)) unless $expectchars =~ /[ -~]/;
      printf STDERR "* Did not receive expected text for %s at line %d column $col (got '%s', wanted '%s').\n", $filename,  $i+1, $gotchars, $expectchars;
      print STDERR "** Wanted:   ", $expect[$i], "\n";
      print STDERR "** Received: ", $gotp->[$i], "\n";
      $error++;
      last;
      }
    }
  return $error;
  }

sub Main () {
  GetOptions(
    'preserve' => \$opt_preserve,
    'plugin=s' => \@opt_plugins,
    );
  if (@opt_plugins) {
    for my $plugin (@opt_plugins) {
      next if $plugin eq '';
      next if -d "plugins/$plugin";
      die "There is no plugin called '$plugin' installed.\n";
      }
    }
  else {
    @opt_plugins = map { s!.*/!!; $_ } sort glob 'plugins/*';
    }
  @::ARGV = glob('lib/test/*') unless @::ARGV;

  my %testinfo;
  ResetTestInfo \%testinfo;
  while (<>) {
    if (/^#begintest\s+(.*)/) { $testinfo{'testname'} = $1; ResetTestInfo \%testinfo; next; }
    elsif (/^#endtest\s*$/) { RunTest \%testinfo; ResetTestInfo \%testinfo; next; }

    elsif (/^#beginconfig\s*$/)   { $testinfo{'buffer'} = '';}
    elsif (/^#endconfig\s*$/)     { $testinfo{'config'} = $testinfo{'buffer'}; }

    elsif (/^#begincommands\s*$/) { $testinfo{'buffer'} = ''; }
    elsif (/^#endcommands\s*$/)   { $testinfo{'commands'} = $testinfo{'buffer'}; }

    elsif (/^#beginstdout\s*$/)   { $testinfo{'buffer'} = ''; }
    elsif (/^#endstdout\s*$/)     { $testinfo{'stdout'}{$testinfo{'plugins'}} = $testinfo{'buffer'}; }

    elsif (/^#beginstderr\s*$/)   { $testinfo{'buffer'} = ''; }
    elsif (/^#endstderr\s*$/)     { $testinfo{'stderr'}{$testinfo{'plugins'}} = $testinfo{'buffer'}; }

    elsif (/^#beginofile\s+(\S.*\S)$/) { $testinfo{'buffer'} = ''; $testinfo{'ofilename'} = $1; }
    elsif (/^#endofile\s*$/) { 
      $testinfo{'ofiles'}{$testinfo{'ofilename'}}{$testinfo{'plugins'}} = $testinfo{'buffer'};
      $testinfo{'ofilename'} = undef;
      }

    elsif (/^#beginifile\s+(\S+)\s*$/) { $testinfo{'buffer'} = ''; $testinfo{'ifilename'} = $1; }
    elsif (/^#endifile\s*$/) {
      die "#endifile without matching #beginifile" unless defined $testinfo{'ifilename'};
      $testinfo{'ifiles'}{$testinfo{'ifilename'}} = $testinfo{'buffer'};
      $testinfo{'ifilename'} = undef;
      }
    elsif (s/^##/#/) {
      $testinfo{'buffer'} .= $_; 
      }
    elsif (/^#timeout\s*(\d+)\s*$/) {
      $testinfo{'timeout'} = $1;
      }
    elsif (/^#plugins\s*([\s\w]*?)\s*$/) {
      my $plugins = $1;
      $testinfo{'plugins'} = join(' ', sort split(' ', $plugins));
      }
    elsif (/^#/) {
      die "Unknown directive in $::ARGV: $_\n";
      }
    else { $testinfo{'buffer'} .= $_; }
    }
  if ($testinfo{'error'}) {
    warn "+ Some tests failed: " . join(', ', @{$testinfo{'failed'}}) . "\n";
    }
  else {
    warn "+ All tests successful.\n";
    }
  }

sub ResetTestInfo ($) {
  my $testinfo_p = shift;
  $testinfo_p->{'config'} = '';
  $testinfo_p->{'buffer'} = '';
  $testinfo_p->{'failed'} = [] unless defined $testinfo_p->{'failed'};
  $testinfo_p->{'ifiles'} = {};
  $testinfo_p->{'ofiles'} = {};
  $testinfo_p->{'plugins'} = '';
  $testinfo_p->{'ifilename'} = undef;
  $testinfo_p->{'ofilename'} = undef;
  $testinfo_p->{'commands'} = '';
  if ($testinfo_p->{'serial'}) { $testinfo_p->{'serial'}++ if $opt_preserve; }
  else { $testinfo_p->{'serial'} = time; }
  $testinfo_p->{'stdout'} = {};
  $testinfo_p->{'stderr'} = {};
  $testinfo_p->{'testname'} => 'unnamed test',
  $testinfo_p->{'timeout'} = 10;
  }

sub RunTest ($) {
  my $testinfo_p = shift;

  if (@opt_plugins and (@opt_plugins > 1 or length $::opt_plugins[0])) {
    IterateSubsets [], \@opt_plugins,
      sub {
	my $plugins_p = shift;
	RunTestWithPlugins $testinfo_p, "@$plugins_p";
	};
    }
  else { 
    RunTestWithPlugins $testinfo_p, undef;
    }
  }

sub IterateSubsets ($$&) {
  my $superset_p = shift;
  my $set_p = shift;
  my $sub = shift;
  
  if (@$set_p == 1) {
    &$sub($superset_p);
    &$sub([@$superset_p, @$set_p]);
    }
  elsif (@$set_p) {
    my (@new_superset) = @$superset_p;
    my (@new_set) = @$set_p;
    my $first_item = shift @new_set;

    IterateSubsets \@new_superset, \@new_set, \&$sub;
    push(@new_superset, $first_item);
    IterateSubsets \@new_superset, \@new_set, \&$sub;
    }
  else {
    &$sub($superset_p);
    }
  }

sub RunTestWithPlugins ($$) {
  my $testinfo_p = shift;
  my $plugins = shift;

  print STDERR "+ Running test '$testinfo_p->{'testname'}' ";
  my $testdir = "test.$testinfo_p->{'serial'}";
  -d $testdir or mkdir $testdir or die "Cannot create $testdir: $!";
  WriteConfig $testdir, $testinfo_p->{'config'};
  while (my ($iname, $idata) = each %{$testinfo_p->{'ifiles'}}) {
    WriteIFile $testdir, $iname, $idata;
    }
  if (defined $plugins) {
    if (!length $plugins) {
      print STDERR "without plugins";
      }
    elsif ($plugins =~ / /) {
      print STDERR "with plugins $plugins";
      }
      else {
      print STDERR "with plugin $plugins";
      }
    }
  else { 
    $plugins = ''; 
    print STDERR "without plugins";
    }
  $::ENV{'TSH_PLUGINS'} = $plugins;
  print STDERR ' ... ';
  my $stdout = $testinfo_p->{'stdout'}{$plugins};
# warn "using default stdout" unless defined $stdout;
  $stdout = $testinfo_p->{'stdout'}{''} unless defined $stdout;
  my $stderr = $testinfo_p->{'stderr'}{$plugins};
  $stderr = $testinfo_p->{'stderr'}{''} unless defined $stderr;
  my $thiserror = RunTSH $testdir, $testinfo_p->{'commands'}, $stdout, $stderr,
    $testinfo_p->{'timeout'};
  for my $ofile (sort keys %{$testinfo_p->{'ofiles'}}) {
    if (open my $fh, "<$testdir/$ofile") {
      my (@got) = <$fh>;
      for my $line (@got) { $line =~ s/[\015\012]+$//; }
      close $fh;
      my $ofile_content = $testinfo_p->{'ofiles'}{$ofile}{$plugins};
#     warn "$ofile defaulting from $plugins" unless defined $ofile_content;
      $ofile_content = $testinfo_p->{'ofiles'}{$ofile}{''} unless defined $ofile_content;
      $thiserror += CompareReceived $ofile_content, \@got, $thiserror, $ofile;
      }
    else {
      print STDERR "\n" unless $thiserror++;
      print STDERR "cannot open '$ofile': $!\n";
      }
    }
  if ($thiserror) {
    warn "failed\n";
    push(@{$testinfo_p->{'failed'}}, "$::ARGV ($testinfo_p->{'testname'})"
      . (defined $plugins ? length $plugins ? " with plugins $plugins" : ' without plugins': ''));
    $testinfo_p->{'error'} += $thiserror;
    }
  else {
    warn "ok\n";
    }

  Clean $testdir;
  }

sub RunTSH ($$$$$) {
  my $dir = shift;
  my $commands = shift;
  my $stdout = shift;
  my $stderr = shift;
  my $timeout = shift;
  my $error = 0;
  my $command = $^O eq 'MSWin32' 
    ? "perl tsh.pl $dir"
    : "./tsh.pl $dir";
  $::SIG{'PIPE'} = sub { die "SIGPIPE"; };
  my $pid = open3(*TOTSH, *FROMTSH, *ERRTSH, $command);
  my (%fromtsh) = ('stdout' => '', 'stderr' => '');
  my $timedout = 0;

  my $read_ports = new IO::Select(*FROMTSH, *ERRTSH);
  my $write_ports = new IO::Select(*TOTSH);
  my (%which_read) = (fileno(*FROMTSH) => 'stdout', fileno(*ERRTSH) => 'stderr');
  my $ports_left = 3;
  while ($ports_left) {
    my ($can_read, $can_write, $can_err) 
      = IO::Select::select($read_ports,
  	  length($commands) ? $write_ports : undef,
	  undef,
	  $timeout
	);
    unless (defined $can_err) {
      warn "\nselect() failed (could be timeout too short): $!";
      $error++;
      last;
      }
    my $did_something = 0;
    for my $fh (@$can_read) {
      my $which = $which_read{fileno($fh)};
      die "\nUnknown file handle: $fh" unless $which;
      my $buffer = '';
      my $count = sysread($fh, $buffer, 4096, 0);
      unless (defined $count) {
	die "\nsysread(tsh stdout) failed: $!";
	}
      unless ($count) {
#	warn "EOF on $which";
	$read_ports->remove($fh);
	$ports_left--;
        }
      else {
# 	warn "Read $count bytes from tsh $which: \n---\n$buffer\n---\n";
	$fromtsh{$which} .= $buffer;
	$did_something = 1;
        }
      }
    if (my $fh = $can_write->[0]) {
      my $count = syswrite($fh, $commands, length($commands));
      unless (defined $count) {
	die "\nsyswrite(tsh stdin) failed: $!";
        }
#     warn "Wrote $count bytes to tsh from: $commands";
      substr($commands, 0, $count) = '';
      $did_something = 1;
      unless (length($commands)) {
#	warn "no commands left to send";
	$write_ports->remove($fh);
	$ports_left--;
        }
      }
    if ($ports_left && !$did_something) {
      warn "\nselect() timed out, exiting.";
      last;
      }
    }

  $error += CompareReceived $stdout, SplitLines($fromtsh{'stdout'}), $error, 'stdout';
  $error += CompareReceived $stderr, SplitLines($fromtsh{'stderr'}), $error, 'stderr';
  close(TOTSH) || die "to-tsh exited $?";
  close(ERRTSH) || die "err-tsh exited $?";
  close(FROMTSH) || die "from-tsh exited $?";
  my $kid = waitpid($pid, WNOHANG);
  if ($kid != $pid) {
    print STDERR "\n" unless $error;
    if (kill 0, $pid) {
      print STDERR "* TSH process $pid is still running, trying to kill it.\n";
      if (kill 'TERM', $pid) {
	print STDERR "** Process killed.\n";
	$kid = waitpid($pid, 0);
	if ($kid != $pid) {
	  print STDERR "** Could not reap killed process: $!.\n";
	  if (kill 0, $pid) {
	    die "** Killed unreapable process still exists, giving up.\n";
	    }
	  }
	}
      else {
	print STDERR "** Kill failed: $!.\n";
	}
      }
    }
  return $error;
  }

sub SplitLines ($) {
  my $s = shift;
  my (@lines) = split($/, $s, -1);
  for my $line (@lines) { $line =~ s/[\012\015]+$//; }
  pop @lines if @lines && $lines[-1] eq '';
  return \@lines;
  }

sub Usage () {
  die "$0 [--plugin plugin-name] [--preserve] [test-files...]\n";
  }

sub WriteConfig ($$) {
  my $dir = shift;
  my $contents = shift;
  open my $fh, ">$dir/config.tsh" or die "Can't create $dir/config.tsh: $!";
  print $fh $contents or die "Can't write to $dir/config.tsh: $!";
  close $fh or die "Can't close $dir/config.tsh: $!";
  }

sub WriteIFile ($$$) {
  my $dir = shift;
  my $iname = shift;
  my $idata = shift;
  open my $fh, ">$dir/$iname" or die "Can't create $dir/$iname";
  print $fh $idata or die "Can't write to $dir/$iname";
  close $fh or die "Can't close $dir/$iname";
  }
