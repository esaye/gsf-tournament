#!/usr/lib/perl

# Copyright (C) 2007-2018 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Config;

use strict;
use warnings;

# $::SIG{__WARN__} = sub { eval 'use Carp'; &confess($_[0]); };
# $::SIG{__DIE__} = sub { eval 'use Carp'; &confess($_[0]); };

use Carp;
use Data::Dumper;
use Encode;
use FileHandle;
use File::Copy;
use File::Path;
use File::Spec;
use File::Temp qw(tempfile);
use TSH::Division;
use TSH::Processor;
use TSH::Utility;
use JavaScript::Serializable;
use Scalar::Util qw(looks_like_number);
use TFile; 
use UserMessage;
use threads::shared;

our (@ISA);
@ISA = qw(JavaScript::Serializable);
sub EXPORT_JAVASCRIPT () { return map { $_ => $_ } qw(assign_firsts check_by_winner currency_symbol division_label division_rating_list division_rating_system entry event_date esb_lite event_name max_rounds no_boards notes player_moods player_photos show_teams tables photo_database prize_bands scoreboard_team_colors scoreboard_team_colours scoreboard_teams spread_bad spread_cap standings_spread_cap suppress_results_in_pairings track_firsts no_scores _termdict rating_system thai_points); }
my $gDefaultRatingSystem = 'nsa';

=pod

=head1 NAME

TSH::Config - Manipulate tsh's configuration settings

=head1 SYNOPSIS

  ## newstyle usage

  my $config = new TSH::Config($tournament, $config_filename) 
    or die "no such file";
  my $config = new TSH::Config($tournament); # use default configuration file
  # in Tournament.pm
  $config->Read(); # reads from designated file
  $config->Setup(); # checks that directories exist, etc.
  # deprecated access methods
  $config->Export(); # exports into 'config' namespace
  $value = $config::key;
  $config::key = $value;
  # preferred access methods
  $old_value = $config->Value($key);
  $config->Value($key, $value);
  $config->Write(); # updates configuration file

  ## noninteractive support
  
  @option_names = $config->UserOptions();
  $help = TSH::Config::UserOptionHelp($option_name);
  $type = TSH::Config::UserOptionType($option_name);
  $time = $config->LastModified(); 
  $js = $config->ToJavaScript();

=head1 ABSTRACT

This class manages tsh's configuration settings.

=cut

=head1 DESCRIPTION

The configuration file started off as a document that was intended
to be hand-edited and then tested by running tsh to see if any Perl
errors were generated.  The original intent was that it have a small
number of line types (originally just comment, division and config),
and that configuration option values be arbitrary Perl expressions
to be passed through eval().  This intent was subverted first by
the increasing complexity required of the file's contents, which
led to an ever-longer list of line types; then by unexpected language
restrictions on data types, which prevented the full range of Perl
expressions from being accepted as values.  (Data shared between
threads is severely restricted in type, and in particular cannot
include closures; and while it is possible to use C<Data::Dumper>
to reconstruct functionally equivalent closure source code 
(as might be needed to automatically save changes to the
configuration), it
can't identify the origin of that code 
(e.g. C<\&TSH::PairingCommand::FlightCapNSC>).)

What we currently have is a configuration file format which permits
the following values: scalars (undefined, numeric and string) and
lists or hashes of permitted values.

=over 4

=cut

sub initialise ($;@);
sub initialise_event ($@);
sub initialise_profile ($@);
sub new ($;$);
sub Append ($@);
sub AssignClasses ($);
sub AssignPasswords ($);
sub AssignTables ($);
sub AttachedContent ($$);
sub CheckDirectory ($$);
sub ChooseFile ($$);
sub ComputedValues ($);
sub CopyFromProfile ($$);
sub DeterminePrizeBandsFromPrizeTable ($);
sub Export ($);
sub GetPlayerByPassword ($$);
sub GetToken ($);
sub GraphicCharacterHBar($);
sub GraphicCharacterLowerRightCorner($);
sub GraphicCharacterUpperRightCorner($);
sub GraphicCharacterVBar($);
sub InstallPhoto ($$);
sub LastModified ($);
sub LoadPhotoIndex ($);
sub LoadPlayerNicknames ($);
sub LoadTwitterIndex ($);
sub LastPrizeRank ($$);
sub MakeBackupPath ($$);
sub MakeHTMLPath ($$);
sub MakeRootPath ($$;$);
sub Normalise ($);
sub PhotoPath ($$);
sub Read ($;$);
sub RealmDefaults ($$);
sub Render ($;$);
sub RenderPerlValue ($$);
sub RootDirectory ($;$);
sub Save ($);
sub SetPassword ($$$);
sub Setup ($);
sub SetupTerminology ($);
sub SetupWindows ($);
sub Terminology ($$@);
sub UninstallPhoto ($$);
sub UserOptions ($);
sub UserOptionEditable ($);
sub UserOptionHelp ($);
sub UserOptionType ($);
sub ValidateLocalDirectory ($$$);
sub Value ($$@);
sub Write ($$;$);

my %user_option_data; # information about individual configuration options

=item $config->initialise(%options)

Initialise the config object.
See C<sub new()> for details about C(%options).

=cut

sub initialise ($;@) {
  my $this = shift;
  my (%options);
  if (ref($_[0])) {
    $options{'tournament'} = shift;
    $options{'filename'} = shift;
    $options{'readonly'} = shift;
    $options{'search'} = shift;
    }
  else {
    %options = @_;
    }
  $options{'type'} ||= 'event';

  # default values (don't include realm-specific)
  $this->{'_config_type'} = $options{'type'};
  if ($options{'type'} eq 'event') {
    $this->initialise_event(%options);
    }
  elsif ($options{'type'} eq 'profile') {
    $this->initialise_profile(%options);
    }
  else {
    confess "Unknown config file type: $options{'type'}";
    }
  return $this;
  }

=item $config->initialise_any(%options);

Shared initialisation for profiles and regular configurations.
Options should go here if you might want either to give
a value specific to an event, or establish a default
for an installation.

=cut

sub initialise_any ($@) {
  my $this = shift;
  my (%options) = @_;

  $this->{'_readonly'} = $options{'readonly'};
  $this->{'_saved'} = &share([]);
  $this->{'_saved_index'} = &share({});
  $this->{'attachments'} = &share({});
  $this->{'attachments_lc'} = &share({});
  $this->{'autopair'} = &share({});
  $this->{'begin'} = &share([]);
  $this->{'division_label'} = &share({});
  $this->{'division_rating_list'} = &share({});
  $this->{'division_rating_system'} = &share({});
  $this->{'external_path'} = &share([]);
  $this->{'external_path'}[0] = q(./bin);
  $this->{'esb_geometry'} = &share({});
  $this->{'gibson_equivalent'} = &share({});
  $this->{'gibson_groups'} = &share({});
  $this->{'hook_division_complete'} = &share({});
  $this->{'index_top_extras'} = &share({});
  $this->{'interleave_rr'} = &share({});
  $this->{'max_div_rounds'} = &share({});
  $this->{'mirror_directories'} = &share([]);
  $this->{'pairing_system'} = 'chew'; # auto bracket chew manual nast none basd guelph green
  $this->{'passwords'} = &share({});
  $this->{'pix'} = &share({}); 
  $this->{'pixmood'} = &share({}); 
  $this->{'player_csv_key_map'} = &share({});
  $this->{'prize_bands'} = &share({});
  $this->{'prizes'} = &share([]);
  $this->{'realm'} = 'nsa';
  $this->{'reserved'} = &share({});
  $this->{'spitfile'} = &share({});
  $this->{'swiss_order'} = &share([]);
  $this->{'tables'} = &share({});
  $this->{'tournament'} = $options{'tournament'};
  }

=item $config->initialise_event(%options);

Initialisation of non-profile configuration values.  Options should
go here for anything that you might want to change on a per-event
basis.  All new options with aggregate values must be listed here,
to mitigate the risk of crashing when TSH automatically creates an
unshared member element within a shared object.

=cut

sub initialise_event ($@) {
  my $this = shift;
  my (%options) = @_;
  $this->initialise_any(%options);
  $this->{'backup_directory'} = File::Spec->catdir(File::Spec->curdir(),'old');
  $this->{'bye_firsts'} = 'alternate';
  $this->{'bye_spread'} = 50;
  $this->{'de_alternate'} = &share({});
  eval { $this->{'director_name'} = (getpwuid($<))[6] };
  $this->{'entry'} = 'scores'; 
  {
    my (@now) = localtime;
    $this->{'event_date'} = sprintf("%04d-%02d-%02d", $now[5]+1900, $now[4]+1, $now[3]);
  }
  $this->{'event_name'} = 'Unnamed Event'; 
  $this->{'filename'} = undef;
  $this->{'flight_cap'} = 'TSH::PairingCommand::FlightCapDefault';
  $this->{'html_directory'} = File::Spec->catdir(File::Spec->curdir(),'html');
  $this->{'max_name_length'} = 22;
  $this->{'name_format'} = '%-22s';
  $this->{'no_boards'} = undef;
  $this->{'random'} = undef; # fixed random value for this run
  $this->{'_rating_system'} = TSH::Utility::ShareSafely({
    'absp' => { 'class' => 'Ratings::ABSP' },
    'aus' => { 'class' => 'Ratings::Elo' },
    'deu' => { 'class' => 'Ratings::Elo' },
    'elo' => { 'class' => 'Ratings::Elo' },
    'ken' => { 'class' => 'Ratings::Elo' },
    'naspa2024' => { 'class' => 'Ratings::Elo' },
    'naspa2024 lct' => { 'class' => 'Ratings::Elo' },
    'naspa-csw' => { 'class' => 'Ratings::Elo' },
    'naspa-csw lct' => { 'class' => 'Ratings::Elo' },
    'none' => { 'class' => 'Ratings::None' },
    'nor' => { 'class' => 'Ratings::Elo' },
    'glixo' => { 'class' => 'Ratings::Glixo' },
    'glixo2' => { 'class' => 'Ratings::Glixo2' },
    'glixo-nor' => { 'class' => 'Ratings::Glixo' },
    'nsa' => { 'class' => 'Ratings::Elo' },
    'nsa lct' => { 'class' => 'Ratings::Elo' },
    'nsa2008 lct' => { 'class' => 'Ratings::Elo' },
    'nsa2008' => { 'class' => 'Ratings::Elo' },
    'pak' => { 'class' => 'Ratings::Elo' },
    'snic' => { 'class' => 'Ratings::Sudoku' },
    'sudoku' => { 'class' => 'Ratings::Sudoku' },
    'take5' => { 'class' => 'Ratings::Sudoku' },
    'thai' => { 'class' => 'Ratings::Elo' },
    'wespa' => { 'class' => 'Ratings::Elo' },
    });
  $this->{'realm'} = 'nsa';
  $this->{'show_last_player_name'} = undef;
  $this->{'split1'} = 1000000;
  $this->{'table_format'} = '%3s';
  $this->{'terminology'} = undef;
  $this->{'twitter'} = &share({}); 
  $this->{'_termdict'} = undef;

  if ($::gPlugInManager) {
    my (%pdsp) = %{$::gPlugInManager->CallAll('ImplementedRatingSystems')};
    while (my ($name, $rssp) = each %pdsp) {
      my (%rss) = @$rssp; # can't combine this with next: each fails
      while (my ($rs_name, $rs_datap) = each %rss) {
#	print "Adding $rs_name: $rs_datap\n";
	$this->{'_rating_system'}{$rs_name} = $rs_datap;
	}
      }
  }

  if ($options{'search'}|| defined $options{'filename'}) {
    return undef unless $this->ChooseFile($options{'filename'});
    }
  elsif (!defined $options{'filename'}) {
    return $this;
    }
  my $time = time; # can't use utime undef, undef without AIX warnings
  utime $time, $time, $this->MakeRootPath($this->{'filename'});
  }

=item $config->initialise_profile(%options);

Initialisation of profile configuration values.  Options should
go here for anything that you might want to establish an installation
default for, or that is not tied to specific events.
All new options with aggregate values must be listed here,
to mitigate the risk of crashing when TSH automatically creates an
unshared member element within a shared object.

=cut

sub initialise_profile ($@) {
  my $this = shift;
  my (%options) = @_;
  $this->initialise_any(%options);
  $this->{'backup_directory'} = $this->MakeLibPath('old');
  $this->{'filename'} = $options{'filename'};
  $this->{'root_directory'} = File::Spec->curdir();
  $this->{'_rating_system'} = TSH::Utility::ShareSafely({
    'nsa2008' => { 'class' => 'Ratings::Elo' }});
  }

=item $d = new TSH::Config($tourney, $filename, $readonly, $search);

=item $d = new TSH::Config(%options);

Create a new TSH::Config object.  
If C<$filename> is undefined, a default value is chosen.
If C<$readonly> is true, the event is considered read-only.
If C<$search> is true and there is no filename, the user is asked to search for one.

In the second calling syntax, the following keys are accepted in the options hash.

C<filename>: C<$filename> above

C<readonly>: C<$readonly> above

C<search>: C<$search> above

C<tourney>: C<$tourney> above

C<type>: "event" (default) or "profile"

=cut

sub new ($;$) { return TSH::Utility::newshared(@_); }

# Do not delete this sub - it is used in rating system management
# Do not use this sub to add configuration lines that a user may
# want to edit later through tsh, at least until it's rewritten
# to update _saved_index.

sub Append ($@) {
  my $this = shift;
  my (@lines) = @_;
  for my $line (@lines) {
    $line =~ s/[^\n]$/$&\n/;
    }
  push(@{$this->{'_saved'}}, @lines);
  }

=item $config->AssignClasses();

Assign players to classes.

=cut

sub AssignClasses ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  # assign players to classes

  for my $dp ($tournament->Divisions()) {
    my $classes = $dp->Classes();
#   warn "$dp->{name} 1";
    next unless $classes;
    next if ref($classes);
#   warn "$dp->{name} 2";
    my (@psp) = $dp->Players();
    TSH::Player::SpliceInactive @psp, 0, 0;
    next unless @psp;
    @psp = TSH::Player::SortByInitialStanding @psp;
    my $phase = 0;
    my $last_rating;
    my $last_class;
    my $current_class = sprintf("%c", ord('A') + $classes - 1);
    for (my $i = $#psp; $i >= 0; $i--) {
      my $pp = $psp[$i];
      my $class = $current_class;
      $phase += $classes;
      my $current_rating = $pp->Rating();
      if ((defined $last_rating) && $last_rating == $current_rating) {
	$class = $last_class;
#	  warn "1 $current_rating $last_rating $current_class $last_class\n";
	}
      else {
	$last_rating = $current_rating;
	$last_class = $current_class;
#	  warn "2 $current_rating $last_rating $current_class $last_class\n";
	}
      $pp->Class($class);
      if ($phase >= @psp) {
	$phase -= @psp;
	$current_class = sprintf("%c", ord($current_class)-1);
	}
      }
    }
  }

=item $config->AssignPasswords();

Assign data entry passwords to any players who do not yet have them.

=cut

