#!/usr/bin/perl

# Copyright (C) 2008-2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Ratings;

# use Ratings::Event;

use strict;
use warnings;
use Carp;
use List::Util qw(sum);
use threads::shared;

=head1 SYNOPSIS

  use Ratings;

  my $rs = new Ratings('homan_state_filename' => $filename) || die;

  my $rs = new Ratings('logistic_state_filename' => $filename) || die;

  Ratings::EventIterator({
    'start' => [$year1, $month1, $event1],
    'end' => [$year2, $month2, $event2],
    'handlers' => {
      'monthly' => $sub1,
      'delete' => $sub2,
      'rename' => $sub3,
      'ort' => $sub4,  
      'lct' => $sub5,
      },
     });
  
=head1 ABSTRACT

This Perl module represents the state of a (Scrabble, so far) tournament rating system. 

=cut

=head1 DESCRIPTION

=head2 Methods

=cut

BEGIN {
  use Exporter ();
  use vars qw(
    $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
    );
  $VERSION = do { my @r = (q$Revision: 1.11 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw(
    );
  %EXPORT_TAGS = ();
  }

  # my $debug_name_pattern = qr/liebfried/i;

sub AddFeedback ($$$);
sub AddPlayer ($$);
sub BaseSystemName ($);
sub CalculateAccelerationBonus ($$$$$$);
sub CalculateSegmentRatings ($$$$$);
sub CalculateSegmentStandings ($$$$$);
sub CalculateSplitRatings ($$$$);
sub CopyField ($$$$);
sub CountEWins ($$$$$);
sub DeleteAllPlayers ($);
sub EventIterator ($);
sub LoadHomanStateFile ($);
sub LoadLogisticStateFile ($;$);
sub LoadNSAStateFile ($);
sub new ($@);
sub MakeRoundToSplit ($@);
sub MakeSplits ($$);
sub ProcessSpecialEvent ($$);
sub ProcessTournament ($$;$);
sub RoundNewRatings ($$$);
sub SaveHomanStateFile ($$);
sub SaveLogisticStateFile ($$;$);
sub SetFeedbackToZero ($$);
sub SetMaximumIterations ($$);
sub UseAccelerationBonuses ($$);
sub UseClubDivisor ($$);

=over 4

=cut

sub AddFeedback ($$$) {
  my $this = shift;
  return unless $this->{'use_feedback'};
  die "not yet implemented" if $this->{'teams'};
  my $psp = shift;
  my $key_usage_p = shift;
  my $newr_k = $key_usage_p->{'newr'};

  for my $p (@$psp) { 
#   warn "$p->{name}: adding $p->{xrat_feed} FB to $p->{$newr_k} NR" if $p->{name} =~ $debug_name_pattern;
    $p->{$newr_k} += $p->{'xrat_feed'}; 
    }
  }

sub AddPlayer ($$) {
  my $this = shift;
# my $pname = shift;
  my $pp = shift;
  Carp::confess if @_;
# Carp::cluck join(',',%$pp) if $pname =~ /RIDOUT MAT/;
  my $key = $this->PlayerKey($pp);
  if (exists $this->{'_players'}{$key}) {
    confess "Duplicate player: '$key'";
    }
  else {
#   warn "Added $pp->{'name'} as $key.\n";
    $this->{'_players'}{$key} = $pp;
    }
  }

sub AverageRatings ($@) {
  my $this = shift;
  my (@ratings) = @_;
  return 0 unless @ratings;
  return sum(@ratings)/@ratings;
  }

=item $s = BaseSystemName($sf);

Some rating system names contain variant information that needs
to be stripped off to leave the key under which ratings data
is stored.  This function does that stripping.

=cut

sub BaseSystemName ($) {
  my $name = shift;
  $name =~ s/ .*//;
  return $name;
  }

=item $r->CalculateAccelerationBonus(\@ps, $pn, $first_round0, $last_round_0, $key_usage_p);

Internal use.
Add on acceleration bonuses to the given player, based on how many
points they have gained in how many rounds.  Keys used in player hashes:

newr: post-segment ratings

oldr: pre-segment ratings

rgames: rated games in segment

=cut

sub CalculateAccelerationBonus ($$$$$$) {
  my $this = shift;
  my $psp = shift;
  my $pn = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  my $p = $psp->[$pn];
  my $oldr_k = $key_usage_p->{'oldr'};
  my $newr_k = $key_usage_p->{'newr'};
  my $rgames_k = $key_usage_p->{'rgames'};
  my $pairings_k = $key_usage_p->{'pairings'};

# warn "$this->{'use_acceleration_bonuses'},$this->{'use_club_divisor'}";
  my $accel = ($this->{'use_acceleration_bonuses'}) * ($p->{$newr_k} - $p->{$oldr_k} - 5 * $p->{$rgames_k});
  return unless $accel > 0;
# warn "acceleration: $this->{'use_acceleration_bonuses'} $p->{'name'} $accel\n" if $p->{'name'} =~ $debug_name_pattern;
  $p->{$newr_k} += $accel; 
  if (my $ta_k = $key_usage_p->{'totalacc'}) {
    $p->{$ta_k} = ($p->{$ta_k}||0) + $accel;
    }
  # calculate feedback
# warn "$p->{'name'}: accel=$accel" if $p->{name} =~ $debug_name_pattern;
  $accel = $accel/20; # 2002
  if ($this->{'use_feedback'}) {
    my $tf_k = $key_usage_p->{'totalfeed'};
    for my $r0 ($first_round_0..$last_round_0) {
      my $o = $p->{$pairings_k}[$r0];
  #   die "r0=$r0 p=$p->{'name'}: @{$p->{$pairings_k}}." unless defined $o;
      next if (!defined $o) || $o == -1;
      my $op = $psp->[$o];
      next unless $op->{$oldr_k}; # 2002
      my $key = $this->{'use_homan_feedback_bug'} ? $newr_k : 'xrat_feed';
      $op->{$key} += $accel;
  #   warn "$p->{'name'} $op->{'name'}: early feedback ($key) +$accel=$op->{$key}" if $op->{'name'} =~ $debug_name_pattern;
      if ($tf_k) {
	$op->{$tf_k} = ($op->{$tf_k}||0) + $accel;
	}
      }
    }
  }

=item $r->CalculateSegmentRatings(\@ps, $first_round_0, $last_round_0, $key_usage_p);

Internal use.
Calculate ratings for all players for the split segment covering the
designated 0-based rounds.  Player hash key usage:

ewins: earned wins in segment

id: player id (0-based index in \@ps)

newr: post-segment ratings

news: post-segment deviation

oldr: pre-segment ratings

olds: pre-segment deviation

pairings: 0-based list of opponents (-1 indicates bye)

perfr: performance ratings (optional)

rgames: rated games in segment

scores: 0-based list of scores

=cut

sub CalculateSegmentRatings ($$$$$) { 
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  my $oldr_k = $key_usage_p->{'oldr'};
  my $newr_k = $key_usage_p->{'newr'};

  $this->SetFeedbackToZero($psp);
  $this->CopyField($psp, 'xrat_effr', $oldr_k);
  $this->RateNewcomers($psp, $first_round_0, $last_round_0, $key_usage_p);
  $this->RateVeterans($psp, $first_round_0, $last_round_0, $key_usage_p);
  $this->AddFeedback($psp, $key_usage_p);
  $this->RoundNewRatings($psp, $key_usage_p);
  $this->CapClubChanges($psp, $key_usage_p) if $this->{'use_club_divisor'};
  $this->CalculatePerformanceRatings($psp, $first_round_0, $last_round_0, $key_usage_p) if $key_usage_p->{'perfr'};
  }

=item $this->CalculateSegmentStandings(\@ps, $first_round_0, $last_round_0, $key_usage_p);

Public use.
Calculate cume and wins for all players for the split segment covering the
designated 0-based rounds.  Player hash key usage:

cume: cume in segment

games: games in segment

pairings: 0-based list of opponents (-1 indicates bye)

scores: 0-based list of scores

wins: wins in segment (including unearned ones (byes))

=cut

sub CalculateSegmentStandings ($$$$$) { 
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  my $cume_k = $key_usage_p->{'cume'};
  my $games_k = $key_usage_p->{'games'};
  my $pairings_k = $key_usage_p->{'pairings'};
  my $scores_k = $key_usage_p->{'scores'};
  my $wins_k = $key_usage_p->{'wins'};

  for my $p (@$psp) {
    my $opps = $p->{$pairings_k};
    my $scores = $p->{$scores_k};
    my $this_last_round_0 = $#$scores;
    $this_last_round_0 = $last_round_0 if $this_last_round_0 > $last_round_0;
    my $cume = 0;
    my $games = 0;
    my $wins = 0;
    for my $r0 ($first_round_0..$this_last_round_0) {
      $games++;
      my $ms = $scores->[$r0];
      my $on = $opps->[$r0];
      if ($on < 0) { $cume += $ms; $wins++ if $ms > 0; next; }
      my $os = $psp->[$on]{$scores_k}[$r0];
      unless (defined $os) { printf STDERR "In round %d player %d has no score but opponent does.\n", $r0+1, $on+1; next; }
      my $spread = $ms - $os;
      $cume += $spread;
      $wins += $this->{'rating_system'} eq 'thai' ? ($spread > 0? 1 : 0) :(($spread <=> 0) + 1)/2;
      }
    $p->{$cume_k} = $cume;
    $p->{$games_k} = $games;
    $p->{$wins_k} = $wins;
    }
  }

=item @splitlist = $elo->CalculateSplitRatings(\@players, $rounds, \%key_usage);

Public use.
@players is a 0-based list of players, each of which is a reference
to a hash.
$rounds specifies how many rounds the tournament lasts.
%key_usage specifies how keys are used in the player hashes, and
must include values corresponding to the following keys:

ewins: basename for keys in which to store earned wins by split segment

lifeg: lifetime games played

newr: posttournament rating

oldr: pretournament rating

pairings: 0-based list of opponents (-1 indicates bye)

perfr: performance ratings (optional)

rgames: basename for keys in which to store rated games by split segment

scores: 0-based list of scores

splitr: basename for keys in which to store intermediate ratings

It may also include the following keys:

totalacc: total acceleration points awarded

totalfeed: total feedback points awarded

Returns list of 0-based [first_round,last_round] pairs.

=cut

sub CalculateSplitRatings ($$$$) {
  my $this = shift;
  my $psp = shift;
  my $nrounds = shift;
  my $key_usage_p = shift;

  my $scores_key = $key_usage_p->{'scores'};
  my @splits = $this->MakeSplits($nrounds);
  my @round_to_split = $this->MakeRoundToSplit(@splits);
  $this->CountAllEWins($psp, \@splits, $key_usage_p);
  for my $si (0..$#splits) {
    my $split = $splits[$si];
    my $from = $si == 0 ? $key_usage_p->{'oldr'} 
      : "$key_usage_p->{'splitr'}$si";
    my $to = $si == $#splits ? $key_usage_p->{'newr'}
      : ($key_usage_p->{'splitr'}.($si+1));
    my $perfr_k = (defined $key_usage_p->{'perfr'})
      ? "$key_usage_p->{'perfr'}$si" : undef;
    my $lifeg_k = ($si == 0 || not $this->{use_split_lifeg}) 
      ? $key_usage_p->{lifeg} : "$key_usage_p->{lifeg}$si";
#   warn $key_usage_p->{'rgames'};
    $this->CalculateSegmentRatings($psp, $split->[0], $split->[1], {
      'ewins' => "$key_usage_p->{'ewins'}$si",
      'id' => $key_usage_p->{'id'},
      'lifeg' => $lifeg_k,
      'newr' => $to,
      'oldr' => $from,
      'pairings' => $key_usage_p->{'pairings'},
      'perfr' => $perfr_k,
      'rgames' => "$key_usage_p->{'rgames'}$si",
      'scores' => $key_usage_p->{'scores'},
      'totalacc' => $key_usage_p->{'totalacc'},
      'totalfeed' => $key_usage_p->{'totalfeed'},
      ($key_usage_p->{'excwins'} ? 
	('excwins', "$key_usage_p->{'excwins'}$si") : ()),
      });
    }
  return @splits;
  }

my %canonicaliser_cache;
sub CanonicaliseName ($$) {
  my $this = shift;
  my $rating_list = shift;
  my $name = shift;
  confess unless defined $rating_list;
  my $canonicaliser = $canonicaliser_cache{$rating_list};
  unless ($canonicaliser) {
    my $class = "Ratings::\U$rating_list";
    $canonicaliser = eval "use $class; \\&$class"."::Canonicalise";
    }
  if ($canonicaliser) {
    return &$canonicaliser($name);
    }
  else { 
    return $name; 
    }
  }

sub CapClubChanges ($$$) {
  my $this = shift;
  return unless $this->{'use_club_divisor'};
  die "not yet implemented" if $this->{'teams'};
  my $psp = shift;
  my $key_usage_p = shift;
  my $newr_k = $key_usage_p->{'newr'};
  my $oldr_k = $key_usage_p->{'oldr'};

  for my $p (@$psp) {
    next unless $p->{$oldr_k};
    my $diff = $p->{$newr_k} - $p->{$oldr_k};
    if ($diff > 50) { $p->{$newr_k} = $p->{$oldr_k} + 50; }
    elsif ($diff < -50) { $p->{$newr_k} = $p->{$oldr_k} - 50; }
    }
  }

sub CompareRatings ($$$) {
  return $_[1] <=> $_[2];
  }

=item $r->CountAllEWins(\@ps, \@splits, $key_usage_p);

Internal use.
Counts earned wins and rated games for all players.
Keys used in player hashes:

ewins: basename for keys in which to store earned wins by split segment

lifeg: basename for keys in which to store segment-initial life game count

pairings: 0-based list of opponents (-1 indicates bye)

rgames: basename for keys in which to store rated games by split segment

scores: 0-based list of scores

spreads: basename for keys in which to store cume by split segment

=cut

sub CountAllEWins ($$$$) {
  my $this = shift;
  my $psp = shift;
  my $splitsp = shift;
  my $key_usage_p = shift;
  my $lifeg_k = $key_usage_p->{lifeg};
  for my $si (0..$#$splitsp) {
    my $split = $splitsp->[$si];
    my $lifeg_pre = "$lifeg_k" . ($si || '');
    my $lifeg_post = "$lifeg_k" . ($si+1);
    $this->CountEWins($psp, $split->[0], $split->[1], {
      'ewins' => "$key_usage_p->{'ewins'}$si",
      'lifeg-pre' => $lifeg_pre,
      'lifeg-post' => $lifeg_post,
      'rgames' => "$key_usage_p->{'rgames'}$si",
      'pairings' => $key_usage_p->{'pairings'},
      'scores' => $key_usage_p->{'scores'},
      });
    }
  }

=item $r->CountEWins(\@ps, $first_round0, $last_round0, $key_usage_p);

Internal use.
Count earned wins and rated games for each player over the given
range of rounds.  
Keys used in player hashes:

ewins: earned wins in segment

lifeg-pre: segment-initial life game count

lifeg-post segment-final life game count

pairings: 0-based list of opponents (-1 indicates bye)

rgames: rated games in segment

scores: 0-based list of scores

=cut

sub CountEWins ($$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round0 = shift;
  my $last_round0 = shift;
  my $key_usage_p = shift;
  my $ewins_k = $key_usage_p->{'ewins'};
  my $lifeg_pre_k = $key_usage_p->{'lifeg-pre'};
  my $lifeg_post_k = $key_usage_p->{'lifeg-post'};
  my $rgames_k = $key_usage_p->{'rgames'};
  my $opps_k = $key_usage_p->{'pairings'} // die "missing pairings key";
  my $scores_k = $key_usage_p->{'scores'} // die "missing scores key";
  for my $pn (0..$#$psp) {
    my $p = $psp->[$pn];
    $p->{$ewins_k} = 0;
#   confess $p;
    $p->{$rgames_k} = 0;
    my $oppsp = $p->{$opps_k};
    my $scoresp = $p->{$scores_k};
#   warn "$p->{'name'} $rgames_k; @$oppsp; @$scoresp";
    my $this_last_0 = $#$scoresp;
    $this_last_0 = $last_round0 if $last_round0 < $this_last_0;
    for my $r0 ($first_round0..$this_last_0) {
      my $on = $oppsp->[$r0];
      unless (defined $on) {
	my $pn1 = $pn+1;
	my $r1 = $r0+1;
	warn "Player $pn1 has no opponent in round $r1\n";
	next;
        }
      next unless $on >= 0;
      my $ms = $scoresp->[$r0];
      next unless defined $ms;
      my $os = $psp->[$on]{$scores_k}[$r0];
      next unless defined $os;
      $p->{$ewins_k} += $this->{'rating_system'} eq 'thai' ? ($ms > $os ? 1 : 0) :(($ms<=>$os)+1)/2;
      $p->{$rgames_k} ++;
      }
    $p->{$lifeg_post_k} = ($p->{$lifeg_pre_k} // 0) + $p->{$rgames_k};
#   warn "$p->{name} $lifeg_pre_k @{[$p->{$lifeg_pre_k}//0]} $p->{$rgames_k} $p->{$lifeg_post_k}";
    }
  }

=item $r->CopyField($hashlistref, $destination_key, $source_key);

Public use.
Copies fields in each of a list of hashes.

=cut

sub CopyField ($$$$) {
  my $this = shift;
  my $hashlistp = shift;
  my $dst_k = shift;
  my $src_k = shift;
  for my $hashp (@$hashlistp) {
    if (exists $hashp->{$src_k}) { 
      $hashp->{$dst_k} = $hashp->{$src_k}; 
      }
    else { delete $hashp->{$dst_k}; }
    }
  }

sub DeleteAllPlayers ($) {
  my $this = shift;
  $this->{'_players'} = {};
  }

=item EventIterator(\%options);

Iterate over all events in the specified range, calling callbacks depending
on the type of event.  The range is given by the options

  - start => [ $year, $month, $event_id]
  - end => [ $year, $month, $event_id]

Events are numbered consecutively beginning with zero in each month,
and the zero event is the monthly ratings list issued at the beginning
of the month.

Other required options are

  - caller => calling object, to pass back on callbacks
  - handlers => reference to hash giving handlers to various events

  Handlers are passed the caller and the event.
    - monthly => \&sub (monthly ratings list)
    - rename => \&sub (rename player)
    - delete => \&sub (delete player)
    - ort => \&sub (open rated tourney cross-table)
    - lct => \&sub (local club tourney cross-table)
    - final => \&sub (final standings from multi-segment tourney))

=cut

sub EventIterator ($) {
  my $optionsp = shift;
  my ($current_year, $current_month, $current_event_id)
    = @{$optionsp->{'start'}};
  my ($final_year, $final_month, $final_event_id)
    = @{$optionsp->{'end'}};
  eval "use Ratings::Event";
  confess $@ if $@;
  while (
    (($current_year <=> $final_year) ||
    ($current_month <=> $final_month) ||
    ($current_event_id <=> $final_event_id)) <= 0) {
    if (my $event = 'Ratings::Event'->new({
      'type' => 'xtable',
      'year' => $current_year,
      'month' => $current_month,
      'id' => $current_event_id,
      })) {
      if (my $sub = $optionsp->{'handlers'}{$event->HandlerType()}) {
	&$sub($optionsp->{'caller'}, $event);
        }
      else {
#       warn "Ignoring $current_year-$current_month-$current_event_id";
        }
      $current_event_id++;
      }
    else {
#     warn "Did not find $current_year-$current_month-$current_event_id";
      $current_event_id = 0;
      if (12 < ++$current_month) {
	$current_month = 1;
	$current_year++;
	}
      }
    }
  }

=item $g = $rs->Games($player_key, $games);

Set or get a player's current game total.

=cut

sub Games($$;$) {
  my $this = shift;
  my $key = shift;
  my $new = shift;
  if (ref($key)) { $key = $this->PlayerKey($key); }
  Carp::confess $key unless exists $this->{'_players'}{$key};
  if (defined $new) {
    $this->{'_players'}{$key}{'games'} = $new;
    }
  return $this->{'_players'}{$key}{'games'};
  }

sub LoadFileToHash ($$$;$) {
  my $this = shift;
  my $filename = shift;
  my $hashp = shift;
  my $create = shift;

  open my $fh, '<:encoding(utf8)', $filename or return undef;

  my (@fields) = qw(name rating rank expiry games);
  while (<$fh>) {
    chomp;
    if ($. == 1 && !/\d/) {
      @fields = split(/\t/);
      next;
      }
    my %data;
    @data{@fields} = split(/\t/);
    $data{'name'} = uc $data{'name'};
#   warn $data{'name'} if $data{'name'} =~ /POH/;
    $data{'name'} =~ s/,//; # should maybe be part of Ratings::Canonicalise
    $data{'name'} =~ s/\((?:EXP|GM)\)//; # should maybe be part of Ratings::Canonicalise
    my $pdp = $hashp->{$data{'name'}};
    unless ($pdp) {
      if ($create) {
	$hashp->{$data{'name'}} = $pdp = {};
	}
      else {
	next;
        }
      }
    $pdp->{'rd'} = \%data;
#   warn $data{'name'} . ': ' . join(',', %$pdp);
    }
  close $fh;
  }

=item $rs->LoadStateFile();

Load the state of the rating system from the designated file.

=cut

sub LoadStateFile ($) {
  my $this = shift;
  my $type = $this->{'_type'};
  if ($type eq 'homan') { $this->LoadHomanStateFile(); }
  elsif ($type eq 'logistic') { $this->LoadLogisticStateFile(); }
  elsif ($type eq 'nsa') { $this->LoadNSAStateFile(); }
  else { die "Unknown type: $type"; }
  }

=item $rs->LoadHomanStateFile();

Load the state of the rating system from a Homan file, or confess failure.
Internal use only.

=cut

sub LoadHomanStateFile ($) {
  my $this = shift;
  my $filename = $this->{'homan_state_filename'};
  eval "use Ratings::Player";
  confess $@ if $@;

  if (open my $fh, '<:encoding(isolatin1)', $filename) {
    while (<$fh>) {
      chomp;
      confess "Can't parse (1): '$_'" unless length($_) == 51;
      my %param;
      @param{qw(name rating games peak_rating)} = unpack('A36A5A5A5', $_);
      for my $key (qw(rating games peak_rating)) { 
	$param{$key} =~ s/^(?:\s+)(\d+)$/$1/
	  or confess "Can't parse (2: $key): '$param{$key}'";
        }
      if ($param{'name'} =~ s/[=:](.*)//) {
	$param{'membership_number'} = $1;
        }
      $this->AddPlayer($param{'name'}, Ratings::Player->new(%param));
      }
    }
  else {
    confess "Error opening $filename: $!";
    }
  }

=item $rs->LoadLogisticStateFile();

Load the state of the rating system from a logistic file, or confess failure.
Internal use only.

=cut

sub LoadLogisticStateFile ($;$) {
  my $this = shift;
  my $filename = shift;
  $filename = $this->{'logistic_state_filename'} unless defined $filename;
  eval "use Ratings::Player";
  confess $@ if $@;

  if (open my $fh, '<:encoding(isolatin1)', $filename) {
#   warn $filename;
    while (<$fh>) {
      chomp;
#     warn $_;
      my %param;
      @param{qw(name rating games)} = split(/\t/);
      if (my $sub = $this->{'canonicalize_lsfile_player_name'}) {
        $param{'name'} = &$sub($param{'name'});
        }
      die "Can't parse: '$_'" unless (defined $param{'games'}) && $param{'games'} =~ /^\d+$/;
      die "Can't parse: '$_'" unless $param{'rating'} =~ /^[+.\d]+$/;
      $this->AddPlayer(Ratings::Player->new(%param));
      }
    }
  else {
    confess "Error opening $filename: $!";
    }
  }

=item $rs->LoadNSAStateFile();

Load the state of the rating system from an NSA file, or confess failure.
Internal use only.

=cut

sub LoadNSAStateFile ($) {
  my $this = shift;
  my $filename = $this->{'nsa_state_filename'};
  eval "use Ratings::Player";
  confess $@ if $@;

  if (open my $fh, '<:encoding(isolatin1)', $filename) {
#   warn $filename;
    while (<$fh>) {
      chomp;
#     warn $_;
      my %param;
      @param{qw(name rating rank expiry games)} = split(/ *\t */);
      die "Can't parse games ($param{'games'}): '$_'" unless $param{'games'} && $param{'games'} =~ /^\d+$/;
      die "Can't parse rating ($param{'rating'}): '$_'" unless $param{'rating'} =~ /^\d+$/;
      if ($param{'name'} =~ s/[=:](.*)//) {
	$param{'membership_number'} = $1;
        }
      $this->AddPlayer(Ratings::Player->new(%param));
      }
    }
  else {
    confess "Error opening $filename: $!";
    }
  }

=item @round_to_split = $this->MakeRoundToSplit(@splits);

Internal use.
Make a list mapping 0-based round numbers to 0-based split segment indices.

=cut

sub MakeRoundToSplit ($@) {
  my $this = shift;
  my @rts;
  for my $si (0..$#_) {
    my $sp = $_[$si];
    for my $r ($sp->[0]..$sp->[1]) {
      $rts[$r] = $si;
      }
    }
  return @rts;
  }

=item @splits = $this->MakeSplits($nrounds);

Internal use.
Return a list of 0-based first and last rounds for each segment
of a tournament that must be split-rated under NSA rules.

=cut

sub MakeSplits ($$) {
  my $this = shift;
  my $nrounds = shift;
  my $nrounds0 = $nrounds - 1;
  if ($nrounds0 < 16 || !$this->{'use_split_ratings'}) {
    return ([0,$nrounds0]);
    }
  if ($nrounds0 < 35) {
    my $s1 = int($nrounds0/2);
    return ([0,$s1],[$s1+1,$nrounds0]);
    }
  my $s1 = int($nrounds0/3);
  my $s2 = int((2*$nrounds0+1)/3);
  return ([0,$s1],[$s1+1,$s2],[$s2+1,$nrounds0]);
  }

sub Name ($) {
  my $this = shift;
  return $this->{'rating_system'};
  }

=item $key = $rs->PlayerKey($pp);

Compute the internal key corresponding to a TSH player object.

=cut

sub PlayerKey ($$) {
  my $this = shift;
  my $pp = shift;
  my $key = $pp->Name();
  Carp::confess join(';', %$pp) unless defined $key;
  $key = uc $key;
  if (my $sub = $this->{'make_player_key'}) {
    return &$sub($this, $pp, $key);
    }
  $key =~ s/, / /g;
  if (defined $pp->{'membership_number'}) {
    $key .= "\n$pp->{'membership_number'}";
    }
  else {
    # thought about doing the following at first
#   $key =~ s/:([A-Z][A-Z]\d{6})$/\n$1/;
    # we currently use the following, because otherwise a player might have two keys, one with and without the membership number
    $key =~ s/:(.*)$//;
    # eventually need to make the key be the membership number, looked up if necessary
    }
  return $key;
  }

=item $rs->ProcessSpecialEvent($xml);

Update the rating system to include the results of a special event,
such as a player renaming or deletion.

=cut

sub ProcessSpecialEvent ($$) {
  my $this = shift;
  my $xml = shift;
  eval 'use RatingEvent';
  die $@ if $@;
# warn "PSE $xml";
  &RatingEvent::ProcessEvents($xml, $this->{'_players'});
# warn join("\n", grep { /EDWARDS/ } keys %{$this->{'_players'}});
  }

=item $rs->ProcessTournament($tournament[, \%options]);

Update the rating system to include the results of a tournament.

Store results in supplementary player data for this rating system type,
or for the specified type if overridden.

=cut

sub ProcessTournament ($$;$) {
  my $this = shift;
  my $tourney = shift;
  my $optionsp = shift || {};
  my $type = $this->Name();
  my $teams = $this->{'teams'};

  unless ($tourney) { eval 'use Carp'; &confess("no tourney"); }
  my $rating_term_count = $this->RatingTermCount();
  for my $dp ($tourney->Divisions()) {
    $dp->LoadSupplementaryRatings($this, $optionsp);
    $dp->ComputeSupplementaryRatings();
    for my $pp ($dp->Players()) {
      my $newr = $pp->SupplementaryRatingsData($type, 'new');
      my $sub = $this->{'canonicalize_tfile_player_name'};
      unless ($this->{'teams'}) {
        my $name = $pp->Name();
	if ($sub) { $name = &$sub($name); }
#	warn "$sub!$name";
#	die "$sub,$name" if $name =~ /epstein/i;
	$this->Rating($name, $newr);
	if (my $games = $pp->GamesPlayed()) {
	  $this->Games($name, ($this->Games($name)||0)+$games);
	  }
	next;
	}
      # if teams
      my (@names) = $sub
        ? &$sub($pp->Name())
        : $this->CanonicaliseName(undef, $pp->Name());
      my (@newr) = split(/\+/, $newr);
      my $games = $pp->GamesPlayed();
      for my $i (0..$#names) {
        my $name = uc $names[$i];
        $this->Rating($name, join('+', @newr[$i*$rating_term_count..($i+1)*$rating_term_count-1]));
        $this->Games($name, ($this->Games($name)||0) + $games);
        }
      }
    }
  }

=item $rs = new Ratings(%argv);

Create a new object representing a ratings system,
confess if the object cannot be created.
Required arguments: type.
Optional arguments: homan_state_filename logistic_state_filename nsa_state_filename rating_system.

=cut

sub new ($@) { 
  my $proto = shift;
  my (%argv) = @_;
  my $class = ref($proto) || $proto;
  my $this : shared = &share({});
  $this->{'_type'} = 'none';
  bless($this, $class);
  for my $required (qw()) {
    unless (exists $argv{$required}) {
      confess "Missing required argument: $required";
      }
    $this->{$required} = $argv{$required};
    }
  # order is significant: e.g., canonicalizers must come ahead of filenames
  my (@keys) = qw(
    canonicalize_lsfile_player_name
    canonicalize_tfile_player_name
    make_player_key
    homan_state_filename
    logistic_state_filename
    nsa_state_filename
    rating_system
    );
  $this->{'_valid_option_keyshp'} = (defined &TSH::Utility::ShareSafely) 
    ? TSH::Utility::ShareSafely({ map { $_ => 1 } @keys })
    : { map { $_ => 1 } @keys }
    ;

  for my $key (@keys) {
    $this->Option($key, $argv{$key});
    }
  return $this;
  }

=item $old = $rs->Option($key[, $new]);

Get or set an option value.

=cut

sub Option ($$;$) {
  my $this = shift;
  my $key = shift;
  my $new = shift;
  die "Unknown option key: $key" unless $this->{'_valid_option_keyshp'}{$key};
  my $old = $this->{$key};
  if (defined $new) {
    $this->{$key} = $new;
    if ($key eq 'homan_state_filename') {
      $this->{'_type'} = 'homan';
      $this->LoadHomanStateFile();
      }
    elsif ($key eq 'logistic_state_filename') {
      $this->{'_type'} = 'logistic';
      die unless $this->{'canonicalize_lsfile_player_name'};
      $this->LoadLogisticStateFile();
      }
    elsif ($key eq 'nsa_state_filename') {
      $this->{'_type'} = 'nsa';
      $this->LoadNSAStateFile();
      }
    }
  return $old;
  }

=item $r = $rs->Rating($player_key[, $rating[, $name]]);

Set or get a player's current rating.

=cut

sub Rating($$;$$) {
  my $this = shift;
  my $key = shift;
  my $new = shift;
  if (ref($key)) { $key = $this->PlayerKey($key); }
  my $name = shift || $key;
  my $p = $this->{'_players'}{$key};
  Carp::confess unless defined $name;
  if (!defined $p) {
    $this->AddPlayer(
      ($p = Ratings::Player->new(
      'name' => $name,
      'peak_rating' => ($new||0),
      'rating' => ($new||0),
      'games' => 0,
      )));
    }
  elsif (defined $new) {
    $p->{'rating'} = $new;
#   confess "$p->{'name'}: ".join(',',%$p)  unless defined $p->{'peak_rating'};
    $p->{'peak_rating'} = $p->{'rating'} 
      if (!defined $p->{'peak_rating'}) || $this->CompareRatings($p->{'peak_rating'}, $p->{'rating'}) < 0;
    }
  return $p->{'rating'};
  }

sub RatingDifference ($$$) {
  my $this = shift;
  my $a = shift || 0;
  my $b = shift || 0;
  return $a - $b;
  }

sub RatingTermCount ($) { return 1; }

=item $rs->SaveStateFile($fn);

Save the state of the rating system from to the designated file.

=cut

sub SaveStateFile ($$) {
  my $this = shift;
  my $fn = shift;
  my $type = $this->{'_type'};
  if ($type eq 'homan') { $this->SaveHomanStateFile($fn); }
  elsif ($type eq 'logistic') { $this->SaveLogisticStateFile($fn); }
  else { die "Unknown type: $type"; }
  }

=item $rs->SaveHomanStateFile($filename);

Save the state of the rating system from to a Homan file, or confess failure.
Internal use only.

=cut

sub SaveHomanStateFile ($$) {
  my $this = shift;
  my $filename = shift;
  eval "use Ratings::Player";
  confess $@ if $@;

  if (open my $fh, '>:encoding(isolatin1)', $filename) {
    my $psp = $this->{'_players'};
    for my $key (sort keys %$psp) {
      my $p = $psp->{$key};
      my $name = $p->Get('name');
      my $memnum = $p->Get('membership_number');
      $name .= "=$memnum" if defined $memnum;
      my $rating = $p->Get('rating');
      my $games = $p->Get('games');
      my $peak_rating = $p->Get('peak_rating');
#     confess unless defined $p->{'rating'};
#     confess unless defined $p->{'games'};
#     confess unless defined $p->{'peak_rating'};
#     confess unless defined $filename;
#     confess $key unless defined $name;
      printf $fh "%-36s%5s%5s%5s\n", $name, $rating, $games, $peak_rating
        or confess "Error writing to $filename: $!";
      }
    close $fh;
    }
  else {
    confess "Error creating $filename: $!";
    }
  }

=item $rs->SaveLogisticStateFile($filename);

Save the state of the rating system from to a logistic file, or confess failure.
Internal use only.

=cut

sub SaveLogisticStateFile ($$;$) {
  my $this = shift;
  my $filename = shift;
  my $optionsp = shift || {};
  eval "use Ratings::Player";
  confess $@ if $@;

  if (open my $fh, '>:encoding(isolatin1)', $filename) {
    if ($optionsp->{'header'}) {
      print $fh $optionsp->{'header'};
      }
    my $psp = $this->{'_players'};
    for my $key (sort keys %$psp) {
      my $p = $psp->{$key};
      Carp::confess join(',', %$p) if $key =~ /ARRAY/;
#     my $name = $p->Get('name');
      my $name = $key;
      my $memnum = $p->Get('membership_number');
      my $rating = $p->Get('rating');
      my $games = $p->Get('games');
      Carp::confess $name if $name =~ /\n/;
#     warn $name if $name =~ /EDWARDS G/;
      if ($rating || $games) {
	print $fh join("\t", $name, $rating, $games), "\n"
	  or confess "Error writing to $filename: $!";
        }
      else {
	warn "Not writing null user ($p) $name to $filename.";
        }
      }
    close $fh;
    }
  else {
    confess "Error creating $filename: $!";
    }
  }

=item $s = $rs->RenderRating($value, \%options);

Render a rating value according to the specified options, which may be:

alpha - render alphabetical ratings

=cut

sub RenderPerformanceRating ($$$) { 
  my $this = shift;
  my $a = shift || 0;
  my $options = shift || {};
  return $this->RenderRating($a, $options); 
  }

sub RenderRating ($$$) {
  my $this = shift;
  my $a = shift || 0;
  my $options = shift || {};
  if ($options->{'alpha'}) {
#   my $i = int(@{$options->{'alpha'}{'values'}} * ($options->{'alpha'}{'max'} - $a) / ($options->{'alpha'}{'max'} - $options->{'alpha'}{'min'}) + 0.00001);
#   warn "$a -> $i: int(".@{$options->{'alpha'}{'values'}}."*($options->{'alpha'}{'max'}-$a)/($options->{'alpha'}{'max'}-$options->{'alpha'}{'min'})+0.00001) $options->{'alpha'}{'values'}[$i]\n" unless $::gAlreadyWhined{$a}++;
    my $i = $#{$options->{'alpha'}{'values'}} - int($a * @{$options->{'alpha'}{'values'}} / ($options->{'alpha'}{'max'} - $options->{'alpha'}{'min'}) + 0.00001);
#   warn "$a -> $i: int($a*".@{$options->{'alpha'}{'values'}}."/($options->{'alpha'}{'max'}-$options->{'alpha'}{'min'})+0.00001) $options->{'alpha'}{'values'}[$i]\n" unless $::gAlreadyWhined{$a}++;
    $i = $#{$options->{'alpha'}{'values'}} if $i > $#{$options->{'alpha'}{'values'}};
    $i = 0 if $i < 0;
    return $options->{'alpha'}{'values'}[$i];
    }
  return $a;
  }

sub RenderRatingDifference ($$$$) {
  my $this = shift;
  my $a = shift || 0;
  my $b = shift || 0;
  my $options = shift || {};
  return $options->{'style'} eq 'html'
    ? TSH::Utility::FormatHTMLSignedInteger($a - $b) 
    : sprintf("%+d", $a - $b);
  }

sub RoundNewRatings ($$$) {
  my $this = shift;
  my $psp = shift;
  my $key_usage_p = shift;
  my $newr_k = $key_usage_p->{'newr'};

  if ($this->{'teams'}) {
    for my $p (@$psp) { 
      my $newrp = $p->{$newr_k};
      for my $r (@$newrp) { $r = int(0.5 + $r) }
      }
    }
  else {
    for my $p (@$psp) { 
#     warn "rounding $p->{name} newr: $p->{$newr_k}\n" if $p->{'name'} =~ $debug_name_pattern;
      $p->{$newr_k} = int(0.5 + $p->{$newr_k});
      }
    }
  }

# binary search
sub Search ($$$$) { 
  my $this = shift;
  my $sub = shift;
  my $low = shift;
  my $high = shift;
  my $mid;
  while ($high - $low > 1) {
    $mid = int(($low+$high)/2);
    no strict 'refs';
    if (&$sub($mid) < 0) { $low = $mid; } else { $high = $mid; }
    }
  $mid;
  }

sub SetFeedbackToZero ($$) {
  my $this = shift;
  my $psp = shift;
  for my $p (@$psp) { $p->{'xrat_feed'} = 0; }
  }

sub SetMaximumIterations ($$) {
  my $this = shift;
  my $n = shift;
  
  $this->{'maximum_iterations'} = $n;
  }

=item $type = $rs->Type();

Return a string identifying the rating system type. 

=cut

sub Type ($) {
  my $this = shift;
  return $this->{'type'};
  }

=item $r->UseAccelerationBonuses($scale);

Specify whether acceleration bonuses should be used: players
whose ratings are due to increase by more than an average of
five points per round earn a bonus of excess * $scale

=cut

sub UseAccelerationBonuses ($$) { 
  my $this = shift;
  my $scale = shift;
  $this->{'use_acceleration_bonuses'} = $scale;
# if ($scale) { $this->{'use_club_divisor'} = 0; }
  }

=item $r->UseClubDivisor($boolean);

Specify whether club multipliers are to be used: ratings
changes are reduced by a factor of three, and acceleration
bonuses are disabled.

=cut

sub UseClubDivisor ($$) { 
  my $this = shift;
  my $yesno = shift;
  $this->{'use_club_divisor'} = $yesno;
  if ($yesno) {
    $this->UseAccelerationBonuses(0);
    }
  }

=back

=cut

1;
