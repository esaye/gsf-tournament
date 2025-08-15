#!/usr/bin/perl

# Copyright (C) 2005-2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Utility;

use strict;
use warnings;

use threads::shared;

use Exporter;
use File::Spec;
use File::Temp qw(tempfile);
use Scalar::Util qw(blessed);
use Term::ReadLine;

our(@ISA) = 'Exporter';
our(@EXPORT_OK) = qw(ConcatenateCarefully
  Debug DebugOn DebugOff DebugDumpPairings
  Error FormatHTMLHalfInteger FormatHTMLInteger FormatHTMLSignedInteger 
  IsASafely Isodate Max Min OpenFile Ordinal PrintConsoleCrossPlatform
  ThreadID);
my $gConsoleIsWindowsUnicode;
my %gTERM;  # Aux readline objects for addscore etc.

=pod

=head1 NAME

TSH::Utility- miscellaneous Perl utilities

=head1 SYNOPSIS

  sub new { Util::new(@_); }
  Browse($url);
  DebugOn($code);
  DebugOff($code);
  Debug($code, $format, @args);
  DebugDumpPairings($code, $round0, $psp);
  Error "You goofed.\n";
  $old_value = GetOrSet($object, $field, $new_value);
  $current_value = GetOrSet($object, $field);
  $iso_string = Isodate($epoch);
  PrintColour $colour_name, $text;
  Prompt('subtsh>');
  $fh = OpenFile(">", $dir1, $dir2, ..., $file);
  ReplaceFile($filename, $data);
  print TaggedName($player);
  print Wrap($indent, @text);

  DoRanked($list $comparator, $selector, $actor);
  TruncateFileHandle($fh, $length);
  ShareSafely($ref);
  SpliceSafely(@array, $offset, $length, $list);

  MakeFramesets($html_prefix, %frameset_hash);

=head1 ABSTRACT

This library contains miscellaneous bits of code used by in more than 
one C<tsh> source file.

=cut

sub ArchiveObsoleteFile ($);
sub Browse ($);
sub CanASafely($$);
sub Colour ($$);
sub ConcatenateCarefully (@);
sub Debug ($$@);
sub DebugDumpPairings($$$);
sub DebugOff ($);
sub DebugOn ($);
sub DoOneRank ($$$$);
sub DoRanked ($$$$);
sub Error ($);
sub ExecInNewWindow($@);
sub FormatHTMLHalfInteger ($);
sub FormatHTMLInteger ($);
sub FormatHTMLSignedInteger ($);
sub GaussianRand ($$);
sub GetColourData ($$);
sub GetOrSet ($@);
sub GetWindowsCP ();
sub HTMLToText ($);
sub IsASafely($$);
sub Isodate($);
sub MakeFramesets($$);
sub Max (@);
sub Min (@);
sub new (@);
sub newshared (@);
sub OpenFile ($@);
sub OpenFileThreadShared ($@);
sub Ordinal ($);
sub PrintColour ($$);
sub PrintConsoleCrossPlatform (@);
sub Prompt ($);
sub ReadLine ($$);
sub ReadPassword ();
sub ReplaceFile ($$;$);
sub SetupWindowsUnicodeConsole ();
sub ShareSafely ($);
sub SpliceSafely(\@$$@);
sub TaggedName ($;$);
sub ThreadID ();
sub TruncateFileHandle ($$);
sub UpdateFile ($$);
sub Wrap ($@);

our ($BG_BLUE, $BG_WHITE, $FG_BLUE, $FG_GRAY, $FG_GREEN, $FG_RED, $FG_YELLOW, $FG_WHITE, $ATTR_NORMAL);
my %Colours = (
  'red' => { 'ansi' => "\e[31m", 'win' => $FG_RED },
  'green' => { 'ansi' => "\e[32m", 'win' => $FG_GREEN },
  'blue' => { 'ansi' => "\e[34m", 'win' => ($FG_BLUE||0)|($BG_WHITE||0) },
  'yellow' => { 'ansi' => "\e[33m", 'win' => ($FG_YELLOW||0) },
  'yellow on blue' => { 'ansi' => "\e[44;33m", 'win' => (($FG_YELLOW||0) | ($BG_BLUE||0)) },
  'plain' => { 'ansi' => "\e[30;47;0m", 'win' => $ATTR_NORMAL },
  );
my %gComplained;
my %gDebug;
my $gDebugFH;
my $WinConsole; 
my $WinInConsole; 
BEGIN { 
  if ($^O eq 'MSWin32') { 
    require Win32::Console; import Win32::Console;
    $WinConsole = new Win32::Console &STD_OUTPUT_HANDLE;
    $WinConsole->Title("tsh");
    $WinInConsole = new Win32::Console &STD_INPUT_HANDLE;
    };
  }