sub AssignPasswords ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  my %passwords : shared;
  my $bag = 'AAAAAAAAABBCCDDDDEEEEEEEEEEEEFFGGGHHIIIIIIIIIJKLLLLMMNNNNNNOOOOOOOOPPQRRRRRRSSSSTTTTTTUUUUVVWWXYYZ';
  my @missing;
  # check already assigned passwords
  for my $dp ($tournament->Divisions()) {
    my $dname = $dp->Name();
    for my $p ($dp->Players()) {
      my $password = $p->Password();
      if ((!defined $password) || $password eq '') { # no password yet
	push(@missing, $p);
	next;
        }
      $password = uc $password;
      if (exists $passwords{$password}) { # has someone else's password
	my ($adname, $pid) = @{$passwords{$password}};
	$tournament->TellUser('eduppass', $tournament->GetDivisionByName($adname)->Player($pid)->TaggedName(), $p->TaggedName(), $p->TaggedName());
	next;
        }
      # has unique password already
      my @data : shared;
      @data = ($dname, $p->ID());
      $passwords{$password} = \@data;
      }
    }
  $this->{'passwords'} = \%passwords;

  # assign needed passwords
  for my $p (@missing) {
    my $password;
    for (my $tries = 0; $tries<10; $tries++) {
      my $apassword = join('', sort map { substr($bag, rand(length($bag)), 1) } 1..7);
      unless (exists $passwords{$apassword}) {
	$password = $apassword;
	last;
        }
      }
    if ($password) {
      $this->SetPassword($p, $password);
      }
    }

  $tournament->UpdateDivisions();
  }

=item $config->AssignTables();

Assign boards to tables (after the division data has been loaded, 
in case of consecutive numbering).

=cut

sub AssignTables ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  # allow the configuration file to omit the division if there's only one
  if (ref($this->{'tables'}) eq 'ARRAY') {
    if ($tournament->CountDivisions() == 1) {
      my $dp = ($tournament->Divisions())[0];
      my %hash : shared;
      $hash{$dp->Name()} = $this->{'tables'};
      $this->{'tables'} = \%hash;
      }
    else {
      $tournament->TellUser('ebadcfgtbl');
      $this->{'tables'} = &share({});
      }
    }
  if (defined $this->{'table_method'}) {
    # number tables consecutively across divisions
    if ($this->{'table_method'} eq 'consecutive') {
      my $base = 1;
      for my $dp (sort { $a->Name() cmp $b->Name() } $tournament->Divisions()) {
	my $np = $dp->CountPlayers();
	my $nb = int($np/2);
	my @tables : shared = ($base..$base+$nb);
	$this->{'tables'}{$dp->Name()} = \@tables;
#	warn "$dp->{'name'} $base..$base+$nb";
	$base += $nb;
        }
      }
    elsif ($this->{'table_method'} eq 'none') {
      }
    else {
      $tournament->TellUser('ebtabmet', $this->{'table_method'});
      }
    }
  }

=item $content = $c->AttachedContent($filename);

Returns content that was attached to the configuration file, or
undef if the requested content is not present.

=cut

sub AttachedContent ($$) {
  my $this = shift;
  my $filename = shift;
  if (exists $this->{'attachments'}{$filename}) {
    return $this->{'attachments'}{$filename}{'content'};
    }
  elsif (exists $this->{'attachments_lc'}{lc $filename}) {
    return $this->{'attachments_lc'}{lc $filename}{'content'};
    }
  else {
    return undef;
    }
  }

=item CheckDirectory($path, $message);

Checks to see if $path exists, creates it if necessary and possible,
reports an error message on failure.

=cut

sub CheckDirectory ($$) {
  my ($dir, $what) = @_;
  return if -d $dir;
  eval { mkpath $dir, 0, 0755; };
  return if -d $dir;
  $_[0] = File::Spec->curdir();
  warn "Cannot create $dir, so $what will have to go in the main tsh directory.\n" if $what;
  }

=item (@values) = $config->CheckRequiredValues($key1, $key2, ...);

Checks to see if the listed configuration options have been specified
in this session.  If they all are, return a corresponding list of values.
If at least one is not, report missing values to the user and return undef.

=cut

sub CheckRequiredValues ($@) {
  my $this = shift;

  my $ok = 1;
  my @values;
  for my $key (@_) {
    my $value = $this->Value($key);
    push(@values, $value);
    next if defined $value;
    $ok = 0;
    $this->Tournament()->TellUser("eneed_$key");
    }
  return $ok ? @values : undef;
  }

=item $success = $config->ChooseFile($argv);

Used internally to choose a default configuration file.
$argv should contain whatever the user specified on the command line,
typically undef or the name of an event directory.
Sets $this->{'filename'}.
Returns true on success; dies on failure.

=cut

sub ChooseFile ($$) {
  my $this = shift;
  my $argv = shift;

  local($SIG{__DIE__}) = sub { die $_[0] }; # traceback confuses users.

  $this->{'root_directory'} = File::Spec->curdir();
  # first choice: something specified on the command line
  if (defined $argv) {
    # if it's a directory
    if (-d $argv) {
      for my $try (qw(config.tsh tsh.config)) {
	if (-e "$argv/$try") {
	  $this->{'root_directory'} = $argv;
	  $this->{'filename'} = $try;
	  return 1;
	  }
        }
      die "$argv is a directory but has neither config.tsh nor tsh.config.\n";
      }
    # else it's a configuration file
    elsif (-f $argv) {
      if ($argv =~ /\//) {
        @$this{qw(root_directory filename)} = $argv =~ /^(.*)\/(.*)/;
	return 1;
        }
      else { 
	# using the main tsh directory is a bad idea, but still allowed
	$this->{'root_directory'} = File::Spec->curdir();
	$this->{'filename'} = $argv;
	return 1; 
        }
      }
    else { die "No such event directory: $argv.\n"; }
    }
  # second choice: the directory containing the newest of */config.tsh
  elsif (my (@glob) = glob('*/config.tsh')) {
    # if more than one, choose newest
    if (@glob > 1) {
      my $newest_age = -M $glob[0];
      while (@glob > 1) {
	my $this_age = -M $glob[1];
	if ($this_age < $newest_age) {
	  $newest_age = $this_age;
	  shift @glob;
	  }
	else {
	  splice(@glob, 1, 1);
	  }
        }
      }
    @$this{qw(root_directory filename)} = $glob[0] =~ /^(.*)\/(.*)/;
#   print "Directory: $this->{'root_directory'}\n";
    if ($this->{'root_directory'} =~ /^sample\d$/) {
      print <<"EOF";
You are about to run tsh using its sample event "$this->{'root_directory'}".
This is fine for practice, but might not be want you meant.  If you
want to continue with the sample event, please press the Return key
now.  To choose a different event, enter its name and then press
the Return key.
EOF
      print "[$this->{'root_directory'}] ";
      my $choice = scalar(<STDIN>);
      $choice =~ s/^\s+//;
      $choice =~ s/\s+$//;
      $this->{'root_directory'} = $choice if $choice =~ /\S/;
      unless (-f "$this->{'root_directory'}/$this->{'filename'}") {
	die "Cannot find config.tsh in $this->{'root_directory'}/.\n";
        }
      }
    else {
      print "Using most recent config.tsh in $this->{'root_directory'}.\n";
      }
    return 1;
    }
  # third choice: ./tsh.config
  if (-f 'tsh.config') {
    # don't use colour here, as colour configuration hasn't been found
    print "Warning: use of tsh.config is deprecated.\n";
    print "Please place your event files in a subdirectory, and save your\n";
    print "configuration in that subdirectory under the name config.tsh.\n";
    $this->{'filename'} = 'tsh.config';
    return 1;
    }
  die "Cannot find a configuration file.\n";
  }

sub DecodeConsoleInput ($$) {
  my $this = shift;
  my $line = shift;
  unless (defined &Win32::Console::new) {
    return undef unless defined $line;
    my $save = $line;
    eval { utf8::decode($line); };
    if ($@) { $line = $save; warn $@; }
    $this->LogConsole($line);
    return $line;
    }
  unless ((defined $line) && length($line) && -t STDOUT) {
    $this->LogConsole($line);
    return $line;
    }
  unless ($this->Value('use_windows_code_page') || ($this->Value('console_encoding')||'') =~ /^cp\d+$/) {
    $this->LogConsole($line);
    return $line;
    }
  my $cp = TSH::Utility::GetWindowsCP();
  my $s = Encode::decode("cp$cp", $line, 1);
  if (!defined $s) {
    warn "decode to cp$cp failed";
    $s = $line;
    }
  $this->LogConsole($s);
  return $s;
  }

sub HasSpreadCaps ($) {
  my $this = shift;
  return $this->{'standings_spread_cap'} || $this->{'spread_cap'};
  }

=item $c->JavaScriptTypeCacheInvalidate();

Called when all of the JavaScript types associated with this configuration
option need to be recalculated; e.g., when the division list or player 
roster is changed.

=cut

sub JavaScriptTypeCacheInvalidate ($) {
  my $this = shift;
  $this->{'_jstype_cache'}++;
  }

sub JavaScriptTypeCacheIsValid ($$) {
  my $this = shift;
  my $key = shift;
  return ($user_option_data{$key}{'jscached'}||0) > ($this->{'_jstype_cache'}||0);
  }

sub JavaScriptTypeCacheValidate ($$$) {
  my $this = shift;
  my $key = shift;
  my $value = shift;
  # the next two lines need to be an atomic operation in a multithreaded environment
  $user_option_data{$key}{'jscached'} = ($this->{'_jstype_cache'}||0)+1;
  $user_option_data{$key}{'jstype'} = $value;
  }

sub LogConsole ($$) {
  my $this = shift;
  my $line = shift;
  unless ($::gConfigLog) { # can't be part of $this, as GLOBs can't be shared
    eval 'use IO::Compress::Gzip';
    if (0 and defined &IO::Compress::Gzip::new) {
      my $class = 'IO::Compress::Gzip';
      my $fn = $this->MakeHTMLPath('log.gz');
      $::gConfigLog = &IO::Compress::Gzip::new(
	'IO::Compress::Gzip',
	$fn,
	'Merge' => (-e $fn),
#	'Level' => &IO::Compress::Gzip::Z_BEST_COMPRESSION,
        );
      warn "gzip error: $IO::Compress::Gzip::GzipError" unless $::gConfigLog;
      }
    else {
      open $::gConfigLog, '>>', $this->MakeHTMLPath('log.txt');
      }
    }
  if (0 and $::gConfigLog) {
    eval { 
      print $::gConfigLog "$line\n"
        or die "gzip error: $IO::Compress::Gzip::GzipError";
#     $::gConfigLog->flush(&IO::Compress::Gzip::Z_SYNC_FLUSH)
#       if defined &IO::Compress::Gzip::Z_SYNC_FLUSH;
      };
    warn $@ if $@;
#   close $::gConfigLog; $::gConfigLog = undef;
    }
  }

sub DESTROY () {
  if ($::gConfigLog) { 
    $::gConfigLog->flush(&IO::Compress::Gzip::Z_FINISH)
      if defined &IO::Compress::Gzip::Z_FINISH;
    eval { close $::gConfigLog };
    $::gConfigLog = undef; 
    }
  }

=item $config->DivisionsLoaded();

Informs the configuration object that division data has been loaded,
so that it can perform any late initialisation.

=cut

sub DivisionsLoaded($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  my $config_type = $this->{'_config_type'};
  if ($config_type eq 'event') {
    $this->AssignTables();
    $this->AssignClasses();
    if ($this->{'port'}) {
      $this->AssignPasswords();
      }
    }
  if ($this->{'player_nicknames'}) {
    $this->LoadPlayerNicknames();
    }

  # gvc nassc2016
  if (my $sbpath = $this->Value('school_bios')) {
    eval 'use NSA::SchoolBios qw(LoadBios)';
    unless ($@) {
      my $psp = NSA::SchoolBios::LoadBios($this->MakeRootPath($sbpath));
      for my $p1 (@$psp) {
	my $player = $tournament->FindPlayer($p1->{'school'});
	if ( !defined $player ) {
	  die "No player found for sbios entry $player";
	  }
	$player->GetOrSetEtcScalar('coach', $p1->{'coach'} );
	}
      }
    }

  $this->RunBegin();
  }

=item $config->ComputedValues();

Computes configuration parameter values that depend on other values.

=cut

sub ComputedValues ($) {
# warn "ComputedValues";
  my $this = shift;
  my $tournament = $this->{'tournament'};
  my $pairing_system = $this->{'pairing_system'} || '';
  if ($pairing_system eq 'guelph') {
    $this->{'max_rounds'} = 6 unless defined $this->{'max_rounds'};
    $this->{'avoid_sr_runs'} = 1 unless defined $this->{'avoid_sr_runs'};
    }
  elsif ($pairing_system eq 'bracket') {
    $this->{'bracket_order'} = 'id' unless defined $this->{'bracket_order'};
    }
  elsif ($pairing_system eq 'green') {
    $this->{'max_rounds'} = 6 unless defined $this->{'max_rounds'};
    }
  elsif ($pairing_system eq 'auto') {
    if ($this->{'force_koth'}) {
      $tournament->TellUser('eautokoth');
      }
    }
  elsif ($pairing_system eq 'none') {
    if ($this->{'entry'} eq 'both') {
      $tournament->TellUser('enopairboth');
      $this->{'entry'} = 'scores';
      }
    }
  if ($this->{'seats'} && $this->{'entry'} ne 'board') {
    $tournament->TellUser('wboardentry');
#   $this->{'entry'} = 'board';
    }
  unless ($this->{'max_rounds'}) {
    # set to maximum of max_div_rounds values
    my $maxr1 = 0;
    for my $value (values %{$this->{'max_div_rounds'}}) {
      $maxr1 = $value if $maxr1 < $value;
      }
    $this->{'max_rounds'} = $maxr1 if $maxr1;
    }
  unless ($this->{'player_number_format'}) {
    $this->{'player_number_format'} = 
      $tournament->CountDivisions() == 1 ? '#%s' : '%s';
    }
  {
    my $esb_geometry = $this->{'esb_geometry'};
    for my $div (keys %$esb_geometry) {
      $esb_geometry->{$div} = TSH::Utility::ShareSafely([[]])
        unless ref($esb_geometry->{$div}) eq 'ARRAY';
      $esb_geometry->{$div} = TSH::Utility::ShareSafely([$esb_geometry->{$div}])
        unless ref($esb_geometry->{$div}[0]) eq 'ARRAY';
      for my $geom (@{$esb_geometry->{$div}}) {
	if (@$geom == 1 || @$geom > 3) { 
	  $tournament->TellUser('eesbgeom', $div, scalar(@$geom));
	  $esb_geometry->{$div} = TSH::Utility::ShareSafely([[]]);
	  }
	}
      }
  }
  for my $div (keys %{$this->{'gibson_groups'}}) {
    my $divp = $this->{'gibson_groups'}{$div};
    $this->{'gibson_equivalent'}{$div} = &share([])
      unless exists $this->{'gibson_equivalent'}{$div};
    for my $gibson_group (@$divp) {
      my $first = $gibson_group->[0];
      for my $i (1..$#$gibson_group) {
	$this->{'gibson_equivalent'}{$div}[$gibson_group->[$i]] = $first;
#	print "$gibson_group->[$i] equiv $first in $div.\n";
	}
      }
    }
  if ($this->{'assign_firsts'}) { # can't have one without the other
    $this->{'track_firsts'} = 1;
    }
  if ($this->{'manual_pairings'}) {
    $this->{'pairing_system'} = 'manual';
    $tournament->TellUser('wmanpair');
    }
  if (defined $this->{'entry'}) {
    if ($this->{'entry'} =~ /^absp$/i) { 
      $this->{'entry'} = 'spread';
      $tournament->TellUser('wentryabsp');
      }
    elsif ($this->{'entry'} =~ /^nsa$/i) { 
      $this->{'entry'} = 'scores';
      $tournament->TellUser('wentrynsa');
      }
    elsif ($this->{'entry'} =~ /^snic$/i) { 
      $this->{'entry'} = 'sudoku';
      }
    elsif ($this->{'entry'} =~ /^(?:both|scores|spread|board|sudoku|tagged)$/i) {
      $this->{'entry'} = lc $this->{'entry'};
      }
    else {
      $tournament->TellUser('ebadconfigentry', $this->{'entry'});
      $this->{'entry'} = 'scores';
      }
    if ($this->{'entry'} eq 'spread') {
      if (defined $this->{'assign_firsts'}) {
	if (!$this->{'assign_firsts'}) {
	  $tournament->TellUser('wsetassignfirsts');
	  }
	}
      $this->{'assign_firsts'} = 1;
      if (defined $this->{'track_firsts'}) {
	if (!$this->{'track_firsts'}) {
	  $tournament->TellUser('wsettrackfirsts');
	  }
	}
      $this->{'track_firsts'} = 1;
      }
    }
  else {
    $this->{'entry'} = 'scores';
    }
  $this->SetupTerminology();
  if ($this->{'player_photos'}) {
    if ($this->{'html_in_event_directory'}) {
      $tournament->TellUser('warnhied');
      }
    $this->LoadPhotoIndex();
    }
  if ($this->{'twitter_handles'}) {
    $this->LoadTwitterIndex();
    }
  # Don't set this earlier in case someone wants to use srand
  $this->{'random'} = rand() unless defined $this->{'random'};
  # tell divisions how many rounds they have before they are loaded
  for my $dp ($tournament->Divisions()) {
    $dp->RatingList($this->{'division_rating_list'}{$dp->Name()}||$this->{'rating_list'});
    $dp->RatingSystem($this->CreateRatingSystem($this->{'division_rating_system'}{$dp->Name()}||$this->{'rating_system'}));
    my $maxr = $this->{'max_div_rounds'}{$dp->Name()} 
      || $this->{'max_rounds'};
    next unless defined $maxr;
    $dp->MaxRound0($maxr-1);
    }
  }

