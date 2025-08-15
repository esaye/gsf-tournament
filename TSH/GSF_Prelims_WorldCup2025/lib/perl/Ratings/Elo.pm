#!/usr/bin/perl

# Copyright (C) 2008-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Ratings::Elo;

use strict;
use warnings;
use Carp;
use threads::shared;
# $SIG{__WARN__} = sub () { confess $_[0]; };

BEGIN {
  use Exporter ();
  use vars qw(
    $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
    );
  $VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
  @ISA = qw(Exporter Ratings);
  @EXPORT = qw();
  @EXPORT_OK = qw(
    erf erf2 outcome outcome_cached
    );
  %EXPORT_TAGS = ();
  }


## my $debug_name_pattern = qr[ADAMS,? BRUCE]i;
#my $debug_name_pattern = qr[.]i;
my @nsa_win_probs;

=head1 SYNOPSIS

  use Ratings::Elo;

=head1 ABSTRACT

This Perl module contains code for performing Elo rating calculations,
and is used by tourney.pl, tsh, MarlDOoM and the NSA rating system.

It is littered with legacy compatibility code and poor demarcation
of internal and public routines.  The module is very slowly being
cleaned up.

Many routines manipulate lists of player data hashes.  For the
sake of generality, the keys used to find data in those hashes are
passed in their own hashes ("key usage maps").  Temporary data may
be stored in player data hashes under keys beginning with 'xrat_'.

=cut

=head1 DESCRIPTION

=head2 Methods

=cut

sub CalculateHomanPR ($$$$$$);
sub CalculateRatings ($$$$$$$);
sub ConvertExcessToPoints ($$$$);
sub Erf ($$);
sub Erf2 ($$);
sub ExpectAustralian ($$$);
sub ExpectLogistic ($$$);
sub ExpectWESPA ($$$);
sub Multiplier ($$$);
sub Outcome ($$$);
sub OutcomeCached ($$);
sub RateNewcomers ($$$$$);
sub RateNewcomersCorrectly ($$$$$$);
sub RateNewcomersHoman ($$$$$$);
sub RateVeterans ($$$$$);
sub SetupNewcomerPR ($$$$$$);

my (%rating_system_defaults) = (
  'aus' => {
    'expectation_function' => 'Ratings::Elo::ExpectAustralian',
    'multiplier_function' => 'Ratings::Elo::Multiplier20',
    'use_homan_bugs' => 0,
    'use_split_ratings' => 0,
    'use_acceleration_bonuses' => 0,
    'use_feedback' => 0,
    },
  'deu' => {
    'class' => 'Ratings::Elo::Deutsch',
    'cap_all_newcomers' => 1,
    'use_doom_multipliers' => 1,
    'use_homan_bugs' => 0,
    },
  'elo' => {
    'use_doom_multipliers' => 1,
    'use_homan_bugs' => 0,
    },
  'ken' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'use_homan_bugs' => 0,
    },
  'nsa' => {
    'use_homan_bugs' => 1,
    },
  'nsa lct' => {
    'use_acceleration_bonuses' => 0,
    'use_club_divisor' => 1,
    'use_homan_bugs' => 1,
    },
  'naspa-csw' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'use_homan_bugs' => 0,
    },
  'naspa-csw lct' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'use_acceleration_bonuses' => 0,
    'use_club_divisor' => 1,
    'use_homan_bugs' => 0,
    },
  'naspa2024' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'use_homan_bugs' => 0,
    'use_split_lifeg' => 1,
    },
  'naspa2024 lct' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic', 'use_acceleration_bonuses' => 0,
    'use_club_divisor' => 1,
    'use_homan_bugs' => 0,
    'use_split_lifeg' => 1,
    },
  'nor' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'use_homan_bugs' => 0,
    },
  'nsa2008' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'floor' => 1,
    'use_homan_bugs' => 0,
    },
  'nsa2008 lct' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'floor' => 1,
    'use_acceleration_bonuses' => 0,
    'use_club_divisor' => 1,
    'use_homan_bugs' => 0,
    },
  'nsa2008 lct rcalc' => {
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'floor' => 0,
    'use_acceleration_bonuses' => 0,
    'use_club_divisor' => 1,
    'use_feedback' => 0,
    'use_homan_bugs' => 0,
    },
  'nsa2008 rcalc' => { # used by rcalc.pl
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'floor' => 0,
    'use_feedback' => 0,
    'use_homan_bugs' => 0,
    },
  'pak' => {
    'expectation_function' => 'Ratings::Elo::ExpectAustralian',
    'floor' => 500,
    'multiplier_function' => 'Ratings::Elo::Multiplier20',
    'use_homan_bugs' => 0,
    'use_split_ratings' => 0,
    'use_acceleration_bonuses' => 0,
    'use_feedback' => 0,
    },
  'sudoku' => {
    'expectation_function' => 'Ratings::Elo::ExpectAustralian',
    'use_homan_bugs' => 0,
    },
  'thai' => {
    'unrated_ties' => 1,
    'expectation_function' => 'Ratings::Elo::ExpectLogistic',
    'use_homan_bugs' => 0,
    },
  'wespa' => {
    'expectation_function' => 'Ratings::Elo::ExpectWESPA',
    'ignore_boundaries' => 1,
    'use_acceleration_bonuses' => 2/3,
    'use_club_divisor' => 0,
    'use_homan_bugs' => 0,
    'use_split_ratings' => 0,
    },
  );

=over 4

=cut

=item $elo = new Ratings::Elo(%options);

Object constructor.

=cut

sub new ($@) { 
  my $proto = shift;
# confess if @_ % 2;
  my (%options) = @_;
  my $class = ref($proto) || $proto;
  my $this : shared = new Ratings(%options);
  bless($this, $class);
  $this->{'cache'} = &share({});
  $this->{'epsilon'} = 1E-10;
  $this->{'maximum_iterations'} = 50;
  $this->{'scale'} = 400;
  $this->{'use_acceleration_bonuses'} = 1;
  $this->{'use_feedback'} = 1;
  $this->{'use_club_divisor'} = 0;
# The NSA ratings code contains a bug affecting players whose rating
# drops from exactly 1800 or 2000.
  $this->{'use_homan_boundary_bug'} = 1;
# The NSA uses a noniterative approximation of performance ratings.
  $this->{'use_homan_pr'} = 1;
# The NSA caps ratings diff at 700 and computes expectation to seven digits
  $this->{'use_homan_expectation'} = 1;
# The NSA sometimes compounds acceleration on feedback
  $this->{'use_homan_feedback_bug'} = 1;
# toggle all homan bugs on or off
  $this->{'use_homan_bugs'} = undef;
# Update life games count at each split
  $this->{'use_split_lifeg'} = 0;
# Split rated tournaments every 16 games
  $this->{'use_split_ratings'} = 1;
# expectation function for Elo-like systems
  $this->{'expectation_function'} ='Ratings::Elo::OutcomeCached';
# multiplier function for Elo-like systems
  $this->{'multiplier_function'} = 'Ratings::Elo::Multiplier';
# WESPA ratings don't change multipliers at boundaries
  $this->{'ignore_boundaries'} = 0;
# choose defaults for a known rating system
  $this->{'rating_system'} = 'nsa';

  for my $optional (qw(epsilon maximum_iterations scale 
    use_doom_multipliers
    use_acceleration_bonuses 
    use_club_divisor
    use_homan_boundary_bug use_homan_pr use_homan_feedback_bug
    use_homan_expectation
    use_homan_bugs
    use_split_ratings
    expectation_function
    multiplier_function
    ignore_boundaries
    rating_system
    )) {
    if (exists $options{$optional}) {
      $this->{$optional} = $options{$optional};
      delete $options{$optional};
      }
    }
# if (%options) { die "Unknown options: " . join(', ', keys %options); }
  if (my $system_defaults = $rating_system_defaults{$this->{'rating_system'}}) {
    if (my $class = $system_defaults->{'class'}) {
      eval "use $class";
      die "Cannot load $class: $@" if $@;
      my $class_defaults = $class->GetParameters();
      for my $key (keys %$class_defaults) {
	$system_defaults->{$key} = $class_defaults->{$key};
	}
      }
    for my $key (keys %$system_defaults) {
      $this->{$key} = $system_defaults->{$key};
      }
    }
  else { confess "no defaults for $this->{'rating_system'}"; }
  if (defined $this->{'use_homan_bugs'}) {
    for my $key (qw(
      use_homan_boundary_bug use_homan_pr use_homan_feedback_bug
      use_homan_expectation
      )) {
      $this->{$key} = $this->{'use_homan_bugs'};
#     warn "$key = $this->{'use_homan_bugs'}";
      }
    }
  return $this;
  }