=head1 DESCRIPTION

=over 4

=cut
 
sub ArchiveObsoleteFile ($) {
  my $file = shift;
  my $dir = 'obsolete';
  -d $dir || mkdir $dir || do {
    for (my $i = 0; ; $i++) {
      next if -d "$dir-$i";
      mkdir "$dir-$i" or die "mkdir $dir-$i failed: $!";
      $dir .= "-$i";
      last;
      }
    };
  my $target = File::Spec->join($dir, (File::Spec->splitpath($file))[2]);
  -f $target && do {
    for (my $i=0; ; $i++) {
      next if -f "$target-$i";
      $target .= "-$i";
      last;
      }
    };
  rename $file, $target or die "rename $file -> $target failed: $!";
  }

=item Browse($url)

Open a browser window on the specified URL.

=cut

sub Browse ($) {
  my $url = shift;
  eval "use ActiveState::Browser";
  if (defined &ActiveState::Browser::open) {
    &ActiveState::Browser::open($url);
    return;
    }
  elsif ($^O eq 'darwin') {
    system 'open', $url;
    return;
    }
  elsif ($^O eq 'MSWin32') {
    # You'd think system "start $url" would work, but it doesn't.
    open(TSH::Utility::SAVEIN, "<&STDIN"); # forking might be closing STDIN
    open(TSH::Utility::SAVE, ">&STDOUT"); # forking sometimes closes STDOUT
    unless (fork) { exec "rundll32 url.dll,FileProtocolHandler $url"; }
    close(STDOUT); # avoid undefined value errors
    open(STDOUT, ">&TSH::Utility::SAVE"); # restore saved handle just in case
    open(STDIN, "<&TSH::Utility::SAVEIN"); # restore saved handle just in case
#   close(TSH::Utility::SAVEIN); # be tidy
#   close(TSH::Utility::SAVE); # be tidy
    return;
    }
  elsif ($^O =~ /^(?:aix|linux)$/) {
    my $hostname = (eval "use Sys::Hostname;hostname") // '';
    if ($hostname eq 's104-238-81-242.secureserver.net') {
      print "TSH cannot open your browser from this server.\n";
      print "$url\n" if $url =~ /^http/;
      return;
      }

    for my $command (
      'xdg-open %s', 
      'gnome-open %s', 
      'sensible-browser %s', 
      'firefox %s', 
      'mozilla -remote "openURL(%s, new-tab)"', 
      'htmlview %s', 
      ) {
      system sprintf($command, $url);
      if ($? == -1) {
	# could not exec()
	next;
        }
      else {
	# assume all is well
	return;
        }
      }
    }
  print "I don't know how to launch the browser for '$^O'. Please contact John Chew.\n";
  }

sub CanASafely($$) {
  my $object = shift;
  my $method = shift;
  # UNIVERSAL::can() has been officially deprecated because it 
  # cannot be overridden when needed.
  return blessed($object) && $object->can($method);
  }

=item Colour($colour, $text)

Add escape sequences to add colour to text.
Deprecated in favour of PrintColour because Windows console
doesn't use escape sequences.

=cut

sub Colour ($$) {
  die "deprecated function TSH::Utility::Colour";
  my $colour = shift;
  my $text = shift;
  return $text if (defined $config::colour) && $config::colour =~ /^(?:no|0)$/i;
  return $text if $^O eq 'MSWin32' &&
    ((!defined $config::colour) || $config::colour !~ /^yes$/i);
  my $escape = $Colours{$colour}{'ansi'};
  die "Unknown colour: $colour\n" unless defined $escape;
  return "$escape$text$Colours{'plain'}{'ansi'}";
  }

=item @array = ConcatenateCarefully ($scalar, @array, \@array, ...);

Carefully concatenate a bunch of things that might be
scalars, arrays, or references to arrays, omitting undefined
values

=cut

sub ConcatenateCarefully (@) {
  my @array;
  for my $p (@_) {
    next unless defined $p;
    if (ref($p) eq 'ARRAY') {
      push(@array, grep { defined $_ } @$p);
      }
    else {
      push(@array, $p);
      }
    }
  return @array;
  }

=item Debug($code, $format, @args)

Display and log debug text.

=cut

sub Debug ($$@) {
  my $code = shift;
  my $format = shift;
  my (@args) = @_;
  return unless $gDebug{$code};
# local($SIG{__WARN__}) = \&Carp::confess;
  my $s = "[$code] " .  sprintf($format, @args);
  $s .= "\n" unless $s =~ /\n$/;
  print "Debug: " . $s;
  unless ($gDebugFH) {
    $gDebugFH = OpenFile ">:encoding(UTF-8)", "debug.txt";
    }
  if ($gDebugFH) {
    print $gDebugFH $s;
    }
  }