sub CopyFromProfile ($$) {
  my $this = shift;
  my $profile = shift;
  for my $key (keys %$profile) {
    if (my $key_datap = $user_option_data{$key}) {
      next if $key_datap->{'private'};
      }
    elsif (ref($profile->{$key})) {
      die "Reference values are not yet supported as profile configuration values (key=$key)";
      }
    $this->{$key} = $profile->{$key};
    }
  }

sub CreateRatingSystem ($$;$) {
  my $this = shift;
  my $name = shift;
  my $optionsp = shift || {};
  my $infop = $this->{'_rating_system'}{$name} || do {
    $this->{'tournament'}->TellUser('ebadconfigrating', 'CreateRatingSystem', $name);
    return undef;
    };
  my $class = $infop->{'class'}
    or die "No Perl class is defined for rating system '$name': please contact John Chew";
  if (($this->Value('event_date') ||'') =~ /^\d\d\d\d-\d\d-\d\d$/) {
    $optionsp->{'event_date'} ||= $this->Value('event_date');
    }
  return do {
    &::Use($class);
    no strict 'refs'; 
    $class->new('rating_system' => $name, %{$optionsp});
    };
  }

sub DeterminePrizeBandsFromPrizeTable ($) {
  my $this = shift;
  my %max_rank_prize;
  my $tourney = $this->{'tournament'};

  # Iterate over prizes to find number of rank prizes in each division
  foreach my $prize (@{$this->Value('prizes')}) {
    if ( $prize->{'type'} eq 'rank' ) {
      if ( ! defined $max_rank_prize{uc $prize->{'division'}} || $prize->{'subtype'} > $max_rank_prize{uc $prize->{'division'}} )  {
	  $max_rank_prize{uc $prize->{'division'}} =  $prize->{'subtype'};
        }
      }
    }
  foreach my $div (sort keys %max_rank_prize) {
    if ( $this->Value('prize_bands')->{$div} ) {
      $tourney->TellUser('wpbconflict', $div);
      }
    my @bands : shared;
    @bands = (1..$max_rank_prize{$div});
    $this->Value('prize_bands')->{$div} = \@bands;
    }
  }

sub Exagony($) {
  my $this = shift;
  my $r0 = shift;
  return 1 if $r0 == 0 && $this->{'initial_exagony'};
  return 0 unless $this->{'exagony'};
  return 1 unless ref($this->{'exagony'});
  unless (defined $this->{'exagony_hash'}) {
    my %data : shared;
    for my $ar1 (@{$this->{'exagony'}}) {
      $data{$ar1-1}++;
      }
    $this->{'exagony_hash'} = \%data;
    }
  return $this->{'exagony_hash'}{$r0};
  }

=item $config->Export();

Exports $config->{'key'} to $config::key, @config::key or %config::key
depending on the type of its value.
Severely deprecated.

=cut

sub Export ($) {
  my $this = shift;
  while (my ($key, $value) = each %$this) {
    my $ref = ref($value);
    if ($ref eq '') 
      { eval "\$config::$key=\$value"; }
    elsif ($ref eq 'ARRAY')
      { eval "\@config::$key=\@\$value"; }
    elsif ($ref eq 'HASH')
      { eval "\%config::$key=\%\$value"; }
    elsif ($ref eq 'CODE')
      { eval "\$config::$key=\$value"; }
    }
  }

=item ($first_r0, $last_r0) = $config->FindSession($r0);

Return the first and last zero-based rounds in the session
that includes zero-based round C<$r0>, or undef if it cannot
be determined.

=cut

sub FindSession ($$) {
  my $this = shift;
  my $round0 = shift;

  my $first_r0 = 0;
  my $last_r0;

  my $max_rounds = $this->Value('max_rounds');
  my $session_breaks = $this->Value('session_breaks');
  my (@breaks1) = @$session_breaks;
  push(@breaks1, $max_rounds) if $max_rounds;
  for my $break1 (@breaks1) {
    if ($break1-1 < $round0) {
      $first_r0 = $break1;
      next;
      }
    $last_r0 = $break1-1;
    last;
    }
  if (defined $last_r0) { return ($first_r0, $last_r0); }
  return undef;
  }

=item $cap = $config->FlightCap($rounds_left);

Return limit on number of players in a pairings flight
when there are the designated number of rounds left.

=cut

sub FlightCap ($$) {
  my $this = shift;
  my $rounds_left = shift;
  my $caps = $this->Value('flight_cap');
  my $koth = $this->Value('force_koth');
  if ($koth && $rounds_left <= $koth) { return 2; }
  my $cap;
  if (!defined $caps) {
    warn "Soft assertion failed: no flight_cap";
    return 0;
    }
  elsif (ref($caps) eq 'ARRAY') {
    $cap = $rounds_left > @$caps
      ? $caps->[0]
      : $caps->[-$rounds_left];
    }
  else {
    no strict 'refs';
    $cap = &$caps($rounds_left);
    }
  $cap++ if $cap % 2;
  return $cap;
  }

=item $p = $config->GetPlayerByPassword($password);

If there is a player whose data entry password is (ignoring case)
equal to C<$password>, return the player; else return undefined.

=cut

sub GetPlayerByPassword ($$) {
  my $this = shift;
  my $password = shift;
  my $data = $this->{'passwords'}{uc $password} || return undef;
  return $this->{'tournament'}->GetDivisionByName($data->[0])->Player($data->[1]);
  }

=item $token = GetToken($string);

Delete a token from the beginning of the string and return it. 
Leading whitespace is skipped. 
Tokens not containing whitespace do not need to be delimited.
Tokens with whitespace should be delimited with single or double
quotes.  Backslashes and delimiters can be escaped with backslashes.
Return undef if nothing was found, or if a delimiter wasn't matched.

=cut

