#!/usr/bin/perl

# Copyright (C) 2005-2015 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Tournament;

use strict;
use warnings;

use Fcntl ':flock';
use FileHandle;
use JavaScript::Serializable;
use Ratings;
use TSH::Config;
use TSH::Utility qw(ThreadID);
use threads::shared;
use UserMessage;

our (@ISA);
@ISA = qw(JavaScript::Serializable);
sub EXPORT_JAVASCRIPT () { return (
  'config' => 'config',
  'divlist' => 'divisions',
  'esb' => 'esb',
  'profile' => 'profile',
  ); }

=pod

=head1 NAME

TSH::Tournament - abstraction of a Scrabble tournament within C<tsh>

=head1 SYNOPSIS

  $t = new Tournament($eventdir);
  $t = new Tournament({'path' => $eventdir, 'silent' => 1);
  $t->LoadConfiguration();
  $t->Config()->Export(); # deprecated
  $t->TellUser('iwelcome', $gkVersion);
  $t->Lock();
  $t->LoadDivisions();
  # edit the tournament data here
  $t->Unlock();

  $um = $t->UserMessage(); # see UserMessage.pm;
  $p = GetPlayerByName($pname);
  $t->AddDivision($d);
  $n = $t->CountDivisions();
  @d = $t->Divisions();
  $d = $t->GetDivisionByName($dn);
  $c = $t->Config();
  $t->Explain($code);
  $t->RegisterPlayer($p);
  $t->TellUser($code, @args);

=head1 ABSTRACT

This Perl module is used to manipulate tournaments within C<tsh>.

=head1 DESCRIPTION

=over 4

=cut

sub AddDivision ($$);
sub Config ($;$);
sub CountDivisions ($);
sub Divisions ($);
sub ErrorFilter($$$);
sub Explain ($;$);
sub ExplainFilter ($$);
sub FindPlayer ($$$$;$);
sub GetPlayerByName ($$);
sub GetDivisionByName ($$);
sub initialise ($;$);
sub LastReport ($;$);
sub LoadConfiguration ($;$);
sub LoadDivisions ($);
sub LoadRatings ($);
sub Lock ($);
sub new ($;$);
sub NoteFilter ($$$);
sub Path ($;$);
sub RegisterPlayer($$);
sub TellUser ($$@);
sub Unlock ($);
sub UnregisterPlayer ($$);
sub WarningFilter($$$;$);

=item $t->AddDivision($d)

Add a division to the tournament.

=cut

sub AddDivision ($$) { 
  my $this = shift;
  my $dp = shift;
  my $dname = $dp->Name();
  if (exists $this->{'divhash'}{$dname}) {
    die "Duplicate division: $dname.\nAborting";
    }
  push(@{$this->{'divlist'}}, $dp);
  $this->{'divhash'}{$dname} = $dp;
  $dp->Tournament($this);
  $this->{'config'}{'reserved'}{$dname} = &share([]);
  $this->{'config'}{'gibson_groups'}{$dname} //= &share([]);
  $this->{'config'}{'esb_geometry'}{$dname} = &share([]);
  }

sub AddMessageFiles ($@) {
  my $this = shift;
  my @files = @_;
  $this->{'message'}{ThreadID()}->AddFiles('file' => \@files,
    'encoding' => $this->{'config'}->MessageFileEncoding());
  }

=item ($dp, $pn) = $tourney->CheckMatchDivPN($s)

If $s looks like it is intended to identify a
player by division name and player number,
return a division pointer and player number.
If an invalid division name is given, return
the division name and player number.
Otherwise, return undef.

=cut

sub CheckMatchDivPN ($$) {
  my $tourney = shift;
  my $s = shift;

  return unless $s =~ /^([a-zA-Z]+)(\d+)$/;
  my $dn = $1;
  my $pn = $2;
  my $dp = $tourney->GetDivisionByName($dn);
  return ($dp||$dn, $pn);
  }

=item $c = $t->Config();
=item $t->Config($c);

Get/set a tournament's configuration object.

=cut

sub Config ($;$) { TSH::Utility::GetOrSet('config', @_); }

=item $t->CopyDivisions($srct);

Copy division data from another tournament.
The destination tournament determines the names of the divisions
to be copied, which must exist and be identically named in the
source tournament.

=cut

sub CopyDivisions ($$) {
  my $this = shift;
  my $srct = shift;
  for my $dp (@{$this->{'divlist'}}) {
    my $srcdp = $srct->GetDivisionByName($dp->Name());
    my $data = $srcdp->Render();
    $dp->ReadFrom({'type'=>'string', 'data' => $data});
    }
  }

=item $n = $t->CountDivisions()

Count how many divisions a tournament has.

=cut

sub CountDivisions ($) { 
  my $this = shift;
  return scalar(@{$this->{'divlist'}});
  }

=item @d = $t->Divisions()

Return a list of a tournament's divisions.

=cut

sub Divisions ($) { 
  my $this = shift;
  return @{$this->{'divlist'}};
  }

=item ErrorFilter($code, $type, $message);

Callback subroutine used by UserMessage.pm

=cut

sub ErrorFilter ($$$) {
  my $code = shift;
  my $type = shift;
  my $message = shift;
  my $tourney = shift;

  my $config = ($tourney && $tourney->Config());

  if (!-t STDOUT) { 
    print STDERR "Error: $message [$code]\n";
    return;
    }
  my $colour = $config->Value('error_colour') 
    || $config->Value('error_color') || 'red';
  TSH::Utility::PrintColour $colour, "Error: $message";
  if ($config->Value('beep')) { print "\a"; }
  print " [$code]\n";
  }

=item $success = $t->ExpandNames($string, $dp);

Replace player names with player IDs in a string (edited in place).
Return success unless some player names could not be found.

=cut

sub ExpandNames ($$$) {
  my $this = shift;
  my $dp = pop;

  while ($_[0] =~ /^(.*?)(\S*),(\S*)(.*)$/i) {
    my ($pre, $last, $first, $post) = ($1, $2, $3, $4);
    my $pp = $this->FindPlayer($last, $first, $dp);
    return 0 unless $pp;
    $_[0] = $pre . ($pp->ID()) . $post; 
    }
  while ($_[0] =~ /^(.*?)([^-+\s\d]\S*)(.*)$/i) {
    my ($pre, $name, $post) = ($1, $2, $3, $4);
    my $pp = $this->FindPlayer($name, '', $dp);
    return 0 unless $pp;
    $_[0] = $pre . ($pp->ID()) . $post; 
    }
  return 1;
  }

=item $t->Explain();
=item $t->Explain($code);

Explain a message code (or the last one) to the user.

=cut

sub Explain ($;$) {
  my $this = shift;
  my $code = shift;

  my $um = $this->{'message'}{ThreadID()} || $this->{'message'}{0};
  return unless $um;
  $um->Explain($code) ||
  $this->TellUser('ebadhuh', $code);
  }

=item ExplainFilter($code, $message);

Callback subroutine used by UserMessage.pm

=cut

sub ExplainFilter ($$) {
  my $code = shift;
  my $message = shift;

  if (!-t STDOUT) { 
    return;
    }
  print TSH::Utility::Wrap(0, "[$code] $message");
  }

=item $pp = $t->FindPlayer($name1, $name2, $dp[, $style]);

Find a player whose name matches C</$name1.*,$name2/i> in division $dp.
If C<$name2> is null, look for C</^\Q$name1$/i>.
If C<$dp> is null, look in all divisions.
If C<$style> eq 'detailed', return a hash with keys 'otherdiv' and 'matches'.
If C<$style> has another true value, return a list of matches.
If C<$style> has a false value, return a single matching value or warn the user and return undef if a
  unique match cannot be found.

=cut

sub FindPlayer ($$$$;$) {
  my $this = shift;
  my $name1 = shift;
  my $name2 = shift;
  my $dp = shift;
  my $quiet = shift;
  my $dname = $dp && $dp->Name();
  my $pattern;
  $name1 =~ s/\\(\d)/$1/g if $name1;
  $name2 =~ s/\\(\d)/$1/g if $name2;
  eval { $pattern = (defined $name2) ? qr/\Q$name1\E.*\Q$name2\E/i : qr/^\Q$name1\E$/i; };
  if ($@) {
    $this->TellUser('ebadregexp', $@);
    return undef;
    }
  my @matched;
  my $wrong_div_match = undef;
  # not thread-safe in 5.8.6
# while (my ($name, $pp) = each %{$this->{'pbyname'}}) {
  for my $name (keys %{$this->{'pbyname'}}) { 
    my $pp = $this->{'pbyname'}{$name};
#   warn "$name $pattern";
    next unless $name =~ /$pattern/;
#   warn "$name $pattern matched";
    if ($dname && $pp->Division()->Name() ne $dname) {
      $wrong_div_match = $pp->Division()->Name();
      next;
      }
    push(@matched, $pp);
    }
  if ($quiet) { 
    if ($quiet eq 'detailed') {
      return { 'otherdiv' => $wrong_div_match, 'matches' => \@matched };
      }
    return @matched; 
    }
  if (@matched == 0) { 
    # TODO: report other division here
    $this->TellUser((defined $wrong_div_match) ? 'enomatch2' : 'enomatch', 
      (defined $name2) ? "$name1,$name2" : "^\Q$name1\E\$", $wrong_div_match); 
    }
  elsif (@matched == 1) { return $matched[0]; }
  elsif (@matched <= 10) {
    $this->TellUser('emultmatch', "$name1,$name2", 
      join('; ', map { $_->TaggedName() } @matched));
    }
  else { $this->TellUser('emanymatch', "$name1,$name2"); }
  return undef;
  }

=item $pp = $t->GetPlayerByName($name);

Obtain a Player pointer given a player name.

=cut

sub GetPlayerByName ($$) {
  my $this = shift;
  my $pname = shift;
  return $this->{'pbyname'}{uc $pname};
  }

=item $d = $t->GetDivisionByName($dn);

Obtain a Division pointer given the division's name in not 
necessarily canonical style.

=cut

sub GetDivisionByName ($$) {
  my $this = shift;
  my $dname = shift;
  $dname = TSH::Division::CanonicaliseName($dname);
  return $this->{'divhash'}{$dname};
  }

=item $t->initialise(\%options);

(Re)initialise a Tournament object, for internal or careful external use.

=cut

sub initialise ($;$) {
  my $this = shift;
  my $argv = shift;
  if (!defined $argv) {
    $argv = { 'path' => undef, 'search' => 1 };
    }
  elsif (!ref($argv)) {
    $argv = { 'path' => $argv };
    }
  if ($argv->{'virtual'}) {
    delete $argv->{'path'};
    $argv->{'search'} = 0;
    $argv->{'readonly'} = 1;
    }
  # all fields should be listed here, regardless of whether they need init
  $this->{'cmdhash'} = &share({});
  $this->{'cmdlist'} = &share([]);
  # the optional profile file contains user-customizable installation defaults
  if (-r 'lib/profile.tsh' && -f 'lib/profile.tsh') {
    $this->{'profile'} = new TSH::Config(
      'tournament' => $this,
      'filename' => 'lib/profile.tsh',
      'search' => 0,
      'type' => 'profile',
      );
    }
  # the following line creates a configuration object but does not 
  # read configuration data into it (see LoadConfiguration())
  $this->{'config'} = new TSH::Config($this, $argv->{'path'}, $argv->{'readonly'}, $argv->{'search'})
    or die "TSH::Tournament::initialise: could not load configuration";
  $this->{'divhash'} = &share({});
  $this->{'divlist'} = &share([]);
  $this->{'esb'} = &share({});
  $this->{'esb'}{'message'} = &share({});
  $this->{'esb'}{'message'}{'mode'} = 'reveal';
  $this->{'esb'}{'message'}{'text'} = '';
  $this->{'lastreport'} = undef;
  $this->{'lockfh'} = undef;
  $this->{'message'} = &share({});
  $this->{'pbyname'} = &share({});
  for my $argn (qw(path readonly sandbox silent virtual)) {
    $this->{$argn} = $argv->{$argn};
    }

  $this->Silent($argv->{'silent'});
  }

sub IsInSandbox($) {
  my $this = shift;
  return $this->{'sandbox'};
  }

=item $filename = $t->LastReport();
=item $t->LastReport($filename);

Get/set a tournament's last generated report, for use by the BrowseLast
command.

=cut

sub LastReport ($;$) { TSH::Utility::GetOrSet('lastreport', @_); }

=item $t->LoadConfiguration([$string]);

Read and check the profile and configuration files for this tournament.

Seldom-used optional argument C<$string> gives content of configuration
file, possibly overriding a previously specified path.

=cut

sub LoadConfiguration ($;$) {
  my $this = shift;
  my $string = shift;
  my $config = $this->{'config'};
  if (my $profile = $this->{'profile'}) {
    $profile->Read();
    $profile->Setup();
    $config->CopyFromProfile($profile);
    }
  $config->Read($string);
  $config->Setup();
  if ($config->Value('message_file')) {
    $this->AddMessageFiles($config->Value('message_file'));
    }
  }

=item $t->LoadDivisions();

Read and parse one .t file for each division to load its data.
Can take a while to run for a large tournament.

=cut

sub LoadDivisions ($) {
  my $this = shift;
  for my $dp (@{$this->{'divlist'}}) {
    $dp->Read();
    }
  }

=item $t->LoadDivisionsAttached(\%options);

Read and parse division data from configuration file attachments.

=cut

sub LoadDivisionsAttached ($) {
  my $this = shift;
  my $argh = shift || {};
  my $config = $this->{'config'};
  for my $dp (@{$this->{'divlist'}}) {
    next if $argh->{'ignore_unrated'} && $dp->RatingSystemName() eq 'none';
    my $dfile = $dp->File();
    my $content = $config->AttachedContent($dfile);
    warn "No content for '$dfile'" unless defined $content;
    $dp->ReadFromString($content || '');
    }
  }

=item $success = $t->LoadRatings ();

Load current ratings for players in this tournament, from the rating 
data file for the currently configured rating system.

=cut

sub LoadRatings ($) {
  my $this = shift;
  my $config = $this->{'config'};

  my $success = 1;
  for my $dp ($this->Divisions()) {
    $success &&= $dp->LoadRatingsFile();
    }

  return $success;
  }

=item $error = $t->Lock();

At most one process should have a tournament open for writing at
any time.  This is enforced by Lock() and Unlock().

It is safe for other processes to read data without obtaining a lock,
because it is always written to a separate temporary file before
being moved into place.

Dies if something unexpected goes wrong.
Returns an error message if flock() itself fails, typically because
another process already had the lock.
Returns the empty string on success.

=cut

sub Lock ($) {
  my $this = shift;
  my $error;

  no strict 'refs';
  (defined $this->{'config'})
    or die "TSH::Tournament::Lock: configuration file has not yet been read.\n";
  my $fn = $this->{'config'}->MakeRootPath('tsh.lock');
# my $fh = $this->{'lockfh'} = new FileHandle $fn, O_CREAT | O_RDWR
  my $fh = $this->{'lockfh'} = TSH::Utility::OpenFileThreadShared('+>', $fn, {'noencode'=>1})
    or die "Can't open lock file $fn, probably because of a file or directory permission error ($!).\n";
# warn "lock file is $fn; fh is $fh";
  flock($fh, LOCK_EX | LOCK_NB) 
    or return $!;
  seek($fh, 0, 0) 
    or die "Can't rewind tsh.lock - something is seriously wrong.\n";
  TSH::Utility::TruncateFileHandle($fh, 0) 
    or die "Can't truncate tsh.lock - something is seriously wrong.\n";
  print $fh "$$\n"
    or die "Can't update tsh.lock - something is seriously wrong.\n";
  return '';
  } 

=item $t = new Tournament(\%options);

Create a new Tournament object.  Supported options:

C<path>: if set, names the tournament's directory

C<readonly>: if true, the tournament will not be updated to disk

C<search>: if true, search for the directory with newest config.tsh file

C<virtual>: if set, tournament has no directory (implies !path readonly !search)

=cut

sub new ($;$) { return TSH::Utility::newshared(@_); }

=item NoteFilter($code, $type, $message);

Callback subroutine used by UserMessage.pm

=cut

sub NoteFilter ($$$) {
  my $code = shift;
  my $type = shift;
  my $message = shift;

  if (!-t STDOUT) { 
    return;
    }
  print "$message [$code]\n";
  }

=item $p = $t->Path();
=item $t->Path($p);

Get/set a tournament's (directory) path.
Not currently recommended for use in setting the path.

=cut

sub Path ($;$) { TSH::Utility::GetOrSet('path', @_); }

=item $p = $t->Profile();
=item $t->Profile($p);

Get/set a tournament's profile object.

=cut

sub Profile ($;$) { TSH::Utility::GetOrSet('profile', @_); }

=item $t->RegisterPlayer($p);

Register a player so that they can subsequently be looked up by name.

=cut

sub RegisterPlayer ($$) {
  my $this = shift;
  my $p = shift;
  $this->{'pbyname'}{uc $p->Name()} = $p;
  }

=item $s = $t->RenderMessage($code, @args);

Render a user message, without displaying it.

=cut

sub RenderMessage ($$@) {
  my $this = shift;
  my $code = shift;
  my @args = @_;

  my $um = $this->{'message'}{ThreadID()} || $this->{'message'}{0};
  return undef unless $um;
  return $um->Render('code' => $code, 'argv' => \@args);
  }

=item $success = $t->SaveJSON();

Save the tournament's state in JSON format.

=cut

sub SaveJSON ($) {
  my $this = shift;
  my $config = $this->Config();
  my $c_is_capped = $config->HasSpreadCaps();
  my $c_has_moods = $config->Value('player_moods');
  my $fn = $config->MakeHTMLPath('tourney.js');
  my $fh = TSH::Utility::OpenFile '>:encoding(utf-8)', $fn;
  return 0 unless $fh;
  for my $dp ($this->Divisions()) {
    my (@ps) = ($dp->Players());
    TSH::Player::SpliceInactive(@ps, 0, 0);
    my $max_r0 = $dp->MostScores()-1;
    my $p = $ps[0];
    next unless $p;
    for my $r0 (-1..$max_r0) {
      if ($c_is_capped) {
	if (!defined $p->RoundCappedRank($r0, undef, 1)) {
	  $dp->ComputeCappedRanks($r0);
	  }
	}
      else {
 	if (defined $p->RoundRank($r0, undef, 1)) {
# 	  warn "Should not have to recompute ranks for round ".($r0+1)." for division ".$dp->Name();
#	  $dp->ComputeRanks($r0);
 	  }
 	else {
#	  warn "Recomputing ranks for round ".($r0+1)." for division ".$dp->Name().': '.join(',',@{$p->{'etc'}{'rrank'}});
	  $this->TellUser('irecomprank', $r0+1, $dp->Name());
	  $dp->ComputeRanks($r0);
 	  }
	}
      next unless $r0 >= 0;
      if ($c_is_capped) {
	@ps = TSH::Player::SortByCappedStanding($r0, @ps);
	}
      else {
	@ps = TSH::Player::SortByStanding($r0, @ps);
	}
      $dp->FirstOutOfTheMoney(\@ps, $r0); # populate cache
      if (defined $p->NewRating($r0)) {
#  	warn "Not recomputing ratings for round ".($r0+1);
        }
      else {
	$this->TellUser('irecomprat', $r0+1, $dp->Name());
        $dp->ComputeRatings($r0);
        }
      $dp->ComputeMoods($r0) if $c_has_moods;
      }
    $dp->ComputeSeeds();
    }
  print $fh "newt=".$this->ToJavaScript().";\n" || return 0;
  close $fh or return 0;
  return 1;
  }

=item $success = $t->SaveRatings([$processor]);

Save post-event ratings for players in this tournament
in the appropriate file.

If an optional processor is specified and a division data update is 
triggered by the rating calculation, then the processor will be used
to run config hook_division_update (if it is set).

=cut

sub SaveRatings ($;$) {
  my $this = shift;
  my $processor = shift;

  my $config = $this->Config();

  # make sure input ratings are current
  $this->LoadRatings() or return 0;
  
  # export unsaved division data, so that it's always older than rating data
  if ($processor) { $this->Processor()->Flush(); }
  else { $this->UpdateDivisions(); }

  # compute the rating timestamp
  my $timestamp = $config->Value('event_date');
  if ($timestamp !~ /^\d\d\d\d-\d\d-\d\d$/) {
    $timestamp = 0;
    }

  # store information related to a rating list
  my %rating_lists;

  # for each division
  for my $dp ($this->Divisions()) {
    # make sure its current ratings are computed
    $dp->ComputeRatings($dp->MostScores()-1);
    # identify its rating list and system
    my $rating_list = $dp->RatingList();
    my $rating_system = $dp->RatingSystem();
    # if this is the first time we are encountering this rating list
    if (!exists $rating_lists{$rating_list}) {

      }
    }
  }

=item $t->SetESBMessage($mode, $msg);

Set or clear a message on the ESB.

=cut

sub SetESBMessage ($$$) {
  my $this = shift;
  my $mode = shift;
  my $msg = shift;
# warn "mode is now $mode";
  $msg = '' if (!$msg) || lc($msg) eq "off";
  $this->{'esb'}{'message'}{'text'} = $msg;
  $this->{'esb'}{'message'}{'mode'} = $mode;
  return $msg;
  }

=item $boolean = $t->Silent();
=item $t->Silent($boolean);

Get/set the tournament's silent flag.

=cut

sub Silent ($;$) { 
  my $this = shift;
  my $old_value = TSH::Utility::GetOrSet('silent', $this, @_); 
  if ($this->{'silent'}) {
    if ($this->{'message'}) {
      $this->{'message_hidden'} = $this->{'message'};
      delete $this->{'message'};
      }
    }
  elsif ($this->{'message_hidden'}) {
    $this->{'message'} = $this->{'message_hidden'};
    delete $this->{'message_hidden'};
    }
  else {
    my $config = $this->{'config'};
    # TODO: In what follows, we set up a UserMessage with the default (English) message file, so that we have a way to report on errors during LoadConfiguration. There should be a way to speciy an alternate default message file for a given installation.
    my (@filenames) = $config->MakeLibPath('messages.txt');
    my $um = $this->{'message'}{0} = new UserMessage('file' => \@filenames,
      'encoding' => $config->MessageFileEncoding());
    # not permitted by threads::shared
  # $um->SetErrorFilter(\&ErrorFilter);
  # $um->SetExplainFilter(\&ExplainFilter);
  # $um->SetNoteFilter(\&NoteFilter);
  # $um->SetWarningFilter(\&WarningFilter);
    $um->SetErrorFilter('TSH::Tournament::ErrorFilter', $this);
    $um->SetExplainFilter('TSH::Tournament::ExplainFilter');
    $um->SetNoteFilter('TSH::Tournament::NoteFilter');
    $um->SetWarningFilter('TSH::Tournament::WarningFilter', $this);
    }
  # warn "SILENT=@{[$this->{silent}//'undef']};".join(',', keys %{$this->{'message'}}); Carp::cluck 'backtrace';
  return $old_value;
  }

=item $success = $t->TellUser($code, @args);

Tell the user something important.  Return false if we were unable
to do so.

=cut

sub TellUser ($$@) {
  my $this = shift;
  my $code = shift;
  my @args = @_;

  # warn join(',', keys %{$this->{'message'}});
  my $um = $this->{'message'}{ThreadID()} || $this->{'message'}{0};
  return 0 unless $um;
  $um->Show($code, @args);
  }

=item $t->Unlock();

Releases a lock created by Lock().  Will die on serious error.

=cut

sub Unlock ($) {
  my $this = shift;
  my $fh = $this->{'lockfh'};
  (defined $fh)
    or die "Can't unlock configuration: no lock handle exists.\n";
  flock($fh, LOCK_UN)
    or die "Can't unlock tsh.lock - something is seriously wrong.\n";
  close($fh)
    or die "Can't close tsh.lock - something is seriously wrong.\n";
  $this->{'lockfh'} = undef;
  }

=item $t->UnregisterPlayer($p);

Unregister a player, undoing the effect of RegisterPlayer();

=cut

sub UnregisterPlayer ($$) {
  my $this = shift;
  my $p = shift;
  delete $this->{'pbyname'}{uc $p->Name()};
  }

=item (@changed) = $t->UpdateDivisions();

Update divisions that have been marked as dirty.
Returns a list of divisions that were updated (which in a scalar context
will be be the number of divisions that were updated).

This method is usually called only from TSH::Processor::Flush(), 
which checks to see if config hook_division_update needs to be run.
If you are running this method in a context where there exists a 
processor that can run hooks, you should use TSH::Processor::Flush()
instead.

=cut

sub UpdateDivisions ($) {
  my $this = shift;
  die if defined shift;
  my @changed;
  for my $dp ($this->Divisions()) {
    next unless $dp->Dirty();
    push @changed, $dp;
    my $dname = $dp->Name();
#   print "Updating Division $dname.\n";
    $dp->Update();
    }
# if (@changed) { if (my $series = $this->Config()->Series()) { $series->UpdateSession(); } } # causes infinite recursion
  return @changed;
  }

=item $um = $t->UserMessage();
=item $t->UserMessage($um);

Get/set the tournament's user message hash, mapping current
thread ID to UserMessage objects containing user interface
messages..

=cut

sub UserMessage ($;$) { TSH::Utility::GetOrSet('message', @_); }

=item $um = $t->Virtual();
=item $t->Virtual($flag);

Get/set the tournament's virtuality flag.

=cut

sub Virtual ($;$) { TSH::Utility::GetOrSet('virtual', @_); }

=item WarningFilter($code, $type, $message);

Callback subroutine used by UserMessage.pm

=cut

sub WarningFilter ($$$;$) {
  my $code = shift;
  my $type = shift;
  my $message = shift;
  my $tourney = shift;

  my $config = ($tourney && $tourney->Config());

  if (!-t STDOUT) { 
    print STDERR "Warning: $message [$code]\n";
    return;
    }
  my $colour = $config->Value('error_colour') 
    || $config->Value('error_color') || 'red';
  TSH::Utility::PrintColour $colour, 'Warning: ';
  print "$message [$code]\n";
  }

=back

=cut

=head1 BUGS

None known

=cut

1;