=item DebugDumpPairings($code, $round0, $psp)

Dump the $round0 pairings for the players in $psp if DebugOn($code);

=cut

sub DebugDumpPairings($$$) {
  my $code = shift;
  my $round0 = shift;
  my $psp = shift;
  return unless $gDebug{$code};
  Debug $code, 'Pairings:';
  my %done;
  for my $i (0..$#$psp) {
    my $p = $psp->[$i];
    my $opp = $p->Opponent(-1);
    next if $done{$p->ID()};
    $done{$opp->ID()}++;
    Debug $code, '... %s vs %s.', $p->TaggedName(), $opp->TaggedName();
    }
  }

=item DebugOff($code)

Turn off debugging of type $code.

=cut

sub DebugOff ($) {
  my $code = shift;
  $gDebug{$code} = 0;
  }

=item DebugOn($code)

Turn on debugging of type $code.

=cut

sub DebugOn ($) {
  my $code = shift;
  $gDebug{$code} = 1;
  }

=item DoOneRank($list, $comparator, $actor, $rank0);

Given a sorted list C<@$list>, call C<&$actor($list->[$i], $rank0, $count)> for
all elements C<$list->[$i]> which are at 0-based position C<$rank0>
when C<&$comparator($list->[$j], $list->[$j-1])==0> indicates
that the elements at positions C<$j> and C<$j-1> are to be considered
of equal rank.  C<$count> starts at 1 and increments with each call.
See also C<&DoRanked>.

=cut

sub DoOneRank ($$$$) {
  my $listp = shift;
  my $comparatorp = shift;
  my $actorp = shift;
  my $rank0 = shift;

  my $rank = 0;
  my $count = 0;
  for my $i (0..$#$listp) {
    my $item = $listp->[$i];
    my $changed = 0;
    if ($i == 0 || &$comparatorp($listp->[$i-1], $item)) {
      $rank = $i;
      }
    if ($rank == $rank0) {
      &$actorp($item, $rank, ++$count);
      }
    }
  }

=item DoRanked($list, $comparator, $selector, $actor);

Sort @$list privately by &$comparator, then iterate calling 
&$actor($list->[$i], $rank), where $rank starts at 0 and is set to
$i whenever the value of &$selector($list->[$i]), a list of scalars, changes.
See also C<&DoOneRank>.

=cut

sub DoRanked ($$$$) {
  my $listp = shift;
  my $comparatorp = shift;
  my $selectorp = shift;
  my $actorp = shift;

  my (@sorted) = sort $comparatorp @$listp;
  my @lastvalue;
  my $rank = 0;
  for my $i (0..$#sorted) {
    my $item = $sorted[$i];
    my (@newvalue) = &$selectorp($item);
    my $changed = 0;
    if (@lastvalue != @newvalue) { $changed = 1; }
    else {
      for my $j (0..$#lastvalue) {
	if ($newvalue[$j] ne $lastvalue[$j]) {
	  $changed = 1;
	  last;
	  }
        }
      }
    if ($changed) {
      $rank = $i;
      @lastvalue = @newvalue;
      }
    &$actorp($sorted[$i], $rank);
    }
  }

=item Error($text)

Display an error message.

=cut

sub Error ($) {
  my $message = shift;
  $message .= "\n" unless $message =~ /\n$/;
  PrintColour 'red', $message;
  return 'You should not be using the return value of TSH::Utility::Error.';
  }

=item $error = ExecInNewWindow($command, @argv);

Try to execute a shell command in a new window, return empty string on success, error on failure.

=cut

sub ExecInNewWindow($@) {
  my ($command, @argv) = @_;

  if ($^O eq 'darwin') {
    system 'open', $command, '--args', @argv;
    }
  elsif ($^O eq 'MSWin32') {
    $command =~ s/\//\\/g;
    open(TSH::Utility::SAVEIN, "<&STDIN"); # forking might be closing STDIN
    open(TSH::Utility::SAVE, ">&STDOUT"); # forking sometimes closes STDOUT
    unless (fork) { exec "start cmd /k $command @argv"; }
    close(STDOUT); # avoid undefined value errors
    open(STDOUT, ">&TSH::Utility::SAVE"); # restore saved handle just in case
    open(STDIN, "<&TSH::Utility::SAVEIN"); # restore saved handle just in case
#   close(TSH::Utility::SAVE); # be tidy
    return;
    }
  elsif ($^O =~ /^(?:aix|linux)$/) {
    for my $unix_command (
      "xterm -e '%s' &", 
      "gnome-terminal '%s' &", 
      "Konsole -e '%s' &", 
      ) {
      system sprintf($unix_command, "$command @argv");
      if ($? == -1) {
	# could not exec()
	next;
        }
      else {
	# assume all is well
	return '';
        }
      }
    }
  return "I do not know how to launch programs in the $^O operating system. Please contact John Chew.";
  }