sub GetToken ($) {
  $_[0] =~ s/^\s+//;
  return undef unless $_[0] =~ /\S/;
  if ($_[0] =~ s/^(['"])//) {
    my $delimiter = $1;
    my $token = '';
    while (1) {
      if (s/^[^\\$delimiter]+//) {
	$token .= $&;
        }
      if (s/^\\([\\$delimiter])//) {
	$token .= $1;
        }
      elsif (s/^\\//) {
	$token .= $&;
        }
      elsif (s/^$delimiter\s*//) {
	return $token;
        }
      else {
	# unmatched delimiter
	return undef;
        }
      }
    }
  else {
    s/^(\S+)\s*// or die "assertion failed";
    return $1;
    }
  }

=item GraphicCharacterHBar($);

Returns a graphic character appropriate to the current environment.

=cut

sub GraphicCharacterHBar($) {
  defined &Win32::Console::new && return "\304";
  return "\e(0\x71\e(B";
}

=item GraphicCharacterHBar($);

Returns a graphic character appropriate to the current environment.

=cut

sub GraphicCharacterLowerRightCorner($) {
  defined &Win32::Console::new && return "\331";
  return "\e(0\x6a\e(B";
}

=item GraphicCharacterUpperRightCorner($);

Returns a graphic character appropriate to the current environment.

=cut

sub GraphicCharacterUpperRightCorner($) {
  defined &Win32::Console::new && return "\277";
  return "\e(0\x6b\e(B";
}

=item GraphicCharacterVBar($);

Returns a graphic character appropriate to the current environment.

=cut

sub GraphicCharacterVBar($) {
  defined &Win32::Console::new && return "\263";
  return "\e(0\x78\e(B";
}

=item $config->InstallPhoto($pp);

If a player has a photo (or mood photos) available, copy it (them) to the appropriate location(s) in the web directory
and store that location (those locations) in the player object.

=cut

sub InstallPhoto ($$) {
  my $this = shift;
  my $pp = shift;
  my $name = uc $pp->Name();
  $name =~ s!:/\d+$!!;

  my $savepath = $this->InstallPhoto1($name, $this->{'pix'}{$name});
  $pp->PhotoURL($savepath) if defined $savepath;

  if (my $pathsp = $this->{'pixmood'}{$name}) {
    for my $mood (0..$#$pathsp) {
      my $savepath = $this->InstallPhoto1($name, $pathsp->[$mood]);
      $pp->PhotoMoodURL($mood, $savepath) if defined $savepath;
      }
    }
  }

=item $savepath = $config->InstallPhoto1($pname, $path);

Used internally to install one player photo file if necessary.

Returns a path that should be stored as the player's photo URL path;
could have been redirected to the unknown player image.

=cut

sub InstallPhoto1 ($$) {
  my $this = shift;
  my $pname = shift;
  my $path = shift;
  my $sourcefn;
  my $destfn;

  if (defined $path) {
    $sourcefn = $this->MakeLibPixPath($path);
    $destfn = $this->MakeHTMLPath("pix/$path");
    }
  else {
    $path = 'u/unknown_player.gif';
    $sourcefn = $this->MakeLibPath('pix/u/unknown_player.gif');
    $destfn = $this->MakeHTMLPath("pix/$path");
    }

  my (@sstat) = stat $sourcefn;
  if (!@sstat) { # source file is missing
    $this->{'tournament'}->TellUser('enopic', $sourcefn, $pname);
    return "pix/u/unknown_player.gif";
    }

  # don't actually install files if TSH is running in readonly mode
  return $destfn if $this->{'_readonly'};

  my (@dstat) = stat $destfn;
  # see if we need to copy the file
  if ((!@dstat)  # no destination file
    || $sstat[7] != $dstat[7] # different file size
    || $sstat[9] > $dstat[9] # stale mod time
    ) {
    # create the directory if necessary
    my ($destvol, $destdir, $destfile) = File::Spec->splitpath($destfn);
    my $destpath = File::Spec->catpath($destvol, $destdir, '');
    unless (-d $destpath) {
#     warn "Creating $destpath for $destfn\n";
      eval { mkpath $destpath, 0, 0755; };
      }
    # copy the file
    unless (copy($sourcefn, $destfn) ) {
      $this->{'tournament'}->TellUser('ecopypic', $sourcefn, $!);
      return "pix/u/unknown_player.gif";
      }
    }

  return "pix/$path";
  }

=item $config->InstallTwitter($pp);

If a player has a twitter handle available but not
yet assigned, assign it to the player.

=cut

sub InstallTwitter ($$) {
  my $this = shift;
  my $pp = shift;
  return if $pp->{'etc'}{'twitter'};
  my $handle = $this->{'twitter'}{uc $pp->Name()};
  $pp->GetOrSetEtcScalar('twitter', $handle) if defined $handle;
  }

=item $config->LastModified();

Returns the time (in seconds since the Unix epoch) when the most
recent associated file (config.tsh or *.t) was modified.

=cut

sub LastModified ($) {
  my $this = shift;
  my $modtime;
  my (@stat) = stat $this->MakeRootPath($this->{'filename'});
  $modtime = $stat[9] if defined $stat[9];
  my (@files);
  if (defined $this->{'tournament'}) {
    @files = map { $this->MakeRootPath($_->File()) } 
      $this->{'tournament'}->Divisions();
    }
  else {
    my $divsp = $this->Load(undef, 1);
    @files = map { $this->MakeRootPath($_) } values %$divsp;
    }
  for my $fn (@files) {
    (@stat) = stat $fn;
    $modtime = $stat[9] if (defined $stat[9]) && $stat[9] > $modtime;
    }
  return $modtime;
  }


=item $rank1 = $c->LastPrizeRank($divname);

Return the one-based rank of the last place to which prizes are paid out
in division C<$divname>.

=cut

sub LastPrizeRank ($$) {
  my $this = shift;
  my $divname = shift;
  my $tourney = $this->{'tournament'};
  my $dp = $tourney->GetDivisionByName($divname);
  my $last_prize_rank = $dp->GetConfigValue('prize_bands');
  # wrap in eval in case prize_bands isn't a list ref
  eval { 
    $last_prize_rank = $last_prize_rank->[-1] if defined $last_prize_rank; 
    };
  if ($@ or !defined $last_prize_rank) {
    $tourney->TellUser('wwant_prize_bands');
    $last_prize_rank 
      = int($dp->CountPlayers()/4) || 1;
    }
  return $last_prize_rank;
  }

=item $c->LoadPhotoIndex();

Load the photo index (or complain about it being missing)

=cut

sub LoadPhotoIndex ($) {
  my $this = shift;
  my $fn = $this->MakeLibPixPath('photos.txt');
  my $fh = new FileHandle($fn, "<");
  my $tourney = $this->{'tournament'};
  unless ($fh) {
    $tourney->TellUser('enopixind', $fn, $!);
    return;
    }
  {
    my $encoding = $this->Value('tfile_encoding') || 'isolatin1';
    binmode $fh, ":encoding($encoding)";
  }
  my $was_run_after_players_loaded;
  while (<$fh>) {
    s/[\012\015]+$//;
    next unless /\S/;
    my $mood;
    if (s/\/(\d+)$//) { $mood = $1; }
    my ($given, $surname, $path) = split(/\t/);
    unless (defined $path) {
      $tourney->TellUser('ebadpixind', $.);
      return;
      }
    my $name = uc(length($surname) ? length($given) ? "$surname, $given" : $surname : $given);
    if (defined $mood) {
      $this->{'pixmood'}{$name} ||= &share([]);
      $this->{'pixmood'}{$name}[$mood] = $path;
      }
    else {
      $this->{'pix'}{$name} = $path;
      }
    if (my $p = $tourney->GetPlayerByName($name)) {
      if (defined $mood) {
	$p->PhotoMoodURL($mood, $path);
	}
      else {
	$p->PhotoURL($path);
	}
      $was_run_after_players_loaded = 1;
      }
#   warn "$name;$path";
    }
  if ($was_run_after_players_loaded) {
    for my $dp ($tourney->Divisions()) {
      for my $p ($dp->Players()) {
	next unless $p;
	next if $p->PhotoURL();
	$p->PhotoURL('u/unknown_player.gif');
	}
      }
    }
  close($fh);
  }

=item $c->LoadPlayerNicknames();

Load the twitter handle index (or complain about it being missing)

=cut

sub LoadPlayerNicknames ($) {
#TODO:  Don't act on ambiguous nicknames
  my $this = shift;
  my $fn = $this->MakeLibPath($this->Value('player_nicknames'));
  my $fh = new FileHandle($fn, "<");
  my $tourney = $this->{'tournament'};
  my @ambiguously_nicknamed_players;
  my %assigned_nicknames;
  my %nicknamed_players;
  unless ($fh) {
    $tourney->TellUser('enoplyrnicks', $fn, $!);
    return;
    }
  binmode $fh, ':encoding(UTF8)';
  while (<$fh>) {
    s/\s+$//g;
    next unless /\S/;
    my ($player, $nickname) = split(/[\t\|]/);
    # gvc was traumatized by invisible delimiters back in the days of
    # manual sendmail configs, so allows tabs or bars
    $player =~ s/\s+$//;
    $nickname =~ s/^\s+//;
    unless (defined $nickname) {
      $tourney->TellUser('ebadplyrnick', $player);
      return;
      }
    $nicknamed_players{$player} = $nickname;
    }
  close($fh);
  for my $dp ($tourney->Divisions()) {
    foreach my $player ($dp->Players) {
      if ( my $nickname = $nicknamed_players{$player->Name()} ) {
	# There is a nickname defined for this player
	my $sbname = join " ", @{$player->ScoreBoardNames()} if ( defined$player->ScoreBoardNames() ) ;
	if ( $sbname && $sbname ne $nickname ) {
	  # sbname in .t file overrides nicknames from lib;  won't use this one
	  $tourney->TellUser('wignplyrnick', $player->Name(), $sbname );
          }
        else {
	  if ( $assigned_nicknames{$dp->Name()}{$nickname} ) {
	    # This nickname is already in use for someone else in the div
   	    $tourney->TellUser('wambplyrnick', 
		  	       ${assigned_nicknames{$dp->Name()}{$nickname}}->Name(), 
			       $player->Name(), 
			       $nickname);
	    push @ambiguously_nicknamed_players, ${assigned_nicknames{$dp->Name()}{$nickname}};
            }
          else {
            $player->ScoreBoardNames( [$nickname] );
            $assigned_nicknames{$dp->Name()}{$nickname} = $player;
	    }
	  }
        }
      }
    }
    for my $ambig ( @ambiguously_nicknamed_players ) {
      undef $ambig->{'etc'}{'sbname'};
      }
  }

=item $c->LoadTwitterIndex();

Load the twitter handle index (or complain about it being missing)

=cut

sub LoadTwitterIndex ($) {
  my $this = shift;
  my $fn = $this->MakeLibPath('twitter/'.$this->Value('twitter_handles'));
  my $fh = new FileHandle($fn, "<");
  my $tourney = $this->{'tournament'};
  unless ($fh) {
    $tourney->TellUser('enotwitind', $fn, $!);
    return;
    }
  binmode $fh, ':encoding(isolatin1)';
  while (<$fh>) {
    s/[\012\015]*$//;
    next unless /\S/;
    my $mood = 0;
    if (s/\/(\d+)$//) { $mood = $1; }
    my ($name, $handle) = split(/\t/);
    unless (defined $handle) {
      $tourney->TellUser('ebadtwitind', $.);
      return;
      }
    $this->{'twitter'}{uc $name} = $handle;
    }
  close($fh);
  }

=item $path = $c->MakeBackupPath($relpath);

Return a path to a file in the configured backup directory.

=cut

sub MakeBackupPath ($$) {
  my $this = shift;
  my $relpath = shift;
  return File::Spec->file_name_is_absolute($this->{'backup_directory'})
    ? File::Spec->join($this->{'backup_directory'}, $relpath)
    : File::Spec->join($this->{'root_directory'},
      $this->{'backup_directory'}, $relpath);
  }

=item $path = $c->MakeHTMLPath($relpath);

Return a path to a file in the configured HTML directory.

=cut

sub MakeHTMLPath ($$) {
  my $this = shift;
  my $relpath = shift;
  my (@path_components) = $this->{'html_directory'};
  push(@path_components, $relpath) if defined $relpath;
  return File::Spec->file_name_is_absolute($this->{'html_directory'})
    ? File::Spec->join(@path_components)
    : $this->MakeRootPath(File::Spec->join(@path_components));
  }

=item $path = $c->MakeLibPath($relpath[, $plugin]);

Return a path to a file in the lib directory.

=cut

sub MakeLibPath ($$;$) {
  my $this = shift;
  my $relpath = shift;
  my $plugin = shift;
  # first we find where lib is
  if (!$this->{'lib_directory'}) {
    my $lib_perl_tfile_path = $main::INC{'TFile.pm'};
    my ($libvol, $libdir, $file) = File::Spec->splitpath($lib_perl_tfile_path);
    my (@libdir) = File::Spec->splitdir($libdir);
# warn "1libdir: ".join(',',@libdir)."\n";
    pop @libdir if $libdir[-1] eq '';
    pop @libdir; # remove the 'perl';
# warn "2libdir: ".join(',',@libdir)."\n";
    $this->{'lib_directory'} = File::Spec->catpath($libvol, File::Spec->catdir(@libdir), '');
    }
  my $lib_dir = $this->{'lib_directory'};
  if ($plugin) {
    my ($libvol, $libdir, $file) = File::Spec->splitpath($lib_dir);
    my (@libdir) = File::Spec->splitdir($libdir);
    if (@libdir) { splice(@libdir, -1, 0, 'plugins', $plugin); }
    else { @libdir = ('plugins', $plugin, 'lib'); }
    $lib_dir = File::Spec->catpath($libvol, File::Spec->catdir(@libdir), '');
    }
  return File::Spec->join($lib_dir, $relpath);
  }

=item $path = $c->MakeLibPixPath($relpath);

Return a path to a file in the lib/pix directory.

=cut

sub MakeLibPixPath ($$) {
  my $this = shift;
  my $relpath = shift;
  if ($this->{'photo_database'} && $this->{'photo_database'} ne 'nsa') {
    $relpath = File::Spec->join($this->{'photo_database'}, $relpath);
    }
  $relpath = File::Spec->join('pix', $relpath);
  return $this->MakeLibPath($relpath);
  }

=item $path = $c->MakeRootPath($relpath);

Return a path to a file in the root directory for the event, where
its config.tsh file is.
Arguably not the best-named function ever.

=cut

sub MakeRootPath ($$;$) {
  my $this = shift;
  my $relpath = shift;
  my $separator = shift;
  return File::Spec->file_name_is_absolute($relpath)
    ? $relpath
    : (defined $separator) 
      ? "$this->{'root_directory'}$separator$relpath"
      : File::Spec->join($this->{'root_directory'}, $relpath)
  }

=item $path = $c->MakeSessionSiblingPath($sibling_id[, $relpath]);

Return a path to a file in the directory of a sibling of the event,
or to the directory itself if the second argument is omitted.

=cut

sub MakeSessionSiblingPath ($$;$) {
  my $this = shift;
  my $sibling_id = shift;
  my $relpath = shift;
  return File::Spec->join(
    $this->{'root_directory'},
    File::Spec->updir(),
    $sibling_id,
    $relpath
    );
  }

sub MessageFileEncoding ($) {
  my $this = shift;
  return $this->{'message_encoding'} || 'isolatin1';
  }

=item $config->Normalise();

Called internally after the configuration is read to normalise 
parameter values.

=cut

sub Normalise ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  for my $key (qw(pairing_system realm)) {
    $this->{$key} = lc $this->{$key};
    }
  unless (($this->{'bracket_order'}||'') =~ /^(?:|id|rating)$/) {
    $tournament->TellUser('ebadconfigbracket_order', $this->{'bracket_order'});
    $this->{'bracket_order'} = 'id';
    warn $this->{'bracket_order'};
    }
  unless ($this->{'realm'} =~ /^(?:absp|caspa|deu|go|ken|naspa|naspa-csw|naspa-csw-lct|naspa-lct|naspa2024(?:-csw)?(?:-lct)?|nga|nor|nsa|pak|pol|sgp|snic|sudoku|take5|thai|wespa)$/) {
    $tournament->TellUser('ebadconfigrealm', $this->{'realm'});
    $this->{'realm'} = 'nsa';
    }
  unless($this->{'pairing_system'} =~ /^(?:auto|basd|bracket|chew|green|guelph|manual|nast|none)$/) {
    $tournament->TellUser('ebadconfigpairing', $this->{'pairing_system'});
    $this->{'pairing_system'} = 'auto';
    }
  for my $key (qw(session_breaks)) {
    my $value = $this->{$key};
    if ((defined $value) && ref($value) ne 'ARRAY') {
      $tournament->TellUser('ebadconfigarray', $key, $value);
      delete $this->{$key};
      }
    }
  if ((ref($this->{'swiss_order'})||'') ne 'ARRAY') {
    $this->{'swiss_order'} = [$this->{'swiss_order'}];
    }
  $this->{'html_suffix'} ||= '.html';
  }

=item $config->Normalise2();

Called internally after the configuration is read to normalise 
parameter values that might or might not have been set by a realm
default.

=cut

sub Normalise2 ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  # post-realm normalisation
  my $rating_system 
    = $this->{'rating_system'} 
    = lc($this->{'rating_system'}||$gDefaultRatingSystem);
  # this dumps core
# $this->{'rating_system'} =~ s/^naspa((?: lct)?)$/nsa2008$1/;
  # TODO: this needs to be done before division rating systems are assigned
  if ($rating_system eq 'naspa') 
    { $rating_system = $this->{'rating_system'} = 'nsa2008'; }
  elsif ($rating_system eq 'naspa lct') 
    { $rating_system = $this->{'rating_system'} = 'nsa2008 lct'; }

  unless ($this->{'_rating_system'}{$rating_system}) {
    $tournament->TellUser('ebadconfigrating', 'Normalise2', $rating_system);
    $rating_system = $gDefaultRatingSystem;
    }
  unless (%{$this->{'player_csv_key_map'}}) {
    # sensible default?
    }
  if ($this->{'locale'}) {
#   warn "Setting locale to $this->{'locale'}";
    eval "use POSIX";
    if ($@) { warn $@; }
    else {
      eval { &POSIX::setlocale(&POSIX::LC_CTYPE, $this->{'locale'}) };
      if ($@) { warn $@; }
      }
    }
  }

sub PersistentKeys ($) {
  my $this = shift;
  return sort keys %{$this->{'_saved_index'}};
  }

=item $path = $c->PhotoPath($name);

Return a relative path for a photo corresponding to a named player.
Most of the time, you'll want to make sure that a photo is actually
installed at that path relative say to your event web directory,
and use C<TSH::Config::InstallPhoto> and C<TSH::Player::PhotoURL>.

=cut

sub PhotoPath ($$) {
  my $this = shift;
  my $name = shift;
  $name =~ s/ /, / unless $name =~ /, /;
# warn "$name: $this->{'pix'}{$name}";
  return $this->{'pix'}{$name} || 'u/unknown_player.gif';
  }

=item $config->Read([$string]);

Read the associated configuration file and set configuration values.

Seldom-used optional argument C<$string> gives content of configuration
data, overriding the initialised C<$filename>.

=cut

sub Read ($;$) {
# warn "Read";
  my $this = shift;
  my $string = shift;
  my $fn = $this->{'filename'};
  my $tournament = $this->{'tournament'};
  my %dirty;
  my $config_type = $this->{'_config_type'};
  if ((!$tournament->Virtual()) || defined $string) {
    my $fh;
    my $closure_next_line;
    my $closure_line_number;
    if (defined $string) {
      my (@lines) = split(/\n/, $string);
      my $i0 = 0;
      $closure_line_number = sub { $i0 + 1 };
      $closure_next_line = sub {
	return undef if $i0 > $#lines;
	return $lines[$i0++] . "\n";
        };
      }
    else {
      my $fqfn = $this->MakeRootPath($fn);
      $fh = new FileHandle($fqfn, "<") || die "Can't open $fn: $!\n";
      local($_);
      $tournament->TellUser($config_type eq 'event' ? 'iloadcfg' : 'iloadprof', $fqfn) if $tournament->can('TellUser');
      $closure_line_number = sub { $. };
      $closure_next_line = sub { scalar(<$fh>); };
      }
    local($_);
    while (defined($_ = &$closure_next_line)) {
      if (1 == &$closure_line_number) {
	if (s/^\xef\xbb\xbf// && defined $fh) {
	  binmode $fh, ':pop' or warn $!;
	  binmode $fh, ':encoding(UTF-8)' or warn $!;
#	  warn "auto-detected UTF8";
	  }
	elsif (s/^\x{feff}//) {
#	  warn "ignoring UTF8 BOM";
	  }
        }

#     my (@x) = unpack('C8', $_); printf STDERR "%02x %02x %02x %02x %02x %02x %02x %02x: %s\n", @x, $_;
#     die if 20 < &$closure_line_number;
      if (/^#begin_file\s+(.+)/) {
	my $options = $1;
	my $end = $_; $end =~ s/begin/end/;
	my %data : shared;
	while (length($options)) {
	  $options =~ s/^(\w+)=// || die "Can't parse: $options";
	  my $key = $1;
	  if ($options =~ s/^'([^']*?)'//
	    || $options =~ s/^"([^"]*?)"//
	    || $options =~ s/^(\S+)//) 
	    { $data{$key} = $1; }
	  else {
	    die "Can't parse: $options";
	    }
	  $options =~ s/^\s+//;
	  }
	die "#begin_file is missing required option 'name'" 
	  unless defined $data{'name'};
	$data{'content'} = '';
	while (defined($_ = &$closure_next_line)) {
	  last if $_ eq $end;
	  $data{'content'} .= $_;
	  }
	$this->{'attachments_lc'}{lc $data{'name'}} =
	$this->{'attachments'}{$data{'name'}} = \%data;
	next;
	}
      push(@{$this->{'_saved'}}, $_)
	unless /^\s*config\s+\w+_password\s+/;;
      s/^\s*(#.*)//; s/^\s*//; s/\s*$//; next unless /\S/;
      if (/^encoding\s+(.*)/i) {
	if (defined $fh) {
	  binmode $fh, ':pop' or warn $!;
	  binmode $fh, ":encoding($1)" or warn $!;
	  }
	next;
        }
      if (/^division\s+(\S+)\s+(.*)/i) {
	if ($config_type ne 'event') {
	  warn "Ignoring division directive in profile";
	  next;
	  }
	my $dname = $1;
	my $dfile = $2;
	my $dp = new TSH::Division;
	$dp->Name($dname);
	$dp->File($dfile);
	$tournament->AddDivision($dp);
	next;
	}
      if (s/^perl\s+//i) { 
	local(*main::gTournament) = \%$tournament; # backward compatibility
	eval $_ unless $tournament->IsInSandbox();
	print "eval: $@\n" if length($@);
	next;
	}
      if (/^config\s+(\w+)\s*((?:(?:\[[^]]+\])|(?:\{[^}]+\}))*)\s*=\s*(.*)/i) { 
	my $key = $1;
	my $subkey = $2;
	my $rhs = $3;
	$rhs =~ s/\s*;\s*$//;
	my $s = "\$this->{'$key'}\U$subkey\E=TSH::Utility::ShareSafely($rhs)";
	eval $s; # TODO: should sandbox this too
	$dirty{$key}++;
  #     print "\n***$s\n";
	if ($@) {
	  $tournament->TellUser('ebadcfg', &$closure_line_number, $fn, $_);
	  if ($@ =~ /^Can't find string terminator/) {
	    warn "... The Perl interpreter reports a missing 'string terminator'.\n... The most likely cause is a missing line-ending single or double quote.\n";
	    }
	  elsif ($s =~ /\\'/) {
	    warn qq{... The Perl interpreter reports "$@".\n... The most likely cause is a Windows backslash that hasn't been entered as required as a double blackslash (\\ should be entered as \\\\).\n};
	    }  
	  else {
	    warn "The error message is not one that is commonly seen.\nPlease feel free to send the following to John Chew for analysis:\n$@\n";
	    }
	  }
	unless ($key =~ /_password/) {
	  $this->{'_saved_index'}{$key} = $#{$this->{'_saved'}};
	  }
	next;
	}
      if (/^begin\s+(\S.*)$/i) {
	push(@{$this->{'begin'}}, $1);
	next;
	}
      # classes divname nclasses: specify number of prize classes in a division
      if (/^classes\s+(\S+)\s+(\S+)\s*$/i) {
	if ($config_type ne 'event') {
	  warn "Ignoring classes directive in profile";
	  next;
	  }
	my $dname = $1;
	my $classes = $2;
	my $dp = $tournament->GetDivisionByName($1);
	unless ($dp) {
	  die $tournament->RenderMessage('eclassdiv', $dname) . "\n";
	  }
	unless ($classes =~ /^\d+$/ && $classes <= 26) {
	  die $tournament->RenderMessage('eclassnum', $classes) . "\n";
	  }
	if ($classes > 1) { $dp->Classes($classes); }
	next;
	}
      if (s/^autopair\s+//i) { 
	if ($config_type ne 'event') {
	  warn "Ignoring autopair directive in profile";
	  next;
	  }
	$this->{'pairing_system'} = 'auto';
	my $dname;
	my $ref = $this->{'autopair'};
	my $save = $_;
	if (!s/^(\w+)\s*//) {
	  die $tournament->RenderMessage('ebadapa', $save, $fn) . "\n";
	  }
	$dname = uc $1;
	if (exists $ref->{$dname}) {
	  $ref = $ref->{$dname};
	  }
	elsif (!$tournament->GetDivisionByName($1)) {
	  die $tournament->RenderMessage('ebadapaa', $save, $fn, $dname)."\n";
	  }
	else {
	  $ref = $this->{'autopair'}{$dname} = &share([]);
	  }
	if (/^(\d+)\s+(\d+)\s+(\w+)\s+(.*)/) {
	  my ($sr, $round, $command, $args) = ($1, $2, $3, $4);
	  if ($sr >= $round) {
	    die $tournament->RenderMessage('eapbr', $dname, $sr, $round) . "\n";
	    }
	  my (@args) = split(/\s+/, $args);
	  $ref = $ref->[$round] = &share([]);
	  push(@$ref, $sr, $command, @args);
	  }
	else {
	  chomp;
	  die $tournament->RenderMessage('ebadap', $save, $fn) . "\n";
	  }
	next;
	}
      if (s/^prize\s+//i) {
	if ($config_type ne 'event') {
	  warn "Ignoring prize directive in profile";
	  next;
	  }
	my %pdata : shared;
	my $save = $_;
	for my $key (qw(type subtype division value)) {
	  unless (defined($pdata{$key} = GetToken($_))) {
	    $tournament->TellUser('ebadprzf', $key, $save);
	    }
	  last if $pdata{'type'} =~ /^(?:separator|break)$/;
	  if ($pdata{'type'} =~ /^(?:note|title)$/) {
	    $pdata{'note'} = $_; 
	    $_ = '';
	    last;
	    }
	  }
	while (s/^\s*(\w+)=//) {
	  my $key = $1;
	  my $value;
          if ( $key eq 'eval' ) {
	       s/(.*)//;
	      $value = $1; 
	    } else {
	      $value = GetToken($_);
	      $value = '' unless defined $value;
	    }
	    $pdata{$key} = $value;
	  }
	if (/\S/) {
	  $tournament->TellUser('ebadprzt', $save, $_);
	  }
	else {
	  push(@{$this->{'prizes'}}, \%pdata);
	  }
	next;
	}
      die $tournament->RenderMessage('ebadcfg', &$closure_line_number, $fn, $_) . "\n";
      }
    close($fh) if defined $fh; 
    }
  if (defined $this->{'ftp_password'}) {
    die "config ftp_password is no longer supported, as it results in malware\nbeing injected into your website. Please remove it from your config.tsh file\nand try again.\nAborting";
    }