=head1 SUBROUTINES

=over 4

=item $pr = $elo->CalculateCorrectPR($rated_games, $rated_wins, \@opponent_ratings);

Public use.
Calculate the performance rating for a given record, using a binary search.

=cut

sub CalculateCorrectPR ($$$$$) {
  my $this = shift;
  my $games = shift;
  my $wins = shift;
  my $orp = shift;

  die "undefined games" unless defined $games;
  if ($games == 0) { return 0; }
  if ($wins <= 0) { $wins = $games/20; }
  elsif ($wins >= $games) { $wins = $games*0.95; }

  my $esub = $this->{'expectation_function'};
  my $code = 'sub ($) {';
  for my $or (@$orp) {
    no strict 'refs';
    $code .= "&$esub(\$this,\$_[0],$or)+";
    }
  $code .= "-($wins);}";
  my $isub = eval $code;
# warn $code;
  die $@ if $@;
  my $pr = $this->Search($isub, 0, 3000);
# warn $pr;
  return $pr;
  }

=item $elo->CalculateExcess(\@ps, $pn, $first_round_0, $last_round_0, $key_usage_p);

Internal use.
Calculate how many games over their expectation the given player won
over the given range of rounds.  Keys used in player hashes:

ewins: earned wins in segment

pairings: 0-based list of opponents (-1 indicates bye)

=cut

sub CalculateExcess ($$$$$$) {
  my $this = shift;
  my $psp = shift;
  my $pn = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  my $p = $psp->[$pn];

# warn "$pn: $p->{'name'} $first_round_0..$last_round_0";
  my $excess = $p->{$key_usage_p->{'ewins'}};
  my $pairings_k = $key_usage_p->{'pairings'};
  my $scores_k = $key_usage_p->{'scores'};
  my $esub = $this->{'expectation_function'};
  for my $r ($first_round_0..$last_round_0) {
    my $on = $p->{$pairings_k}[$r];
#   warn "pairings for $p->{'name'}: $p->{$pairings_k}[$r]";
#   warn "$r @{$p->{$pairings_k}} @{$p->{$scores_k}}";
#   warn "round0 $r #$p->{$key_usage_p->{'id'}} $p->{'xrat_effr'} #$psp->[$on]->{$key_usage_p->{'id'}} $psp->[$on]->{'xrat_effr'}";
    next if (!defined $on) or $on < 0 or (!defined $p->{$scores_k}[$r]);
    {
      no strict 'refs';
    $excess -= 
      &$esub($this, $p->{'xrat_effr'}, $psp->[$on]->{'xrat_effr'});
    }
    }
#    Carp::cluck "$p->{'name'} ($p->{$key_usage_p->{'oldr'}}) has excess: $excess\n" if $p->{'name'} =~ $debug_name_pattern;
#    die "$p->{'name'} ($p->{$key_usage_p->{'oldr'}}) has excess $excess of earned wins $p->{$key_usage_p->{'ewins'}}\n";
  if (my $excwins = $key_usage_p->{'excwins'}) {
    $p->{$excwins} = $excess;
    }
  return $excess;
  }

=item $pr = $elo->CalculateHomanPR($rated_games, $is_new, $rated_wins, $sum_opponent_ratings, $maximum_opponent_rating);

Public use.
Calculate the Homan pseudo-performance rating, a float value.
Returns a rounded integer value, unlike the original float.

=cut

sub CalculateHomanPR ($$$$$$) {
  my $this = shift;
  my $is_new = shift;
  my $games = shift;
  my $wins = shift;
  my $sumor = shift;
  my $maxor = shift;
  die unless defined $maxor;

  if ($games == 0) { return 0; }
  my $aor = $sumor/$games;
  my $wr = $wins/$games;

  if ($is_new) {
    if ($wr == 0) { $wr = 0.05; }
    elsif ($wr == 1) { $wr = 0.95; }
    }
# warn "$is_new $games $wins $sumor $maxor $aor $wr";
# warn "$wins $wr $aor";

  # 20081108 Homan actually does a linear search, which might be off by 1 from the binary search
# my $low = 1; my $high = 700; my $target;
# if ($wr > 0.5) { $target = $wr; } else { $target = 1 - $wr; }
# while ($high - $low > 1) { my $mid = int(($low+$high)/2); if ($this->OutcomeCached($mid) > $target) { $high = $mid; } else { $low = $mid; } }
# my $pr = int($aor+0.5) + ($wr > 0.5 ? $high : -$high);
  my $pr;
  my $esub = $this->{'expectation_function'};
  if ($wr < 0.5) {
    my $diff;
    no strict 'refs';
    for ($diff = 0; &$esub($this,$diff,0) < 1-$wr && $diff < 700; $diff++) { }
    $pr = $aor - $diff;
    }
  else {
    my $diff;
    no strict 'refs';
    for ($diff = 0; &$esub($this,$diff,0) < $wr && $diff < 700; $diff++) { }
    $pr = $aor + $diff;
    }
  if ($is_new) {
    if ($pr < 500) { $pr = 500; }
    if ($maxor) {
      my $limit = $maxor + 400 * $wins / $games; # not clipped to [0.05,0.95]
      if ($pr > $limit) { $pr = $limit; }
      }
    }

  $pr = int($pr+0.5);
# warn $pr;
  return $pr;
  }

=item $elo->CalculatePerformanceRatings(\@ps, $first_round_0, $last_round_0, $key_usage_p);

Calculate performance ratings for veteran players using binary search.
Player hash key usage:

ewins: earned wins in segment (input)

id: player id (0-based index in \@ps)

lifeg: lifetime games played

newr: newly earned regular rating (input)

oldr: previous regular rating (input)

perfr: segment performance rating

pairings: 0-based list of opponents (-1 indicates bye)