=item $s = FormatHTMLHalfInteger($n/2);

Return an HTML string representing C<$n/2>, possibly using vulgar fractions.

=cut

sub FormatHTMLHalfInteger ($) {
  my $n = shift;
  $n =~ s/^(-*)0*\.5$/$1&frac12;/
    or $n =~ s/\.5$/&frac12;/;
  return $n;
  }

=item $s = FormatHTMLInteger($n);

Return an HTML string representing C<$n>, using correct symbols for signs.

=cut

sub FormatHTMLInteger ($) {
  my $x = shift;
  $x =~ s/^-/&minus;/;
  return $x;
  }

=item $s = FormatHTMLSignedInteger($n);

Return an HTML string representing C<$n>, using correct symbols for signs.
Add a plus sign for nonnegative values, if not already present.

=cut

sub FormatHTMLSignedInteger ($) {
  my $x = shift;
  return $x if $x =~ /^(?:\s*|&nbsp;)$/;
  $x =~ s/^-/&minus;/
    || $x =~ s/^([^+])/+$1/;
  return $x;
  }

=item ($g1, $g2) = GaussianRand($mean, $stdev);

Return two normally distributed random numbers from a distribution with
mean $mean and standard deviation $stdev.

=cut

sub GaussianRand ($$) {
  my $mean = shift;
  my $stdev = shift;
  my ($u1, $u2, $w, $g1, $g2);
  while (1) {
    $u1 = 2 * rand(1) - 1;
    $u2 = 2 * rand(1) - 1;
    $w = $u1 * $u1 + $u2 * $u2;
    last if $w < 1;
    }
  $w = sqrt((-2 * log($w))/$w);
  return wantarray ? ($g1, $g2) : $g1;
  }

=item $s = GetColourData $os, $colour;

Return OS-dependent string corresponding to colour name.

=cut

sub GetColourData ($$) {
  my $os = shift;
  my $colour = shift;
  my $s = $Colours{$colour}{$os};
  unless (defined $colour) {
    warn "Unexpected error, contact John Chew. os=$os, colour=$colour.\n"
      unless $gComplained{'badcolour'}++;
    }
  return $s;
  }

=item GetOrSet()

Boilerplate code for get/set methods.

=cut

sub GetOrSet ($@) {
  my $field = shift;
  my $object = shift;
  my $value = shift;
  my $old = $object->{$field};
  if (defined $value) {
#   eval { $::SIG{__DIE__} = sub { Carp::confess "GetOrSet($object,$field,$value) failed: $_[0]"; }; $object->{$field} = $value; };
    $object->{$field} = $value;
    }
  return $old;
  }

sub GetWindowsCP () {
  return $WinConsole->OutputCP();
  }

my (%gEntities) = (
  'amp' => '&',
  'gt' => '>',
  'lt' => '<',
  'quot' => '"',
  );
my $gEntityPattern = join('|', keys %gEntities);

sub HTMLToText ($) {
  local($_) = shift;
  s/<br>/\n/g;
  s/<p(?:[^>]*)>/\n\n/g;
  s/<(?:[^>]+)>//g;
  s/&((?:$gEntityPattern));/$gEntities{$1}/ge;
  s/^\n+//;
  s/[ \t]*\n[ \t]*/\n/g;
  return $_;
  }

sub IsASafely($$) {
  my $object = shift;
  my $class = shift;
  # UNIVERSAL::isa() has been officially deprecated because it 
  # cannot be overridden when needed.
  return blessed($object) && $object->isa($class);
  }

=item $s = Isodate($);

Local ISO 8601 representation of Datetime of the argument epoch,
or current time.

=cut

sub Isodate ($) {
  my $epoch = shift;
  my ($sec, $min, $hour, $mday, $mon, $year) 
    = (localtime($epoch))[0, 1, 2, 3, 4, 5];
  $year += 1900;
  $mon  += 1;
  return sprintf "%04d-%02d-%02d %02d:%02d:%02d",
    $year, $mon, $mday, $hour, $min, $sec;
  }

=item new()

Boilerplate code for creating Perl objects.

=cut

sub new (@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this = { };
  bless($this, $class);
  $this->initialise(@_);
  return $this;
  }