# print "Configuration file loaded.\n";
  $this->Normalise();
  $this->RealmDefaults(\%dirty);
  $this->Normalise2();
  if ($config_type eq 'event') {
    $this->ComputedValues();
    }
  }

=item $old_value = $c->ReadOnly();
=item $c->ReadOnly($new);

Get/set the read-only flag.

=cut

sub ReadOnly ($;$) { 
  my $this = shift; 
  my $new = shift; 
  TSH::Utility::GetOrSet('_readonly', $this, $new); 
  }

=item $c->RealmDefaults(\%dirty);

Assign realm-based defaults.

=cut

{
  my (%realm_data) = (
    'absp' => {
      'alpha_pair_page_break' => 10000,
      'assign_firsts' => 1,
      'avoid_sr_runs' => 1,
      'bye_firsts' => 'ignore',
      'bye_spread' => 100,
      'currency_symbol' => '&pound;',
      'entry' => 'both',
#     'gibson_class' => 'A', # causes problems if classes unspecified
      'html_in_event_directory' => 1,
      'no_index_tally_slips' => 1,
      'photo_database' => 'centrestar',
      'rating_list' => 'absp',
      'rating_system' => 'absp',
      'surname_last' => 1,
      'table_method' => 'consecutive',
      'terminology' => 'absp',
      'track_firsts' => 1,
      },
    'deu' => {
      'assign_firsts' => 0,
      'bye_firsts' => 'ignore',
      'currency_symbol' => '&euro;',
      'locale' => 'de_DE',
      'message_file' => 'lib/messages/deu.txt',
      'photo_database' => 'deu',
      'rating_list' => 'deu',
      'rating_system' => 'deu',
      'terminology' => 'deu',
      'use_windows_code_page' => 1,
      },
    'go' => {
      'assign_firsts' => 1,
      'bye_spread' => 2,
      'rating_system' => 'nsa',
      'scores' => 'WL',
      'track_firsts' => 1,
       },
    'ken' => {
      'assign_firsts' => 1,
      'avoid_sr_runs' => 1,
      'board_stability' => 0,
      'bye_spread' => 100,
      'check_by_winner' => 1,
      'currency_symbol' => 'KES',
      'ftp_host' => 'scrabblekenya.poslarchive.com',
      'ftp_path' => 'web',
      'hook_addscore_flush' => 'json',
      'hook_autopair' => 'json;stats',
#     'hook_division_complete' => { 'A' => 'st a;rat a;stats;esb a; sb a;sdsc a;wc a;rwc a;crs $r a', 'B' => 'st b;rat b;stats;esb b; sb b;sdsc b;wc b;rwc b;crs $r b'},
      'html_index_recent_first' => 1,
      'html_index_recent_first' => 1,
      'html_index_recent_first' => 1,
      'max_rounds' => 18,
      'no_text_files' => 1,
      'photo_database' => 'ken',
      'player_photos' => 1,
      'rating_list' => 'ken',
      'rating_system' => 'ken',
      'roster_order' => 'seed',
      'show_inactive' => 1,
      'standings_hotlink' => 1,
      'track_firsts' => 1,
      },
    'naspa' => {
      'rating_list' => 'nsa',
      'rating_system' => 'nsa2008',
      },
    'naspa-lct' => {
      'rating_list' => 'nsa',
      'rating_system' => 'nsa2008 lct',
      },
    'naspa-csw' => {
      'rating_list' => 'naspa-csw',
      'rating_system' => 'naspa-csw',
      },
    'naspa-csw-lct' => {
      'rating_list' => 'naspa-csw',
      'rating_system' => 'naspa-csw lct',
      },
    'naspa2024' => {
      'rating_list' => 'nsa',
      'rating_system' => 'naspa2024',
      },
    'naspa2024-lct' => {
      'rating_list' => 'nsa',
      'rating_system' => 'naspa2024 lct',
      },
    'naspa2024-csw' => {
      'rating_list' => 'naspa-csw',
      'rating_system' => 'naspa2024',
      },
    'naspa2024-csw-lct' => {
      'rating_list' => 'naspa-csw',
      'rating_system' => 'naspa2024 lct',
      },
    'nga' => {
      'photo_database' => 'nga',
      },
    'nor' => {
#     'assign_firsts' => 0,
#     'bye_firsts' => 'ignore',
      'currency_symbol' => '&euro;',
      'locale' => 'nb_NO',
      'message_file' => 'lib/messages/nor.txt',
      'message_encoding' => 'utf8',
      'rating_list' => 'nor',
      'rating_system' => 'nor',
      'terminology' => 'nor',
      'use_windows_code_page' => 1,
      },
    'nsa' => {
      'alpha_pair_page_break' => 10,
#     'rating_system' => 'nsa',
      'rating_list' => 'nsa',
      'rating_system' => 'nsa2008',
      },
    'pak' => {
      'photo_database' => 'pak',
      'bye_firsts' => 'ignore',
      'rating_list' => 'pak',
      'rating_system' => 'pak',
      'terminology' => 'pak',
      },
    'pol' => {
      'all_byes_tie' => 1,
      'assign_firsts' => 1,
      'bye_spread' => 300,
      'locale' => 'pl_PL',
      'message_encoding' => 'utf8',
      'message_file' => 'lib/messages/pol.txt',
      'rating_system' => 'absp',
      'sum_before_spread' => 1,
      'tally_slips_no_spread' => 1,
      'terminology' => 'pol',
      'tfile_encoding' => 'utf8',
      'track_firsts' => 1,
      'rating_list' => 'pol',
      'rating_system' => 'nsa2008',
      },
    'sgp' => {
      'bye_firsts' => 'ignore',
      'rating_list' => 'sgp',
      'rating_system' => 'nsa',
      'surname_last' => 1,
      },
    'snic' => {
      'entry' => 'sudoku',
      'tfile_game' => 'sudoku',
      'pairing_system' => 'none',
      'rating_list' => 'snic',
      'rating_system' => 'snic',
      'scores' => 'sudoku',
      'terminology' => 'snic',
      },
    'sudoku' => {
      'entry' => 'sudoku',
      'tfile_game' => 'sudoku',
      'pairing_system' => 'none',
      'rating_list' => 'sudoku',
      'rating_system' => 'sudoku',
      'scores' => 'sudoku',
      'terminology' => 'sudoku',
      },
    'take5' => {
      'entry' => 'sudoku',
      'tfile_game' => 'sudoku',
      'pairing_system' => 'none',
      'rating_list' => 'take5',
      'rating_system' => 'take5',
      'scores' => 'sudoku',
      'terminology' => 'sudoku',
      'spread_bad' => 1,
      },
    'thai' => {
      'bye_firsts' => 'alternate',
      'bye_spread' => 100,
      'console_encoding' => 'cp874',
      'csv_encoding' => 'windows-874',
      'entry' => 'scores',
      'localise_names' => 1,
      'member_separator' => '-',
      'message_encoding' => 'windows-874',
#     'message_file' => 'lib/messages/thai.txt',
      'rating_list' => 'thai',
      'rating_system' => 'thai',
      'spread_cap' => 350,
      'terminology' => 'thai',
      'tfile_encoding' => 'windows-874',
      },
    'wespa' => {
      'bye_spread' => 100,
      'rating_list' => 'wespa',
      'rating_system' => 'wespa',
      },
    );
sub RealmDefaults ($$) { 
  my $this = shift; 
  my $dirtyp = shift;
  my $defp = $realm_data{$this->{'realm'}} || $realm_data{'nsa'};
  while (my ($key, $value) = each %$defp) {
#   $this->{$key} = $value unless defined $this->{$key};
    $this->{$key} = $value unless $dirtyp->{$key}; # 2010-06-16
    }
  }

sub RealmsKnown ($) {
  my $this = shift;
  return sort keys %realm_data;
  }
}

=item $s = $c->Render('division_filter' => sub {});

Render and return a copy of the current configuration information.
The following options may be specified:

C<division_filter>: if C<&$division_filter($division)> is true for a division, 
include the public information in the division's  C<.t> file.

C<raw>: if true, return concatenated saved lines without tampering

See also Save().

=cut

sub Render ($;$) {
  my $this = shift;
  my (%options);
  if (ref($_[0])) {
    $options{'division_filter'} = shift @_;
    }
  else {
    (%options) = @_;
    }

  if ($options{'raw'}) {
    my $s2 = join('', @{$this->{'_saved'}});
    $s2 =~ s/\n?$/\n/;
    return $s2;
    }

  my $division_filter = $options{'division_filter'};
  my $tournament = $this->{'tournament'};
  my $config_type = $this->{'_config_type'};
  my $version = $::gkVersion ? " version $::gkVersion" : '';
  my $s = '';
  if ($division_filter) {
    $s .= "# tsh archive file\n";
    }
  elsif ($config_type eq 'event') {
    $s .= "# tsh configuration file\n";
    }
  else {
    $s .= "# tsh archive file\n# including profile\n";
    }
  $s .= "# automatically generated by tsh$version.\n";
  my $s2 = join('', grep {
    ! /^\s*division\s+/i # too hard to keep track of changes to list of division
    } @{$this->{'_saved'}});
  $s2 =~ s/\n?$/\n/;
  my $s1 = '';
  if ($division_filter) {
    for my $dp ($tournament->Divisions()) {
      next unless &$division_filter($dp);
      my $dfile = $dp->File();
      $s .= "division " . $dp->Name() . " $dfile\n";
      $s1 .= "#begin_file name=$dfile\n";
      for my $pp ($dp->Players()) {
	$s1 .= TFile::FormatLine($pp, 'public');
	}
      $s1 .= "#end_file name=$dfile\n";
      }
    }
  $s .= $s2 . $s1;
  return $s;
  }

sub RenderPerlValue ($$) {
  my $this = shift;
  my $value = shift;
  return 'undef' unless defined $value;
  if (my $ref = ref($value)) {
    if ($ref eq 'ARRAY') {
      return '[' . join(',', map { $this->RenderPerlValue($_) } @$value) . ']';
      }
    elsif ($ref eq 'HASH') {
      return '{' . join(',', map { $this->RenderPerlValue($_) } %$value) . '}';
      }
    else {
      die "Illegal reference type ($ref) in configuration value";
      }
    }
  else {
    # it would be nice to be able to set the variables in a persistent way,
    # but we can't be sure that code elsewhere doesn't change them.
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Terse = 1;
    my $s = Dumper($value);
    chomp $s;
    return $s;
    }
  }

=item $old_value = $c->RootDirectory();
=item $c->RootDirectory($new);

Get/set the root directory (where the event files live).  Use with extreme caution.

=cut

sub RootDirectory ($;$) { 
  my $this = shift; 
  my $new = shift; 
  TSH::Utility::GetOrSet('root_directory', $this, $new); 
  }

=item $basename = $c->RootDirectoryBasename();

Get the basename (final component) of the directory where the
event files live, typically for use as a session ID.

=cut

sub RootDirectoryBasename ($) { 
  my $this = shift; 
  my $root_directory = $this->Value('root_directory');
  my ($volume, $directories, $file) = File::Spec->splitpath($root_directory);
  my (@dirs) = File::Spec->splitdir($directories);
  push(@dirs, $file);
  pop @dirs while @dirs and $dirs[-1] eq '';
  return $dirs[-1];
  }

# warning: usually runs *before* Config::Export();
sub RunBegin ($) {
  my $this = shift;
  my $begin = $this->{'begin'};
  if (@$begin) {
    my $tournament = $this->{'tournament'};
    return if $tournament->IsInSandbox();
    my $begin_processor = new TSH::Processor($tournament);
    for my $cmd (@$begin) {
      $begin_processor->Process($cmd);
      }
    }
  }

=item $config->Save(%options);

Save the current configuration in its configuration file.
The following options are recognized:

C<mode>: C<edit> (use old algorithm to edit source), C<update> (use newer algorithm to re-render)

See also Render().