rgames: rated games in segment

=cut

sub CalculatePerformanceRatings ($$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  my $ewins_k = $key_usage_p->{'ewins'};
  my $newr_k = $key_usage_p->{'newr'};
  my $oldr_k = $key_usage_p->{'oldr'};
  my $pairings_k = $key_usage_p->{'pairings'};
  my $perfr_k = $key_usage_p->{'perfr'};
  my $rgames_k = $key_usage_p->{'rgames'};

  for my $p (@$psp) { 
    next unless $p->{$oldr_k};
    my @or;
    for my $r0 ($first_round_0..$last_round_0) {
      my $on = $p->{$pairings_k}[$r0];
      next if (!defined $on) || $on < 0;
      my $op = $psp->[$on];
      # use new opp rating for newbies, old rating for veterans
#     die "$newr_k;".join(';', %$op) unless $op->{$oldr_k};
      my $or = $op->{$op->{$oldr_k} ? $oldr_k : $newr_k};
      push(@or, $or);
      }
#   warn "$p->{id} @or";
#   warn $this->{'use_homan_pr'};
    if ($this->{'use_homan_pr'}) {
      my $sumor = 0;
      my $maxor = 0;
      for my $or (@or) { 
	$sumor += $or;
	$maxor = $or if $maxor < $or;
        }
      $p->{$perfr_k} = $this->CalculateHomanPR(!$p->{$oldr_k}, $p->{$rgames_k}, $p->{$ewins_k}, $sumor, $maxor);
#     warn "$p->{'name'} $p->{$perfr_k} $p->{$rgames_k} $p->{$ewins_k} $sumor $maxor";
      }
    else {
#     warn $rgames_k; die join(';', %$p);
      $p->{$perfr_k} = $this->CalculateCorrectPR($p->{$rgames_k}, $p->{$ewins_k}, \@or);
      }
#   warn "$p->{'name'}: $p->{$perfr_k},$p->{$ewins_k},$p->{$rgames_k},@or";
    }
  }

=item $elo->CalculateRatings($players, $oldr_key, $first_round, $newr_key, $last_round, $ewins_key);

Deprecated in favour of CalculateSplitRatings.

=cut

=for deprecated

sub CalculateRatings ($$$$$$$) {
  my $this = shift;
  my $psp = shift; # list of players
  my $old_k = shift; # player hash key for old rating
  my $first_round_1 = shift; # first 1-based round to rate
  my $new_k = shift; # player hash key for new rating
  my $last_round_1 = shift; # last 1-based round to rate
  my $ewins_k = shift; # player hash key for earned wins
  my $first_round_0 = $first_round_1 - 1;
  my $last_round_0 = $last_round_1 - 1;

  if ($last_round_0 < $first_round_0) {
    $this->CopyField($psp, $new_k, $old_k);
    return;
    }
  $this->CountEWins($psp, $first_round_0, $last_round_0, {
    'ewins' => 'xrat_ewins',
    'rgames' => 'xrat_rgames',
    # remaining values are assumed by the old interface
    'pairings' => 'opps', 
    'scores' => 'scores', 
    });
  $this->CalculateSegmentRatings($psp, $first_round_0, $last_round_0, {
    'ewins' => 'xrat_ewins',
    'newr' => $new_k,
    'oldr' => $old_k,
    'rgames' => 'xrat_rgames',
    # remaining values are assumed by the old interface
    'id' => 'id', 
    'lifeg' => 'totalg', 
    'pairings' => 'opps', 
    'scores' => 'scores', 
    });
  }

=cut

=item $elo->ConvertExcessToPoints($p, $excess, $key_usage_p);

Internal use.
Convert excess wins to ratings points.  Keys used in player hashes:

lifeg: lifetime games played (read-only)

newr: post-segment rating (updated)

=cut

sub ConvertExcessToPoints ($$$$) {
  my $this = shift;
  my $p = shift;
  my $excess = shift;
  my $key_usage_p = shift;
  my $life_k = $key_usage_p->{'lifeg'} || die "need lifeg key";
  my $newr_k = $key_usage_p->{'newr'} || die "need newr key";

# warn "$p->{name} $life_k $p->{$life_k}";
  my $msub = $this->{'multiplier_function'};
  my $newr = $p->{$newr_k};
  while ($excess) {
    no strict 'refs';
    my $starting_rating = $newr;
    my $starting_multiplier = &$msub($this, $p->{$life_k}, $starting_rating);
#       $r = int(0.5 + $starting_rating + $multiplier * $excess);
    my $r = $starting_rating + $starting_multiplier * $excess; # 2002
# warn "$p->{'name'}: $excess $starting_rating $r\n" if $p->{name} =~ /liebfried/i;
    # If the whole rating adjustment can be made within one multiplier band
    if ($this->{'ignore_boundaries'} ||
      $starting_multiplier == &$msub($this, $p->{$life_k}, $r)) 
      # make the adjustment and return
      { 
	$newr = $r; 
#       warn "$p->{'name'} is now $r (mult=$starting_multiplier, lifeg=$p->{$life_k}, sys=$this->{'rating_system'}, no boundaries)" if $p->{'name'} =~ $debug_name_pattern;
	last; 
      }
    # Otherwise, compute just the adjustment to the boundary of the band.
    my $boundary;
    if ($starting_rating < 1800) { $boundary = 1800; }
    elsif ($starting_rating == 1800 && $excess < 0 && $this->{'use_homan_boundary_bug'}) 
      { 
	$newr = $r; 
#       warn "$p->{'name'} is now $r (no boundaries)" if $p->{'name'} =~ $debug_name_pattern;
	last; 
      }
    elsif ($starting_rating < 2000) {
      $boundary = $excess > 0 ? 2000 : 1799;
      }
    elsif ($starting_rating == 2000 && $excess < 0 && $this->{'use_homan_boundary_bug'}) {
      if ($r < 1799) { $boundary = 1799; }
      else { 
	$newr = $r; 
#       warn "$p->{'name'} is now $r (no boundaries)" if $p->{'name'} =~ $debug_name_pattern;
	last;
        }
      }
    else {
      $boundary = 1999;
      }
    $excess -= ($boundary - $starting_rating) / $starting_multiplier;
    $newr = $boundary;
#  warn "$p->{'name'} at boundary $boundary, excess is $excess" if $p->{'name'} =~ $debug_name_pattern;
    }
  if ($this->{'use_club_divisor'}) {
    my $change = $newr - $p->{$newr_k};
    $p->{$newr_k} += $change / 3;
#    warn "Dividing change $change by three" if $p->{'name'} =~ $debug_name_pattern;
    }
  else {
    $p->{$newr_k} = $newr;
    }
  }

=item $y = $elo->Erf($x)

Calculate normalized error function.

=cut

sub Erf ($$) { 
  my $this = shift;
  my $x = shift;
  return $this->Erf2($x/1.414213562373095); 
  }

=item $y = $elo->Erf2($x)

Calculate unnormalized error function.

=cut

sub Erf2 ($$) { 
  my $this = shift;
  my $x = shift;
  $x >= 4 ? return 1 : $x <= -4 ? return 0 : 0;
  my ($n,$sum,$term,$x2) = (0, 0.5, $x/1.772453850905516, $x*$x);
  while (abs($term) > $this->{'epsilon'}) {
    $n++; $sum += $term; $term *= - ($x2 * ($n+$n-1))/(($n+$n+1) * $n); 
    }
  $sum;
  }