=item newshared()

Boilerplate code for creating Perl objects.

=cut

sub newshared (@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  # combining the following two lines fails in 5.8.0, assigning $this = 1
  my $this = {};
  &share($this);
  bless($this, $class);
  $this->initialise(@_);
  return $this;
  }

=item $value = Max(@values);

Return the numerically greatest of its arguments, just like
List::Util::max, which is not unfortunately always available.

=cut

sub Max (@) {
  my $x = shift;
  while (@_) { 
    my $y = shift;
    $x = $y if $x < $y;
    }
  return $x;
  }

=item $value = Min(@values);

Return the numerically least of its arguments, just like
List::Util::min, which is not unfortunately always available.

=cut

sub Min (@) {
  my $x = shift;
  while (@_) { 
    my $y = shift;
    $x = $y if $x > $y;
    }
  return $x;
  }

=item $s = Ordinal($n);

Return a string representing the English ordinal corresponding to the
cardinal C<$n>.  For example, "1st" for 1, "112th" for 112.
Also found in C<JJC.pm>.

=cut

sub Ordinal ($) {
  my $n = shift;
  return $n unless $n =~ /^\d+$/;
  if ($n =~ /(?:^1|[^1]1)$/) { $n .= 'st'; }
  elsif ($n =~ /(?:^2|[^1]2)$/) { $n .= 'nd'; }
  elsif ($n =~ /(?:^3|[^1]3)$/) { $n .= 'rd'; }
  else { $n .= 'th' };
  return $n;
  }

=item my $fh = OpenFile($mode, $dir1,...,$dirn, $file, [\%options])

Open a file as indicated.  Use this for consistency rather
than the various "standard" ways of calling open().

Note that at least as of Perl 5.12.4, creating a thread when a file
handle is open with a binmode'd encoding will cause a segmentation fault.

=cut

sub OpenFile ($@) {
  my $fh;
  my $mode = shift;
  my $arghp = {};
  $arghp = pop @_ if @_ && ref($_[-1]) eq 'HASH';
  my $fn = File::Spec->join(@_);
  return undef unless open($fh, $mode, $fn);
  binmode $fh, ':encoding(isolatin1)' unless $mode =~ /:encoding/ or $arghp->{'noencode'};
  return $fh;
  }

=item OpenFileThreadShared($mode, $dir1,...,$dirn, $file, [\%options])

Open a file as indicated.  Use this version for any file whose
handle needs to be shared: typeglobs are not yet shareable, so
we resort to symbolic references.  TODO: Should be replaced by a call
to OpenFile when threads::shared is fully developed.

Note that at least as of Perl 5.12.4, creating a thread when a file
handle is open with a binmode'd encoding will cause a segmentation fault.

=cut

our $HANDLE_NUMBER = 0;

sub OpenFileThreadShared ($@) {
  my $fh = "TSH::Utility::HANDLE$HANDLE_NUMBER";
  $HANDLE_NUMBER++;
  my $mode = shift;
  my $arghp = {};
  $arghp = pop @_ if @_ && ref($_[-1]) eq 'HASH';
  my $fn = File::Spec->join(@_);
  {
    no strict "refs";
    return undef unless open($fh, $mode, $fn);
  }
  binmode $fh, ':encoding(isolatin1)' unless $mode =~ /:encoding/ or $arghp->{'noencode'};
  return $fh;
  }

=item PrintColour($colour, $text)

Print text in specified colour.

=cut

sub PrintColour ($$) {
  my $colour = shift;
  my $text = shift;
  if ((defined $config::colour) && $config::colour =~ /^(?:no|0)$/i) {
    print $text;
    }
  elsif ($^O eq 'MSWin32') { 
#   if ((!defined $config::colour) || $config::colour !~ /^(?:yes|1)$/i) {
#     print $text;
#     }
#   else 
      {
      my $attr = GetColourData 'win', $colour;
      $WinConsole->Attr($attr) if defined $attr;
      print $text;
      $attr = GetColourData 'win', 'plain';
      $WinConsole->Attr($attr) if defined $attr;
      }
    }
  else {
    $text =~ s/([\r\n]*)$//;
    my $stripped = $1;
    my $escape = GetColourData 'ansi', $colour;
    print $escape if defined $escape;
    print $text;
    $escape = GetColourData 'ansi', 'plain';
    print $escape if defined $escape;
    print $stripped;
    }
  }