=cut

sub Save ($) {
  my $this = shift;
  my (%options) = @_;
  my $mode = $options{'mode'} || 'edit';
  my $s = '';
  my $fn = $this->MakeRootPath($this->{'filename'});
  if ($mode eq 'edit') {
    my $fh = new FileHandle($fn, "<");
    unless ($fh) {
      return "<div class=failure>Could not open '$fn': $!</div>";
      }
    local($/) = undef;
    $s = <$fh>;
    close($fh);
    # update user options
    while (my ($key, $datap) = each %user_option_data) {
      my $value = ${$config::{$key}};
      my $type = $datap->{'type'};
      unless (defined $value) {
	if ($type eq 'boolean') { $value = 0; }
	elsif ($type eq 'integer') { $value = 0; }
	elsif ($type eq 'string') { $value = ''; }
	else { die "oops - unknown type $datap->{'type'} for $key\n"; }
	}
      if ($type eq 'string') { $value = '"' . quotemeta($value) . '"'; }
      $s =~ s/^\s*config\s+$key\s*=.*$/config $key = $value/m
	or $s .= "config $key = $value\n";
      }
    }
  elsif ($mode eq 'update') {
    $s = join('', @{$this->{'_saved'}});
    }
  else { die $mode; }
  my $error = '';
  my $backup_fn = $this->MakeBackupPath(time . '.tsh');
  copy($fn, $backup_fn)
    or ($error = "A backup copy of the configuration could not be saved: $!");
  TSH::Utility::ReplaceFile($fn, $s)
    or ($error = "A new copy of the configuration could not be written: $!");
  return $error 
    ? "<div class=failure>Your changes were not saved. $error</div>"
    : "<div class=success>Your changes were saved.</div>";
  }

=item $series = $config->Series();

Return the TSH::Series object associated with this configuration's
tournament, if any, else undef

=cut

sub Series ($@) {
  my $this = shift;
  return TSH::Utility::GetOrSet('_series', $this, @_); 
  }
 
=item $c->SetPassword($p, $password);

Sets a players password and updates the internal password map.

=cut

sub SetPassword ($$$) {
  my $this = shift;
  my $p = shift;
  my $password = shift;
  my @data : shared;
  my $dp = $p->Division();
  @data = ($dp->Name(), $p->ID());
  $this->{'passwords'}{$password} = \@data;
  $p->Password($password);
  $dp->Dirty(1);
  }

=item $c->Setup();

Perform any initialisation required after the configuration has been
read: create necessary directories.

=cut

sub Setup ($) {
  my $this = shift;
  # do nothing if we are not supposed to change the filesystem
  return if $this->{'_readonly'};
  # Check for backup and HTML directories
  CheckDirectory ($this->MakeRootPath($this->{'backup_directory'}), "backups");
  my $config_type = $this->{'_config_type'};
  return if $config_type eq 'profile';
  CheckDirectory ($this->MakeRootPath($this->{'html_directory'}), "web files");
  my $realm = $this->Value('realm');
  # install CSS stylesheet if missing
  my $destfn = $this->MakeHTMLPath('tsh.css');
  my $sourcefn = $this->MakeLibPath('tsh.css');
#   $realm eq 'nsa' ? 'tsh.css' : "tsh-$realm.css");
  copy($sourcefn, $destfn) unless -f $destfn;
  if ($this->Value('html_in_event_directory')) {
    $destfn = $this->MakeRootPath('tsh.css');
    copy($sourcefn, $destfn) unless -f $destfn;
    }
  if (my $css = $this->Value('custom_stylesheet')) {
    copy($this->MakeLibPath("css/$css"), $this->MakeHTMLPath($css));
    }
  if ($this->Value('phiz_url')) {
    copy($this->MakeLibPath('css/phiz.css'), $this->MakeHTMLPath('phiz.css'));
    copy($this->MakeLibPath('js/phiz.js'), $this->MakeHTMLPath('phiz.js'));
    copy($this->MakeLibPath('js/phizlaunch.js'), $this->MakeHTMLPath('phizlaunch.js'));
    copy($this->MakeLibPath('js/jquery-1.5.2-min.js'), $this->MakeHTMLPath('jquery-1.5.2-min.js'));
    }
  if ( $this->Value('prize_bands_from_prizes') ) {
      $this->DeterminePrizeBandsFromPrizeTable();
    }
  if (my $frameset = $this->Value('frameset')) {
    TSH::Utility::MakeFramesets($this->MakeHTMLPath('frameset'), $frameset);
    }
  $this->SetupSeries();
  $this->SetupWindows();
  }

=item $c->SetupSeries();

Set up tournament series data.

=cut

sub SetupSeries ($) {
  my $this = shift;
  
# warn "SetupSeries: $this->{'series_id'}";
  if ($this->Value('series_id')) {
#   warn "SetupSeries(3)";
    eval "use TSH::Series";
    die $@ if $@;
    my $series = TSH::Series::new('TSH::Series', $this);
#   warn "SetupSeries(2): $series";
    $this->Series($series);
    if ($series->Stale()) {
      # this has to be done after series object is stored in config, 
      # or else LoadRatings doesn't know we're in a series environment
#     warn "Series was stale: loading ratings";
      $this->Tournament()->LoadRatings();
      $series->Stale(0);
      }
#   warn "SetupSeries(1): $this->{'_series'}";
    }
  else {
#   warn "SetupSeries(0)";
    $this->{'_series'} = undef;
    }
  }

=item $c->SetupTerminology();

Set up tournament terminology database.

=cut

sub SetupTerminology ($) {
# warn "SetupTerminology";
  my $this = shift;
  if (defined $this->{'terminology'}) {
    $this->{'terminology'} = lc $this->{'terminology'};
    }
  else {
    $this->{'terminology'} = 'nsa';
    }
  my (@filenames) = ('nsa');
  unshift(@filenames, $this->{'terminology'}) unless $this->{'terminology'} eq 'nsa';
# warn "@filenames";
  @filenames = grep { -f $_ } map { 
    $this->MakeLibPath(
      File::Spec->catfile('terms', "$_.txt"))
    } @filenames;
# warn "@filenames";

  unless ($this->{'_termdict'} = new UserMessage(
    'file' => \@filenames,
    'nodetail' => 1,
    'hidecode' => 1,
    'encoding' => $this->MessageFileEncoding(),
    )) {
    my $tournament = $this->{'tournament'};
    $tournament->TellUser('ebadconfigterms', $this->{'terminology'}, $!);
    }
  }

sub SetupWindows ($) {
  my $this = shift;
  return unless defined &Win32::Console::new;
  if ($this->{'use_windows_code_page'}) {
    my $cp = TSH::Utility::GetWindowsCP();
#   $cp = 850; system 'chcp 850'; # for testing Western Europe settings from elsewhere
    # note that STDIN encoding is ignored by Term::ReadLine
    print "Using default local Windows code page $cp for console encoding.\n";
    binmode STDIN, ":encoding(cp$cp)" or die "binmode STDIN failed: $!";
    binmode STDERR, ":encoding(cp$cp)" or die "binmode STDERR failed: $!";
    binmode STDOUT, ":encoding(cp$cp)" or die "binmode STDOUT failed: $!";
    }
  elsif (($this->{'console_encoding'}||'') =~ /^cp(\d+)$/) {
    my $cp = $1;
    print "Switching to Windows code page $cp.\n";
    binmode STDIN, ":encoding(cp$cp)" or die "binmode STDIN failed: $!";
    binmode STDERR, ":encoding(cp$cp)" or die "binmode STDERR failed: $!";
    binmode STDOUT, ":encoding(cp$cp)" or die "binmode STDOUT failed: $!";
    system "chcp $cp";
    }
  elsif ($this->{'windows_console_unicode'}) {
    TSH::Utility::SetupWindowsUnicodeConsole();
    }
  }

=item my $s = $c->Terminology($code, @argv);

=item my $hash = $c->Terminology({$code1=>\@argv1, $code2=>\@argv2, ...});

Return a term or terms from the currently selected international terminology database.

=cut

sub Terminology ($$@) {
  my $this = shift;
  my $codes = shift;
  my $was_single;
  my %terms;
  if (!ref($codes)) {
    $was_single = $codes;
    $codes = { $codes => \@_ };
    }
  while (my ($code, $argvp) = each %$codes) {
    my $faked_code = $code;
    if ($code =~ /^(?:Sprd|Spread)$/ && $this->Value('oppless_spread')) {
      $faked_code = 'SOS';
      }
    $terms{$code} = $this->{'_termdict'}->Render(
      'code' => $faked_code,
      'argv' => \@$argvp,
      );
    }
  return (defined $was_single) ? $terms{$was_single} : \%terms;
  }

sub Tournament ($) {
  my $this = shift;
  return $this->{'tournament'};
  }
  
sub TFileEncoding ($) {
  my $this = shift;
  return $this->{'tfile_encoding'} || 'isolatin1';
  }

sub TweetDirectMessage ($$$) {
  my $this = shift;
  my $handle = shift;
  my $message = shift;
  my $command = $this->Value('twitter_dm_command');
  $message =~ s/[\012\015]/ /g;
  if ($command eq 'ttytter') {
    print "tweet /dm $handle $message\n";
    open my $pipe, '|ttytter -script' or warn "pipe open failed: $!";
    print $pipe "/dm $handle $message" or warn "pipe write failed: $!";
    close $pipe or warn "pipe close failed: $!";
    }
  else {
    warn "bad value '$command' for twitter_dm_command, message unsent";
    }
  }

sub UninstallPhoto ($$) {
  my $this = shift;
  my $pp = shift;
  # for now, don't actually remove file, which might be needed by someone
  # else, if say it's withheld.gif
  $pp->PhotoURL('');
  }

=item @option_names = $cfg->UserOptions();

Returns a list of user-configurable option names.

If the configuration object is based on a regular configuration file, 
the list will be the full list of known option names.

If the configuration object is based on a profile file, the list
will include only those options recommended for profile files.

=cut

sub UserOptions ($) {
  my $this = shift;
  return $this->{'_config_type'} eq 'event'
    ? keys %user_option_data
    : grep { $user_option_data{$_}{'profile'} } keys %user_option_data;
  }

=item $category = UserOptionCategory($option_name);

Returns the category under which a user option might usefully
be displayed.

=cut

sub UserOptionCategory ($) {
  my $key = shift;
  return $user_option_data{$key}{'category'} || 'miscellaneous';
  }

=item $help = UserOptionEditable($option_name);

Returns true if the specified option may safely be edited by the user.

=cut

sub UserOptionEditable ($) {
  my $key = shift;
  return $user_option_data{$key}{'editable'};
  }

=item $help = UserOptionHelp($option_name);

Returns the help text associated with a user-configurable option name.

=cut

sub UserOptionHelp ($) {
  my $key = shift;
  return $user_option_data{$key}{'help'};
  }

=item $type = $c->UserOptionJSType($option_name);

Returns the type of a user-configurable option name represented in JavaScript
for use with lib/js/tsh-widget.js.

=cut