sub Expect ($$$) {
  my $this = $_[0];
  my $sub = $this->{'expectation_function'};
  return do { no strict 'refs'; &$sub(@_); };
  }

sub ExpectAustralian ($$$) {
  my $rs = shift;
  my $a = shift;
  my $b = shift || 0;
  my $e = (50+($a-$b)/12)/100;
  $e = $e > 0.95 ? 0.95 : $e < 0.05 ? 0.05 : $e;
# warn "$a-$b: $e";
  return $e;
  }

sub ExpectLogistic ($$$) {
  my $rs = shift;
  my $a = shift;
  my $b = shift || 0;
  return 1 - 1/(1+exp(0.0031879*($a-$b)));
  }

sub ExpectWESPA ($$$) {
  my $rs = shift;
  my $a = shift;
  my $b = shift || 0;
  my $e = 1/(1 + exp(($b-$a)/172));
  return $e;
  }

=item $multiplier = $this->Multiplier($games, $rating);

Return the appropriate multiplier to use for a player who has
played $games games and has a pretournament rating of $rating.

=cut

sub Multiplier ($$$) { 
  my $this = shift;
  my $games = shift || 0;
  my $rating = shift || 0;
  $games < 0 ? 0 : 
    ($games < 50
      ? $rating < 1800 ? 30 : $rating < 2000 ? 24 : 15
      : $rating < 1800 ? 20 : $rating < 2000 ? 16 : 10);
  }

sub Multiplier20 { 20; }

=item (E(win),E(loss)) = $elo->Outcome(rating1, rating2)

Return the expectation of a win or loss for players with the
given ratings.  Use only with oldstyle Homan ratings.

=cut

sub Outcome ($$$) { 
  my $this = shift;
  my $r1 = shift;
  my $r2 = shift;
  my($e) = $this->Erf2(($r1-$r2)/$this->{'scale'}); 
  return ($e, 1-$e);
  }

=item  (E(win)) = $elo->OutcomeCached(difference in ratings)

Return the expectation of a win given a difference in player ratings.
Consult a cache to trade memory for speed.  Use only with oldstyle 
Homan ratings.

=cut

sub OutcomeCached ($$) { 
  my $this = shift;
  my $r1 = shift;
  my $r2 = shift||0;
  Carp::confess unless defined $r1;
  my $d = $r1 - $r2;
  if ($this->{'use_homan_expectation'}) {
    if ($d > 700) { $d = 700; }
    elsif ($d < -700) { $d = -700; }
    return $d >= 0 ? $nsa_win_probs[$d] : 1-$nsa_win_probs[-$d];
#   my $o = $d >= 0 ? $nsa_win_probs[$d] : 1-$nsa_win_probs[-$d];
#   warn "$o: $d";
#   return $o;
    }
  else {
    return $this->{'cache'}{$d} || ($this->{'cache'}{$d}=$this->Erf2($d/400));
    }
  }

sub RateDivision ($@) {
  my $this = shift;
  my (%argh) = @_;
  my $dp = $argh{'division'};
  my $r0 = $argh{'r0'};
  $this->{'current_tournament'} = $dp->Tournament();
  my $allow_gaps = $argh{'allow_gaps'};

  # prepare CalculateSplitRatings arguments - ugh
  my (@ps) = $dp->MakeRatingsInput($r0, {'allow_gaps' => $allow_gaps});

  my $maxr = $dp->MaxRound0();
  if (defined $maxr) { $maxr++; }
  else { $maxr = $dp->MostScores(); }

  $this->CalculateSplitRatings(\@ps, $maxr, {
    'ewins' => 'ewins',
    'excwins' => 'excwins',
    'lifeg' => 'lifeg',
    'newr' => 'newr',
    'oldr' => 'oldr',
#   'perfr' => 'perfr', # 2012-03-29
    'rgames' => 'rgames',
    'pairings' => 'pairings',
    'scores' => 'scores',
    'splitr' => 'splitr',
    'id' => 'id', });
  for my $p (@ps) {
    my $pp = $dp->Player($p->{'id'});
    $pp->NewRating($r0, $p->{'newr'});
    my $excwins = 0;
    for (my $i=0; defined $p->{"excwins$i"}; $i++) {
      $excwins += $p->{"excwins$i"};
      }
#     warn $pp->{'name'}.' '. $excwins;
    $pp->GetOrSetEtcScalar('excwins', $excwins);
    }
  }

=item $elo->RateDivisionSupplementary(%argv);

Alternate version of RateDivision used for producing extra
details useful in administering a rating system.

=cut

sub RateDivisionSupplementary ($@) {
  my $this = shift;
  my (%argh) = @_;
  my $dp = $argh{'division'};
  $this->{'current_tournament'} = $dp->Tournament();

  my $maxr0 = $dp->MaxRound0();
  unless (defined $maxr0) { $maxr0 = $dp->MostScores()-1; }
  my $type = $this->Name();

  my (@ps);
  for my $p ($dp->Players()) {
    my $id = $p->ID();
    $ps[$id-1] = {
      'name' => $p->Name(),
      'oldr' => $p->SupplementaryRatingsData($type, 'old'),
      'pairings' => [ map { $_-1 } @{$p->{'pairings'}} ],
      'scores' => $p->{'scores'},
      'lifeg' => $p->SupplementaryRatingsData($type, 'games'),
      'id' => $id,
      'p' => $id,
      };
    }

  $this->CalculateSplitRatings(\@ps, $maxr0+1, {
    'ewins' => 'ewins',
    'excwins' => 'excwins',
    'lifeg' => 'lifeg',
    'newr' => 'newr',
    'oldr' => 'oldr',
    'perfr' => 'perfr',
    'rgames' => 'rgames',
    'pairings' => 'pairings',
    'scores' => 'scores',
    'splitr' => 'splitr',
    'id' => 'id',
    });

  for my $pp ($dp->Players()) {
    my $p = $ps[$pp->ID()-1];
    $pp->SupplementaryRatingsData($type, 'new', $p->{'newr'});
    my $i;
#   warn join(',', %$p);
    for ($i=0;$i<=2; $i++) {
      my $i1 = $i+1;
      my $i_1 = $i-1;
      last if $i && !defined $p->{'splitr'.$i};
      $pp->SupplementaryRatingsData($type, "mid$i", $p->{"splitr$i"}) if $i > 0;
      $pp->SupplementaryRatingsData($type, "perf$i", $p->{"perfr$i_1"}) if $i > 0;
      $pp->SupplementaryRatingsData($type, "games$i1", $p->{"rgames$i"});
      }
    $pp->SupplementaryRatingsData($type, 'nseg', $i-1);
    $pp->SupplementaryRatingsData($type, 'perf', $p->{'perfr'.($i-1)});
#   warn join(',', @{$pp->{'etc'}{'rating_nsa2008'}});
    }
  }

=item $elo->RateNewcomers(\@ps, $first_round_0, $last_round_0, $key_usage_p);

Internal use.
Determine initial ratings for all unrated players, based on results
from the given rounds.
Keys used in player hashes:

id: player id (0-based index in \@ps)

newr: post-segment ratings

oldr: pre-segment ratings

ewins: earned wins in segment

pairings: 0-based list of opponents (-1 indicates bye)

rgames: rated games in segment

scores: 0-based list of scores

=cut

sub RateNewcomers ($$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  if (my @unrated = grep { !$_->{$key_usage_p->{'oldr'}} } @$psp) {
    if ($this->{'use_homan_pr'}) {
      $this->RateNewcomersHoman($psp, $first_round_0, $last_round_0, 
        \@unrated, $key_usage_p);
      }
    else {
      $this->RateNewcomersCorrectly($psp, $first_round_0, $last_round_0,
        \@unrated, $key_usage_p);
      }
    # new rating and effective rating are last iterated performance rating
    $this->CopyField(\@unrated, 'xrat_effr', 'xrat_curr');
    $this->CopyField(\@unrated, $key_usage_p->{'newr'}, 'xrat_curr');
    }
  }

=item $elo->RateNewcomersCorrectly(\@ps, $first_round_0, $last_round_0, $key_usage_p);

Internal use.
Determine initial ratings for all unrated players (saved in key
xrat_newpr), based on results
from the given rounds, using iterated performance ratings.
Keys used in player hashes:

id: player id (0-based index in \@ps)

oldr: pre-segment ratings

ewins: earned wins in segment

pairings: 0-based list of opponents (-1 indicates bye)

rgames: rated games in segment

scores: 0-based list of scores

=cut

sub RateNewcomersCorrectly ($$$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $unratedp = shift;
  my $key_usage_p = shift;
  my $id_k = $key_usage_p->{'id'};
  $this->SetupNewcomerPR($psp, $first_round_0, $last_round_0, $unratedp, $key_usage_p);
  my $pairings_k = $key_usage_p->{'pairings'};
  my $scores_k = $key_usage_p->{'scores'};
  my $oldr_k = $key_usage_p->{'oldr'};
  
  # keep updating 'xrat_curr' until we attain stability
  my $i;
  for ($i = 0; $i < $this->{'maximum_iterations'}; $i++) {
#   warn "i=$i \$#\$psp=$#$psp";
    my $changed = 0;
    for my $p (@$unratedp) {
      next unless $p->{$key_usage_p->{'rgames'}};
#     $::SIG{__WARN__} = sub () { confess join("\n", @_); };
#	my $r = &main'search4($p->{'xrat_iprsub'}, 0, 3000, 0.1);
#     print STDERR "$p->{'id'}: ? " . join(",",map {$_->{'xrat_curr'}||'?'}@$psp) . "\n";
      my $r = $this->Search($p->{'xrat_iprsub'}, 0, 3000);
#     print STDERR "$p->{'id'}: $r\n";
      if ($r < 500) { $r = 500; }
      my $this_last_0 = $#{$p->{$scores_k}};
      $this_last_0 = $last_round_0 if $last_round_0 < $this_last_0;
      my $maxuor = 0; # maximum unrated opponent (current) rating
      my $maxror = 0; # maximum rated opponent (pre) rating
      # the following block rewritten several times around 2011-09-15
      for my $r ($first_round_0..$this_last_0) {
	my $on = $p->{$pairings_k}[$r];
	next if $on == -1;
	my $op = $psp->[$on];
	if ($op->{$oldr_k}) {
	  $maxror = $op->{$oldr_k} if $op->{$oldr_k} > $maxror;
	  next;
	  }
	if (defined $op->{'xrat_curr'}) {
	  $maxuor = $op->{'xrat_curr'} if $op->{'xrat_curr'} > $maxuor;
	  }
	}
      # If at least one opponent was rated, stay close to their rating.
      # If not, stay close to the strongest unrated opponent rating
      my $maxor = $maxror || $maxuor;
      $maxor ||= 1500 if $this->{'cap_all_newcomers'} && ($maxor||0) > 1500;
      # 400 should probably be changed for logistic.
      if ($maxor) { my $limit = $maxor + 400 * $p->{$key_usage_p->{'ewins'}} / $p->{$key_usage_p->{'rgames'}}; # not clipped to [0.05,0.95]
# 	warn "$p->{'name'} $p->{$key_usage_p->{'id'}} $p->{$key_usage_p->{'ewins'}} $p->{$key_usage_p->{'rgames'}} $r $limit" if $p->{'name'} =~ /./;
        if ($r > $limit) { 
# 	  warn "Capping $r to $limit." if $p->{'name'} =~ /quackle/i;
	  $r = $limit; 
	  } 
        }
      if ($r != $p->{'xrat_curr'}) {
	$changed = 1;
#       warn "($i) $p->{'name'} $p->{'xrat_curr'} => $r\n";
	}
      $p->{'xrat_newpr'} = $r;
      }
    $this->CopyField($unratedp, 'xrat_curr', 'xrat_newpr');
    last unless $changed;
    }
  return if $i < $this->{'maximum_iterations'};

  $this->{'current_tournament'}->TellUser('wratnc', $i, $i);

  my (@means);
  for ($i = 0; $i < $this->{'maximum_iterations'}; $i++) { 
    # warn "i=$i \$#\$psp=$#$psp";
    for my $p (@$unratedp) {
      next unless $p->{$key_usage_p->{'rgames'}};
#     $::SIG{__WARN__} = sub () { confess join("\n", @_); };
#	my $r = &main'search4($p->{'xrat_iprsub'}, 0, 3000, 0.1);
#     print STDERR "$p->{'id'}: ? " . join(",",map {$_->{'xrat_curr'}||'?'}@$psp) . "\n";
      my $r = $this->Search($p->{'xrat_iprsub'}, 0, 3000);
#     print STDERR "$p->{'id'}: $r\n";
      if ($r < 500) { $r = 500; }
      my $this_last_0 = $#{$p->{$scores_k}};
      $this_last_0 = $last_round_0 if $last_round_0 < $this_last_0;
      my $maxor = 0;
      for my $r ($first_round_0..$this_last_0) {
	my $on = $p->{$pairings_k}[$r];
	next if $on == -1;
	my $op = $psp->[$on];
	$maxor = $op->{$oldr_k} if (defined $op->{$oldr_k}) && $op->{$oldr_k} > $maxor;
	}
      # 400 should probably be changed for logistic.
      $maxor ||= 1500 if $this->{'cap_all_newcomers'};
      if ($maxor) { my $limit = $maxor + 400 * $p->{$key_usage_p->{'ewins'}} / $p->{$key_usage_p->{'rgames'}}; # not clipped to [0.05,0.95]
#	warn "$p->{$key_usage_p->{'ewins'}} $p->{$key_usage_p->{'rgames'}} $r $limit";
        if ($r > $limit) { 
#	  warn "Capping $r to $limit.";
	  $r = $limit; 
	  } 
        }
      if ($r != $p->{'xrat_curr'}) {
#       warn "($i) $p->{'name'} $p->{'xrat_curr'} => $r\n";
	}
      $p->{'xrat_newpr'} = $r;
      $means[$p->{$id_k}] += $r;
      }
    $this->CopyField($unratedp, 'xrat_curr', 'xrat_newpr');
    }
  for my $p (@$unratedp) {
    next unless $p->{$key_usage_p->{'rgames'}};
    $p->{'xrat_curr'} = $means[$p->{$id_k}]/$this->{'maximum_iterations'};
    }
  }