# There is a known bug in ActivePerl that causes it to emit 
# a blank line after any console line that contains a character
# outside of the ASCII range.
my $console_output_buffer = '';
sub PrintConsoleCrossPlatform (@) {
  return print @_ unless $gConsoleIsWindowsUnicode;
  my $s = join('', $console_output_buffer, @_);
  while ($s =~ s/^([^\n]*\n)//) {
    my $line = $1;
    print $line;
    next unless $line =~ /[^\0-~]/;
    my ($x, $y) = $WinConsole->Cursor();
    $WinConsole->Cursor($x, $y-1);
    }
  $console_output_buffer = $s;
  }

=item Prompt($text)

Displays the given prompt in blue, followed by a plain space.

=cut

sub Prompt ($) {
  my $text = shift;
  PrintColour 'blue', $text;
  print ' ';
  }

=item TSH::Utility::ReadLine($instance, $prompt);

Use Term::ReadLine to read input.  Initializes if necessary, using
$instance as the differentiator.

See also the more elaborate use of Term::ReadLine involving event
processing while at the input prompt in TSH::Processor::RunInteractive.

=cut

sub ReadLine ($$) { 
  my $instance = shift; 
  my $prompt = shift;
  if ($config::accept_remote_commands) {
    # doesn't help with bug
    $gTERM{$instance} = $main::term_rtsh_kludge unless $gTERM{$instance}; 
    }
  else {
    $gTERM{$instance} = Term::ReadLine->new($instance, \*STDIN, \*STDOUT) unless $gTERM{$instance}; 
    }
  return $gTERM{$instance}->readline($prompt);
  }

=item $p = ReadPassword();

Try to read a password without revealing it to onlookers.

=cut

sub ReadPassword () {
  my $s = '';
  if ($^O eq 'MSWin32') {
    my $savemode = $WinInConsole->Mode();
    $WinInConsole->Mode($savemode & ~(&ENABLE_LINE_INPUT()|&ENABLE_ECHO_INPUT()));
    while (1) {
      my $ch = $WinInConsole->InputChar(1);
      if ($ch =~ /^[\0\004\012\015\032]$/) {
	last;
        }
      elsif ($ch =~ /^[\010\377]$/) {
	chop $s;
	}
      else {
	$s .= $ch;
	}
      }
    $WinInConsole->Mode($savemode);
    }
  else {
    eval "use POSIX";
    if ($@) {
      print "I can't figure out how to suppress keyboard echo on your machine, please contact John Chew.\n";
      $s = readline(STDIN);
      chomp $s;
      }
    else {
      my $term = POSIX::Termios->new(); # allocate Termios object
      my $saveflags;
      my $flags = $saveflags = $term->getlflag();
      my $fd_stdin = fileno(STDIN);
      $flags &= ~(&POSIX::ICANON | &POSIX::ECHO | &POSIX::ECHOK);
      # following line shouldn't be necessary, but is on NASPA server
      $saveflags |= &POSIX::ICANON | &POSIX::ECHO | &POSIX::ECHOK;
      $term->getattr($fd_stdin); # fill $term with data about STDIN
      $term->setlflag($flags);
#     $term->setcc(&POSIX::VTIME, 1);
      $term->setattr($fd_stdin, &POSIX::TCSANOW);
      $s = readline(STDIN);
      chomp $s if defined $s;
#     # is hanging under OS/X 10.6
      $term->setlflag($saveflags);
#     $term->setcc(&POSIX::VTIME, 0);
      $term->setattr($fd_stdin, &POSIX::TCSANOW); 
      }
    }
  return $s;
  }

=item $success = ReplaceFile($filename, $data)

Carefully replace the contents of the file called $filename with
$data, by creating a temporary file in the same directory, then
renaming it, so as to prevent another process from reading garbled
data in the middle of an update.  Returns boolean indicating success.

=cut

sub ReplaceFile ($$;$) {
  my $filename = shift;
  my $data = shift;
  my $optionsp = shift || {};
  my (@stat) = stat $filename;

  my ($volume, $dirs, $file) = File::Spec->splitpath($filename);
  my $dir = File::Spec->catpath($volume, $dirs,'');
  my ($newfh, $newfn) = tempfile(DIR => $dir, UNLINK => 0);
  my $encoding = $optionsp->{'encoding'} || 'isolatin1';
# warn $encoding;
  binmode $newfh, ":encoding($encoding)";
  print $newfh $data or return 0;
  close $newfh or return 0;
  chmod $stat[2], $newfn if @stat;
  for (my $try=0; $try<10; $try++) {
    rename $newfn, $filename and return 1;
    warn "File $filename cannot be replaced ($!), retrying (try $try/10) in one second.\n";
    sleep 1;
    }
  return 0;
  }