sub UserOptionJSType ($$) {
  my $this = shift;
  my $key = shift;
  my $p = $user_option_data{$key};
  return $p->{'jstype'} if $this->JavaScriptTypeCacheIsValid($key);
  my $js = JavaScript::Serializable::ToJavaScriptAny($p->{'type'});
  $js =~ s/\['division']/q(['enum',{'values':[) . join(',', map{"'".$_->Name()."'"} $this->{'tournament'}->Divisions()) . q(]}])/ge;
  $js =~ s/'sparselist'\s*,\s*{/'hash',{'key':['integer',{}],/g;

  $this->JavaScriptTypeCacheValidate($key, $js);
  return $js;
  }

=item $relatedp = UserOptionRelated($option_name);

Returns the list of options related to a user-configurable option.

=cut

sub UserOptionRelated ($) {
  my $key = shift;
  return $user_option_data{$key}{'related'};
  }

=item $type = UserOptionType($option_name);

Returns the type of a user-configurable option name.
See below for a detailed description of what a user option type is.

=cut

sub UserOptionType ($) {
  my $key = shift;
  return $user_option_data{$key}{'type'};
  }

=item $error = UserOptionValidate($option_name, $option_value);

Checks to see if $option_value is a valid value for $option_name.
If it isn't, an error message is returned.  If it is, $option_value
may be cleaned slightly before being returned.

=cut

sub UserOptionValidate ($$) {
  my $key = shift;
  my $sub = $user_option_data{$key}{'validate'};
  return '' unless $sub;
  return &$sub($key, $_[0]);
  }

=item $error = $config->ValidateLocalDirectory($option_name, $option_value);

Returns an error message if $option_value is not a valid value for $option_name.
Returns the null string if it is valid.
Cleans up $option_value if necessary.
Checks to see if the value designates a local directory that exists
or can be created.
Paths may be relative to C<$config->{'root_directory'}>.

=cut

sub ValidateLocalDirectory ($$$) {
  my $this = shift;
  my $key = shift;
  my $path = $_[0];
  $path =~ s/^\s+//;
  $path =~ s/\s+$//;
  $path = '/' unless $_[0] =~ /\/$/;
  $path = File::Spec->canonpath($path);
  my $fqpath = $path;
  if (!File::Spec->file_name_is_absolute($path)) {
    $fqpath = File::Spec->join($this->{'root_directory'}, $path);
    }
  if (-e $fqpath) { 
    unless (-d $fqpath) {
      return "$path exists but is not a directory.";
      }
    }
  else {
    mkpath $fqpath, 0, 0755
      or return "$fqpath does not exist and cannot be created.";
    }
  $_[0] = $path;
  return 1;
  }

=item $old_value = $c->Value($key);
=item $old_value = $c->Value($key, $value, %options);

Get/set a configuration value.  If setting, return the old value, if any.
The following options are currently supported.

C<persist>: if true, mark the new value for output in Render() and Save('mode'=>'update') even if its key had no specified value in the original configuration file.  No effect if no new value is specified.

C<text>: if specified, provide text to be used to represent the value in Render(), for example if the value contains code or is otherwise not easy to reconstruct.  No effect if no new value is specified. Probably should not be used until closures etc. can actually be used as configuration values.

=cut

sub Value ($$@) { 
  my $this = shift; 
  my $key = shift; 
  my $value = shift;
  my (%options) = @_;
  if ($key =~ /\W/) {
    if (my $tournament = $this->{'tournament'}) {
      $tournament->TellUser('ebadcfgk', $key);
      }
    return undef;
    }
  # if we are setting a new value
  if (defined $value) {
    # if value is persistent, make sure it is indexed
    if ($options{'persist'} && !$this->{'_saved_index'}{$key}) {
      my $savedp = $this->{'_saved'};
      $this->{'_saved_index'}{$key} = scalar(@$savedp);
      push(@$savedp, '');
      }
    # if value is indexed, update the saved copy of the config source text
    if (defined $this->{'_saved_index'}{$key}) {
      $this->{'_saved'}[$this->{'_saved_index'}{$key}] = "config $key = "
        . ((defined $options{'text'}) ? $options{'text'} : $this->RenderPerlValue($value)) . "\n";
      }
    # if value is a reference, make sure it is safe to share
    if (defined(&threads::shared::is_shared) && ref($value) && !threads::shared::is_shared($value)) {
      $value = TSH::Utility::ShareSafely($value);
      }
    return TSH::Utility::GetOrSet($key, $this, $value); 
    }
  # else, we are returning the current value.
  # if we know this variable or are a profile file, return available value
  if ((exists $this->{$key}) or ($this->{'_config_type'} eq 'profile')) {
    return $this->{$key};
    }
  # else see if the value can be found in the profile file
  if (my $tournament = $this->{'tournament'}) {
    if (my $profile = $this->{'tournament'}->Profile()) {
      return $profile->Value($key);
      }
    }
  }

=item $c->Write($fh, $division_filter);

Write a copy of the current configuration information to file handle
C<$fh>.  See C<Render()> for C<$division_filter> usage.

=cut

sub Write ($$;$) {
  my $this = shift;
  my $fh = shift;
  my $division_filter = shift;

  print $fh $this->Render($division_filter);
  }

=back

=head1 CONFIGURATION (USER) OPTIONS

Over the years, C<tsh> has acquired a large number of configuration
options to support the different styles of tournaments that its
users prefer to run.  The primary documentation for the options is
in doc/config.html.

All configuration options should also be listed for validation
purposes in the following data structure, C<%user_option_data>.  A
configuration option can have a value of simple or compound type,
as described therein.  A simple value must be of one of the following:

  boolean
  integer
  string
  enum
  divname (division name)
  round (round number)
  round0 (round number or zero)
  localdirectory
  internal (opaque values which are not accessible to the user)

A compound value
must be one of the following: list, hash, sparselist (a list where
empty positions should not be displayed), integerlist (a list whose
values must be integers).  The elements making up a compound value
may be simple or compound.

A configuration option's type may be modified by type options
as follows.

* C<int>: C<low> and C<high> give minimum and maximum permitted values.

=cut

BEGIN {

# information about configuration options
# type: see above
# jscached: value used by JavaScriptTypeCacheValidate
# jstype: JavaScript version of type 
# help: help text
# private: should not be inherited by event configs from user profile
# validate: validation closure
# related: list of related keys (see tsh-widget.js)
(%user_option_data) = (
  '_config_type' => { 'type' => ['internal'], 'help' => 'This configuration file\'s type: event or profile.', 'private' => 1, 'editable' => 0, },
  '_jstype_cache' => { 'type' => ['internal'], 'help' => 'An integer value that is incremented each time the JavaScript type cache is to be invalidated.', 'private' => 1, 'editable' => 0, },
  '_rating_system' => { 'type' => ['internal'], 'help' => 'A hash mapping rating system names to hashes of information about them.', 'private' => 1, 'editable' => 0, },
  '_saved' => { 'type' => ['internal'], 'help' => 'A saved copy of the source lines for this configuration file.', 'private' => 1, 'editable' => 0, },
  '_saved_index' => { 'type' => ['internal'], 'help' => 'A hash mapping appearances of configuration variable names (keys) to the source lines in which they appear.', 'private' => 1, 'editable' => 0, },
  'all_byes_tie' => { 'type' => ['boolean'], 'help' => 'If checked, byes are scored as half a win and half a loss; if not, byes with positive score count as a win, byes with negative score a loss, and byes with no score neither.', 'editable' => 1, 'category' => 'regional'},
  'account_for_h2h_sr' => { 'type' => ['boolean'], 'help' => 'If checked, players\' head-to-head record of firsts and seconds will be considered  when assigning firsts.', 'editable' => 1, 'category' => 'pairing' },
  'allow_gaps' => { 'type' => ['boolean'], 'help' => 'If checked, unpaired gaps may appear in a player\'s schedule.  Should almost never be checked.', 'editable' => 1, 'category' => 'pairing' },
  'alpha_pair_first_page_break' => { 'type' => ['integer',{'low'=>1,'high'=>99999}], 'help' => 'Gives the maximum number of rows that will be printed on the first page of alpha pairings before a column or page break, overriding the value of <em>alpha_pair_page_break</em> if set.', 'editable' => 1, 'category' => 'formatting' },
  'alpha_pair_page_break' => { 'type' => ['integer',{'low'=>1,'high'=>99999}], 'help' => 'Gives the maximum number of rows that will be printed on one page of alpha pairings before a column or page break. See also <em>alpha_pair_first_page_break</em>.', 'editable' => 1, 'category' => 'formatting' },
  'alpha_pair_single_column' => { 'type' => ['boolean'], 'help' => 'If set, tells TSH not to try to squeeze two columns of alpha pairings onto each page.', 'editable' => 1, 'category' => 'formatting' },
  'alpha_rosters' => { 'type' => ['boolean'], 'help' => 'If set, the &ldquo;<code><a href="/docraw/commands.html#rosters" target="_new">ROSTERS</a></code>&rdquo;, lists players alphabetically; if not, in player number order.', 'editable' => 1, 'category' => 'deprecated' },
  'assign_firsts' => { 'type' => ['boolean'], 'help' => 'If checked, tsh decides who plays first (starts) or second (replies) in each game. Should usually be checked.', 'editable' => 1, 'category' => 'regional', 'profile' => 1, },
  'attachments' => { 'type' => ['internal'], 'help' => 'Used internally to store content of attached documents in a TSH archive.', 'private' => 1, 'editable' => 0, },
  'attachments_lc' => { 'type' => ['internal'], 'help' => 'Used internally to store content of attached documents in a TSH archive (indexed by lower-case filename).', 'private' => 1, 'editable' => 0, },
  'auto_koth_repeats' => { 'type' => ['integer',{'low'=>0,'high'=>'$max_rounds'}], 'help' => 'If set, gives the number of repeats permitted in the final KOTH rounds automatically generated when <em>force_koth</em> is set; if not, unlimited repeats are permitted.', 'editable' => 1, 'category' => 'pairing', 'related' => [qw(max_rounds)], },
  'autopair' => { 'type' => ['internal'], 'help' => 'Autopair instructions specify which round\'s results trigger which round\'s pairings and how.', 'editable' => 0, },
  'avoid_sr_runs' => { 'type' => ['boolean'], 'help' => 'If checked, when two opponents have the same number of firsts and seconds (starts and replies) and one of them has just gone first and the other second, they will do the reverse this round; if not, first and second will be determined at random.', 'editable' => 1, 'category' => 'regional'},
  'backup_directory' => { 'type' => ['localdirectory'], 'help' => 'Specifies where journalled ".t" and ".tsh" files are kept.', 'private' => 1, 'editable' => 1, 'category' => 'directories', }, # should reuse ValidateLocalDirectory
  'beep' => { 'type' => ['boolean'], 'help' => 'If checked, TSH will try to beep when reporting an error message.', 'editable' => 1, 'category' => 'ui'},
  'begin' => { 'type' => ['internal'], 'help' => 'Stores the contents of "begin" declarations.', 'private' => 1, 'editable' => 0, },
  'board_stability' => { 'type' => ['boolean'], 'help' => 'If checked, tsh will try to keep one player from each game at the same board during a session. If not checked, tsh will try to assign players to boards according to their current rank.', 'editable' => 1, 'category' => 'pairing', },
  'bracket_cap' => { 'type' => ['integer', {'low' => 2}], 'help' => 'When using the &ldquo;<code><a href="/docraw/commands.html#bracketpair" target="_new">BRACKetpair</a></code>&rdquo; command, this specifies how many players advance into the bracket.', 'private' => 1, 'editable' => 1, 'category' => 'advanced', },
  'bracket_noncon_pairings' => { 'type' => ['enum', {'values' => [qw(none nasc)], 'default' => 'none nasc'}], 'help' => 'When using the &ldquo;<code><a href="/docraw/commands.html#bracketpair" target="_new">BRACKetpair</a></code>&rdquo; command, this specifies how players should be paired when they fail to advance.', 'private' => 1, 'editable' => 1, 'category' => 'advanced' },
  'bracket_order' => { 'type' => ['enum', {'values' => [qw(id prelim rating)], 'default' => 'prelim'}], 'help' => 'When using the &ldquo;<code><a href="/docraw/commands.html#bracketpair" target="_new">BRACKetpair</a></code>&rdquo; command, this specifies how players should be ordered at the beginning of the bracket: by preliminary standings, by player ID, or by pretournament rating.', 'private' => 1, 'editable' => 1, 'category' => 'advanced' },
  'bracket_prelims' => { 'type' => ['integer', {'low' => 0, 'high' => '$max_rounds'}], 'help' => 'When using the &ldquo;<code><a href="/docraw/commands.html#bracketpair" target="_new">BRACKetpair</a></code>&rdquo; command, this specifies how many rounds of preliminary play there should be, if any.', 'private' => 1, 'editable' => 1, 'category' => 'advanced', 'related' => [qw(max_rounds)], },
  'bracket_repeats' => { 'type' => ['integer', {'low' => 1, 'high' => '$max_rounds'}], 'help' => 'When using the &ldquo;<code><a href="/docraw/commands.html#bracketpair" target="_new">BRACKetpair</a></code>&rdquo; command, this specifies how many times each pair of players should face each other consecutively in a bracket stage.', 'private' => 1, 'editable' => 1, 'category' => 'advanced', 'related' => [qw(max_rounds)], },
  'bye_firsts' => { 'type' => ['enum', {'values' => [qw(alternate ignore)], 'default' => 'alternate'}], 'help' => 'When set to <i>ignore</i>, byes count neither as firsts (starts) nor seconds (replies); when set to <i>alternate</i>, the first bye is a first, after which they alternate.', 'private' => 0, 'editable' => 1, 'category' => 'regional', },
  'bye_spread' => { 'type' => ['integer', {'low' => 0, 'high' => 250}], 'help' => 'Specifies the spread assigned to a player who is automatically assigned a bye. Usually not adjusted directly, but by changing the value of \'realm\'.', 'editable' => 1, 'category' => 'regional', },
  'canonicalize_tfile_player_name' => { 'type' => ['string'], 'help' => 'Names a function that canonicalizes the spelling of player names in .t files.', 'private' => 0, 'editable' => 1, 'category' => 'advanced', },
  'check_by_winner' => { 'type' => ['boolean'], 'help' => 'If set, the &ldquo;<code><a href="/docraw/commands.html#checkroundscores" target="_new">CheckRoundScores</a></code>&rdquo; command lists players by winner rather than by the player who went first (started). If your score slips list the winner first, use this; if they list the player who went first, do not.', 'editable' => 1, 'category' => 'ui' },
  'chew_no_swiss_all' => { 'type' => ['boolean'], 'help' => 'If set, the &ldquo;<code><a href="/docraw/commands.html#chewpair" target="_new">ChewPair</a></code>&rdquo; command will not Swiss-pair a group of players who are all in contention, but will instead try to divide them into leaders and non-leaders.', 'editable' => 1, 'category' => 'advanced' },
  'class_endagony' => { 'type' => ['boolean'], 'help' => 'If set, whenever Swiss pairings are computed, an additional criterion is added after rank separation and starts/replies, namely favouring opponents who are in the same class if they have both lost at least one game.', 'editable' => 1, 'category' => 'advanced' },
  'colour' => { 'type' => ['boolean'], 'help' => 'If true, add colour to the command-line interface.', 'editable' => 1, 'category' => 'ui', },
  'commentary_directory' => { 'type' => ['localdirectory'], 'help' => 'Specifies where generated commentary files are kept.', 'validate' => \&ValidateLocalDirectory, 'editable' => 1, , 'category' => 'directories', },
  'console_encoding' => { 'type' => ['string'], 'help' => 'Specifies the console encoding for non-Roman Windows users.', 'editable' => 1, 'category' => 'advanced' },
  'count_good_words' => { 'type' => ['boolean'], 'help' => 'If set, the &ldquo;<code><a href="/docraw/commands.html#look" target="_new">LOOK</a></code>&rdquo; command will report on how many words in a multi-word challenge were acceptable.', 'editable' => 1, 'category' => 'ui' },
  'cross_tables_id' => { 'type' => ['integer', {'low' => 1, 'high' => '999999999'}], 'help' => 'Specifies the ID number of this tournament at <a href="http://www.cross-tables.com target="new">cross-tables.com</a>, so that you can load your player roster from that site using the &ldquo;<code><a href="/docraw/commands.html#updateplayers" target="_new">UpdatePLAYers</a></code>&rdquo; command.', 'editable' => 1, 'category' => 'identification' },
  'csv_encoding' => { 'type' => ['string'], 'help' => 'Specifies the text encoding used when importing or exporting data from CSV files; may require additional plug-in modules.', 'editable' => 1, 'category' => 'advanced' },
  'currency_symbol' => { 'type' => ['string'], 'help' => 'Specifies the currency symbol (as an HTML entity, beginning with an ampersand and ending with a semicolon) used to mark players who are in the running for prize money in scoreboards.', 'editable' => 1, 'category' => 'formatting' },
  'custom_stylesheet' => { 'type' => ['string'], 'help' => 'Specifies the name of an additional CSS stylesheet (typically stored in <code>lib/css</code>) that will be included to customize the formatting of reports', 'editable' => 1, 'category' => 'formatting' },
  'de_alternate' => { 'type' => ['integer', {'low' => 1, 'high' => '999999999'}], 'help' => 'Gives the player number for the alternate player in double elimination pairings.', 'editable' => 1, 'category' => 'miscellaneous',},
  'director_id' => { 'type' => ['integer', {'low' => 1, 'high' => '999999999'}], 'help' => 'Gives the name of the director of this event.', 'editable' => 1, 'category' => 'identification', 'profile' => 1,},
  'director_email' => { 'type' => ['string'], 'help' => 'Gives the email address of the director of this event, for use in ABSP ratings submission.', 'editable' => 1, 'category' => 'identification', },
  'director_name' => { 'type' => ['string'], 'help' => 'Gives the name of the director of this event, for use in NASPA ratings submission.', 'editable' => 1, 'category' => 'identification', },
  'director_password' => { 'type' => ['string'], 'help' => 'Gives the event director\'s password, for use in NASPA ratings submission. It is not a good idea to include passwords in readable files.', 'editable' => 1, 'private' => 0, 'category' => 'deprecated', },
  'division_label' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['string', {'validate' => 'alphanumeric'}]}], 'help' => 'Specifies non-default names to display for each division.', 'editable' => 1, 'private' => 0, 'category' => 'formatting', },
  'division_rating_list' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['string', {'validate' => 'alphanumeric'}]}], 'help' => 'Specifies the rating list associated with each division.', 'editable' => 1, 'private' => 0, 'category' => 'regional', },
  'division_rating_system' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['string', {'validate' => 'rating_system'}]}], 'help' => 'Specifies the rating system associated with each division.', 'editable' => 1, 'private' => 0, 'category' => 'regional', },
  'entry' => { 'type' => ['enum', {'values' => [qw(board both scores spread)], 'default' => 'both'}], 'help' => 'Specifies how the &ldquo;<code><a href="/docraw/commands.html#addscore" target="_new">Addscore</a></code>&rdquo; command accepts game results: scores only, spread only, both scores and spread, or both + board.', 'private' => 0, 'editable' => 1, 'category' => 'ui', },
  'entry_pairing' => { 'type' => ['boolean',{'default'=>0}], 'help' => 'If true, when you enter unpaired players into &ldquo;<code><a href="/docraw/commands.html#addscore">Addscore</a></code>&rdquo;, they are paired with each other rather than being rejected.', 'editable' => 1, 'category' => 'advanced', },
  'esb_geometry' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['list,list,integer']}], 'help' => 'Indicates rows and columns for ESBs in a division', 'private' => 0, 'editable' => 1, 'category' => 'formatting', },
  'esb_lite' => { 'type' => ['boolean'], 'help' => 'If true, certain elements of theESB will be suppressed to save on pixels', 'editable' => 1, 'category' => 'formatting', 'profile' => 1, },
  'event_date' => { 'type' => ['string'], 'help' => 'Gives the date(s) of this event, for use in report headers and ratings submission.', 'editable' => 1, 'category' => 'identification', },
  'event_name' => { 'type' => ['string'], 'help' => 'Gives the name of this event, for use in report headers and ratings submission.', 'editable' => 1, 'category' => 'identification', },
  'ftp_host' => { 'type' => ['string'], 'help' => 'Gives the name of the FTP host to which files should be mirrored.', 'editable' => 1, 'category' => 'identification', },
  'ftp_path' => { 'type' => ['string'], 'help' => 'Gives the remote path on the FTP host to which files should be mirrored.', 'editable' => 1, 'category' => 'identification', },
  'exagony' => { 'type' => ['boolean',{'default'=>0}], 'help' => 'If true, TSH will try to avoid pairing teammates with each other.', 'editable' => 1, 'category' => 'pairing', },
  'external_path' => { 'type' => ['list',{'value'=>['localdirectory']}], 'help' => 'Lists directories in which TSH will search for external commands.', 'editable' => 1, 'private' => 0, 'category' => 'directories', },
  'fat_tweets' => { 'type' => ['string'], 'help' => 'Enable detailed data in tweets, for when TWEET sends data to systems which can handle it.', 'editable' => 1, 'category' => 'formatting', },
  'filename' => { 'type' => ['internal'], 'help' => 'Used internally to specify the configuration filename relative to the event root directory.', 'private' => 1, 'editable' => 0, 'category' => 'directories', },
  'final_draw' => { 'type' => ['boolean',{'default'=>0}], 'help' => 'If true, when players with equal first/second records face each other in the final round, they are instructed to draw to see who plays first when they would otherwise be chosen randomly to do so.', 'editable' => 1, 'category' => 'pairing', },
  'force_koth' => { 'type' => ['integer',{'low'=>0,'high'=>'$max_rounds'}], 'help' => 'When computing Chew pairings, use the specified number of king-of-the-hill pairings at the end of the event.', 'editable' => 1, 'category' => 'pairing', 'related' => [qw(max_rounds)],},
  'frameset' => { 'type' => ['hash',{'key' => ['integer'], 'value' => ['string']}], 'help' => 'Indicates layouts of HTML frameset pages', 'private' => 0, 'editable' => 1, 'category' => 'formatting', },
  'gibson' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'gibson_class' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'gibson_equivalent' => { 'type' => ['internal'], 'help' => 'Used internally to specify information about Gibson-equivalent ranks in divisions.', 'private' => 1, 'editable' => 0, 'category' => 'pairing', },
  'gibson_groups' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['list,list,integer']}], 'help' => 'Indicates final ranks that are to be considered equivalent when testing for Gibsonization in Chew pairings', 'private' => 0, 'editable' => 1, 'category' => 'pairing', },
  'gibson_spread' => { 'type' => ['list', {'value' => ['integer',{}]}], 'editable' => 1, 'private' => 0, 'category' => 'advanced', 'help' => 'Specifies a list of maximum attainable spreads per round, beginning with the last round of the event, with the last value being repeated as necessary.' },
  'gui_port' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'hook_addscore_flush' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'hook_autopair' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'hook_division_complete' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['string']}], 'help' => 'Specifies commands to run when a round\'s data entry has completed in a division.', 'editable' => 1, 'private' => 0, 'category' => 'advanced', },
  'hook_division_update' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_bottom' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_directory' => { 'type' => ['localdirectory'], 'help' => 'Specifies where generated web files are kept.', 'validate' => \&ValidateLocalDirectory, 'editable' => 1, , 'category' => 'directories', },
  'html_in_event_directory' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_index_bottom' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_index_recent_first' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_index_style' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_index_top' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_suffix' => { 'type' => ['string'], 'help' => 'Specifies the suffix to be used for generated HTML files, typically one of .htm, .html or .shtml.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_top' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'html_page_break_top' => { 'type' => ['string'], 'help' => 'Not yet documentedOverrides html_top for continuation pages.', 'editable' => 1, 'category' => 'miscellaneous', },
  'index_top_extras' => { 'type' => ['hash', {'key' => ['string'], 'value' => ['url']}], 'help' => 'If specified, gives additional entries to appear in the top section of the web coverage index.', 'editable' => 1, 'private' => 0, 'category' => 'formatting', },
  'initial_random' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'initial_schedule' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'initial_snaked' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'interleave_rr' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'localise_names' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'manual_pairings' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'max_div_rounds' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['integer',{'low' => 1, 'high' => 99999, 'default_value' => 12}]}], 'help' => 'Gives the number of rounds in each division, when divisions have different numbers of rounds.', 'editable' => 1, 'category' => 'basic', },
  'max_rounds' => { 'type' => ['integer'], 'help' => 'Gives the number of rounds in this tournament. This parameter is mandatory when using tsh in server mode.', 'editable' => 1, 'category' => 'basic', },
  'max_score' => { 'type' => ['integer'], 'help' => 'Gives the largest score that is accepted through data entry.', 'editable' => 1, 'category' => 'basic', },
  'member_separator' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'message_file' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'minimum_prize_team' => { 'type' => ['integer'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'mirror_directories' => { 'type' => ['list', {'value' => ['localdirectory']}], 'help' => 'Lists directories in which TSH will keep a copy of all data and report files.', 'editable' => 1, 'private' => 0, 'category' => 'directories',  },
  'next_round_style' => { 'type' => ['string'], 'help' => 'Style for rendering Next Game in standings.', 'editable' => 1, 'category' => 'formatting', },
  'no_aupair_bye_ties' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_boards' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_console_input' => { 'type' => ['boolean',{'default'=>0}], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_console_output' => { 'type' => ['boolean',{'default'=>0}], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_index_tally_slips' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_initial_rr' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_random' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_ranked_pairings' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_show_last' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'no_text_files' => { 'type' => ['boolean'], 'help' => 'If checked, tsh creates only web HTML files. Leave this checked unless you prefer the retro look.', 'editable' => 1, 'category' => 'directories', },
  'nohistory' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'notes' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'numeric_pairing_display' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'oppless_spread' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
   'overseed_tiebroken_by_spread' => { 'type' => ['boolean'], 'help' => 'If checked, ties in rank change are broken by spread, then initial ranking (else spread is ignored).', 'editable' => 1, 'category' => 'miscellaneous', },
  'pairing_bars' => { 'type' => ['boolean'], 'help' => 'Enables pairing bars in STandings and RoundRATings reports.', 'editable' => 1, 'category' => 'formatting', },
  'pairing_caption_pipe' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'pairing_system' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'pairings_refresh' => { 'type' => ['string'], 'help' => 'If set to an integer, adds a metatag to pairings HTML indicating how often in seconds the page should be refreshed.', 'editable' => 1, 'category' => 'formatting', },
  'passwords' => { 'type' => ['internal'], 'help' => 'Stores kiosk data entry passwords for each player', 'editable' => 0, 'private' => 1, },
  'phiz_event_id' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'photo_database' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'pix' => { 'type' => ['internal'], 'help' => 'Stores filenames for player photos.', 'private' => 1, 'editable' => 0, },
  'pixmood' => { 'type' => ['internal'], 'help' => 'Stores filenames for player mood photos.', 'private' => 1, 'editable' => 0, },
  'player_csv_key_map' => { 'type' => ['hash', {'key' => ['string'], 'value' => ['value']}], 'help' => 'Used by the LoadPlayersCSV command.', 'editable' => 1, 'private' => 0, 'category' => 'advanced', },
  'player_id_first' => { 'type' => ['string'], 'help' => 'Render player FullID with Player ID preceding name.', 'editable' => 1, 'category' => 'formatting', },
  'player_nicknames' => { 'type' => ['string'], 'help' => 'Names a file in lib with preferred represenations of player names, for use in the scoreboard.', 'editable' => 1, 'category' => 'miscellaneous', },
  'player_number_format' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'player_photo_aspect_ratio' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'player_photos' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'port' => { 'type' => ['integer', {'low' => 1024, 'high' => 65535}], 'help' => 'If set to a nonzero value, enables the web interface that you are using and specifies its TCP/IP port number.  Do not change unless you know what this is.', 'editable' => 1, 'category' => 'advanced', },
  'primary_gui' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'prize_bands' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['list', {'value' => 'integer'}]}], 'help' => 'Specifies which final ranks are to be considered equivalent for pairing purposes: the numbers given mark the end of each band (range) of equivalent prizes (ranks). Used in Chew pairings and by electronic scoreboards.', 'editable' => 1, 'private' => 1, 'category' => 'pairing', },
  'prize_bands_from_prizes' => { 'type' => ['boolean'], 'help' => 'Indicates that the prize_bands for all divisions are to be derived from the rank prizes as specified by the prizes configuration.', 'editable' => 1, 'category' => 'miscellaneous', },
  'prizes' => { 'type' => ['internal'], 'help' => 'Stores the contents of prize declarations.', 'private' => 1, 'editable' => 0, },
  'prizes_page_break' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'quiet_hooks' => { 'type' => ['boolean'], 'help' => 'If enabled, hooks run quietly without displaying the output of commands that are run.', 'editable' => 1, 'category' => 'miscellaneous', },
  'random' => { 'type' => ['float', {'default' => '0.5', 'low' => 0, 'high' => 1}], 'help' => 'Some algorithms, such as round robin first/second determination, use a random number determined at the beginning of each run. If you specify a number here, it will be used instead of the random value.', 'private' => 0, 'editable' => 1, 'category' => 'advanced', },
  'random_rr_order' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'rating_fields' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'rating_list' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'rating_system' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'ratings_note' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'realm' => { 'type' => ['enum', {'values' => [qw(absp deu go ken naspa naspa-lct naspa-csw naspa2024 naspa2024-csw naspa2024-csw-lct naspa2024-lct nga nor nsa pak pol sgp sudoku thai)], 'default' => 'naspa'}], 'help' => 'Specifies default values for many configuration options based on regional or game defaults.', 'private' => 0, 'editable' => 1, 'category' => 'regional', 'profile' => 1,},
  'reserved' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['sparselist', {'value' => 'integer'}]}], 'help' => 'Assigns players to fixed tables.', 'private' => 0, 'editable' => 1, 'category' => 'basic', },
  'root_directory' => { 'type' => ['internal'], 'help' => 'Used internally to specify the event root directory where the event files are usually found.', 'private' => 1, 'editable' => 0, },
  'rotofile' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'round_robin_order' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'save_interval' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'port' => { 'type' => ['integer', {'low' => 1024, 'high' => 65535}], 'help' => 'If set to a nonzero value, enables the web interface that you are using and specifies its TCP/IP port number.  Do not change unless you know what this is.', 'editable' => 1, 'category' => 'advanced', },
  'sb_banner_height' => { 'type' => ['integer', {'low' => 0}], 'help' => 'Specifies the height in pixels to reserve for a banner to display above the EnhancedScoreBoard.', 'private' => 0, 'editable' => 1, 'category' => 'formatting', },
  'sb_banner_url' => { 'type' => ['url', {}], 'help' => 'Specifies the URL of a banner to display above the EnhancedScoreBoard.', 'private' => 0, 'editable' => 1, 'category' => 'formatting', },
  'school_bios' => { 'type' => ['local_filename'], 'help' => 'The local filename of school bio data.', 'private' => 1, 'editable' => 0, 'category' => 'miscellaneous'},
  'scoreboard_teams' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'scorecards_refresh' => { 'type' => ['string'], 'help' => 'If set to an integer, adds a metatag to scorecard HTML indicating how often in seconds the page should be refreshed.', 'editable' => 1, 'category' => 'formatting', },
  'scores' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'seats' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'session_breaks' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_class_in_pairings' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_divname' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_honourable_mention' => { 'type' => ['boolean'], 'help' => 'If set, list prizes not awarded due to exclusive ineligibility are listed as honourable mentions..', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_inactive' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_last_player_name' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_roster_classes' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_roster_photos' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'show_teams' => { 'type' => ['boolean'], 'help' => 'If set, the &ldquo;<code><a href="/docraw/commands.html#rosters" target="_new">ROSTERS</a></code>&rdquo;, &ldquo;<code><a href="/docraw/commands.html#statistics" target="new">STATisticS</a></code>&rdquo; and &ldquo;<code><a href="/docraw/commands.html#wallchart" target="new">WallChart</a></code>&rdquo;commands include information about <a href="/docraw/teams.html" target="_new">teams</a>, and team names are shown in most places after player numbers.', 'editable' => 1, 'category' => 'basic', },
  'sort_by_first_name' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'spitfile' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['string', {'validate' => 'local_filename'}]}], 'help' => 'Specifies locations in which U.K. rotisserie pool files can be found for each division.', 'editable' => 1, 'private' => 0, 'category' => 'directories', },
  'split1' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'spread_cap' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'squads' => { 'type' => ['boolean'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'standings_hotlink' => { 'type' => ['boolean'], 'help' => 'Render player names in standings as links to the player\'s scorecard.', 'editable' => 1, 'category' => 'formatting', },
  'standings_hotlink_target' => { 'type' => ['string'], 'help' => 'Format string for customizing the hotlinks in player scorecards.', 'editable' => 1, 'category' => 'formatting', },
  'standings_refresh' => { 'type' => ['string'], 'help' => 'If set to an integer, adds a metatag to standings HTML indicating how often in seconds the page should be refreshed.', 'editable' => 1, 'category' => 'formatting', },
  'standings_spread_cap' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'standings_with_ratings' => { 'type' => ['string'], 'help' => 'Show ratings in standings report.', 'editable' => 1, 'category' => 'formatting', },
  'sum_before_spread' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'suppress_results_in_standings' => { 'type' => ['boolean'], 'help' => 'If true, no results will be shown in ESB Pairing mode', 'editable' => 1, 'category' => 'formatting', 'profile' => 1, },
  'surname_last' => { 'type' => ['boolean'], 'help' => 'If true, rewrites names entered as &lsquo;surnames, given names&rsquo; as &lsquo;given names surnames&rsquo;.', 'editable' => 1, 'category' => 'formatting', 'profile' => 1, },
  'swiss_ignores_repeats' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'swiss_order' => { 'type' => ['list', {'value' => ['string']}], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'table_format' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'table_title' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tables' => { 'type' => ['hash', {'key' => ['division'], 'value' => ['integerlist', {'value' => 'integer'}]}], 'help' => 'Lists the name of the table at which each board is located.', 'editable' => 1, 'private' => 0, 'category' => 'basic', },
  'tally_slips_blanks' => { 'type' => ['boolean'], 'help' => 'If set, include blank designations on tally slips.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tally_slips_challenges' => { 'type' => ['boolean'], 'help' => 'If set, include challenged words area on tally slips.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tally_slips_no_spread' => { 'type' => ['boolean'], 'help' => 'If specified, do not show a box for spread on tally slips.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tally_slips_page_break' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'team_pair_page_break' => { 'type' => ['integer'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'team_pair_first_break' => { 'type' => ['integer'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'team_pair_always_break' => { 'type' => ['boolean'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'team_quotas' => { 'type' => ['hash', {'key' => 'string', 'value' => 'string'} ], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tfile_game' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'thai_cash_cutoff' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'thai_cash_payout' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'thai_points' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'thai_team_hack' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'top_down_swiss' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tournament' => { 'type' => ['internal'], 'help' => 'The tournament object associated with this configuration.', 'private' => 1, 'editable' => 0, },
  'tournament_id' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'track_firsts' => { 'type' => ['boolean'], 'help' => 'If checked, keeps track of who played first (started) or second (replied) in each game. Should be checked in most parts of the world now.', 'editable' => 1, 'category' => 'regional', 'profile' => 1, },
# 'track_teams' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'tsh_username' => { 'type' => ['string'], 'help' => 'The name that you use to log onto access enhanced TSH services.', 'editable' => 1, 'category' => 'identification', 'profile' => 1,},
  'twitter_dm_command' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'twitter_password' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'twitter_prefix' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'twitter_username' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  'zero_byes_tie' => { 'type' => ['string'], 'help' => 'Not yet documented.', 'editable' => 1, 'category' => 'miscellaneous', },
  );
}

=head1 BUGS

See master issues list.

Should think about combining Save() and Write().

=cut

1;