=item RateNewcomersHoman $this, \@ps, $first_round_0, $last_round_0, $key_usage_p;

Internal buse.
Determine initial ratings for all unrated players, based on results
from the given rounds, using a traditional NSA approximation.
Keys used in player hashes:

ewins: earned wins in segment

id: player id (0-based index in \@ps)

oldr: pre-segment ratings

pairings: 0-based list of opponents (-1 indicates bye)

rgames: rated games in segment

scores: 0-based list of scores

=cut

# calculate ratings for all previously unrated players, using
# a crude approximation
sub RateNewcomersHoman ($$$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $unratedp = shift;
  my $key_usage_p = shift;
  my $oldr_k = $key_usage_p->{'oldr'};
  my $ewins_k = $key_usage_p->{'ewins'};
  my $pairings_k = $key_usage_p->{'pairings'};
  my $rgames_k = $key_usage_p->{'rgames'};
  my $scores_k = $key_usage_p->{'scores'};

  for my $p (@$psp) {
    if ($p->{$oldr_k}) 
      { $p->{'xrat_curr'} = $p->{$oldr_k}; }
    else 
      { $p->{'xrat_curr'} = 1500; }
    }
  my $n_changed_last_time = -1;
  my $total_change_last_time = -1;
  for (my $i = 0; $i < $this->{'maximum_iterations'}; $i++) {
    my $n_changed = 0;
    my $total_change = 0;
#   warn join(',', map { $_->{'name'}} @$unratedp);
#   warn join(',',%{$unratedp->[0]});
    for my $p (@$unratedp) {
      my $rgames = $p->{$rgames_k};
      confess "$p->{'name'} $rgames_k" unless defined $rgames;
      next unless $rgames > 0;
      my $this_last_0 = $#{$p->{$scores_k}};
      $this_last_0 = $last_round_0 if $last_round_0 < $this_last_0;
      my $sumor = 0;
      my $nor = 0;
      my $maxor = 0;
      for my $r ($first_round_0..$this_last_0) {
	my $on = $p->{$pairings_k}[$r];
	next if $on == -1;
	my $op = $psp->[$on];
	die "Player #".($on+1)." has no current rating.\n" 
	  unless defined $op->{'xrat_curr'};
	$sumor += $op->{'xrat_curr'};
# confess "\$psp->[$on]{$oldr_k} is not defined" unless defined $op->{$oldr_k};
	$maxor = $op->{$oldr_k} if (defined $op->{$oldr_k}) && $op->{$oldr_k} > $maxor;
	$nor++;
	}
      my $aor = $nor ? $sumor/$nor : 500;
      my $wins = $p->{$ewins_k};
      my $wr = $wins/$rgames;
      my $homanpr = $this->CalculateHomanPR(!$p->{$oldr_k}, $nor, $wins, $sumor, $maxor);
#      warn "$p->{name}: $p->{$oldr_k} $nor $wins $sumor $maxor $homanpr" if $p->{name} =~ $debug_name_pattern;
      if ($homanpr != $p->{'xrat_curr'}) {
	$n_changed = 1;
	$total_change += abs(($p->{'xrat_newpr'}||0)-$homanpr);
	$p->{'xrat_newpr'} = $homanpr;
	}
      }
    for my $p (@$unratedp) {
      next unless defined $p->{'xrat_newpr'};
#     warn "$p->{name}: $p->{'xrat_curr'} $p->{'xrat_newpr'}" if $p->{name} =~ /BURROUGHS/;
      $p->{'xrat_curr'} = $p->{'xrat_newpr'};
      }
    if ($n_changed == $n_changed_last_time && $total_change == $total_change_last_time
      && $total_change <= $n_changed) {
      last;
      }
    $n_changed_last_time = $n_changed;
    $total_change_last_time = $total_change;
    }
  }

=item $elo->RateVeterans(\@ps, $first_round_0, $last_round_0, $key_usage_p);

Calculate new ratings for all players who have pre-segment ratings,
based on results of the given rounds.  Keys used in player hashes:

lifeg: lifetime games played

newr: post-segment ratings

oldr: pre-segment ratings

rgames: rated games in segment

scores: 0-based list of scores

=cut

sub RateVeterans ($$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $key_usage_p = shift;
  my $newr_k = $key_usage_p->{'newr'};
  my $oldr_k = $key_usage_p->{'oldr'};
  my $scores_k = $key_usage_p->{'scores'};
  for my $p (@$psp) {
    $p->{$newr_k} = $p->{$oldr_k} if $p->{$oldr_k};
    }
  for my $pn (0..$#$psp) {
    my $p = $psp->[$pn];
    next unless $p->{$oldr_k};
    my $this_last_0 = $#{$p->{$key_usage_p->{'scores'}}};
    $this_last_0 = $last_round_0 if $last_round_0 < $this_last_0;
    next unless $first_round_0 <= $this_last_0;
    my $excess = $this->CalculateExcess($psp, $pn, $first_round_0,
      $this_last_0, $key_usage_p);
    $this->ConvertExcessToPoints($p, $excess, $key_usage_p);
    }
  if ($this->{'use_acceleration_bonuses'}) {
    for my $pn (0..$#$psp) {
      my $p = $psp->[$pn];
      next unless $p->{$oldr_k};
	$this->CalculateAccelerationBonus($psp, $pn, $first_round_0, $last_round_0,
	  $key_usage_p);
	}
    }
  if (defined $this->{'floor'}) {
    for my $pn (0..$#$psp) {
      my $p = $psp->[$pn];
      next unless $p->{$oldr_k}; # this sub is for veterans only
      $p->{$newr_k} = $this->{'floor'} if $p->{$newr_k} < $this->{'floor'};
      }
    }
  }

=item $elo->SetupNewcomerPR($psp, $first_round_0, $last_round_0, \@unrated, $key_usage_p);

Give each player an initial rating equal to the average of their opps
and set up their performance rating calculation sub.
Keys used in player hashes:

ewins: earned wins in segment

oldr: pre-segment ratings

pairings: 0-based list of opponents (-1 indicates bye)

rgames: rated games in segment

scores: 0-based list of scores

=cut