sub SetupWindowsUnicodeConsole () {
  $gConsoleIsWindowsUnicode = 1;
# Thai CP 874
  if (0) {
    binmode STDOUT, ':encoding(UTF-8)';
    print "Setting console to Unicode, default font to Lucida Console.\n";
    `chcp 65001`;
    `REG ADD HKCU\\Console /v FaceName /d "Lucida Console" /f`;
    `REG ADD HKCU\\Console /v FontFamily /t REG_DWORD /d 0x36 /f`;
    }
  else {
    my %gRegHash;
    eval q{use Win32::TieRegistry (Delimiter => '/', TiedHash => \%gRegHash)};
    die $@ if $@;
    my $changed = 0;
    print "Switching Perl STDOUT to UTF8.\n";
    binmode STDOUT, ':encoding(UTF-8)';
    print "Checking console code page.\n";
    my $old_cp = $WinConsole->OutputCP();
    if ($old_cp == 65001) {
      print "Code page was already 65001.\n";
      }
    else {
      print "Code page was $old_cp, changing to 65001.\n";
      $WinConsole->OutputCP(65001);
      }

    print "Checking console fonts.\n";
    if ($gRegHash{'CUser/Console/FaceName'} ne 'Lucida Console') {
      print "Setting default console font to Lucida Console.\n";
      $gRegHash{'CUser/Console/FontFamily'} = ['0x0036', 'REG_DWORD'];
      $gRegHash{'CUser/Console/FaceName'} = 'Lucida Console';
      $changed = 1;
      }
    else {
      print "Default console font is already Lucida Console.\n";
      }
    if (defined $gRegHash{'CUser/Console/%SystemRoot%_system32_cmd.exe/FaceName'}) {
      if ($gRegHash{'CUser/Console/%SystemRoot%_system32_cmd.exe/FaceName'} ne 'Lucida Console') {
	print "Setting default cmd.exe font to Lucida Console.\n";
	$gRegHash{'CUser/Console/%SystemRoot%_system32_cmd.exe/FontFamily'} = ['0x0036', 'REG_DWORD'];
	$gRegHash{'CUser/Console/%SystemRoot%_system32_cmd.exe/FaceName'} = 'Lucida Console';
	$changed = 1;
	}
      else {
	print "Default cmd.exe font is already Lucida Console.\n";
	}
      }
    else {
      print "Default cmd.exe font is not specified on this machine.\n";
      }

    if ($changed) {
      print "Switching to new window with correct font.\n";
      $WinConsole->Free();
      $WinConsole->Alloc();
      print "Switched to new window with correct font.\n";
      }
    }
#   print "If you do not see a Euro sign here: ",chr(0x20AC),", right-click\n", "the title bar and set your font to Lucida Console.\n";
  }

=item $newref = ShareSafely($oldref)

Returns a reference to a thread-shared version of a reference.
At present, using threads::shared::share() on a reference clears
its contents.

=cut

sub ShareSafely($) {
  my $ref = shift;
  my $type = ref($ref);
  if ($type eq '') {
    my $shared : shared = $ref;
    return $shared;
    }
  elsif ($type eq 'ARRAY') {
    my @shared : shared = map { ShareSafely($_) } @$ref;
    return \@shared;
    }
  elsif ($type eq 'HASH') {
    my %shared : shared = map { ($_, ShareSafely($ref->{$_})) } keys %$ref;
    return \%shared;
    }
  elsif ($type eq 'CODE') {
    return $ref;
    }
  else {
    die "ShareSafely: don't yet support reference type $type";
    }
  }

=item @removed = SpliceSafely(@array, $offset, $length, @list);

Does what the built-in splice does, but works even when applied
to a shared object in a threaded environment.  Not particularly
efficient, and should be replaced as soon as splicing works properly
with threads.  Note that unlike in the calling sequence for splice(),
$offset and $length are not optional.

=cut

sub SpliceSafely(\@$$@) {
  my $arrayp = shift;
  my $offset = shift;
  my $length = shift;
  my @list = @_;
  
  my @copy = @$arrayp;
  my @removed = splice(@copy, $offset, $length, @list);
  while (@$arrayp > @copy) { pop @$arrayp; }
  for my $i ($offset..$#copy) {
    $arrayp->[$i] = $copy[$i];
    }
  while (@$arrayp < @copy) {
    push(@$arrayp, $copy[@$arrayp]);
    }
  return @removed;
  }

=item $time = Time

Return current time at highest available resolution.

=cut

sub Time () {
  eval "use Time::HiRes qw(gettimeofday)" unless $::gkTriedTimeHiRes++;
  return defined &gettimeofday ? scalar(&gettimeofday) : time;
  }

=item TaggedName($player, $optionsp)

Safe wrapper for TSH::Player::TaggedName

=cut

