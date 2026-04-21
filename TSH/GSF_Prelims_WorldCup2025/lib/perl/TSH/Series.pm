#!/usr/bin/perl

# Copyright (C) 2017 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Series;

use strict;
use warnings;

use Carp;
use TSH::Utility qw(Debug DebugOn OpenFile);
use threads::shared;

our (@ISA);
@ISA = qw();

=pod

=head1 NAME

TSH::Series - abstraction of a Scrabble tournament series within C<tsh>

=head1 SYNOPSIS

  $s = new TSH::Series($tournament->Config());

=head1 ABSTRACT

This Perl module is used to manipulate tournament series within
C<tsh>.  A tournament series is a sequence of TSH tournaments (in
this case called sessions) connected as a doubly linked list for
rating and standing purposes.  It may be used to implement club or
league statistics.  TSH recognizes a series by the presence of 
a config series_id parameter.

All session directories should be siblings in the file hierarchy.
Sessions are identified by their session name, which is the last
component of the pathname of their data directory.

A series stores post-session rating data in a subdirectory of
lib/ratings whose name is the series_id, in files whose names are
session names concatenated with .txt.  TSH compares timestamps on
those rating data files with timestamps on config.tsh and *.t files
to see when rating data files need rebuilding.

At the beginning of each rating data file are one or more special rows 
containing metadata.  Here is a list of such possible rows:

#prev session_name

#next session_name

=head1 DESCRIPTION

The following member functions are currently defined.

=over 4

=cut

sub initialise ($$);
sub new ($);

=item $s->initialise($config);

Used internally to initialise a new TSH::Series object.

=cut