sub SetupNewcomerPR ($$$$$$) {
  my $this = shift;
  my $psp = shift;
  my $first_round_0 = shift;
  my $last_round_0 = shift;
  my $unratedp = shift;
  my $key_usage_p = shift;
  my $ewins_k = $key_usage_p->{'ewins'};
  my $id_k = $key_usage_p->{'id'};
  my $oldr_k = $key_usage_p->{'oldr'};
  my $pairings_k = $key_usage_p->{'pairings'};
  my $rgames_k = $key_usage_p->{'rgames'};
  my $scores_k = $key_usage_p->{'scores'};
# die join(',', map { $_ ? $_->{'id'} : '?' } @$unratedp);
  for my $p (@$unratedp) {
    my $this_last = $#{$p->{$scores_k}};
    $this_last = $last_round_0 if $last_round_0 < $this_last;
    my $sum = 0;
    my $n = 0;
    if ($this_last >= $first_round_0) {
      my $esub = $this->{'expectation_function'};
      my $code = "sub (\$) {";
      my $warn = '';
      for my $r0 ($first_round_0..$this_last) {
	no strict 'refs';
	my $on = $p->{$pairings_k}[$r0];
	next if $on < 0;
	my $op = $psp->[$on];
	if (defined $op->{$oldr_k}) {
	  $sum += $op->{$oldr_k};
	  $n++ if $op->{$oldr_k};
	  }
	$code .= $op->{$oldr_k} 
#	  ?"&$esub(\$this,\$_[0],$op->{$oldr_k},{1=>2})+\n" # 2010-05-02 JJC 1=>2 WTF?
 	  ?"&$esub(\$this,\$_[0],$op->{$oldr_k})+\n"
	  :"&$esub(\$this,\$_[0],\$psp->[$op->{$id_k}-1]->{'xrat_curr'})+\n";
# 	$warn .= $op->{$oldr_k} 
# 	  ?"warn qq!$on OC(\$_[0]-$op->{$oldr_k})!;"
# 	  :"warn qq!$on OC(\$_[0]-\$psp->[$op->{$id_k}]->{'xrat_curr'})!;";
	}
      my $w = $p->{$ewins_k};
#     die unless defined $w;
      if ($w == 0) { $w = $p->{$rgames_k}*0.05; } 
      elsif ($w == $p->{$rgames_k}) { $w = $p->{$rgames_k}*0.95;  }
      $code .= "-($w);}";
      $code =~ s/{/{$warn/; # }}
      $p->{'xrat_iprsub'} = eval $code;
#     warn $code;
      die "eval failed ($@) for: $code\n" if $@;
      }

    if ($n) { $p->{'xrat_curr'} = $sum / $n; }
    else {
      $p->{'xrat_curr'} = 1500;
#     warn "Player #$p->{$id_k} is unrated but did not play any rated players.\n";
      }
#   warn "$p->{'name'} $p->{'xrat_curr'}";
    }
#   die;
  }

=back

=cut

BEGIN {
  @nsa_win_probs = (
  0.5000000, 0.5014107, 0.5028213, 0.5042315, 0.5056421, 0.5070521, 0.5084625, 0.5098724, 0.5112826, 0.5126922,
  0.5141021, 0.5155114, 0.5169208, 0.5183297, 0.5197388, 0.5211476, 0.5225557, 0.5239640, 0.5253716, 0.5267792,
  0.5281861, 0.5295931, 0.5309993, 0.5324055, 0.5338109, 0.5352162, 0.5366208, 0.5380253, 0.5394289, 0.5408324,
  0.5422354, 0.5436375, 0.5450394, 0.5464404, 0.5478412, 0.5492410, 0.5506406, 0.5520392, 0.5534375, 0.5548347,
  0.5562317, 0.5576276, 0.5590231, 0.5604176, 0.5618117, 0.5632050, 0.5645971, 0.5659888, 0.5673793, 0.5687694,
  0.5701582, 0.5715466, 0.5729337, 0.5743202, 0.5757055, 0.5770902, 0.5784736, 0.5798564, 0.5812378, 0.5826186,
  0.5839984, 0.5853767, 0.5867544, 0.5881307, 0.5895062, 0.5908803, 0.5922536, 0.5936255, 0.5949965, 0.5963660,
  0.5977347, 0.5991018, 0.6004681, 0.6018328, 0.6031967, 0.6045592, 0.6059201, 0.6072801, 0.6086384, 0.6099958,
  0.6113514, 0.6127061, 0.6140590, 0.6154109, 0.6167610, 0.6181101, 0.6194574, 0.6208036, 0.6221480, 0.6234912,
  0.6248330, 0.6261729, 0.6275116, 0.6288485, 0.6301841, 0.6315178, 0.6328503, 0.6341808, 0.6355101, 0.6368374,
  0.6381634, 0.6394874, 0.6408101, 0.6421307, 0.6434501, 0.6447676, 0.6460831, 0.6473973, 0.6487092, 0.6500198,
  0.6513283, 0.6526353, 0.6539401, 0.6552435, 0.6565447, 0.6578443, 0.6591418, 0.6604377, 0.6617318, 0.6630235,
  0.6643137, 0.6656016, 0.6668880, 0.6681720, 0.6694544, 0.6707344, 0.6720128, 0.6732889, 0.6745633, 0.6758352,
  0.6771055, 0.6783734, 0.6796395, 0.6809036, 0.6821652, 0.6834251, 0.6846824, 0.6859380, 0.6871911, 0.6884424,
  0.6896911, 0.6909381, 0.6921824, 0.6934250, 0.6946649, 0.6959030, 0.6971385, 0.6983720, 0.6996034, 0.7008320,
  0.7020588, 0.7032829, 0.7045050, 0.7057245, 0.7069420, 0.7081568, 0.7093696, 0.7105797, 0.7117878, 0.7129931,
  0.7141964, 0.7153969, 0.7165954, 0.7177915, 0.7189847, 0.7201759, 0.7213643, 0.7225505, 0.7237339, 0.7249152,
  0.7260937, 0.7272700, 0.7284434, 0.7296147, 0.7307831, 0.7319493, 0.7331126, 0.7342737, 0.7354322, 0.7365878,
  0.7377412, 0.7388916, 0.7400398, 0.7411850, 0.7423280, 0.7434680, 0.7446057, 0.7457404, 0.7468728, 0.7480022,
  0.7491292, 0.7502533, 0.7513750, 0.7524941, 0.7536101, 0.7547237, 0.7558343, 0.7569425, 0.7580476, 0.7591504,
  0.7602501, 0.7613473, 0.7624415, 0.7635332, 0.7646219, 0.7657081, 0.7667912, 0.7678718, 0.7689497, 0.7700244,
  0.7710966, 0.7721657, 0.7732323, 0.7742958, 0.7753568, 0.7764146, 0.7774699, 0.7785220, 0.7795716, 0.7806180,
  0.7816619, 0.7827026, 0.7837407, 0.7847760, 0.7858081, 0.7868375, 0.7878638, 0.7888875, 0.7899080, 0.7909259,
  0.7919406, 0.7929527, 0.7939615, 0.7949678, 0.7959708, 0.7969712, 0.7979686, 0.7989628, 0.7999544, 0.8009427,
  0.8019283, 0.8029108, 0.8038905, 0.8048670, 0.8058409, 0.8068115, 0.8077794, 0.8087440, 0.8097060, 0.8106647,
  0.8116206, 0.8125737, 0.8135234, 0.8144704, 0.8154142, 0.8163553, 0.8172931, 0.8182281, 0.8191599, 0.8200890,
  0.8210148, 0.8219378, 0.8228576, 0.8237747, 0.8246884, 0.8255994, 0.8265074, 0.8274122, 0.8283142, 0.8292129,
  0.8301088, 0.8310015, 0.8318914, 0.8327780, 0.8336619, 0.8345425, 0.8354203, 0.8362948, 0.8371666, 0.8380351,
  0.8389008, 0.8397635, 0.8406229, 0.8414796, 0.8423329, 0.8431835, 0.8440309, 0.8448754, 0.8457167, 0.8465552,
  0.8473904, 0.8482229, 0.8490521, 0.8498785, 0.8507016, 0.8515220, 0.8523393, 0.8531534, 0.8539648, 0.8547728,
  0.8555781, 0.8563801, 0.8571794, 0.8579754, 0.8587686, 0.8595586, 0.8603458, 0.8611298, 0.8619110, 0.8626890,
  0.8634642, 0.8642364, 0.8650054, 0.8657716, 0.8665346, 0.8672949, 0.8680519, 0.8688061, 0.8695572, 0.8703055,
  0.8710506, 0.8717930, 0.8725321, 0.8732685, 0.8740017, 0.8747322, 0.8754597, 0.8761841, 0.8769057, 0.8776241,
  0.8783398, 0.8790523, 0.8797621, 0.8804688, 0.8811727, 0.8818735, 0.8825716, 0.8832665, 0.8839587, 0.8846478,
  0.8853342, 0.8860177, 0.8866981, 0.8873757, 0.8880503, 0.8887222, 0.8893910, 0.8900570, 0.8907201, 0.8913804,
  0.8920377, 0.8926922, 0.8933438, 0.8939926, 0.8946386, 0.8952816, 0.8959219, 0.8965592, 0.8971938, 0.8978254,
  0.8984544, 0.8990803, 0.8997036, 0.9003239, 0.9009416, 0.9015564, 0.9021684, 0.9027776, 0.9033841, 0.9039878,
  0.9045886, 0.9051867, 0.9057820, 0.9063746, 0.9069643, 0.9075514, 0.9081357, 0.9087173, 0.9092961, 0.9098722,
  0.9104455, 0.9110163, 0.9115842, 0.9121495, 0.9127121, 0.9132719, 0.9138291, 0.9143835, 0.9149354, 0.9154845,
  0.9160310, 0.9165747, 0.9171160, 0.9176544, 0.9181904, 0.9187236, 0.9192542, 0.9197822, 0.9203076, 0.9208305,
  0.9213506, 0.9218682, 0.9223832, 0.9228957, 0.9234054, 0.9239128, 0.9244174, 0.9249196, 0.9254192, 0.9259163,
  0.9264108, 0.9269028, 0.9273922, 0.9278793, 0.9283638, 0.9288457, 0.9293252, 0.9298021, 0.9302767, 0.9307487,
  0.9312183, 0.9316853, 0.9321500, 0.9326122, 0.9330720, 0.9335293, 0.9339843, 0.9344367, 0.9348868, 0.9353346,
  0.9357798, 0.9362228, 0.9366633, 0.9371015, 0.9375372, 0.9379707, 0.9384017, 0.9388305, 0.9392569, 0.9396810,
  0.9401027, 0.9405222, 0.9409393, 0.9413542, 0.9417668, 0.9421770, 0.9425850, 0.9429907, 0.9433942, 0.9437953,
  0.9441943, 0.9445910, 0.9449856, 0.9453778, 0.9457679, 0.9461557, 0.9465414, 0.9469248, 0.9473061, 0.9476852,
  0.9480621, 0.9484369, 0.9488095, 0.9491800, 0.9495483, 0.9499145, 0.9502785, 0.9506406, 0.9510004, 0.9513582,
  0.9517138, 0.9520674, 0.9524190, 0.9527683, 0.9531158, 0.9534610, 0.9538044, 0.9541456, 0.9544848, 0.9548220,
  0.9551572, 0.9554903, 0.9558216, 0.9561507, 0.9564780, 0.9568032, 0.9571265, 0.9574478, 0.9577671, 0.9580846,
  0.9584000, 0.9587136, 0.9590252, 0.9593350, 0.9596428, 0.9599488, 0.9602528, 0.9605550, 0.9608552, 0.9611537,
  0.9614502, 0.9617450, 0.9620379, 0.9623289, 0.9626182, 0.9629056, 0.9631912, 0.9634750, 0.9637570, 0.9640372,
  0.9643157, 0.9645924, 0.9648673, 0.9651404, 0.9654119, 0.9656815, 0.9659495, 0.9662158, 0.9664803, 0.9667431,
  0.9670042, 0.9672636, 0.9675213, 0.9677774, 0.9680317, 0.9682845, 0.9685355, 0.9687850, 0.9690327, 0.9692789,
  0.9695234, 0.9697664, 0.9700077, 0.9702474, 0.9704856, 0.9707221, 0.9709571, 0.9711904, 0.9714223, 0.9716525,
  0.9718813, 0.9721085, 0.9723342, 0.9725583, 0.9727809, 0.9730020, 0.9732216, 0.9734398, 0.9736564, 0.9738716,
  0.9740852, 0.9742975, 0.9745082, 0.9747175, 0.9749254, 0.9751318, 0.9753368, 0.9755404, 0.9757426, 0.9759434,
  0.9761427, 0.9763407, 0.9765374, 0.9767326, 0.9769264, 0.9771189, 0.9773101, 0.9774998, 0.9776883, 0.9778754,
  0.9780612, 0.9782456, 0.9784288, 0.9786107, 0.9787912, 0.9789705, 0.9791485, 0.9793252, 0.9795006, 0.9796748,
  0.9798477, 0.9800194, 0.9801898, 0.9803590, 0.9805269, 0.9806937, 0.9808592, 0.9810235, 0.9811866, 0.9813486,
  0.9815093, 0.9816689, 0.9818273, 0.9819844, 0.9821405, 0.9822954, 0.9824491, 0.9826017, 0.9827532, 0.9829035,
  0.9830528, 0.9832009, 0.9833479, 0.9834938, 0.9836386, 0.9837823, 0.9839249, 0.9840665, 0.9842069, 0.9843464,
  0.9844847, 0.9846220, 0.9847583, 0.9848935, 0.9850277, 0.9851609, 0.9852930, 0.9854242, 0.9855543, 0.9856834,
  0.9858116, 0.9859387, 0.9860649, 0.9861900, 0.9863143, 0.9864375, 0.9865598, 0.9866811, 0.9868015, 0.9869209,
  0.9870395, 0.9871570, 0.9872737, 0.9873894, 0.9875043, 0.9876182, 0.9877312, 0.9878433, 0.9879546, 0.9880649,
  0.9881744, 0.9882830, 0.9883907, 0.9884976, 0.9886036, 0.9887088, 0.9888131, 0.9889166, 0.9890192, 0.9891211,
  0.9892221, 0.9893222, 0.9894216, 0.9895202, 0.9896180, 0.9897149, 0.9898111, 0.9899065, 0.9900011, 0.9900949,
  0.9901880, 0.9902803, 0.9903718, 0.9904626, 0.9905527, 0.9906420, 0.9907305, 0.9908183, 0.9909054, 0.9909918,
  0.9910774, 0.9911624, 0.9912466, 0.9913301, 0.9914129, 0.9914951, 0.9915765, 0.9916572, 0.9917373, 0.9918167,
  0.9918954, 0.9919735, 0.9920509, 0.9921276, 0.9922037, 0.9922791, 0.9923539, 0.9924281, 0.9925016, 0.9925745,
  0.9926468, 0.9927184, 0.9927895, 0.9928599, 0.9929297, 0.9929989, 0.9930675, 0.9931355, 0.9932029, 0.9932698,
  0.9933360,
  );
}

=head2 BUGS

=cut

1;