sub TaggedName ($;$) {
  my $p = shift;
  my $optionsp = shift;
  if (IsASafely($p,'TSH::Player')) {
#   warn "$p->{'etc'}{'team'}[0]:$p->{'name'}:".$p->TaggedName($optionsp).':'.join(",", %$optionsp) if $p->{'etc'}{'team'}[0] =~ /THA/;
    return $optionsp->{html} ? $p->TaggedHTMLName($optionsp)
      : $p->TaggedName($optionsp);
    }
  else {
    return 'nobody';
    }
  }

=item my $tid = ThreadID();

Return the current thread ID, or 0 if threads are not in use.

=cut

sub ThreadID () {
  return UNIVERSAL::can('threads', 'tid') ? threads->tid() : 0;
  }

=item TruncateFileHandle($filehandle, $length);

Works like the built-in truncate(), but assumes its first argument
is a symbolic reference rather than a filename, if it's not a
file handle.  Part of a collection of routines to work around
the inability of the threads::shared module to share fileglobs.

=cut

sub TruncateFileHandle ($$) {
  my $fh = shift;
  my $length = shift;
  unless (ref($fh)) {
    no strict 'refs';
    $fh = *{$fh};
    }
  return truncate $fh, $length;
  }

=item $success = UpdateFile($from, $to);

Copy file from $from to $to if they differ.  Assumes both are names of
regular files.

=cut

sub UpdateFile ($$) {
  my $from = shift;
  my $to = shift;

  local($/) = undef;
  my $fh = OpenFile '<', $from;
  unless ($fh) {
    warn "Cannot open file '$from' to copy it to '$to': $!";
    return 0;
    }
  my $from_data = <$fh>;
  close $fh or return 0;

  if ($fh = OpenFile '<', $to) {
    my $to_data = <$fh>;
    close $fh;
    if ($from_data eq $to_data) {
#     warn "Not copying $from to $to: contents are identical";
      return 2;
      }
    }
  
  if ($fh = OpenFile '>', $to) {
    print $fh $from_data or return 0;
    close $fh or return 0;
    }
  else {
    return 0;
    }
  return 1;
  }

=item MakeFramesets($html_prefix,  %frameset_hash)

Based on the specs for framesets as defined by config frameset lines,
create the corresponding HTML.

=cut

sub MakeFramesets($$) {
  my $html_prefix = shift;
  my $framesets = shift;

  foreach my $frameset_index (keys %{$framesets}) {
    my $frameset_html = ${$framesets}{$frameset_index};
    open my $fh, '>:encoding(utf8)', "$html_prefix-$frameset_index.html"
      or die "Failed to open $html_prefix-$frameset_index.html ($!)";
    print $fh <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head><title>Frameset-$frameset_index</title></head>
EOF

    $frameset_html =~ s/\bfs\b/frameset/g;
    $frameset_html =~ s/\bst\b/standings.html/g;
    $frameset_html =~ s/\besb-(\d+)\b/enhanced-scoreboard-$1.html/g;
    $frameset_html =~ s/\besb\b/enhanced-scoreboard.html/g;
    # The three primary shorthand expansions

    $frameset_html =~ s/\.html\.html/.html/g;
    # Be tolerant of the presence of e.g., "src=A-st.html"

    $frameset_html =~ s/src\s*=\s*(\S+)(<)?/\n<frame frameborder="1"  src="$1"> <\/frame>\n/g;
    # Create a Frame tag from src=
    print $fh $frameset_html;
    close $fh or die "Failed to close frameset HTML ($!)";
    }
  }


=item Wrap($indent, @text)

Justify text right-ragged.

=cut

sub Wrap ($@) {
  my $indent = shift;
  my $indent_space = ' ' x $indent;
  my $width = 78;
  my $s = $indent_space;
  my $hpos = $indent;
  my $atsol = 1;
  while (@_) {
    my (@words) = split(/\s+/, shift);
    for my $word (@words) {
      $word =~ s/\.$/. / unless $word =~ /\../;
      my $l = length($word);
      if ($hpos + $l > $width) {
	$s .= "\n$indent_space$word";
	$hpos = $indent + $l;
        }
      else {
	unless ($atsol) {
	  $word = " $word";
	  $l++;
	  }
	$s .= $word;
	$hpos += $l;
	$atsol = 0;
        }
      }
    }
  $s .= "\n";
  return $s;
  }

=back

=cut

=head1 BUGS

C<Colour>,
C<PrintColour>
and
C<Wrap>
should be in something called 
C<TSH::TTY>.

C<Wrap> should dynamically determine the width of the
current console.

ReadPassword should invoke Config::DecodeConsoleInput

=cut

1;