sub initialise ($$) {
  my $this = shift;
  my $config = shift;

  $this->{'config'} = $config;
  my $series_id = $config->Value('series_id');
  $this->SeriesID($series_id);
  $this->{'series_path'} = $config->MakeSessionSiblingPath();
  my $current_session_id = $config->RootDirectoryBasename();
  $this->SessionID($current_session_id);
  $this->{'series_rating_path'} = $config->MakeLibPath(
    File::Spec->join('ratings', $series_id));
  mkdir $this->{'series_rating_path'}; # in case this is the first session

  $this->{'session_list'} = do {
    # scan rating data to find all session names
    opendir(my $srdir, $this->{'series_rating_path'})
      or die "Cannot open series rating directory '$this->{'series_rating_path'}': $!";
    my (@session_ids) = map { s/\.txt$//; $_ } grep { /^[^._].*.txt$/ } readdir $srdir;
    closedir $srdir;

    # read link information from session rating files
    my (@list, %next, %prev);
    for my $session_id (@session_ids) {
      my $fn = File::Spec->join($this->{'series_rating_path'}, "$session_id.txt");
      open my $fh, '<', $fn or die "Cannot open '$fn': $!";
      while (<$fh>) {
	if (/^#prev\s+(.*)$/) { $prev{$session_id} = $1; }
	elsif (/^#next\s+(.*)$/) { $next{$session_id} = $1; }
	elsif (!/^#/) { last; }
	}
      close $fh;
      }
    # check consistency one way
    for my $session_id (keys %prev) {
      my $prev = $prev{$session_id};
      if (!exists $next{$prev}) { 
	warn "Unidirectional link from $session_id back to $prev"; 
	$next{$prev} = $session_id; 
        }
      elsif ($next{$prev} ne $session_id) {
	warn "Inconsistent session link data for session '$prev'";
        }
      else { warn "$prev <-> $session_id ok"; }
      }
    # check consistency the other way
    for my $session_id (keys %next) {
      my $next = $next{$session_id};
      if (!exists $prev{$next}) { 
	warn "Unidirectional link from $session_id forward to $next"; 
	$prev{$next} = $session_id; 
        }
      elsif ($prev{$next} ne $session_id) {
	warn "Inconsistent session link data for session '$next': prev should be $session_id but is $prev{$next}";
        }
      else { warn "$session_id <-> $next ok"; }
      }
    # build plain list
    if (@session_ids) {
      $list[0] = $session_ids[0];
      while (my $next = $next{$list[-1]}) { push(@list, $next); }
      while (my $prev = $prev{$list[0]}) { unshift(@list, $prev); }
      }
#   warn "Series: @list";
    $this->NextSessionID($next{$current_session_id});
    $this->PreviousSessionID($prev{$current_session_id});
    \@list;
    };
  {
    # make sure changes to past sessions are carried forward
    my $dirty = 0;
    for my $session_id (@{$this->{'session_list'}}) {
      last if $session_id eq $current_session_id;
      $dirty ||= $this->UpdateSession($session_id);
      }
    if ($dirty) {
      $this->Stale(1);
      warn "Need to carry forward past changes to $current_session_id";
      }
    else {
      warn "No past changes in series to carry forward to $current_session_id";
      }
  }
  }

=item $s = new TSH::Series($config);

Create a new TSH::Series object based on data in a TSH::Config object.

=cut

sub new ($) { return TSH::Utility::newshared(@_); }

# =item $s->Update();
# 
# Update rating data files for series, to make sure that they are
# newer than corresponding config.tsh and *.t files.
# 
# =cut
# 
# sub Update ($) {
#   my $this = shift;
#   my $config = $this->{'config'};
#   my $tournament = $config->Tournament();
# 
#   die "needs to be written";
#   }

=item $sid = $s->NextSessionID()

=item $old_sid = $s->NextSessionID($new_sid)

Get/set the next session ID.

=cut

sub NextSessionID ($;$) {
  my $this = shift;
  TSH::Utility::GetOrSet('_next_session_id', $this, @_);
  }

=item $sid = $s->PreviousSessionID()

=item $old_sid = $s->PreviousSessionID($new_sid)

Get/set the previous session ID.

=cut

sub PreviousSessionID ($;$) {
  my $this = shift;
  TSH::Utility::GetOrSet('_previous_session_id', $this, @_);
  }

=item $sid = $s->SeriesID()

=item $old_sid = $s->SeriesID($new_sid)

Get/set the series ID.

=cut

sub SeriesID ($;$) {
  my $this = shift;
  TSH::Utility::GetOrSet('_series_id', $this, @_);
  }

=item $sid = $s->SessionID()

=item $old_sid = $s->SessionID($new_sid)

Get/set the current session ID.

=cut

sub SessionID ($;$) {
  my $this = shift;
  TSH::Utility::GetOrSet('_session_id', $this, @_);
  }

=item $flag = $s->Stale()

=item $old_flag = $s->Stale($new_stale)

Get/set the series staleness (whether or not its input ratings
need to be loaded).

=cut

sub Stale ($;$) {
  my $this = shift;
  TSH::Utility::GetOrSet('_stale', $this, @_);
  }

=item $s->UpdateSession($session_id);

Update rating data file for session specified by session_id (or if
unspecified, the current session), to make sure that it is newer
than corresponding config.tsh and *.t files.

=cut

sub UpdateSession ($;$) {
  my $this = shift;
  my $session_id = shift;
  $session_id = $this->SessionID() unless defined $session_id;

  if ($session_id eq $this->SessionID()) {
    warn "UPDATE $session_id (self)";
#   die "loop?";
    my $processor = new TSH::Processor($this->{'config'}->Tournament());
    $processor->Process('EXPORTRATINGS');
    }
  else {
    warn "UPDATE $session_id (other)";
    my $session_dirname = 
      File::Spec->join($this->{'series_path'}, $session_id);
    warn "START $session_dirname";
    my $t2 = new TSH::Tournament({'path' => $session_dirname, 'silent' => 1});
    $t2->Lock() and die "event files are still in use for $session_dirname";
    $t2->LoadConfiguration(); 
    $t2->Silent(0);
    {
      my $processor = new TSH::Processor($t2);
      $processor->Process('EXPORTRATINGS');
    }
    $t2->Silent(1);
    $t2->Unlock();
    warn "END $session_dirname";
    }
  }

1;
