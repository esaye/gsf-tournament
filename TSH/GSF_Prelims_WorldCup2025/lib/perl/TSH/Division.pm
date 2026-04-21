#!/usr/bin/perl

# Copyright (C) 2005-2015 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Division;

use strict;
use warnings;

use Carp;
use File::Copy;
use File::Path; # mkpath
use TFile;
use TSH::Player;
use TSH::Utility qw(Debug DebugOn Min);
use JavaScript::Serializable;
use threads::shared;
use TSH::Utility qw(Debug);

our (@ISA);
@ISA = qw(JavaScript::Serializable);
sub EXPORT_JAVASCRIPT () { return (
  'classes' => 'classes',
  'name' => 'name',
  'maxr' => 'maxr',
  'maxrp' => 'maxrp',
  'rating_list' => 'rating_list',
  'rating_system' => 'rating_system',
  'data' => 'players',
  'seeds' => 'seeds',
  'first_out_of_the_money' => 'first_out_of_the_money',
  ); }

# DebugOn('RSw');

=pod

=head1 NAME

TSH::Division - abstraction of a Scrabble tournament division within C<tsh>

=head1 SYNOPSIS

  $d = new Division;
  $s = $d->Name();
  print "Yes.\n" if $s eq TSH::Division::CanonicaliseName('whatever');
  $d->Name($s);
  $d->Dirty(1); 
  print "Division has unsaved data.\n" if $d->Dirty();
  $t = $d->Tournament();
  $d->Tournament($t);
  $d->Read();

  $d->ComputeRatings($r0, [$quiet]);
  $n = $d->CheckGibson($sr0, $round0);
  $p = $d->ChooseBye($sr0, $round0, \@psp);
  $n = $d->CountByes();
  print $d->FormatPairing($round0, $pn1, $style);
  $d->Pair($pn1, $pn2, $round0);
  $success = $d->PairSwiss($setup);
  PairSomeSwiss($psp, $repeats, $sr0);

  $d->DeleteScores($pn1, $pn2, $round0);
  $d->DeleteByeScore($pn1, $round0);
  $s = $d->LeastScores();
  $p = $d->LeastScoresPlayer();
  $s = $d->MostScores();
  $p = $d->MostScoresPlayer();
  $r = $d->MaxRound0();
  $r = $d->MaxRoundPlayed0();
  $success = $d->PromptIfNotLatestScoredRound0($$);

  $n = $d->CountPlayers();
  $pp = $d->Player($pn);
  @pp = $d->Players;
  $round0 = $d->LastPairedRound0();
  $round0 = $d->LastPairedScoreRound0();
  $p = $d->LastPairedScorePlayer();

  $d->ComputeBoards($sr0, $r0);
  # $p->Board($sr0); # see TSH::Player.pm
  $d->ComputeRanks($sr0);
  # $p->RoundRank($sr0); # see TSH::Player.pm
  @bs = $d->ReservedBoards();

  $d->PurgeReportsByRound($r0);
  $d->Update(); # do both of the following
  $d->Synch(); # update internal statistics
  $d->Write(); # save to disk

=head1 ABSTRACT

This Perl module is used to manipulate divisions within C<tsh>.

=head1 DESCRIPTION

A Division has (at least) the following member fields, none of which
ought to be accessed directly from outside the class.

  classes     number of classes for prizes
  data        array of player data, 1-based indexing
  file        filename of .t file
  minp        least n such that all players are paired in rounds 1-n (0-based)
  maxp        highest round number that has pairings data (0-based)
  mins        least number of scores registered for any player (0-based)
  mins_player a pointer to a player who has no scores past round mins
  maxs        highest round number that has score data (0-based)
  maxs_player a pointer to a player who has a score in round maxs
  maxr        highest allowable round number as configured (0-based)
  name        division name
  tournament  a pointer to the division's associated tournament

The following member functions are currently defined.

=over 4

=cut

sub AddPlayer($@);
sub BoardTable ($$);
sub CanonicaliseName ($);
sub CheckAutoPair ($$$);
sub CheckChewPair ($$$);
sub CheckRoundHasResults ($$);
sub CheckGibson ($$$);
sub ComputeBoards ($$$);
sub ComputeRanks ($$;$);
sub ComputeRatings ($$;$);
sub ComputeSupplementaryRatings ($$);
sub CountByes ($);
sub CountPlayers ($);
sub DeleteAllPlayers ($);
sub DeleteByeScore ($$$);
sub DeleteScores ($$$$);
sub Dirty ($;$);
sub File ($;$);
sub FirstUnpairedRound ($);
sub FormatPairing ($$$;$);
sub GetUnpaired ($;$);
sub GetUnpairedRound ($$);
sub HasTables ($);
sub initialise ($);
sub IsComplete ($);
sub LastPairedRound0 ($);
sub LastPairedScoreRound0 ($);
sub LastPairedScorePlayer ($);
sub LeastScores ($);
sub LeastScoresPlayer ($);
sub LoadSupplementaryRatings ($$;$);
sub MaxRound0 ($;$);
sub MaxRoundPlayed0 ($);
sub MostScores ($);
sub MostScoresPlayer ($);
sub Name ($;$);
sub new ($);
sub Pair ($$$$;$);
sub PairSomeSwiss($$$);
sub PairSwiss ($$);
sub Player ($$);
sub Players ($);
sub PromptIfNotLatestScoredRound0($$);
sub PurgeReportsByRound0($$);
sub RatingSystem ($;$);
sub Read ($);
sub ReadFrom ($$);
sub ReadFromString ($$);
sub RecursiveSwiss ($$);
sub RecursiveSwissBottom ($$);
sub RecursiveSwissOne ($$);
sub RecursiveSwissTop ($$);
sub ReservedBoards ($);
sub Synch ($);
sub Tournament ($;$);
sub Update ($);
sub Write ($);

=item $pp = $dp->AddPlayer('name' => $name, 'rating' => $rating, ...);

Add a player to the division.

=cut

sub AddPlayer ($@) {
  my $dp = shift;
  my $datap = $dp->{'data'};
  my $tourney = $dp->Tournament();
  my $config = $tourney->Config();
  my $is_readonly = $config->ReadOnly();
  my (%argv) = @_;
  my $pp = &share({});
  while (my ($key, $value) = each %argv) { 
    $pp->{$key} = $value;
    }
  $pp->{'division'} = $dp;
  $pp->{'id'} = scalar(@$datap);
  # if loading from a TFile (as is usually the case), rnd will already be set
  if ($config->Value('no_random')) {
    $pp->{'rnd'} = 0;
    }
  else {
    my $a = 1103515245;
    my $c = 12345;
    my $m = 1<<31;
    my $rnd = $pp->{'rnd'} || (($a*length($argv{'name'}) * (100+$pp->{'id'}) * ord($argv{'name'})+$c)% $m);
    my $count = 0;
    while ($dp->{'rnd'}{$rnd}) {
      $rnd = ($a*$rnd + $c) % $m;
      die "assertion failed" if ++$count > 10000;
      }
    $pp->{'rnd'} = $rnd;
    $dp->{'rnd'}{$rnd}++;
    }
  $pp->{'pairings'} ||= &share([]);
  $pp->{'scores'} ||= &share([]);
  $pp->{'etc'} ||= &share({});
# die join(',', @{$pp->{'scores'}});
  push(@$datap, $pp);
  bless $pp, 'TSH::Player'; 
  if ((!$is_readonly) and $config->Value('player_photos')) {
    $config->InstallPhoto($pp);
    }
  if ($config->Value('twitter_handles')) {
    $config->InstallTwitter($pp);
    }
  if (my $class = $pp->Class()) {
    if (!$dp->{'classes'}) {
      my %classes : shared;
      $classes{$class}++;
      $dp->{'classes'} = \%classes;
      }
    elsif (ref($dp->{'classes'})) {
      $dp->{'classes'}{$class}++;
      }  
#   warn $dp->{'classes'};
    }
  $tourney->RegisterPlayer($pp);
  $dp->Dirty(1);
  return $pp;
  }

=item $table = $dp->BoardTable($board);

Find the table corresponding to a board.

=cut

sub BoardTable ($$) {
  my $dp = shift;
  my $board = shift;
  my $tables = $dp->{'tournament'}->Config()->{'tables'}{$dp->{'name'}};
  die "oops" if $tables && !defined $board;
  return $tables && ($tables->[$board-1] || '?');
  }

=item $s1 = CanonicaliseName($s)

Canonicalise a division name.

=cut

sub CanonicaliseName ($) {
  my $s = shift;
  $s = '' unless defined $s;
  $s =~ s/\W//g;
  $s = uc $s;
  return $s;
  }

=item $success = $dp->CheckAutoPair($processor, $round1)

Check to see if we are ready to generate pairings for division $div 
in 1-based round $round.
Return 1 if we ran a pairings command, 0 if we did not.

=cut

sub CheckAutoPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $round = shift;
  my $tourney = $dp->{'tournament'};
  my $config = $tourney->Config();
  my $round0 = $round - 1; # internally, rounds are zero-based
  # first look to see if there are any unpaired 
  # TODO: check to see if this duplicates one of the sub Get...s
  my (@unpaired) = @{$dp->GetUnpairedRound($round0)};
# warn "checking $round0: @unpaired $config::manual_pairings\n";
  return 0 unless @unpaired;
  my $pairing_system = $config->Value('pairing_system');
  if ($pairing_system eq 'manual') {
    return 0;
    }
  elsif ($pairing_system eq 'chew') {
    return $dp->CheckChewPair($processor, $round0);
    }
  elsif ($pairing_system eq 'basd') {
    return $dp->CheckBASDPair($processor, $round0);
    }
  elsif ($pairing_system eq 'bracket') {
    return $dp->CheckBracketPair($processor, $round0);
    }
  elsif ($pairing_system eq 'nast') {
    return $dp->CheckNASTPair($processor, $round0);
    }
  elsif ($pairing_system eq 'guelph') {
    return $dp->CheckGuelphPair($processor, $round0);
    }
  elsif ($pairing_system eq 'green') {
    return $dp->CheckGreenPair($processor, $round0);
    }
  elsif ($pairing_system eq 'none') {
    return $dp->CheckNonePair($processor, $round0);
    }
  my $apsp = $config->Value('autopair');
  my $app;
  $app = $apsp->{uc $dp->Name()} if $apsp;
  if (!defined $app) {
    return $dp->CheckChewPair($processor, $round0);
    }
  my $apdp = $app->[$round];
  return 0 unless $apdp;
  my (@apd) = @{$apdp};

  my $sr = shift @apd;
  my $sr0 = $sr - 1;
  if ($sr0 > $dp->LeastScores()-1) {
    $tourney->TellUser('emisss2', $dp->Name(), $sr, $dp->LeastScoresPlayer()->TaggedName());
    return 0;
    }
  # check to see if all results are in for the source round
  my $system = $apd[0];
  # check to see we aren't going too far ahead
  if ($round0 != $dp->FirstUnpairedRound0()) {
    $tourney->TellUser('eapwrr', $round, $dp->FirstUnpairedRound0()+1);
    return 0;
    }
  $tourney->TellUser('iautopr');
  
  my $save_no_console_input = $config->Value('no_console_input', 1);
  my $result = $processor->Process("@apd");
  $config->Value('no_console_input', $save_no_console_input);
  if ($result) {
    return 1;
    }
  else {
    $tourney->TellUser('eapfail', "@apd");
    return 0;
    }
  }
  
=item $success = $dp->CheckBASDPair($processor, $round0)

Check to see if we should generate Big Apple Showdown pairings for
the given div/round.  Return 1 if we computed them.

=cut

sub CheckBASDPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $tourney = $dp->{'tournament'};
  my $config = $tourney->Config();
  my $round0 = shift;
  my $sr0 = $dp->LeastScores() - 1;

  my $dname = $dp->Name();
  my (@players) = $dp->Players();
  if (@players != 20) {
    $tourney->TellUser('ebasd20', scalar(@players));
    return 0;
    }
  if ($round0 == 0) {
    $config->Value('initial_snaked', 1);
    $processor->Process("if 9 $dname");
    return 1;
    }
  elsif ($round0 == 9) {
    if ($sr0 < $round0 - 1) { $tourney->TellUser('emisss2', $dp->Name(), $round0, $dp->LeastScoresPlayer()->TaggedName()); return 0; }
    $processor->Process("basdsemi $dname");
    return 1;
    }
  elsif ($round0 >= 12 && $round0 <= 16) {
    if ($sr0 < $round0 - 1) { $tourney->TellUser('emisss2', $dp->Name(), $round0, $dp->LeastScoresPlayer()->TaggedName()); return 0; }
    my $round1 = $round0 + 1;
    $processor->Process("basdfinal $round1 $dname");
    return 1;
    }
  return 0;
  }

=item $success = $dp->CheckBracketPair($processor, $round0)

Check to see if we should generate seeded single-elimination (bracket) pairings for
the given div/round.  Return 1 if we computed them.

=cut

sub CheckBracketPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $tourney = $dp->{'tournament'};
  my $config = $tourney->Config();
  my $round0 = shift;
  my $sr0 = $dp->LeastScores() - 1;
  my $prelims = $config->Value('bracket_prelims') || 0; # number of preliminary non-bracket rounds
  my $dname = $dp->Name();
  my $nroundsp = $config->Value('bracket_repeats') || [1];
  if (!ref($nroundsp)) { $nroundsp = [$nroundsp]; }
  my ($i, $nrounds, $r0i);
  my $prelim_pairing_system = $config->Value('bracket_prelim_pairings') || 'none';
  my $noncon_pairing_system = $config->Value('bracket_noncon_pairings') || 'none';
  my $changed = 0;

  # if prelims needed, generate them
  if ($round0 < $prelims) {
    if ($round0 == 0) {
      if ($prelim_pairing_system eq 'if') {
	$processor->Process("if $prelims $dname");
	return 1;
        }
      elsif ($prelim_pairing_system eq 'default') {
	return $dp->CheckChewPair($processor, $round0);
        }
      else {
	$dp->Tournament()->TellUser('ebadconfigbracket_order', $prelim_pairing_system);
	$processor->Process("if $prelims $dname");
	return 1;
        }
      }
    else {
      if ($prelim_pairing_system eq 'default') {
	return $dp->CheckChewPair($processor, $round0);
        }
      else {
	$dp->Tournament()->TellUser('ebadconfigbracket_order', $prelim_pairing_system);
	$processor->Process("if $prelims $dname");
	return 1;
        }
      }
    die 'unreached';
    }  
  # check first to see if there are any partial phases that can be completed
  if ($dp->GetConfigValue('bracket_partial_phases')) {
    # if we don't require players to keep playing after a pairing 
    # has been decided, zero out the rest of the partial phase
    &::Use("TSH::Division::Pairing::Bracket");
    $changed ||= TSH::Division::Pairing::Bracket::ZeroOutPartials($dp);
    if ($changed) { $dp->Update(); }
    my $unpairedp = $dp->GetUnpairedRound($round0);
    return $changed unless @$unpairedp;
#   warn "Still unpaired in round @{[$round0+1]}";
    }
  # TODO: move this figuring to TSH::Division::Pairing::Bracket?
  # figure out which bracket round set we are in, where we are in it, and how long it is
  for ($i=0, $r0i=$prelims; ; $i++, $r0i+=$nrounds) {
    $nrounds = $nroundsp->[$i > $#$nroundsp ? -1 : $i];
#   warn "$round0 + $nrounds...";
    if ($round0 == $r0i) { last; }
      # we are at the start of a bracket round set
    if ($round0 < $r0i+$nrounds) {
      # we are in the middle of a bracket round set
#     warn "$round0 < $r0i+$nrounds";
      if ($noncon_pairing_system =~ /^(?:multikoth|none)$/) {
        }
      elsif ($noncon_pairing_system eq 'default') {
	$changed ||= $dp->CheckChewPair($processor, $round0);
        }
      elsif ($noncon_pairing_system eq 'nasc') {
	$changed ||= $dp->BracketNASCNonContenderPairings($processor, $round0);
        }
      else {
	$dp->Tournament()->TellUser('ebadconfigbracket_noncon_pairings', $noncon_pairing_system);
        }
      return $changed;
      }
    }

  # check to make sure we have all past scores (might not if had prelims)
  if ($sr0 < $round0 - 1) { 
    $tourney->TellUser('emisss2', $dp->Name(), $round0, $dp->LeastScoresPlayer()->TaggedName());
    return 0; 
    }
  # otherwise, generate pairings for those in the bracket
  $processor->Process("brack $nrounds $dname");
  my $unpairedp = $dp->GetUnpairedRound($round0);
  if (@$unpairedp) { # KOTH everyone else, if any
    Debug 'BRACK', 'noncontenders: %s', join(',',map { $_->ID()} @$unpairedp);
    if ($noncon_pairing_system eq 'default') {
      $dp->CheckChewPair($processor, $round0);
      }
    elsif ($noncon_pairing_system eq 'nasc') {
      $dp->BracketNASCNonContenderPairings($processor, $round0);
      }
    elsif ($noncon_pairing_system eq 'multikoth') {
      $processor->Process("koth 0 ".($sr0+1)." $dname");
      # copy new KOTH pairings to repeated rounds if necessary
      for my $r0 ($round0+1..$round0+$nrounds-1) {
	for my $p (@$unpairedp) {
	  my $oid = $p->OpponentID($round0);
    #     warn "pid=".$p->ID()." oid=$oid r0=$r0";
	  my $pid = $p->ID();
	  if ((defined $oid) && $pid > $oid) {
	    $dp->Pair($p->ID(), $oid, $r0);
	    }
	  }
	}
      }
    elsif ($noncon_pairing_system eq 'none') {
      for my $r0 ($round0..$round0+$nrounds-1) {
	for my $p (@$unpairedp) {
	  $dp->Pair($p->ID(), 0, $r0);
	  }
	}
      }
    else {
      $dp->Tournament()->TellUser('ebadconfigbracket_noncon_pairings', $noncon_pairing_system);
      }
    }
  return 1;
  }

=item $success = $dp->BracketNASCNonContenderPairings($processor, $round0)

Add noncontender pairings for NASC 2015 if necessary. Return 1 if we did.

=cut

sub BracketNASCNonContenderPairings($$$) {
  my $dp = shift;
  my $processor = shift;
  my $tourney = $dp->{'tournament'};
  my $config = $tourney->Config();
  my $round0 = shift;
  my $changed = 0;
  my $maxround0 = $dp->MaxRound0();

  # TODO: need to set up losing QF and 3rd place pairings too
  if ($round0 >= $maxround0 - 2) {
    # no pairings in the last three rounds, because the playoff rounds
    # get played faster
    for my $p (@{$dp->GetUnpairedRound($round0)}) {
      $dp->Pair($p->ID(), 0, $round0);
      $changed = 1;
      }
    }
  else {
    $changed ||= $dp->CheckChewPair($processor, $round0);
    }
  return $changed;
  }

=item $success = $dp->CheckChewPair($processor, $round0)

Check to see if we should generate Chew pairings for the given div/round.
Return 1 if we computed them.

=cut

sub CheckChewPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $tourney = $dp->{'tournament'};
  my $config = $tourney->Config();
  my $round0 = shift;

  return 0 unless defined $dp->{'maxr'};
  my $max_rounds = $dp->{'maxr'} + 1;
  my $rounds_left = $max_rounds - $round0;
  Debug 'CP', "$#{$dp->{'data'}} players and $rounds_left round(s) left";
  # check for start of tournament
  if ($round0 == 0) {
    # This block has been moved twice. First it was after the initial_schedule
    # check, with this comment:
    # # check for possible round robin (has to be done after initial_schedule test,
    # # as that might generate initial round robins itself)
    # Then it was moved inside the initial_schedule check, at the end of that
    # block, because:
    # # This however led to RRs being generated after an initial schedule,
    # # which leads to inappropriate repeat pairings and is contrary to the
    # # intent of initial schedules, to prepare for early Swiss rounds.
    # However, then it would not do initial RRs if initial_schedule was
    # configured, so we try moving it here.
    unless ($config->Value('no_initial_rr')) {
      my $rounds_required = $dp->CountActivePlayers() - 1;
      $rounds_required++ unless $rounds_required % 2;
      my $interleave_count = $dp->GetConfigValue('interleave_rr') || 1;
      if (my $rr_available = int($rounds_left / $rounds_required / $interleave_count)) {
	$processor->Process("roundrobin $rr_available $dp->{'name'}");
	Debug 'CP', "Using round robin pairings (*$rr_available).";
	return 1;
	}
      }
    if ($config->Value('initial_random')) {
      my $dname = $dp->Name();
      Debug 'CP', "Using initial random pairings.";
      $processor->Process("randompair 0 0 $dname");
      return 1;
      }
    if (my $initial_schedule = $config->Value('initial_schedule')) {
      my $dname = $dp->Name();
      Debug 'CP', "Using InitFontes pairings.";
      $processor->Process("initfontes $initial_schedule $dname");
      return 1;
      }
  }
  # check for end of tournament
  {
    my $force_koth = $config->Value('force_koth');
    if ($force_koth && $rounds_left <= $force_koth) {
      my $dname = $dp->Name();
      Debug 'CP', "Using KOTH pairings.";
      my $sr = $max_rounds - $rounds_left;
      my $repeats = $sr;
      if (my $auto_koth_repeats = $config->Value('auto_koth_repeats')) {
	$repeats = $auto_koth_repeats;
        }
      $processor->Process("koth $repeats $sr $dname");
      return 1;
      }
  }

  if ($round0 != $dp->FirstUnpairedRound0()) {
    $tourney->TellUser('eapwrr', $round0+1, $dp->FirstUnpairedRound0()+1);
    return 0;
    }
  # check to see if the source round seems reasonable
  my $sr0 = $dp->LeastScores() - 1;
  # sr0 = previous round is always reasonable, else...
  if ($sr0 != $round0 - 1) {
    # sr0 neither of previous two rounds is never reasonable
    if ($sr0 != $round0 - 2) {
#     warn "$sr0 $round0";
      $tourney->TellUser('eacpbadr', $round0+1, $sr0+1);
      return 0;
      }
    # sr0 = second previous round is always ok if not after a session break
    if ($config->Value('session_breaks')) {
      for my $sb (@{$config->Value('session_breaks')}) {
	if ($round0 == $sb) {
	  $tourney->TellUser('eacprnsb', $round0+1, $round0);
	  return 0;
	  }
        }
      }
    else {
      $tourney->TellUser('eacpnsb', $round0+1, $round0-1);
      return 0;
      }
    }
  {
    my $sr1 = $sr0+1;
    $processor->Process("chewpair $sr1 $dp->{'name'}");
  }
  return 1;
  }

=item $n = CheckGibson($dp, $sr0, $round0)

Returns the number of players in division $dp who are unpaired in
round $round0 and must be Gibsonized as of their standing in
round $sr0.
Does not check for Gibsonization on spread, and if $sr0 is not 
$round0-1 will miss some Gibsonizations. 
See TSH::Command::ChewPair for a better implementation.

=cut

sub CheckGibson ($$$) {
  my $dp = shift;
  my $sr0 = shift;
  my $round0 = shift;
  my $tourney = $dp->{'tournament'};
  my $config = $tourney->Config();
  my $max_rounds = $dp->{'maxr'} + 1;

  unless ($max_rounds) {
    TSH::Utility::Error "Can't do Gibson check without 'config max_rounds = ?'.\n";
    return -1;
    }
  my (@sorted) = TSH::Player::SortByStanding $sr0, @{$dp->GetUnpairedRound($round0)};
  # TODO: handle triple Gibsons

  # Note that this does not catch all Gibson situations.  In particular,
  # if you are using Fontes pairings, players may complain that a Gibson
  # situation in Round N has arisen as a result of a Round N-1 game,
  # when Round N pairings have been computed based on Round N-2 standings
  my $rounds_left = $max_rounds - ($sr0+1);

  my (@spread, @wins);
  for my $i (0..2) {
    my $pp = $sorted[$i];
    $spread[$i] = defined $pp->{'rspread'}[$sr0] ?
      $pp->{'rspread'}[$sr0] : $pp->{'spread'};
    $wins[$i] = defined $pp->{'rwins'}[$sr0] ?
      $pp->{'rwins'}[$sr0] : $pp->{'wins'};
    }

  # Note that we do not yet support Gibsoning on spread.
  if ($wins[0] - $wins[1] > $rounds_left) {
    printf "%s (%d %+d) needs to be Gibsonized with respect to %s (%d %+d).\n",
      (TSH::Utility::TaggedName $sorted[0]), $wins[0], $spread[0],
      (TSH::Utility::TaggedName $sorted[1]), $wins[1], $spread[1],
      ;
    return 1;
    }
  elsif ($wins[1] - $wins[2] > $rounds_left) {
    printf "%s (%d %+d) and %s (%d %+d) need to be Gibsonized with respect to %s (%d %+d).\n",
      (TSH::Utility::TaggedName $sorted[0]), $wins[0], $spread[0],
      (TSH::Utility::TaggedName $sorted[1]), $wins[1], $spread[1],
      (TSH::Utility::TaggedName $sorted[2]), $wins[2], $spread[2],
      ;
    return 2;
    }
  return 0;
  }

=item $success = $dp->CheckGreenPair($processor, $round0)

Check to see if we should generate Guelph pairings for the given
div/round.  Return 1 if we computed them.

=cut

sub CheckGreenPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $round0 = shift;

  my $dname = $dp->Name();
  if ($round0 == 0) {
    $processor->Process("green $dname");
    return 1;
    }
  elsif ($round0 == 5) {
    $processor->Process("koth 1 5 $dname");
    }
  return 0;
  }

=item $success = $dp->CheckGuelphPair($processor, $round0)

Check to see if we should generate Guelph pairings for the given
div/round.  Return 1 if we computed them.

=cut

sub CheckGuelphPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $round0 = shift;

  my $dname = $dp->Name();
  if ($round0 == 0 || $round0 == 3 || $round0 == 5) {
    $processor->Process("guelph $dname");
    return 1;
    }
  return 0;
  }

=item $success = $dp->CheckNASTPair($processor, $round0)

Check to see if we should generate NAST pairings for the given div/round.
Return 1 if we computed them.

=cut

sub CheckNASTPair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $round0 = shift;

  my $max_round0 = $dp->MaxRound0();
  $max_round0 = -1 unless defined $max_round0;
  return 0 if $round0 > $max_round0;
  my $dname = $dp->Name();
  if ($round0 == 0) {
    $processor->Process("nast $dname");
    return 1;
    }
  elsif ($round0 == 4) {
    $processor->Process("ns 1 4 $dname");
    return 1;
    }
  elsif ($round0 == 5) {
    if ($max_round0 <= 5) {
      $processor->Process("koth 2 5 $dname");
      }
    elsif ($dp->CountPlayers() < 10) {
      $processor->Process("ns 1 5 $dname");
      }
    else {
      $processor->Process("ns 0 5 $dname");
      }
    return 1;
    }
  elsif ($round0 == 6) {
    if ($dp->CountPlayers() < 10 && $max_round0 == 6) {
      $processor->Process("ns 2 6 $dname");
      }
    else {
      $processor->Process("ns 1 6 $dname");
      }
    return 1;
    }
  elsif ($round0 == 7) {
    $processor->Process("koth 3 7 $dname");
    return 1;
    }
  return 0;
  }

=item $success = $dp->CheckNonePair($processor, $round0)

Check to see if we should generate no pairings for the given
div/round.  Return 1 if we computed them.

=cut

sub CheckNonePair ($$$) {
  my $dp = shift;
  my $processor = shift;
  my $round0 = shift;

  my $changed = 0;
  for my $p ($dp->Players()) {
    next if defined $p->Opponent($round0);
    $changed++;
    $dp->Pair(0, $p->ID(), $round0);
    }
  if ($changed) {
    $dp->Dirty(1);
    $dp->Update();
    return 1;
    }
  return 0;
  }

=item $boolean = $dp->CheckRoundHasResults($round0):

Return true if the assertion that division has at least some results in
zero-based round $round0 is true.

=cut

sub CheckRoundHasResults ($$) {
  my $this = shift;
  my $sr0 = shift;
  if ($sr0 > $this->{'maxs'}) {
    $this->{'tournament'}->TellUser('ernos', $sr0+1);
    return 0;
    }
  return 1;
  }

=item $p = $d->ChooseBye($sr0, $round0, \@psp)

Original description:

Assign a bye in $round0 to the player who was lowest ranked in round
$sr0 among those players in @psp who had the fewest byes.
Splice player from @psp, return player (or undef if no byes
because @psp is even).

Subsequent additional options:

- Always assign byes to lowest-ranked player
- In team play with unequal team sizes, largest team gets bye
- Assign byes to highest-ranked player
- Assign bye to nth player from bottom in nth round from end (German)

=cut

sub ChooseBye($$$$) {
  my $this = shift;
  my $sr0 = shift;
  my $round0 = shift;
  my $psp = shift;

  return undef unless @$psp % 2;

  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();

  # how to assign byes: top_down, bottom_up, always_bottom
  my $method = lc ($config->Value('bye_method') || 'bottom_up');
  $method =~ s/-/-/g;
  my $unfair_byes = $this->GetConfigValue('unfair_byes');
  $method = 'always_bottom' if $unfair_byes;
  $unfair_byes //= 1 if $method eq 'always_bottom';
  $method = 'german' if $method =~ /^deutsch/;
  if ($method !~ /^(?:always_bottom|bottom_up|german|top_down)$/) {
    warn "Unknown bye method '$method': switching to 'bottom_up'";
    $method = 'bottom_up';
    }

  # make a copy of the candidates list, so that it can be restricted
  # e.g., in team play
  my (@candidates) = @$psp;

  # if team play is in effect and teams have unequal sizes, 
  # then the largest team should get a bye
  if ($config->Exagony($round0)) {
    my $largest_team;
    my %team_sizes;
    for my $p1 (@$psp) {
      $team_sizes{$p1->Team()||''}++;
      }
    my $largest_size = 0;
    my $is_unique;
    while (my ($team_name, $team_size) = each %team_sizes) {
      if ($team_size > $largest_size) {
	$largest_size = $team_size;
	$largest_team = $team_name;
	$is_unique = 1;
        }
      elsif ($team_size == $largest_size) {
	$is_unique = 0;
        }
      }
    if ($is_unique and $largest_size > 2) {
      warn "Team $largest_team has more players, gets bye.\n";
      (@candidates) = grep { $largest_team eq ($_->Team()||'') } @candidates;
      }
    }

  # Assertion could legitimately fail when a late arrivee is added to a division
  # my $minbyes = $this->CountByes();
  # my $p = (TSH::Player::SortByStanding $sr0, grep { $_->{'byes'} == $minbyes } 
  #   @$psp)[-1] or die "Assertion failed";

  # choose the bye player
  if ($method eq 'always_bottom') {
    # always_bottom: lowest-ranked player always gets the bye
    (@candidates) = TSH::Player::SortByStanding $sr0, @$psp;
    splice (@candidates, 0, -$unfair_byes) if @candidates > $unfair_byes;
    }
  else { # $method eq 'always_bottom'
    (@candidates) = TSH::Player::SortByStanding $sr0, @candidates;
    if ($method eq 'top_down') {
      (@candidates) = reverse @candidates;
      }
    elsif ($method eq 'german') {
      if (my $max_rounds = $this->MaxRound0()) {
	my $band_size = $max_rounds - $round0 + 1;
	warn $band_size;
	(@candidates[-$band_size..-1]) = reverse @candidates[-$band_size..-1];
	}
      else {
	$tourney->TellUser('eneed_max_rounds');
	}
      }
    }

  # provisionally choose the least appropriate candidate
  my $bye_p = shift @candidates;
  # but replace them if anyone looks better
  if (@candidates) {
    # make sure each player's bye count is up-to-date
    $this->CountByes();
    # search for a better candidate: one with fewer byes, 
    # or if not greater byes then lower rank
    for my $cand_p (@candidates) {
      $bye_p = $cand_p if $cand_p->Byes() <= $bye_p->Byes();
      }
    }

  # only assign the bye pairing, don't register the +50, as some routines
  # (and operators) may get confused by having early score data present
  my $pid = $bye_p->ID();
  $this->Pair(0, $pid, $round0);

  # remove the bye player from the unpaired player list
  my $found = 0;
  for my $i (0..$#$psp) { # linear search, sigh
    if ($psp->[$i]->ID() eq $pid) {
      TSH::Utility::SpliceSafely(@$psp, $i, 1);
      $found = 1;
      last;
      }
    }
  die "Assertion failed" unless $found;

  # bookkeeping
  $this->{'tournament'}->TellUser('ibye', $bye_p->TaggedName(), $round0+1);
  $this->Dirty(1);
  $this->Update();
  }

=item $c = $d->Classes();
=item $d->Classes($c);

Get/set a division's number of classes for prize purposes.
See also ClassList();

=cut

sub Classes ($;$) { TSH::Utility::GetOrSet('classes', @_); }

=item (@cs) = $d->ClassList();

Get a list of all a division's player classes in sorted order.

=cut

sub ClassList ($) {
  my $this = shift;
  my %classes;

  my $datap = $this->{'data'};
  for my $p (@$datap[1..$#$datap]) {
    my $class = $p->Class();
    $class = '' unless defined $class;
    for my $class1 ($class =~ /\b(\w+)\b/g) {
      $classes{$class1}++;
      }
    }
  return sort keys %classes;
  }

=item $d->ComputeBoards($sr0, $r0);

Compute player board number assignments in zero-based round $r0,
based on standings in zero-based round $sr0, accommodating
board reservations for players with special needs.
Computed board numbers may be obtained using Player::Board().

# If seats are in use, assign boards by seat number instead, and
# do not honor reservations.

=cut

sub ComputeBoards ($$$) {
  my $this = shift;
  my $sr0 = shift;
  my $r0 = shift;
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  my @sorted;
# if ($config->Value('seats')) {
#   $this->ComputeBoardsBySeat($r0);
#   return;
#   }
  if ($config->Value('standings_spread_cap')) {
    @sorted = TSH::Player::SortByCappedStanding $sr0, $this->Players();
    }
  else { 
    @sorted = TSH::Player::SortByStanding $sr0, $this->Players();
    }
# Debug 'CB', "sorted by round %d: %s", $sr0+1, join(',', map { $_->Name()} @sorted[0..9]);
  my %done;
  my %reserved_b_to_p;
  my @unreserved;
  # sample config line: perl $config'reserved{'P'}[13] = 4; # (to permanently station disabled player #13 in division P at board 4) 
  my $reservedsp = $config->Value('reserved');
  $reservedsp = $reservedsp->{$this->Name()} if $reservedsp;
  my (@reserved_p_to_b) = $reservedsp ? @$reservedsp : ();
  # for board stability
  my (%is_after_break) = (1=>1);
  for my $r0 (0, @{$config->Value('session_breaks')||[]}) {
    $is_after_break{$r0}++;
    }
  my $board_stability = $config->Value('board_stability');

  for my $p (@sorted) {
    my $pid = $p->ID();
#   my $oppid = $p->OpponentID($r0, 'undef for unpaired'); # what was this about?
    my $oppid = $p->OpponentID($r0);
    next unless $oppid;
    if (!$done{$pid}++) {
      my $opp = $this->Player($oppid);
      next if $pid != $opp->OpponentID($r0);
      next if $pid == $oppid;
      $done{$oppid}++;
      Debug 'CB', 'checking board for %s', $p->TaggedName({'localise' => 1});
      if ($p->Board($r0)) { 
	Debug 'CB', '%s has assigned board: %d', $p->TaggedName({'localise' => 1}), $p->Board($r0);
	my $board = $p->Board($r0);
	if (exists $reserved_b_to_p{$board}) {
	  $tourney->TellUser('eboardfull', $r0+1, $p->TaggedName({'localise' => 1}), $board,
	    $reserved_b_to_p{$board}[0]->TaggedName({'localise' => 1}),
	    $reserved_b_to_p{$board}[1]->TaggedName({'localise' => 1}));
	  $p->Board($r0, 0);
	  }
	else {
	  $reserved_b_to_p{$board} = [$p, $opp]; 
	  $reserved_p_to_b[$pid] = $board;
	  $reserved_p_to_b[$oppid] = $board;
	  next;
	  }
	}
      elsif (my $board = $reserved_p_to_b[$pid]) { 
	Debug 'CB', '%s has reserved board: %d', $p->TaggedName(), $board;
	if (exists $reserved_b_to_p{$board}) {
	  $tourney->TellUser('eboardfull', $r0+1, $p->TaggedName(), $board,
	    $reserved_b_to_p{$board}[0]->TaggedName(),
	    $reserved_b_to_p{$board}[1]->TaggedName());
	  }
	else {
	  $reserved_b_to_p{$board} = [$p, $opp]; 
	  next;
	  }
	}
      elsif ($board = $reserved_p_to_b[$oppid]) {
	Debug 'CB', '%s\'s opp %s has reserved board: %d', $p->TaggedName(), $opp->TaggedName(), $board;
	if (exists $reserved_b_to_p{$board}) {
	  $tourney->TellUser('eboardfull', $r0+1, $opp->TaggedName(), $board,
	    $reserved_b_to_p{$board}[0]->TaggedName(),
	    $reserved_b_to_p{$board}[1]->TaggedName());
	  }
	else {
	  $reserved_b_to_p{$board} = [$opp, $p]; 
	  next;
	  }
	}
      Debug 'CB', 'unreserved seating: %s %s', $p->TaggedName(), $opp->TaggedName();
      push (@unreserved, [$p, $opp]); 
      }
    } # for my $p (@sorted)
  if ($board_stability && !$is_after_break{$r0}) {
    # try to keep at least one player at the same board
    for (my $i=0; $i < @unreserved; $i++) {
      my $unrp = $unreserved[$i];
      my ($p, $opp) = @$unrp;
      Debug 'CB', 'Trying to stabilize %s or %s in round %d.', $p->{'name'}, $opp->{'name'}, $r0+1;
      my (@old_boards) = $i == 0 ? (1) : ($p->Board($r0-1), $opp->Board($r0-1));
      if ($opp->RoundWins($r0-1)-$opp->RoundWins($r0-2)
	> $p->RoundWins($r0-1)-$p->RoundWins($r0-2)) {
	Debug 'CB', '.. giving %s preference for recent win', $opp->{'name'};
	@old_boards = @old_boards[1,0];
        }
      for my $b (@old_boards) {
	next unless $b;
	next if exists $reserved_b_to_p{$b};
	$reserved_b_to_p{$b} = [$p, $opp]; 
	splice(@unreserved, $i, 1); # not shared, so splice is thread-safe
	Debug 'CB', '.. Placing them at board %d', $b;
	last;
	}
      }
    }
  # assign boards to remaining unseated players first-come first-served
  for (my $board=1; ; $board++) {
    my $p1;
    my $p2;
    if ($reserved_b_to_p{$board}) {
      ($p1, $p2) = @{$reserved_b_to_p{$board}};
      delete $reserved_b_to_p{$board};
      }
    elsif (@unreserved) { # take next pair from unreserved queue
      ($p1, $p2) = @{shift @unreserved};
      }
    elsif (%reserved_b_to_p) { next; }
    else { last; }
    $p1->Board($r0, $board);
    $p2->Board($r0, $board);
    }
  $this->Dirty(1);
  }

sub ComputeBoardsBySeat ($$) {
  my $this = shift;
  my $r0 = shift;
  my $tourney = $this->Tournament();
  for my $p ($this->Players()) {
    if (my $seat = $p->Seat($r0)) {
      $p->Board($r0, int((1+$seat)/2));
      }
    elsif ($p->OpponentID($r0)) {
      $tourney->TellUser('enoseat', TSH::Utility::TaggedName($p));
      }
    }
  }

=item $d->ComputeCappedRanks($sr0);

Compute capped (standings_spread_cap) rankings of players as of
zero-based round $sr0.
Computed rankings may be obtained using Player::RoundCappedRank().

=cut

sub ComputeCappedRanks ($$;$) {
  my $this = shift;
  my $sr0 = shift;
  my $optionsp = shift || {};

  my (@sorted) = TSH::Player::SortByCappedStanding $sr0, $this->Players();
  TSH::Player::SpliceInactive @sorted, 1, $sr0 unless $optionsp->{'show_inactive'};
  my $lastw = -1;
  my $lastl = -1;
  my $lasts = 0;
  my $rank = 0;
  for my $i (0..$#sorted) {
    my $p = $sorted[$i];
    my $wins = $p->RoundWins($sr0);
    my $losses = $p->RoundLosses($sr0);
    my $spread = $p->RoundCappedSpread($sr0);
    if ($wins != $lastw || $spread != $lasts || $losses != $lastl) {
      $lastw = $wins;
      $lastl = $losses;
      $lasts = $spread;
      $rank = $i+1;
      }
    $p->RoundCappedRank($sr0, $rank);
    }
  }

=item $i = $dp->ComputeFirstOutOfTheMoney($sortedp);

Given a list of players sorted by current rank, returns
the index of the one who is highest ranked but out of the
money, or one greater than the last index if everyone is
in the money.  Stores this value in $dp->{'first_out_of_the_money'}[$r0].
Internal use only: external routines should call FirstOutOfTheMoney().

=cut

sub ComputeFirstOutOfTheMoney ($$$) {
  my $this = shift;
  my $psp = shift;
  my $r0 = shift;
  Carp::confess "assertion failed: r0 negative" if $r0 < 0;
  my $config = $this->Tournament()->Config();
  my $first_out_of_the_money = scalar(@$psp);
  if (my $prize_bands = $config->Value('prize_bands')) {
    my $prize_band;
    if (ref($prize_bands) eq 'HASH') { $prize_band = $prize_bands->{$this->{'name'}}; }
    elsif (ref($prize_bands) eq 'ARRAY') { $prize_band = $prize_bands; }
    if ($prize_band) {
      my $last_money_rank = $prize_band->[-1];
      if (TSH::PairingCommand::CalculateBestPossibleFinish($psp, $#$psp) > $last_money_rank) {
	if (TSH::PairingCommand::CalculateBestPossibleFinish($psp, 0) > $last_money_rank) {
	  $first_out_of_the_money = 0;
	  }
	else {
	  my $low = 0; # is not
	  my $high = $#$psp; # is out of the money
	  while ($high - $low > 1) {
	    my $mid = int(($low+$high)/2);
	    if (TSH::PairingCommand::CalculateBestPossibleFinish($psp, $mid) > $last_money_rank) {
	      $high = $mid;
      #	warn "$mid is out of the money";
	      }
	    else {
	      $low = $mid;
      #	warn "$low is not out of the money";
	      }
	    }
	  $first_out_of_the_money = $high;
	  }
	}
      }
    }
  return $this->{'first_out_of_the_money'}[$r0] = $first_out_of_the_money ;
  }

=item $d->ComputeMoods($sr0);

Compute moods of players as of zero-based round $sr0.
Computed rankings may be obtained using Player::RoundMood().

Ranks and ratings must be calculated before moods.

Current algorithm: add the following values, clip to [-1,1], then scale to [0,100]
* rank scaled to [-1,1]
* +0.25 if in the money
* rating change normalized to maximum changes among peers, scaled to [-0.5,0.5]
* WL streak scaled to [-1,1]

=cut

sub ComputeMoods ($$;$) {
  my $this = shift;
  my $sr0 = shift;
  my $optionsp = shift || {};

  my $config = $this->Tournament()->Config();
  my $rating_system = $this->RatingSystem();
  my $min_rating_change = undef;
  my $max_rating_change = undef;

  my (@ps) = $this->Players();
  for my $p (@ps) {
    my $rating_change = $rating_system->RatingDifference($p->NewRating($sr0), $p->Rating());
    if (defined $min_rating_change) {
      $max_rating_change = $rating_change 
        if $rating_system->CompareRatings($max_rating_change, $rating_change) < 0;
      $min_rating_change = $rating_change 
        if $rating_system->CompareRatings($min_rating_change, $rating_change) > 0;
      }
    else {
      $min_rating_change = $rating_change;
      $max_rating_change = $rating_change;
      }
    }

  for my $p (@ps) {
    next unless $p->Active();
    my $rank = $p->RoundRank($sr0);
#   Carp::confess "No rank for $p->{'name'} in round $sr0+1";
    my $old_rating = $p->Rating();
    my $new_rating = $p->NewRating($sr0);
    my $rating_change = $rating_system->RatingDifference($new_rating, $old_rating);
    my ($streak_type, $streak_length) = $p->CountStreak($sr0);

    my $rank_mood = 1 - 2 * ($rank - 1) / (@ps - 1);
    my $money_mood = $rank <= $config->LastPrizeRank($this->{'name'}) ? 0.25 : 0;
    my $rating_mood = $old_rating ? $rating_system->CompareRatings($rating_change, 0) >= 0 ? 
      $rating_change / $max_rating_change : -$rating_change / $min_rating_change : 0;
    my $streak_mood = $streak_type * $streak_length / ($sr0 + 1);

    my $mood = $rank_mood + $money_mood + $rating_mood + $streak_mood;
    $mood = 1 if $mood > 1;
    $mood = -1 if $mood < -1;
    $mood = int(0.5+$mood * 50 + 50);
    $p->RoundMood($sr0, $mood);
    }
  }

=item $dp->ComputePerformanceRatings($r0[, $quiet]);

Compute performance ratings as of 0-based round C<$r0>.
If C<$quiet>, then don't write any status messages to
the console, and don't update the data file.

=cut

sub ComputePerformanceRatings ($$;$) {
  my $dp = shift;
  my $r0 = shift;
  return if $r0 < 0;
  my $noconsole = shift;

  if (my $rating_system = $dp->RatingSystem()) {
    my (%key_usage) = (
      # key usage map
      ewins => 'ewins',
      id => 'id',
      lifeg => 'lifeg',
      oldr => 'oldr',
      newr => 'newr',
      perfr => 'perfr',
      pairings => 'pairings',
      rgames => 'rgames',
      scores => 'scores',
      );

    # create a copy of the player list as of $r0 to avoid contamination
    my (@ps) = $dp->MakeRatingsInput($r0, {});

    # calculate new regular ratings, in case they're needed for the opponents
    # of newbies
    $dp->ComputeRatings($r0);
    for my $p (@ps) {
      $p->{newr} = $dp->Player($p->{id})->NewRating($r0);
      }

    # calculate ewins and rgames
    $rating_system->CountAllEWins(\@ps, 
      [[0, $r0]], # no splits for this calculation
      \%key_usage
      );
    $key_usage{ewins} = 'ewins0';
    $key_usage{rgames} = 'rgames0';
    # calculate perfr
    $rating_system->CalculatePerformanceRatings(
      \@ps, 
      0, # first round0
      $r0, # last round0
      \%key_usage,
      );
    # store perfr
    for my $p (@ps) {
      my $pp = $dp->Player($p->{id});
      $pp->GetOrSetEtcVectorMember('perfr', $r0,
	$p->{oldr} ? $p->{perfr} : $p->{newr});
      }

#   $rating_system->RateDivision('division' => $dp, 'r0' => $r0, 'noconsole' => $noconsole, 'allow_gaps' => $dp->Tournament()->Config()->Value('allow_gaps'));
    $dp->Dirty(1);
    $dp->Update() unless $noconsole;
    }
  else {
    $dp->Tournament()->TellUser('ebadconfigrating', 'ComputePerformanceRatings', 
      $dp->RatingSystemName());
    }
  return;
  }

=item $d->ComputeRanks($sr0);

Compute rankings of players as of zero-based round $sr0.
Computed rankings may be obtained using Player::RoundRank().

=cut

sub ComputeRanks ($$;$) {
  my $this = shift;
  my $sr0 = shift;
  my $optionsp = shift || {};

  # We don't use TSH::Utility::DoRanked here because it's too messy
  # to handle the $sr0 parameter to SortByStanding
  my (@sorted) = TSH::Player::SortByStanding $sr0, $this->Players();
  unless ($optionsp->{'show_inactive'}) {
#   warn scalar(@sorted);
    TSH::Player::SpliceInactive @sorted, 1, $sr0;
#   die scalar(@sorted);
    }
  if ($optionsp->{'splice_paired'}) {
    for (my $i=0; $i<@sorted; $i++) {
      if (defined $sorted[$i]->OpponentID($sr0)) {
	splice(@sorted, $i, 1);
	$i--;
        }
      }
    }
  my $lastw = -1;
  my $lastl = -1;
  my $lasts = 0;
  my $lastr = -1;
  my $rank = 0;
# warn "---";
  for my $i (0..$#sorted) {
    my $p = $sorted[$i];
    my $wins = $p->RoundWins($sr0);
    my $losses = $p->RoundLosses($sr0);
    my $spread = $p->RoundSpread($sr0);
#   warn $spread;
    my $rating = $p->Rating();
    if ($wins != $lastw || $spread != $lasts || $losses != $lastl || ($sr0 < 0 ? $rating ne $lastr : 0)) {
      $lastw = $wins;
      $lastl = $losses;
      $lasts = $spread;
      $lastr = $rating;
      $rank = $i+1;
      }
    $p->RoundRank($sr0, $rank);
    }
  }

=item $dp->ComputeRatings($r0[, $quiet]);

Estimate current ratings as of 0-based round C<$r0>.
If C<$quiet>, then don't write any status messages to
the console, and don't update the data file.

=cut

sub ComputeRatings ($$;$) {
  my $dp = shift;
  my $r0 = shift;
  return if $r0 < 0;
  my $noconsole = shift;
  if (my $rating_system = $dp->RatingSystem()) {
    $rating_system->RateDivision('division' => $dp, 'r0' => $r0, 'noconsole' => $noconsole, 'allow_gaps' => $dp->Tournament()->Config()->Value('allow_gaps'));
    $dp->Dirty(1);
    $dp->Update() unless $noconsole;
    }
  else {
    $dp->Tournament()->TellUser('ebadconfigrating', 'ComputeRatings', 
      $dp->RatingSystemName());
    }
  return;
  }

=item $dp->ComputeSeeds()

Compute player seeds and store: $dp->{'seeds'}[$p->ID()-1] = player seed

=cut

sub ComputeSeeds ($) {
  my $dp = shift;
  my (@seeded) = (TSH::Player::SortByInitialStanding($dp->Players()));
  my @seed : shared;
  my $lastrat = -1;
  my $rank = 1;
  for my $i (0..$#seeded) {
    my $p = $seeded[$i];
    my $rating = $p->Rating();
    if ($rating ne $lastrat) {
      $rank = $i+1;
      $lastrat = $rating;
      }
    $seed[$p->ID()-1] = $rank;
    }
  $dp->{'seeds'} = \@seed;
  }

=item $d->ComputeSupplementaryRatings($type);

Compute detailed rating information for this division, suitable
for administering a rating system.  Unlike C<ComputeRatings()>,
does not update the disk copy of the division, and computes all
segment-final ratings rather than a single-round rating.

=cut

sub ComputeSupplementaryRatings ($$) {
  my $this = shift;

  if (my $rating_system = $this->RatingSystem()) {
    $rating_system->RateDivisionSupplementary('division' => $this);
    $this->Dirty(1);
    }
  else {
    $this->Tournament()->TellUser('ebadconfigrating', 'ComputeRating', 
      $this->RatingSystemName());
    }
  return;
  }

=item $d->CopySupplementaryToMainRatings($type);

Copy supplementary rating data to the main rating data for each player.

=cut

sub CopySupplementaryToMainRatings($$) {
  my $this = shift;
  my $type = shift;
  my $datap = $this->{'data'};
  for my $pn (1..$#$datap) {
    my $pp = $datap->[$pn];
    $pp->Rating($pp->SupplementaryRatingsData($type, 'old'));
    $pp->LifeGames($pp->SupplementaryRatingsData($type, 'games'));
    }
  }

=item $n = $d->CountActivePlayers();

Return the number of active players in the division.
See also &CountPlayers.

=cut

sub CountActivePlayers ($) { 
  my $this = shift;
  my $n = 0;
  my $datap = $this->{'data'};
  for my $p (@$datap[1..$#$datap]) {
    $n++ if $p->Active();
    }
  return $n;
  }

=item $count = $d->CountByes();

Counts how many byes each player has had, returns least number.

=cut

sub CountByes ($) {
  my $dp = shift;

  my $datap = $dp->{'data'};
  my $minbyes = 9999999;

# warn "counting byes";
  for my $p (@$datap[1..$#$datap]) {
    next unless defined $p;
    my $byes = 0;
    for my $opp (@{$p->{'pairings'}}) {
      if ((defined $opp) && $opp == 0) {
	$byes++;
        }
      }
    $minbyes = $byes if $byes < $minbyes;
    $p->Byes($byes);
#   warn "$p->{'name'} $byes byes, opps: @{$p->{'pairings'}}";
    }
  return $minbyes;
  }

=item $n = $d->CountPlayers();

Return the number of players registered in the division.
To count only active ones, use &CountActivePlayers.

=cut

sub CountPlayers ($) { 
  my $this = shift;
  my $datap = $this->{'data'};
  return $#$datap; # players start at 1
  }

=item $dp->CountTeamRecords($wlr0, $rankr0, \%stats);

Tabulate team records, updating a hash that may include results from other divisions.
Count wins, losses and spread up to zero-based round r0.
Record player rankings as of zero-based round $r0.

The hash is keyed on team name, with each value being a reference
to a hash of team statistics.

The following statistics include games played between team members, and byes:
wins, losses, spread, count (of games), ranks (a list reference) and
ranksum.

The following statistics are based on the rounds up to r0 where
a player played a player from another team:
xwins, xlosses, xspread, xcount.

The following statistics are based on the rounds up to r0 where
a player played a player from another team, limited to the current configuration value of team_rank_count_cap:
xcwins, xclosses, xcspread, xccount.

If config squads is true, then results of rounds in which a team
plays only members of one other team (and possibly some ignored
games with their own team) go to tabulate:
xstwins, xstlosses, xstcount, xspwins, xsplosses, xspcount, xsspread

=cut

sub CountTeamRecords ($$$) {
  my $this = shift;
  my $wlr0 = shift;
  my $rankr0 = shift;
  my $countsp = shift;
  my $config = $this->Tournament()->Config();
  my $team_rank_count_cap = $config->Value('team_rank_count_cap');
  my $squads = $config->Value('squads');
  $this->ComputeRanks($rankr0);
  my %squadTemp;
  my %teamTemp;
  for my $p ($this->Players()) {
    next unless $p->Active();
    my $team = $p->Team();
    next unless length($team);
    my $maxr0 = Min($p->CountScores()-1, $wlr0);
    push(@{$teamTemp{$team}},[0,0,0,0]) if $team_rank_count_cap;
    if (!defined $countsp->{$team}) {
      $countsp->{$team}{'name'} = $team;
      $countsp->{$team}{'xstwins'} = 0;
      $countsp->{$team}{'xstlosses'} = 0;
      $countsp->{$team}{'xspwins'} = 0;
      $countsp->{$team}{'xsplosses'} = 0;
      $countsp->{$team}{'xsspread'} = 0;
      }
    for my $r0 (0..$maxr0) {
      my $opp = $p->Opponent($r0);
      next unless $opp;
      my $oteam = $opp->Team();
      next if $team eq $oteam;
      my $spread = $p->RoundGameSpread($r0);
      my $result = $spread <=> 0;
      my $won = ($result + 1)/2;
      my $lost = (1 - $result)/2;
      # count record against other teams
      $countsp->{$team}{'xwins'} += $won;
      $countsp->{$team}{'xlosses'} += $lost;
      $countsp->{$team}{'xcount'} ++;
      # keep another copy if only a capped number of ranks count for each team
      if ($team_rank_count_cap) {
	$teamTemp{$team}[-1][0] += $won;
	$teamTemp{$team}[-1][1] += $lost;
	$teamTemp{$team}[-1][2] += $spread;
	$teamTemp{$team}[-1][3] ++;
        }
      # count squad vs squad records
      if ($squads) {
	$squadTemp{$team}[$r0]{$oteam}{'wins'} += $won;
	$squadTemp{$team}[$r0]{$oteam}{'losses'} += $lost;
	$squadTemp{$team}[$r0]{$oteam}{'spread'} += $spread;
	$squadTemp{$team}[$r0]{$oteam}{'count'} ++;
        }
      }
    # count record against all opponents, including same team
    $countsp->{$team}{'wins'} += $p->Wins();
    $countsp->{$team}{'losses'} += $p->Losses();
    $countsp->{$team}{'spread'} += $p->Spread();
    $countsp->{$team}{'count'} ++;
    unless (defined $countsp->{$team}{'ranks'}) {
      $countsp->{$team}{'ranks'} = [];
      }
    my $rank = $p->RoundRank($rankr0);
    push(@{$countsp->{$team}{'ranks'}}, $rank);
    if ($team_rank_count_cap) {
      $teamTemp{$team}[-1][4] = $rank;
      }
    $countsp->{$team}{'ranksum'} += $rank;
    }
  # compute capped 
  if ($team_rank_count_cap) {
    for my $team (keys %teamTemp) {
      my $teamCounts = $countsp->{$team};
      # keep a copy of the top ranked players so that we can
      # update their total W-L +S as their identities change
#      warn "<$this->{'name'} [$team]: ".join(' ', map { "$_->[4]" } @{$teamCounts->{xcranked}});
      $teamCounts->{xcranked} = [sort {
	# 0:Wins 1:Losses 2:Spread 3:Games 4:Rank
	$a->[4] <=> $b->[4] or $b->[0] <=> $a->[0] or
	$a->[1] <=> $b->[1] or $b->[2] <=> $a->[2]
	} (@{$teamCounts->{xcranked}||[]}, @{$teamTemp{$team}})];
#     warn "=$this->{'name'} [$team]: ".join(' ', map { "$_->[4]" } @{$teamCounts->{xcranked}});
      my $teamData = $teamCounts->{xcranked};
      if (@$teamData > $team_rank_count_cap) {
	splice(@$teamData, $team_rank_count_cap);
	}
      $teamCounts->{xcwins} =
      $teamCounts->{xclosses} =
      $teamCounts->{xcspread} =
      $teamCounts->{xcranksum} =
      $teamCounts->{xccount} = 0;
      $teamCounts->{xcranks} = [];
      for my $teamMemberData (@$teamData) {
	# 20221112
# 	$countsp->{$team}{'cxwins'} += $teamMemberData->[0];
# 	$countsp->{$team}{'cxlosses'} += $teamMemberData->[1];
# 	$countsp->{$team}{'cxspread'} += $teamMemberData->[2];
# 	$countsp->{$team}{'cxcount'} += $teamMemberData->[3];
	$teamCounts->{'xcwins'} += $teamMemberData->[0];
	$teamCounts->{'xclosses'} += $teamMemberData->[1];
	$teamCounts->{'xcspread'} += $teamMemberData->[2];
	$teamCounts->{'xccount'} += $teamMemberData->[3];
	$teamCounts->{xcranksum} += $teamMemberData->[4];
	push(@{$teamCounts->{'xcranks'}}, $teamMemberData->[4]);
        }
#     warn ">$this->{'name'} [$team]: ".join(' ', map { "$_->[4]" } @{$teamCounts->{xcranked}});
      }
    }
  # compute squad
  if ($squads) {
    for my $team (keys %squadTemp) {
      my $team_data_p = $squadTemp{$team};
      for my $r0 (0..$#$team_data_p) {
	my $team_round_data_p = $team_data_p->[$r0];
	my (@oteams) = keys %$team_round_data_p;
	if (@oteams > 1) {
	  warn "Ignoring Round ".($r0+1)." results for squad $team, because they played more than one other squad.\n";
	  next;
	  }
	my $team_round_opp_data_p = $team_round_data_p->{$oteams[0]};
	my $oteam_round_opp_data_p = $squadTemp{$oteams[0]}[$r0]{$team};
	if (!$oteam_round_opp_data_p) {
	  warn "Assertion failed (no opponent squad data)\n";
	  next;
	  }
	$countsp->{$team}{'xspwins'} += $team_round_opp_data_p->{'wins'};
	$countsp->{$team}{'xsplosses'} += $team_round_opp_data_p->{'losses'};
	$countsp->{$team}{'xspcount'} += $team_round_opp_data_p->{'count'};
	$countsp->{$team}{'xsspread'} += $team_round_opp_data_p->{'spread'};
	my $team_result = 
	  $team_round_opp_data_p->{'wins'} 
	  <=> $oteam_round_opp_data_p->{'wins'}
	   || $oteam_round_opp_data_p->{'losses'} 
	  <=> $team_round_opp_data_p->{'losses'}
	  || $team_round_opp_data_p->{'spread'} 
	  <=> $oteam_round_opp_data_p->{'spread'};
	$countsp->{$team}{'xstwins'} += ($team_result + 1)/2;
	$countsp->{$team}{'xstlosses'} += (1 - $team_result)/2;
	$countsp->{$team}{'xstcount'} ++;
	}
      }
    }
  return;
  }

=item $d->DeactivateAllPlayers($spread);

Deactivate all players, with specified spread. 

=cut

sub DeactivateAllPlayers ($$) {
  my $this = shift;
  my $spread = shift;
  my $datap = $this->{'data'};

  for my $p (@$datap[1..$#$datap]) {
    $p->Deactivate($spread);
    }
  }

=item $d->DeleteAllPlayers();

Delete all players.  Does not check to see if players had
any data. Use with caution.

=cut

sub DeleteAllPlayers ($) {
  my $this = shift;
  my $datap = $this->{'data'};
  my $tourney = $this->Tournament();
  my $config = $tourney->Config();
  my $hasphotos = $config->Value('player_photos');

  while (@$datap) {
    my $pp = pop @$datap;
    next unless $pp;
    $tourney->UnregisterPlayer($pp);
    if ($hasphotos) {
      $config->UninstallPhoto($pp);
      }
    }
  push(@$datap, undef);
  }

=item $success = $d->DeleteByeScore($pn1, $round0);

Delete a bye score for the given player in the given (0-based) round.
Player must have had a bye that round.

=cut

sub DeleteByeScore($$$) {
  my $this = shift;
  my $pn1 = shift;
  my $round0 = shift;

  if (!$pn1) {
    return 0;
    }
  my $p1 = $this->Player($pn1);
  if ($p1->OpponentID($round0)) {
    TSH::Utility::Error "Can't delete bye score: "
      . $p1->Name() 
      . ' did not have a bye in Round ' . ($round0+1) . '.';
    return 0;
    }
  $p1->DeleteLastScore();
  return 1;
  }

=item $error = $d->DeletePlayer($pn[, \%options]));

Delete a single player. Options:

'division_paired_ok' => if true, do not return error if other players in division have pairings.  Use with caution, as it's conceivable that other code might think that player opponent lists are not volatile, and it makes this method non-reentrant.

=cut

sub DeletePlayer ($$;$) {
  my $this = shift;
  my $pn = shift;
  my $optionsp = shift || {};
  my $datap = $this->{'data'};
  my $tourney = $this->Tournament();
  my $config = $tourney->Config();
  my $hasphotos = $config->Value('player_photos');
  my $division_paired_ok = $optionsp->{'division_paired_ok'};

  if ($this->{'maxp'} >= 0) {
    die ['edelpap', $this->{'name'}] unless $division_paired_ok;
    # Even if the caller thinks it's okay to delete a player after the division
    # has been paired, we are not prepared to deal with the consequences if the
    # player themselves has been paired with other opponents. It's fine if they
    # have nothing but byes and forfeits.
    my $p = $datap->[$pn];
    my $no = $p->CountOpponents();
    for my $r0 (0..$no-1) {
      die ['edelpup', $this->Name(), $pn] if $p->OpponentID($r0);
      }
    }

  my ($pp) = splice(@$datap, $pn, 1);
  return 'no such player' unless $pp;
  $tourney->UnregisterPlayer($pp);
  if ($hasphotos) {
    $config->UninstallPhoto($pp);
    }

  # reassign necessary player IDs
  for my $pid ($pn..$#$datap) {
    $datap->[$pid]->ID($pid);
    }

  # adjust all pairings
  if ($this->{'maxp'} >= 0) {
    for my $pid (1..$#$datap) {
      my $p = $datap->[$pid];
      my $no = $p->CountOpponents();
      for my $r0 (0..$no-1) {
	my $oid = $p->OpponentID($r0);
	if ($oid >= $pn) {
	  $p->OpponentID($r0, $oid-1);
	  }
        }
      }
    }

  unless ($config->Value('no_random')) {
    delete $this->{'rnd'}{$pp->{'rnd'}};
    }
  $this->Dirty(1);
  }

=item $success = $d->DeleteScores($pn1, $pn2, $round0);

Delete scores for the given players in the given (0-based) round.
Players must have been paired with each other in that round.
Byes may be deleted by giving one of the player numbers as 0.

=cut

sub DeleteScores($$$$) {
  my $this = shift;
  my $pn1 = shift;
  my $pn2 = shift;
  my $round0 = shift;

  if (!$pn1) {
    return $this->DeleteByeScore($pn2, $round0);
    }
  elsif (!$pn2) {
    return $this->DeleteByeScore($pn1, $round0);
    }
  my $p1 = $this->Player($pn1);
  my $p2 = $this->Player($pn2);
  if ($p1->OpponentID($round0) != $pn2) {
    TSH::Utility::Error "Can't delete scores: "
      . $p1->Name() . ' and ' . $p2->Name()
      . ' did not play each other in Round ' . ($round0+1) . '.';
    return 0;
    }
  if ($round0 != $p1->CountScores() - 1) {
    TSH::Utility::Error "Can't delete scores: "
      . $p1->Name() . ' has a score in Round ' . ($round0+2) . '.';
    return 0;
    }
  if ($round0 != $p2->CountScores() - 1) {
    TSH::Utility::Error "Can't delete scores: "
      . $p2->Name() . ' has a score in Round ' . ($round0+2) . '.';
    return 0;
    }
  $p1->DeleteLastScore();
  $p2->DeleteLastScore();
  return 1;
  }

=item $n = $d->Dirty();

=item $d->Dirty($boolean);

Get/set a division's dirtiness.  A division is dirty when changes have been 
made to its data in this process, but the data file has not yet been updated.

=cut

sub Dirty ($;$) { TSH::Utility::GetOrSet('dirty', @_); }

=item $n = $d->DirtyRound();

=item $d->DirtyRound($r0);

Get/set a division's dirtyroundness.  A division is dirtyround when
changes have been made to its data that necessitate recalculating
round-based secondary statistics from the dirtyround forward.

=cut

sub DirtyRound ($;$) { TSH::Utility::GetOrSet('dirtyround', @_); }

=item $n = $d->File();

=item $d->File($n);

Get/set a division's file(name).

=cut

sub File ($;$) { TSH::Utility::GetOrSet('file', @_); }

=item $rank = $dp->FirstOutOfTheMoney($psp, $r0);

Given a list of players sorted by current rank, returns
the index of the one who is highest ranked but out of the
money, or one greater than the last index if everyone is
in the money.  Uses a cache that is reinitialized with each
run to save computation, but be sure to always use the same
list of players to avoid confusing the cache.

=cut

sub FirstOutOfTheMoney ($$$) {
  my $this = shift;
  my $psp = shift;
  my $r0 = shift;
  return scalar(@$psp) if $r0 < 0;
  my $footm = $this->{'first_out_of_the_money'}[$r0];
  return $footm if defined $footm;
  return $this->ComputeFirstOutOfTheMoney($psp, $r0);
  }

=item $r0 = $d->FirstUnpairedRound0()

Returns the (0-based) number of the first round that
is missing pairing information.

=cut

sub FirstUnpairedRound0($) {
  my $this = shift;
  return $this->{'minp'}+1;
  }

=item $dp->FormatPairing($round0, $pn1, $style)

Return a string describing the pairing for player $pn1 in 
zero-based round $round0 in division $dp.
C<$style> may be 
'normal', 'half', 'balanced', 'brief' or 'nextrat'.

'balanced': return a pair of strings representing what C<$pn1> and his opponent do (start/reply/draw).

=cut

sub FormatPairing ($$$;$) {
  my $this = shift;
  my $round0 = shift;
  my $pn1 = shift;
  my $optionsp = shift;

  # backward compatibility
  if ($optionsp) {
    if (!ref($optionsp)) {
      $optionsp = {'style' => $optionsp};
      }
    }
  else {
    $optionsp = {};
    }

  my $style = $optionsp->{'style'} || 'normal';
  my $use_html = $optionsp->{'html'} || 0;
  my $datap = $this->{'data'};
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  my $show_class = $config->Value('show_class_in_pairings');
  my $track_firsts = $config->Value('track_firsts');
  my $seats = $config->Value('seats');
  if ($style eq 'balanced' && !$track_firsts) { return ('', ''); }

  my $pn2 = $datap->[$pn1]{'pairings'}[$round0];
  return $style =~ /^(?:brief|nextrat)$/ ? $config->Terminology((defined $pn2) ? 'bye' : 'unpaired') : $style eq 'balanced' ? ('','') : '' unless $pn2;

  my $p = $datap->[$pn1];
  my $opp = $datap->[$pn2];
  my $p121 = $p->First($round0);
  my $p122 = $opp->First($round0);
# print "$pn1 $p121 $p122 $optionsp->{'style'}\n";
  my $pwhere;
  my $oppwhere;
  if ($seats or $style eq 'nextrat') {
    $pwhere = ($p->RenderLocation($round0))[1];
    $oppwhere = ($opp->RenderLocation($round0))[1];
    }
  for my $where ($pwhere, $oppwhere) 
    { $where = $where ? ' @'.$where : '' }
  my $tn_options = { 
    'html' => $optionsp->{'html'},
    'localise' => $optionsp->{'localise'},
    'style' => $optionsp->{'namestyle'},
    'use_pname' => $config->Value('use_pname'),
    'pname_from_sbname' => $config->Value('pname_from_sbname'),
    };
  # player 1 goes second and player 2 goes first
  if ($p121 == 2 && $p122 == 1) { 
    if ($style eq 'half') { 
      return $config->Terminology('second') . ' ' . $config->Terminology('vs')
	. ' ' . (TSH::Utility::TaggedName $opp, $tn_options); 
      }
    elsif ($style eq 'brief') { 
      return $config->Terminology('2nd') . ' ' . $config->Terminology('vs')
	. ' ' . $pn2;
      }
    elsif ($style eq 'nextrat') { 
      return $config->Terminology('2nd') . ' ' . $config->Terminology('vs')
	. ' ' . $opp->FullID() . $pwhere;
      }
    elsif ($style eq 'balanced') { 
      return (' ' . $config->Terminology('2nd'), ' ' . $config->Terminology('1st'));
      }
    ($p, $opp) = ($opp, $p);
    # FALL THROUGH!
    }
  # must draw for first and second
  elsif ($p121 == 3 && $p122 == 3) {
    if ($style eq 'half') { 
      return (($track_firsts ? $config->Terminology('draws') . ' ' : '')
	. $config->Terminology('vs')
	. ' ' . (TSH::Utility::TaggedName $opp, $tn_options)
        ); 
      }
    elsif ($style eq 'brief') { 
      return (($track_firsts ? '? ' : '') . $config->Terminology('vs')
	. ' ' . $pn2);
      }
    elsif ($style eq 'nextrat') { 
      return (($track_firsts ? '? ' : '') . $config->Terminology('vs')
	. ' ' . $opp->FullID() . $pwhere);
      }
    elsif ($style eq 'balanced') { 
      return $track_firsts 
        ? ($config->Terminology('draws'), $config->Terminology('draws'))
	: ('', '');
      }
    else { 
      my $pclass = '';
      my $oclass = '';
      if ($show_class) {
	$pclass = ' [' . $p->Class() . ']';
	$oclass = ' [' . $opp->Class() . ']';
        }
      return (TSH::Utility::TaggedName $p, $tn_options) 
        . $pclass
        . $pwhere
        . ($track_firsts ? ' *' . $config->Terminology('draws') . '* ' : ' ')
	. $config->Terminology('vs') . ' '
	. (TSH::Utility::TaggedName $opp, $tn_options)
        . $oclass
	. $oppwhere; 
      }
    }
  elsif (!($p121 == 1 && $p122 == 2)) {
    if ($style eq 'half') { 
      return 
        $config->Terminology('vs')
	. ' ' . (TSH::Utility::TaggedName $opp, $tn_options); 
      }
    elsif ($style eq 'brief') {
      return 
        ($track_firsts ? '? ' : '') 
	. $config->Terminology('vs')
	. ' ' . $pn2;
      }
    elsif ($style eq 'nextrat') {
      return 
        ($track_firsts ? '? ' . $config->Terminology('vs') . ' ': '') 
	. $opp->FullID() . $pwhere;
      }
    elsif ($style eq 'balanced') 
      { return $track_firsts ? qw(? ?) : ('',''); }
    else { 
      return (TSH::Utility::TaggedName $p, $tn_options) 
      . $pwhere
      . ' ' . $config->Terminology('vs') 
      . ' ' . (TSH::Utility::TaggedName $opp, $tn_options)
      . $oppwhere; 
      }
    }
  # FALLEN THROUGH FROM WAY ABOVE
  # player 1 goes first and player 2 goes second
  if ($style eq 'half') { 
    return $config->Terminology('first') . ' ' . $config->Terminology('vs')
      . ' ' . (TSH::Utility::TaggedName $opp, $tn_options); 
    }
  elsif ($style eq 'brief') { 
    return $config->Terminology('1st') . ' ' . $config->Terminology('vs')
      . ' ' . $pn2;
    }
  elsif ($style eq 'nextrat') { 
    return $config->Terminology('1st') . ' ' . $config->Terminology('vs')
      . ' ' . $opp->FullID() . $pwhere;
    }
  elsif ($style eq 'balanced') { 
    return (' ' . $config->Terminology('1st'), ' ' . $config->Terminology('2nd'));
    }
  else { 
    my $pclass = '';
    my $oclass = '';
    if ($show_class) {
      $pclass = ' [' . $p->Class() . ']';
      $oclass = ' [' . $opp->Class() . ']';
      }
    return (TSH::Utility::TaggedName $p, $tn_options) 
      . $pclass
      . $pwhere
      . ($track_firsts ? ' *' . $config->Terminology('first') . '* ' : ' ')
      . $config->Terminology('vs')
      . ' ' . (TSH::Utility::TaggedName $opp, $tn_options)
      . $oclass
      . $oppwhere;
    }
  }

=item $value = $d->GetConfigValue($key);

Return the value of a tournament configuration variable that may be specified
on a tournament-wide or division-by-division basis.

=cut

sub GetConfigValue($$) {
  my $this = shift;
  my $key = shift;

  my $value = $this->Tournament()->Config()->Value($key);
# warn "1. $key:$value";
  return $value unless ref($value) eq 'HASH';
# warn "2. $key:$value";
  my $name = $this->Name();
# warn "3. $key;$name:$value:".join(';', %$value);
# return $value unless exists $value->{$name};
# warn "4. $key:$value->{$name}";
  return $value->{$name};
  }

=item $fn = $d->GetInputRatingFilename()

The input rating file for a division contains the ratings for players who
were rated before the beginning of an event.  This function returns the
name of that file.  

On error: return undef.

Side effect: if the file does not exist, it will be created, along with
any necessary directories in its path.

=cut

sub GetInputRatingFilename ($) {
  my $dp = shift;

  my $tournament = $dp->{'tournament'};
  my $config = $tournament->Config();

  if (my $series = $config->Series()) {
    # warn "we are in a session in a multi-session series";
    my $series_id = $series->SeriesID();
    my $previous_session_id = $series->PreviousSessionID();
    if (defined $previous_session_id) {
      return $config->MakeLibPath(File::Spec->catfile('ratings', $series_id, 
	"$previous_session_id.txt"));
      }
    # warn "we are in the first session, so ratings are in _initial.txt";
    my $filename = $config->MakeLibPath(File::Spec->catfile('ratings', $series_id, 
      '_initial.txt'));
    return $filename if -e $filename;
    # warn "creating missing $filename and any necessary paths";
    my $dirname = File::Spec->catfile('ratings', $series_id);
    eval { mkpath $dirname, 0, 0755; };
    if ($@) {
      $tournament->TellUser('edircre', $dirname, $@);
      return undef;
      }
    if (my $fh = TSH::Utility::OpenFile '>', $filename) 
      { close $fh; }
    else {
      $tournament->TellUser('efilecre', $filename, $@);
      return undef;
      }
    return $filename;
    }

  my $rating_list = $dp->RatingList();
  return $config->MakeLibPath("ratings/$rating_list/current.txt");
  }

=item $psp = $d->GetUnpaired($emptyok)

Return a vector of active
players that need to be paired in the last round in the given division.
If the last round is fully paired, the return value will be
the empty vector if C<$emptyok> is true
and a vector of all active players if it is false.

Think carefully before using this method; you may want to use
TSH::PairingCommand::SetupForPairings instead if you want to
filter results by Gibsonization and assignment of byes.

=cut

sub GetUnpaired ($;$) {
  my $dp = shift;
  my $emptyok = shift;

  my @unpaired = $emptyok 
    ? @{$dp->GetUnpairedRound($dp->LastPairedRound0())}
    : @{$dp->GetUnpairedRound($dp->FirstUnpairedRound0())};
# print 'y:', scalar(@unpaired), ',', $dp->{'maxp'}, "\n";
  TSH::Player::SpliceInactive @unpaired, 1, $dp->FirstUnpairedRound0();

  return \@unpaired;
  } 

=item $psp = $d->GetUnpairedRound($sr0)

Return a vector of active players that need to be paired in the given
zero-based round.

=cut

sub GetUnpairedRound ($$) {
  my $dp = shift;
  my $round0 = shift;

  my @unpaired = ();

  for my $p ($dp->Players()) {
    next if defined $p->OpponentID($round0);
    push(@unpaired, $p);
    } # for $p

  TSH::Player::SpliceInactive @unpaired, 1, $round0;
  
  return \@unpaired;
  } # sub GetUnpairedRound

=item $boolean = $dp->HasTables();

Returns true if this division has table names.

=cut

sub HasTables ($) {
  my $dp = shift;
  return $dp->{'tournament'}->Config()->{'tables'}{$dp->{'name'}};
  }

=item $d->initialise();

(Re)initialise a Division object, for internal use.

=cut

sub initialise ($) {
  my $this = shift;
  $this->{'name'} = '';
  my @data : shared;
  push(@data, undef);
  # 'classes': if an integer, the number of classes to assign players to
  # at start (see &Config::AssignClasses); if a hash, 
  $this->{'classes'} = undef;
  $this->{'data'} = \@data;
  my @footm : shared;
  $this->{'first_out_of_the_money'} = \@footm;
  # player random numbers seen
  my %rnd : shared;
  $this->{'rnd'} = \%rnd;
  my %teams : shared;
  $this->{'teams'} = \%teams;
  $this->{'rating_system'} = undef;
  }

=item $boolean = $d->IsComplete();

Return true if every active player in the division has C<config max_rounds> scores.

=cut

sub IsComplete ($) {
  my $this = shift;
  my $tourney = $this->{'tournament'};
  unless (defined $this->{'maxr'}) {
    $tourney->TellUser('eneed_max_rounds');
    return 0;
    }
  my $datap = $this->{'data'};
  for my $p (@$datap[1..$#$datap]) {
    next unless $p->Active();
    for my $r0 (0..$this->{'maxr'}) {
      next if defined $p->Score($r0);
      $tourney->TellUser('edivpart', $p->TaggedName(), $r0+1);
      return 0;
      }
    }
  return 1;
  }

=item $d->PromptIfNotLatestScoredRound0($$);

Prompt the user if the 0-based round provided is earlier than the latest 
round for which all scores have been entered in this division.

=cut

sub PromptIfNotLatestScoredRound0 ($$) {
  my $this = shift;
  my $sr0  = shift;
  if ($this->LeastScores() > $sr0 + 1) {
    my $tournament = $this->{'tournament'};
    my $config = $tournament->Config();
    if ($config->Value('ignore_stale_source_round')) { return 1; }
    $tournament->TellUser('wprnlr', $sr0+1, $this->LeastScores());
    if (!$config->Value('no_console_input')) {
      my $prompt = $config->Terminology('staleok') || '?';
      TSH::Utility::Prompt $prompt;
      my $ok = scalar(<STDIN>);
      return ($ok =~ /^y(e(s)?)?$/i); # TODO i18n
      }
    }
  return 1;
  }


=item $d->PurgeReportsByRound0($$);

Remove all reports which may have been invalidated by the deletion of a
round's data, so users don't mistake leftover provisional reports for
actual data (like pairings).

=cut

sub PurgeReportsByRound0 ($$) {
  my $this = shift;
  my $round  = sprintf "%03d", shift() + 1;
  my $dname = $this->Name();
  my $config = $this->{'tournament'}->Config();
  my $html_suffix = $config->Value('html_suffix');

# Candidates for deletion are:

# alpha-pairings-NNN
# multipair-NNN-NNN
# pairings-NNN
# scorecard
# alpha-pairings
# standings
# CSC-\d+
# tally-slips-NNN

  foreach my $fn ( (glob( $config->MakeRootPath("$dname-*$html_suffix") ),
		    glob( $config->MakeHTMLPath("$dname-*$html_suffix") )) )
    {
      my $basename = $fn;
      $basename =~ s/.*\/$dname-//;
      $basename =~ s/\.doc$//;
      $basename =~ s/$html_suffix$//;
      
      $basename =~ /^scorecard$
		   |^CSC-\d+$
		   |^alpha-pairings$
		   |^pairings$
		   |^standings$
		   |^alpha-pairings-(\d\d\d)$
		   |^pairings-(\d\d\d)$
		   |^tally-slips-(\d\d\d)$/x
	&& do
	  {
	    # Unconditional delete, $round will be 0 in case of
	    # TRUNCATEROUNDS 0, which is 'delete all (for div)'
	    if ( ! defined $1 || $1 >= $round || $round == 0 )
	      {
		unlink $fn or warn "Failed to unlink $fn ($!)";
	      }
	    next;
	  };

      $basename =~ /^multipair-(\d\d\d)-(\d\d\d)$/x
	&& do
	  {
	    if ( $round >= $1 && $round <= $2 )
	      {
		unlink $fn or warn "Failed to unlink $fn ($!)";
	      }
	    next;
	  };
    }
}

=item $n = $d->Label();

Return a division's label.

=cut

sub Label ($) { 
  my $this = shift;
  my $name = shift;
  my $config = $this->{'tournament'}->Config();
  my $label;
  if (my $labels = $config->Value('division_label')) {
    $label = $labels->{$this->{'name'}};
    }
  $label ||= $config->Terminology('Division') . ' ' . $this->{'name'};
  return $label;
  }

=item $d->LastPairedRound0();

Returns the (0-based) number of the last round that
contains pairing information, not including inactive players.

=cut

sub LastPairedRound0 ($) {
  my $this = shift;
  return $this->{'maxp'};
  }

=item $d->LastPairedScoreRound0();

Returns the (0-based) number of the last round that
contains a paired (nonbye) score.

=cut

sub LastPairedScoreRound0 ($) {
  my $this = shift;
  return $this->{'maxps'};
  }

=item $n = $d->LastPairedScorePlayer();

Returns a player who has a paired score in  $this->LastPairedScoreRound0().

=cut

sub LastPairedScorePlayer ($) {
  my $this = shift;
  return $this->{'maxps_player'};
  }

=item $n = $d->LeastScores();

Returns the smallest number of scores that any player in the division
has recorded.  At least for now, it does not work well with allow_gaps.

=cut

sub LeastScores ($) {
  my $this = shift;
  return $this->{'mins'} + 1;
  }

=item $n = $d->LeastScoresPlayer();

Returns a player who has only $this->LeastScores() scores.

=cut

sub LeastScoresPlayer ($) {
  my $this = shift;
  return $this->{'mins_player'};
  }

=item $d->LoadRatings($rating_system);

Load current ratings and game totals from a rating system.

=cut

sub LoadRatings ($$) {
  my $this = shift;
  my $rating_system = shift;
  my $datap = $this->{'data'};
  my $colons_optional = $this->RatingSystemName() =~ /nsa|naspa|nssc/;
  for my $pp (@$datap[1..$#$datap]) {
    my $key = uc $pp->Name();
    $key =~ s/, / /g;
    my $new = $rating_system->Rating($key);
    if (defined $new) {
      $pp->Rating($new); 
      $pp->LifeGames($rating_system->Games($key));
#     warn join(';', $key, $pp->Rating(), $new, $rating_system->Games($key));
      next;
      }
    if ($colons_optional) {
      $key =~ s/:.*//;
      $new = $rating_system->Rating($key);
      if (defined $new) {
	$pp->Rating($new); 
	$pp->LifeGames($rating_system->Games($key));
  #     warn join(';', $key, $pp->Rating(), $new, $rating_system->Games($key));
	next;
	}
      }
    if (my $old = $pp->Rating()) {
      warn "Not removing old rating $old for $key.";
      }
    }
  }

=item $d->LoadRatingsFile(%options);

Load current ratings and game totals from the configured rating list file.
Options:

C<list>: optionally override default list name

C<fallback>: if true, only load ratings for unrated players

C<unrate>: if true, unrate players not found in rating list

=cut

sub LoadRatingsFile ($@) {
  my $this = shift;
  my $tourney = $this->Tournament();
  my (%argh) = @_;
  my $config = $tourney->Config();
  my $series = $config->Series();
# warn "LRF-SI: ".$config->Value('series_id');
# warn "LRF: $series";

  my $rating_list = $argh{'list'} || $this->RatingList();
  my $rating_system = $this->RatingSystem();
  my $fallback = $argh{'fallback'};
  # if using one of the NASPA rating lists, unrate unknown players
  # so that they can be fallback-rated from other rating lists
  # (CSW->OWL or OWL->CSW)
  $argh{'unrate'} ||= $rating_list =~ /^(?:naspa-csw|nsa)$/ unless $argh{'fallback'};
  my $success = 1;

  # We are comparing our division roster (which may consist of 
  # teams of separately rated players) with a possibly lengthy
  # list of all rated players.  When we find any of several 
  # types of differences, we update the division roster.
  #
  # We do this in three phases.  First, build a hash of the rated
  # players, so we can easily tell who is thought to be rated, who
  # isn't, and where they are in the division.  Second, linearly
  # scan the rating list to locate and cache update information.
  # Third, scan the player roster and update as necessary.  
  #
  # If at some point the rating list becomes huge, we should switch
  # to just scanning the player in a single pass, randomly accessing
  # the list as necessary.  We aren't doing so now, because the lists 
  # are currently flat not necessarily sorted text files.

  # 1. Find all ratable players.
  my $pdsp = $this->RatablePlayers('list' => $rating_list) || do {
    warn "Ratings will not be updated";
    return;
    };

  # 2. Scan the rating list and add any new rating data found to the hash.
  my $fn = $this->GetInputRatingFilename();
  $rating_system->LoadFileToHash($fn, $pdsp) or do {
    $tourney->TellUser('euseropen', $fn, $!);
    return 0;
    };

  # Finally, scan the player list again and update with any new
  # information.  
# warn join(',', %{$pdsp->{'COLE JUDY'}});
  for my $p ($this->Players()) {
    $p->UpdateRatingData($pdsp, \%argh);
    }

  unless ($argh{'fallback'}) {
    if ($rating_list eq 'naspa-csw') {
      $success &&= $this->LoadRatingsFile('list' => 'nsa', 'fallback' => 1);
      }
    elsif ($rating_list eq 'nsa') {
      $success &&= $this->LoadRatingsFile('list' => 'naspa-csw', 'fallback' => 1);
      }
    }
  return $success;
  }

=item $pdsp = $d->RatablePlayers(%options);

Return a hash mapping names of individual players (possibly members
of compositely rated teams) to references to hashes mapping C<'p'>
to a reference to the appropriate TSH::Player object and C<'i'> to
a zero-based index (0 in the case of non-composite ratings) identifying
individual players within their teams.

Options:

C<list>: optionally override default list name

=cut

sub RatablePlayers ($@) {
  my $this = shift;
  my (%argh) = @_;
  my $rating_list = $argh{'list'} || $this->RatingList();
  my $rating_system = $this->RatingSystem();
  my $colons_optional = $this->RatingSystemName() =~ /nsa|naspa|nssc/;
  
  my %pds;
  for my $p ($this->Players()) {
    my (@names) = $rating_system->CanonicaliseName($rating_list, uc $p->Name());
    for my $i (0..$#names) {
      my $name = uc $names[$i];
      next if $name =~ /^SHOW,?\s*NO$/;
      $name =~ s/,//g;
      if ($pds{$name}) {
        warn "Duplicate players named $name, aborting" unless $argh{'quiet'};
	return undef;
        }
      $pds{$name} = {'p' => $p, 'i' => $i};
      if ($colons_optional && $name =~ s/:.*// && !$pds{$name}) {
	$pds{$name} = {'p' => $p, 'i' => $i};
	}
      }
    }
  return \%pds;
  }

=item $d->LoadSupplementaryRatings($rating_system[, \%options]);

Load supplementary ratings and game totals from a rating system.

=cut

sub LoadSupplementaryRatings ($$;$) {
  my $this = shift;
  my $rating_system = shift;
  my $optionsp = shift;
  my $type = $rating_system->Name();
  my $datap = $this->{'data'};
  my $canonp = $this->Tournament()->Config()->Value('canonicalize_tfile_player_name');
  my $rating_term_count = $rating_system->RatingTermCount();
  for my $pn (1..$#$datap) {
    my $pp = $datap->[$pn];
    die "Division $this->{'name'} Player $pn is not defined" unless ($pp) and ref($pp) eq 'TSH::Player';
    my $key = $pp->Name();
    my @names;
    if ($canonp) {
      (@names) = &$canonp($key);
      }
    else {
      $key = uc $key; 
      $key =~ s/, / /g;
      # TODO: should check for correct membership number
      $key =~ s/:.*$// if $type =~ /nsa|naspa/;
      (@names) = $key;
      }
    if (@names == 1) {
      $key = $names[0];
      my $new = $rating_system->Rating($key) if defined $key;
      if ($new) {
	$pp->SupplementaryRatingsData($type, 'new', $new); 
	$pp->SupplementaryRatingsData($type, 'old', $new); 
#warn join("\n", keys %{$rating_system->{'_players'}});
	$pp->SupplementaryRatingsData($type, 'games', $rating_system->Games($key)) if defined $key;
  #     warn join(';', $key, $pp->Rating(), $new, $rating_system->Games($key));
	}
      elsif ($optionsp->{'fallback'}) {
#	warn "Trying fallback rating for $key";
	$TSH::Division::debug_key = $key if $key; # useful in debugging runmonth when player has no key
        my $rating = &{$optionsp->{'fallback'}}($key);
	if (defined $rating) {
	  $pp->SupplementaryRatingsData($type, 'new', $rating);
	  $pp->SupplementaryRatingsData($type, 'old', $rating);
	  $pp->SupplementaryRatingsData($type, 'games', 0);
	  }
        }
      elsif (my $old = $pp->Rating()) {
#	warn "Not removing old rating $old for $key."; # 20140609 - removed, why?
 	warn "Removing old rating $old for $key."; # 20140609
	$pp->SupplementaryRatingsData($type, 'new', 0);
	$pp->SupplementaryRatingsData($type, 'old', 0);
	$pp->SupplementaryRatingsData($type, 'games', 0);
	}
      }
    else { # team ratings
      my (%team_data);
      for my $params (
	['new', $rating_term_count], 
	['old', $rating_term_count], 
	['games', 1], 
	) {
	my ($skey, $field_width) = @$params;
	my $data = $pp->SupplementaryRatingsData($type, $skey);
	my (@values) = split(/\+/, $data || '');
	$#values = @names * $field_width - 1;
	(@values) = map { $_ || 0 } @values;
	my (@pvalues);
	while (@values) {
	  push(@pvalues, join('+', splice(@values, 0, $field_width)));
	  }
	$team_data{$skey} = \@pvalues;
        }
      for my $i (0..$#names) {
	my $name = $names[$i];
	my $new = $rating_system->Rating($name);
	die "Unknown name in $key" unless defined $name;
	my (@new) = split(/\+/, $new || 0);
	$#new = $rating_term_count - 1;
	(@new) = map { $_ || 0 } @new;
	$new = join('+', @new);
	if (defined $new) {
	  $team_data{'new'}[$i] = $team_data{'old'}[$i] = $new;
	  $team_data{'games'}[$i] = $rating_system->Games($name);
	  }
	elsif (my $old = $pp->Rating()) {
	  warn "Not removing old rating $old for $name.";
	  }
        }
      for my $skey (qw(new old games)) {
#       local($") = '+'; warn "$pp->{'name'}: $skey = @{$team_data{$skey}}";
	$pp->SupplementaryRatingsData($type, $skey, 
	  join('+', @{$team_data{$skey}}));
        }
      }
    }
  }

=item (@ps) = $dp->MakeRatingsInput($r0, $optionsp);

Return a list of hashes representing data for each player, in a way that
is compatible with legacy rating system code, copying only data up to 
0-based round C<$r0>.

Valid options:

  allow_gaps: allow gaps in score list

=cut

sub MakeRatingsInput ($$$) {
  my $this = shift;
  my $r0 = shift;
  my $optionsp = shift;

  my $allow_gaps = $optionsp->{allow_gaps};
  my (@ps);
  for my $p ($this->Players()) {
    my $id = $p->ID();
    my $lifeg = $p->{'etc'}{'lifeg'};
    $lifeg = (defined $lifeg) ? ($lifeg->[0]||0) : 100;
    my $pr0 = $p->CountScores() - 1;
    if ($r0 < $pr0) { $pr0 = $r0; }
    $ps[$id-1] = {
      'name' => $p->Name(),
      'oldr' => $p->Rating(),
      'pairings' => [ map { ($_||0)-1 } @{$p->{'pairings'}}[0..$pr0] ],
      'scores' => [ map { $_|| ($allow_gaps ? undef : 0) } @{$p->{'scores'}}[0..$pr0] ],
      'lifeg' => $lifeg,
      'id' => $id,
      'p' => $id,
      };
    }
  return @ps;
  }

=item (@win_groups) = MakeWinGroups($sr0, \@players);

Divide players into win groups.  Players must be in rank order as
of round C<$sr0>.

=cut

sub MakeWinGroups ($$) {
  my $sr0 = shift;
  my $psp = shift;
  my @win_groups = ();
  my $wins = -1;

  return () unless @$psp;
  for my $p (@$psp) {
    my $this_wins = $p->RoundWins($sr0);
    if ($this_wins == $wins) {
      push(@{$win_groups[-1]}, $p);
      }
    else {
      push(@win_groups, [$p]);
      $wins = $this_wins;
      }
    } # for my $p
  return @win_groups;
  }

=item $r0 = $d->MaxRound0();
=item $d->MaxRound0($r0);

Get/set a division's maximum configured round number (0-based).

=cut

sub MaxRound0 ($;$) { TSH::Utility::GetOrSet('maxr', @_); }

=item $d->MaxRoundPlayed0();

Get the 0-based number of the last round for which the division
has a scored from a played game (as opposed to a bye).

=cut

sub MaxRoundPlayed0 ($) { TSH::Utility::GetOrSet('maxrp'); }

=item $n = $d->MostScores();

Returns the largest number of scores that any player in the division
has recorded.

=cut

sub MostScores ($) {
  my $this = shift;
  return $this->{'maxs'} + 1;
  }

=item $n = $d->MostScoresPlayer();

Returns a player who has $this->MostScores() scores.

=cut

sub MostScoresPlayer ($) {
  my $this = shift;
  return $this->{'maxs_player'};
  }

=item $success = $d->MovePlayersToOtherDivisions(\%map);

Move players to other divisions.  C<\%map> should map target division names
to references to lists of IDs of players needing to be moved.
Should not be used in a multithreaded environment until we can lock 
divisions.
Return true iff successful.

=cut

sub MovePlayersToOtherDivisions ($$) {
  my $this = shift;
  my $arghp = shift;
  my $tourney = $this->{'tournament'};
  # check that groups are closed under pairing
  for my $pnp (values %$arghp) {
    my %members;
    for my $pn (@$pnp) { $members{$pn}++; }
    for my $pn (@$pnp) {
      my $p = $this->{'data'}[$pn];
      for my $r0 (0..$p->CountOpponents()-1) {
	if (my $oid = $p->OpponentID($r0)) {
	  if (!$members{$oid}) {
	    my $r1 = $r0+1;
	    warn "In round $r1, player $pn plays player $oid, who is in a different division";
	    return 0;
	    }
	  }
        }
      }
    }
  # compute new IDs for players who are not moving
  my @newids;
  my @movers = sort { $a <=> $b } map { @$_ } values %$arghp;
  my @stayers;
  my $offset = 0;
  for my $pn (1..$#{$this->{'data'}}) {
    if ($pn == $movers[$offset]) {
      $offset++;
      }
    else {
      $newids[$pn] = $pn - $offset;
#     warn "$pn will be $newids[$pn]";
      push(@stayers, $pn);
      }
    }
  # renumber opponents for stayers
  for my $pn (@stayers) {
    my $p = $this->{'data'}[$pn];
    for my $r0 (0..$p->CountOpponents()-1) {
      if (my $oid = $p->OpponentID($r0)) {
	if (my $newoid = $newids[$oid]) {
	  $p->{'pairings'}[$r0] = $newoid;
	  }
	else {
	  die "assertion failed, unknown opponent";
	  }
        }
      }
    }
  # copy movers to their destinations
  while (my ($dname, $pnsp) = each %$arghp) {
    my $dp = $tourney->GetDivisionByName($dname);
    # compute new IDs for players who are moving
    my $targetpn = $dp->CountPlayers() + 1;
    for my $pn (@$pnsp) {
      $newids[$pn] = $targetpn++;
      }
    # reassign pairings based on new IDs
    for my $pn (@$pnsp) {
      my $p = $this->Player($pn);
      for my $r0 (0..$p->CountOpponents()-1) {
	if (my $oid = $p->OpponentID($r0)) {
	  if (my $newoid = $newids[$oid]) {
	    $p->{'pairings'}[$r0] = $newoid;
	    }
	  else {
	    die "assertion failed, unknown opponent";
	    }
	  }
	}
      push(@{$dp->{'data'}}, $p);
      }
    }
  # delete movers from this division
  for (my $i=$#movers; $i>=0; $i--) {
    my $pid = $movers[$i];
#   warn "deleting $pid, max pid was $#{$this->{'data'}}";
    splice(@{$this->{'data'}}, $pid, 1);
    }

  return 1;
  }

=item $n = $d->Name();
=item $d->Name($n);

Get/set a division's name.  See also Label()
Caution: does not update divhash in a parent tournament, if any.

=cut

sub Name ($;$) { 
  my $this = shift;
  my $name = shift;
  my $old = $this->{'name'};
  if (defined $name) { 
    $this->{'name'} = CanonicaliseName($name); 
    }
  return $old;
  }

=item $d = new Division;

Create a new Division object.  

=cut

sub new ($) { return TSH::Utility::newshared(@_); }

=item $success = $d->Pair($pn1, $pn2, $round0, $repair);

Pair two players in a given round.  Set one player number to 0 for a bye.
$repair must be true to re-pair a non-final pairing without emitting
a warning. Return boolean success.

=cut

sub Pair ($$$$;$) { 
  my $this = shift;
  my (@p) = (shift, shift);
  my $round0 = shift;
  my $repair = shift;
  my $datap = $this->{'data'};
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  my $c_allow_gaps = $config->Value('allow_gaps');
  my $c_assign_firsts = $config->Value('assign_firsts');
  my $round = $round0 + 1;
  # validate arguments
  return unless ($p[0] || $p[1]); # wise guy, huh?
  for my $p (@p) {
    if ($p < 0 || $p > $#$datap) {
      $tourney->TellUser('enosuchp', $p);
      return 0;
      }
    next unless $p;
    my $nopps = $datap->[$p]->CountOpponents();
    unless ($c_allow_gaps) {
      if ($repair ? $nopps< $round0 : $nopps != $round0) {
	$tourney->TellUser('eprbadr', $p, $nopps+1, $round);
	return 0;
	}
      }
    }
  # update each player
  for my $i (0..1) {
    my $p = $p[$i];
    my $o = $p[1-$i];
    next unless $p;
    my $pp = $datap->[$p];
    my $opp = $pp->Opponent($round0);
    # check to see if opponent was already paired to someone else
    if ($opp && $opp->ID() != $o) {
      $tourney->TellUser('iprwasp',
        $pp->TaggedName(), $opp->TaggedName());
      if ($round == $opp->CountOpponents()) {
	pop @{$opp->{'pairings'}};
	if ($round == $opp->CountScores()) {
	  $opp->DeleteLastScore();
#	  pop @{$opp->{'scores'}}; # 2011-03-12
	  }
        }
      else {
	$opp->{'pairings'}[$round0] = 0;
	if ($round < $opp->CountScores()) {
	  $opp->Score($round0, $config->Value('bye_spread'));
#	  $opp->{'scores'}[$round0] = $config->Value('bye_spread'); # 2011-03-12
	  }
        }
      }
    $pp->{'pairings'}[$round0] = $o;
    # check to see if firsts and seconds conflict for new pairings
    if ($c_assign_firsts && $o) {
      my $newopp = $datap->[$o];
      my $p12 = $pp->First($round0);
      my $o12 = $newopp->First($round0);
      my $p1 = 0;
      my $p1streak = 0;
      my $o1 = 0;
      my $o1streak = 0;
      if ($p12 == $o12 && ($p12 == 1 || $p12 == 2)) {
	$tourney->TellUser($p12 == 1 ? 'idivb1st' : 'idivb2nd',
	  $round0+1, $pp->TaggedName(), $newopp->TaggedName());
	for my $r0 (0..$round0-1) {
	  if ($pp->First($r0) == 1) {
	    $p1++;
	    $p1streak++;
	    }
	  else {
	    $p1streak = 0;
	    }
	  if ($newopp->First($r0) == 1) {
	    $o1++;
	    $o1streak++;
	    }
	  else {
	    $o1streak = 0;
	    }
	  }
	if ($p1 > $o1) { 
	  $pp->First($round0, 2);
	  $newopp->First($round0, 1);
	  }
	elsif ($o1 > $p1) {
	  $pp->First($round0, 1);
	  $newopp->First($round0, 2);
	  }
	# TODO: check config avoid_sr_runs here
	elsif (int(rand(2))) {
	  $pp->First($round0, 2);
	  $newopp->First($round0, 1);
	  }
	else {
	  $pp->First($round0, 1);
	  $newopp->First($round0, 2);
	  }
	}
      }
    }
  $this->Dirty(1);
  return 1;
  }

=item PairSomeSwiss($psp, $repeats, $sr0)

Swiss-pair the players in $psp (who should be in ranking order
as of round $sr0) without exceeding $repeats.

This routine is a wrapper for RecursiveSwiss, which expects
the player list to be divided into win groups.

=cut

sub PairSomeSwiss ($$$) {
  my $psp = shift;
  my $repeats = shift;
  my $sr0 = shift;
  my (@win_groups) = MakeWinGroups($sr0, $psp);
  return unless @win_groups;
  return RecursiveSwiss \@win_groups, $repeats;
  }

=item $success = $d->PairSwiss($setup);

Add Swiss pairings to the last unpaired round in the division.
See TSH::PairingCommand::SetupForPairings for structure of $setup.

=cut

sub PairSwiss ($$) {
# warn "table stability hack active!\n";
  my $dp = shift;
  my $setupp = shift;
  my @pair_list = PairSomeSwiss $setupp->{'players'}, $setupp->{'repeats'}, 
    $setupp->{'source0'} or return 0;
  # store pairings
  my $r0 = $setupp->{'target0'};
  # TODO: should use PairMany for the following
  while (@pair_list) {
    my $p1 = shift @pair_list;
    my $p2 = shift @pair_list;
    $p1->{'pairings'}[$r0] = $p2->{'id'};
    $p2->{'pairings'}[$r0] = $p1->{'id'};
    }
  return 1;
  }

=item $pp = $d->Player($pn);

Look up a player by (1-based) number.

=cut

sub Player ($$) { 
  my $this = shift;
  my $pn = shift;
  Carp::confess "pn is undefined" unless defined $pn;
  return undef if $pn < 1; # mostly in case $pn is negative
  my $p = $this->{'data'}[$pn];
  # direct access to member fields could have caused corruption
  $p = undef unless TSH::Utility::IsASafely($p, 'TSH::Player');
  return $p;
  }

=item @pp = $d->Players();

Return a list of all the players in the division.
The first player in the list (whose index will be 0 if you
are using 0-based subscripting) will be player #1.

=cut

sub Players ($) { 
  my $this = shift;
  my $datap = $this->{'data'};
  return @$datap[1..$#$datap];
  }

=item $r = $d->RatingList();
=item $d->RatingList($r);

Get/set a division's rating list

=cut

sub RatingList ($;$) { TSH::Utility::GetOrSet('rating_list', @_); }

=item $r = $d->RatingSystem();
=item $d->RatingSystem($r);

Get/set a division's rating system

=cut

sub RatingSystem ($;$) { TSH::Utility::GetOrSet('rating_system', @_); }

sub RatingSystemName ($) {
  my $this = shift;
  my $r = $this->{'rating_system'};
  return $r ? $r->Name() : '';
  }

=item $d->Read();

Read in all of a division's data from its .t file.

=cut

sub Read ($) { 
  my $this = shift;
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  my $fn = $config->MakeRootPath($this->{'file'});
  $this->ReadFrom({'type'=>'file', 'filename'=>$fn});
  }

=item $d->ReadFrom(\%options);

$d->ReadFrom({'type' => 'file', 'filename' => $filename});

$d->ReadFrom({'type' => 'string', 'data' => $string});

$d->ReadFrom({'type' => 'file', 'filename' => $filename, 'format' => 'csv'});

$d->ReadFrom({'type' => 'file', 'filename' => $filename, 'format' => 'tfile'});

Read in a division's data from the given source.

Options:

C<csv_encoding> (optional for format csv): text encoding for source data, defaults to $config->TFileEncoding();

C<data> (required for type string): source data string

C<filename> (required for type file): source filename

C<format> (optional): permitted values: 'tfile' (default), 'csv'

C<game> (optional): type of game, affects pairing and scoring formats, defaults to 'scrabble', can be 'sudoku'

C<operation> (optional for format csv): 'load' (default) deletes all existing data first; 'merge' adds to existing data.

C<tfile_encoding> (optional for format tfile): text encoding for source data, defaults to $config->TFileEncoding();

C<type> (required): permitted values: 'file', 'string'

=cut

sub ReadFrom ($$) {
  my $this = shift;
  my $source = shift;

  my $format = $source->{'format'} || 'tfile';
  if ($format eq 'csv') {
    return $this->ReadFromCSV($source);
    }
  else {
    return $this->ReadFromTFile($source);
    }

  }

=item $success = $d->ReadFromCSV(\%options)

$d->ReadFromCSV({'type' => 'string', 'data' => $data});

$d->ReadFromCSV({'type' => 'file', 'filename' => $filename});

Read in a division's data from a CSV file or string.

Options:

C<csv_encoding> (optional): text encoding for source data, defaults to $config->TFileEncoding();

C<data> (required for type string): source data string

C<filename> (required for type file): source filename

C<operation> (optional): 'load' (default) deletes all existing data first; 'merge' adds to existing data.

C<type> (required): permitted values: 'file', 'string'

CSV Column Names:

C<boards>: Space-separated list of player boards

C<board1>, C<board2>, ...: individual boards that can override the full list.

C<name>: Player name

C<pairings>: Space-separated list of player opponent IDs (0 for bye)

C<pairing1>, C<pairing2>, ...: individual opponent IDs that can override the full list.

C<rating>: Player rating

C<scores>: Space-separated list of player scores

C<score1>, C<score2>, ...: individual scores that can override the full list.

C<team>: Player team

=cut

sub ReadFromCSV ($$) {
  my $this = shift;
  my $options = shift;
  &::Use('TSH::Utility::CSV');
  my $tourney = $this->Tournament();
  my $config = $tourney->Config();
  my $use_ratings = ($this->RatingSystemName() || '') ne 'none';
  my $maxr0 = $this->MaxRound0();
  my $operation = $options->{'operation'} || 'load';
  my $source = ($options->{'type'}||'file') eq 'string' ? $options->{'data'}
    : do {
      unless (defined $options->{'filename'}) 
        { $tourney->TellUser('ecsvnofn'); return 0; }
      my $encoding = $config->Value('csv_encoding') || 'isolatin1';
      my $fh = TSH::Utility::OpenFile("<:encoding($encoding)",
	$options->{'filename'}) or do {
	  $tourney->TellUser('ecsvopen', $options->{'filename'}, $!); return 0; };
      local($/) = undef;
      scalar(<$fh>);
      };

  my $rowsp = TSH::Utility::CSV::Decode($source);
  my (@headers) = map { lc $_ } @{$rowsp->[0]};
  my @player_boards;
  for my $rown (1..$#$rowsp) {
    my $rowp = $rowsp->[$rown];
    my (%p) = map { $headers[$_] => $rowp->[$_] } 0..$#$rowp;
    if (defined $p{'name'}) { }
    else { $tourney->TellUser('ecsvnof', 'player name', $rown); return 0; }
    if ($use_ratings) {
      if (defined $p{'rating'}) { }
      elsif ($operation eq 'load') 
	{ $tourney->TellUser('ecsvnof', 'rating', $rown); return 0; }
      }  
    else { $p{'rating'} = 0; }
    my $p;
    if ($operation eq 'load') {
      $p = $this->AddPlayer('name' => $p{'name'}, 'rating' => $p{'rating'});
      }
    else {
      $p = $tourney->FindPlayer($p{'name'}, undef, $this) || do {
	$tourney->TellUser('wcsvnop', $p{'name'});
	$p = $this->AddPlayer('name' => $p{'name'},
	  'rating' => ($p{'rating'}||0));
	};
      }
    if (defined $p{'pairings'}) {
      my (@pairings) = split(/\D/, $p{'pairings'});
      for my $r0 (0..$#pairings) {
	$p->OpponentID($r0, $pairings[$r0]);
	}
      }
    if (defined $p{'boards'}) { $player_boards[$rown] = $p{'boards'} }
    if (defined $p{'scores'}) {
      my (@scores) = split(/[^-+.\d]/, $p{'scores'});
      for my $r0 (0..$#scores) {
	$p->Score($r0, $scores[$r0]);
	}
      }
    if (defined $p{'team'}) { $p->Team($p{'team'}); }
    {
      my $found = 0;
      my (@initrec) = (0,0,0,0);
      if (defined $p{'initw'}) { $initrec[0] = $p{'initw'}; $found = 1; }
      if (defined $p{'initl'}) { $initrec[1] = $p{'initl'}; $found = 1; }
      if (defined $p{'inits'}) { $initrec[2] = $p{'inits'}; $found = 1; }
      if (defined $p{'initc'}) { $initrec[3] = $p{'initc'}; $found = 1; }
      if ($found) { $p->InitialRecord(\@initrec); }
    }
    for my $r0 (0..$maxr0) {
      my $r = $r0 + 1;
      $p->OpponentID($r0, $p{"pairing$r"}) if defined $p{"pairing$r"} && length $p{"pairing$r"};
      if (defined $p{"board$r"} && length $p{"board$r"}) { # must come after pairing
# 	warn qq($rown $r0 $p{"board$r"});
	$player_boards[$rown][$r0] = $p{"board$r"};
        }
      $p->Score($r0, $p{"score$r"}) if defined $p{"score$r"} && length $p{"score$r"};
      }
    }
  for my $pn (1..$#player_boards) { # must come after pairing and players defined
    my $pbs = $player_boards[$pn] || next;
    my $p = $this->{'data'}[$pn];
    my (@boards) = @$pbs;
    for my $r0 (0..$#boards) {
      my $b = $boards[$r0];
      next unless defined $b && length $b;
      $p->Board($r0, $b);
      }
    }
  return 1;
  }

=item $d->ReadFromTFile(\%options)

$d->ReadFromTFile({'type' => 'string', 'data' => $data});

$d->ReadFromTFile({'type' => 'file', 'filename' => $filename});

Read in a division's data from a TFile file or string.

Options:

C<csv_encoding> (optional): text encoding for source data, defaults to $config->TFileEncoding();

C<data> (required for type string): source data string

C<filename> (required for type file): source filename

C<game> (optional): type of game, affects pairing and scoring formats, defaults to 'scrabble', can be 'sudoku'

C<tfile_encoding> (optional): text encoding for source data, defaults to $config->TFileEncoding();

C<type> (required): permitted values: 'file', 'string'

Key map:

=cut

sub ReadFromTFile ($$) {
  my $this = shift;
  my $options = shift;
  
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  $tourney->TellUser('iloaddiv', $this->{'name'});
# my $no_random = $config->Value('no_random');

  my (%tfile_options) = %$options;
  $tfile_options{'tfile_encoding'} ||= $config->TFileEncoding();
  $tfile_options{'game'} ||= $config->Value('tfile_game') || 'scrabble';
  $tfile_options{'no_random'} ||= $config->Value('no_random');
  my $tfile = new TFile \%tfile_options;
  unless ($tfile) {
    my $message = "Can't read data for division $this->{'name'} from "
      . ($options->{'type'} eq 'file' ? "file '$options->{'filename'}'" : 
      $options->{'type'}) . ": $!\n";
    if ($config->Value('cross_tables_id')) {
      warn $message;
      $this->Synch();
      return;
      }
    else {
      die $message;
      }
    }
  my (@data) = ();
  &share(\@data);
  push(@data, undef);
# my $hasphotos = $config->Value('player_photos');
# TODO: see if a cached binary file format would speed large file loads
# TODO: consider delaying parsing of some subfields until it's needed, or we're idle
  my $player_count = 0;
  while (my $pp = $tfile->ReadLine('shared')) {
    $this->AddPlayer(%$pp);
#   $pp->{'name'} =~ s/,\s*/, /;
#   $pp->{'division'} = $this;
#   $pp->{'rnd'} = 0 if $no_random;
#   push(@data, $pp);
#   # TODO: move the following to new() if it doesn't slow things down too much
    bless $pp, 'TSH::Player'; 
#   # this must take place after the blessing
#   if ($hasphotos) {
#     $config->InstallPhoto($pp);
#     }
#   $tourney->RegisterPlayer($pp);
    $player_count++ if $pp->Active();
#   print "Added #$pp->{'id'} $pp->{'name'} opps: @{$pp->{'pairings'}}\n";
    }
  $tfile->Close();

  $tourney->TellUser('iodddiv', $player_count, $this->{'name'})
    if $player_count % 2 == 1;
# $this->{'data'} = \@data;
  $this->Synch();
  }

=item $d->ReadFromString($s);

Read in all of a division's data from a TFile-formatted string.

=cut

sub ReadFromString ($$) { 
  my $this = shift;
  my $s = shift;
  $this->ReadFrom({'type'=>'string', 'data'=>$s});
  }

=item RecursiveSwiss($wgsp, $repeats)

Recursively compute Swiss pairings as follows.

If we have one group, try all pairings until we find one that works
or have exhausted all possibilities.  preference order for opponents
is based on distance from ideal Swiss opponent (1 plays ceil(n/2)).

If we have more than one group, try pairing the top and the bottom
groups as follows.  Make the group even by promoting (demoting)
a player if necessary.  If the group can't be paired without
exceeding the repeat threshold, promote (demote) two more players
until we succeed or run out of players and fail.

=cut

sub RecursiveSwiss ($$) {
  # [[p1,p2],[p3],[p4,p5,p6],...] divided into pairings groups
  # number of players must be even (assign bye before calling)
  my $win_groupsp = shift; # passed as reference, but shouldn't be modified
  # 0 indicates no repeats allowed, ..., 3 means up to 3 repeats = 4 pairings
  my $repeats = shift;
  my $config = $win_groupsp->[0][0]->Division()->Tournament()->Config(); # kludge

  Debug 'RSw', 'Main(%d): %s', scalar(@$win_groupsp), join(',',map { '[' . join(',', map { $_->ID() } @$_) . ']' } @$win_groupsp);
  confess "no groups\n" unless @$win_groupsp;

  # if we're down to one group, try all possibilities
  if (@$win_groupsp == 1) {
    return RecursiveSwissOne $win_groupsp->[0], $repeats;
    }
  # else we have more than one group
  else {
    my ($top_paired, $rest) = RecursiveSwissTop $win_groupsp, $repeats;
    # could not pair top group
    if (@$top_paired == 0) { return (); }
    # used up all players trying to pair top group
    elsif (@$rest == 0) { return @$top_paired; }
    # pairing top group left only one other group
    elsif (@$rest == 1) { 
      my (@rest) = RecursiveSwissOne $rest->[0], $repeats;
      # if that group can be paired, we're done.
      if (@rest) { return (@$top_paired, @rest); }
      # if the other group can't be paired, try pairing everyone together
      else { 
	return RecursiveSwissOne [ map { @$_ } @$win_groupsp], $repeats; 
        }
      }
    # pairing top group left more than one group
    else {
      # We gain a substantial performance improvement if we relax the
      # usual Swiss rules to allow us to pair a group at the bottom each
      # time we pair a group at the top, because repeat pairings tend to
      # accumulate at both ends, not just the top.  If top_down_swiss
      # is specified, we do not perform this optimization.
      if ($config->Value('top_down_swiss')) {
	if (my (@rest) = RecursiveSwiss $rest, $repeats) {
	  # if the rest can be paired, we're done
	  return (@$top_paired, @rest);
	  }
	else {
	  # if not, try pairing everyone together
	  return RecursiveSwissOne [ map { @$_ } @$win_groupsp], $repeats; 
	  }
	}
      # try pairing the bottom group
      my ($bottom_paired, $middle) = RecursiveSwissBottom $rest, $repeats;
      # if we failed, try pairing everything together
      if (@$bottom_paired == 0) { 
#	warn "Had to pair all groups together.\n";
	return RecursiveSwissOne [ map { @$_ } @$win_groupsp], $repeats; 
        }
      # if we used up the players in the middle and succeeded, return
      elsif (@$middle == 0) { return (@$top_paired, @$bottom_paired); }
      # if we left one group in the middle, try pairing it
      elsif (@$middle == 1) { 
	my (@middle) = RecursiveSwissOne $middle->[0], $repeats;
	# if that group can be paired, we're done.
	if (@middle) { return (@$top_paired, @middle, @$bottom_paired); }
	# else fall through to X
        }
      # if we left more than one group in the middle, recurse fully
      else {
	my (@middle) = RecursiveSwiss $middle, $repeats;
	if (@middle) { return (@$top_paired, @middle, @$bottom_paired); }
	# else fall through to X
        }
      # X: we couldn't pair the middle, so first try combining with bottom
      my (@midbot) = 
        RecursiveSwissOne [ map { @$_ } @$rest ], $repeats;
      # if middle and bottom paired together, return what we have
      if (@midbot) { return (@$top_paired, @midbot); }
      # else try pairing everyone together, or give up
      else { 
#	warn "Had to pair all groups together.\n";
	return RecursiveSwissOne [ map { @$_ } @$win_groupsp], $repeats; 
	}
      }
    }
  }

=item ($bottom_paired, $rest) = RecursiveSwissBottom($wgsp, $repeats)

Called by RecursiveSwiss when it wants to pair the bottom players in $wgsp.

=cut

sub RecursiveSwissBottom($$) {
  my $win_groupsp = shift;
  my $repeats = shift;

  Debug 'RSw', 'Bottom(%d): %s', scalar(@$win_groupsp), join(',',map { '[' . join(',', map { $_->ID() } @$_) . ']' } @$win_groupsp);

  # car/cdr nomenclature is upside down here, as we copied this code
  # from RecursiveSwissTop.

  # make sure we have an even number of players
  my $carp = $win_groupsp->[-1];
  my (@cdr) = @$win_groupsp[0..$#$win_groupsp-1];

  my (@car) = (@$carp); # copy so as not to change master copy
  my @cadr;
  unless ($#$carp % 2) {
    # [1] get (copy, so we don't mess things up) the next group
    (@cadr) = (@{pop @cdr});
    # move its top player to top group
      # change this and the other two push(@car)s below to unshift()s
      # and watch the runtime increase by two orders of magnitude
    push(@car, pop @cadr);
    # if that didn't empty the next group, put it back
    if (@cadr) { push(@cdr, \@cadr); }
    }
  # pair within the group, then keep demoting pairs
  while (1) {
    my (@car_paired) = RecursiveSwiss [\@car], $repeats;
    if (@car_paired) {
      return \@car_paired, \@cdr;
      }
    # did we run out of players?
    last unless @cdr;
    # demote one, see [1] for comments
    (@cadr) = (@{pop @cdr}); 
    push(@car, pop @cadr);
    if (@cadr) { push(@cdr, \@cadr); }
    die "Ark error - did you forget to assign a bye?\n" unless @cdr;
    # demote the other, see [1] for comments
    (@cadr) = (@{pop @cdr}); 
    push(@car, pop @cadr);
    if (@cadr) { push(@cdr, \@cadr); }
  }
  # ran out of players - d'oh!
  Debug 'RSw', 'failed: no more players to demote';
  return ([], []);
  }

=item (@pairings) = RecursiveSwissOne($wgsp, $repeats)

Called by RecursiveSwiss when it knows that it has only one group to pair.

=cut

sub RecursiveSwissOne($$) {
  my $win_groupp = shift;
  my $repeats = shift;
  # this is a bit kludgey, getting the configuration this way
  my $config = $win_groupp->[0]->Division()->Tournament()->Config();
  Debug 'RSw', 'One(1:%d)', scalar(@$win_groupp);
  my $consecutive_repeats = $config->Value('consecutive_repeats');

  my $group_size = scalar(@$win_groupp);
  # odd number of players - oops
  if ($group_size % 2) {
    die "Odd number of players in last win group:" 
      . join(',', map { $_->{'id'}} @$win_groupp)
      . "\nAborting";
    }
  # no more players - shouldn't happen
  elsif ($group_size == 0) {
    die "Ran out of players?!\n";
    }

  my (@ps) = @$win_groupp;
  my $r0 = $ps[0]->CountOpponents();
  # how many consecutive repeats are permitted in this round?
  my $c_swiss_max_consecutive_repeats =
    $config->Value('swiss_max_consecutive_repeats') || [];
  # if it's a scalar, it's converted to a singleton array
  $c_swiss_max_consecutive_repeats = [$c_swiss_max_consecutive_repeats]
    if ref($c_swiss_max_consecutive_repeats) ne 'ARRAY';
  # convert array to specific scalar value in effect this round
  $c_swiss_max_consecutive_repeats =
    # if it's empty, there's no limit
    @$c_swiss_max_consecutive_repeats == 0 ? undef :
    # array is extended by repeating last element if necessary
    $r0 > $#$c_swiss_max_consecutive_repeats 
      ? $c_swiss_max_consecutive_repeats->[-1] :
    $c_swiss_max_consecutive_repeats->[$r0];

  # one pair left - almost as easy
  if ($group_size == 2) {
    my ($p1, $p2) = @ps;
    my $exagony = $config->Exagony($p1->CountOpponents());
    if ($p1->Repeats($p2->ID()) > $repeats) {
      Debug 'RSw', 'cannot pair %s and %s due to repeats', $p1->TaggedName(), $p2->TaggedName();
      return ();
      }
    if ($config->Value('exagony') and $p1->Team() eq $p2->Team() and $p1->Team() ne '') {
      Debug 'RSw', 'cannot pair %s and %s due to exagony', $p1->TaggedName(), $p2->TaggedName();
      return ();
      }
    if ($consecutive_repeats and $p1->CountConsecutiveRepeats($p2) > $consecutive_repeats) {
      Debug 'RSw', 'cannot pair %s and %s due to consecutive repeats', $p1->TaggedName(), $p2->TaggedName();
      return ();
      }
    if ($c_swiss_max_consecutive_repeats and
	$p1->CountConsecutiveRepeats($p2) > $c_swiss_max_consecutive_repeats
      ) {
      Debug 'RSw', 'cannot pair %s and %s due to Swiss max consecutive repeats', $p1->TaggedName(), $p2->TaggedName();
      return ();
      }
    Debug 'RSw', 'success: %s', join(',', map { $_->ID() } ($p1, $p2));
    return ($p1, $p2);
    }
  # more than one pair - try each possible opp for first player, recurse
  else {
    # TODO: should look at caching these config variables
    my $exagony = $config->Exagony($ps[0]->CountOpponents());

    # do we care who went first or second?
    my $c_swiss_ignores_firsts = $config->Value('swiss_ignores_firsts');

    # do we care about repeat pairings?
    my $c_swiss_ignores_repeats = $config->Value('swiss_ignores_repeats');

    # do people have to play opponents within their own class?
    my $c_class_endagony = $config->Value('class_endagony');

    # what is the best flight ordering this round (forced/koth/normal)?
    my $c_swiss_order = ($config->Value('swiss_order') || []);
    # if it's a scalar, it's converted to a singleton array
    $c_swiss_order = [$c_swiss_order]
      if ref($c_swiss_order) ne 'ARRAY';
    # convert array to specific scalar value in effect this round
    $c_swiss_order =
      # array must not be empty
      $#$c_swiss_order < 0 ? 'undef' :
      # array is extended by repeating last element if necessary
      $r0 > $#$c_swiss_order ? $c_swiss_order->[-1] :
      $c_swiss_order->[$r0]; # JJC 20170812 - was [$r0]

    # forced flight ordering (used sometimes in Thailand) means that 
    # the top half plays the bottom half in order, regardless of other
    # considerations - easy!
    if ($c_swiss_order eq 'forced') {
      my $half_size = $group_size/2;
      return map { ($ps[$_], $ps[$_+$half_size]) } (0..$half_size-1);
      }

    # the only two choices left are KOTH or normal (see below)
    my $c_swiss_koth = $c_swiss_order eq 'koth';
#   warn "$r0: $c_swiss_koth";

    # true if TSH is keeping track of firsts *and* director wants to
    # account for them in Swiss pairings
    my $c_track_firsts = $config->Value('track_firsts')
      && !$c_swiss_ignores_firsts;

    # pair players by efficiently (using GRT) preparing a preference list
    # of opponents for each player, then working down from the top and
    # up form the bottom to try to find best opponents for players
    #
    # TODO: rework this so that instead of dichotomizing the choice of
    # whether or not a player may be paired with an opponent, calculate
    # badness of individual pairings, then try to minimize overall 
    # badness the way TeX does with paragraph composition.  This could
    # result in better assignment of badness in situations where some
    # players need to have repeat pairings but not others.
    if (TSH::Player::PairGRT(\@ps,
      # Guttman-Rosler Transform synthetic key encoder
      sub {
	my $p = $_[0][$_[1]];
	my $pid = $p->ID();
	my $o = $_[0][$_[2]];
	my $oid = $o->ID();
	my $lastoid = ($p->OpponentID(-1) || -1);
	my $repeats = $c_swiss_ignores_repeats ? 0 : $p->Repeats($oid); 
	my $sameopp = $c_swiss_ignores_repeats ? 0 : ($oid == $lastoid);
	# preferred opponent is closest in rank (if swiss_koth) or
	# closest to half a flight away (if not)
	my $distance = $c_swiss_koth ? abs($_[1]-$_[2]) : abs(@{$_[0]}-abs(2*($_[1]-$_[2])));
	my $same_class = ($c_class_endagony && ($p->Losses()||$p->GamesPlayed() == 0)) ? $p->Class() ne $o->Class() ? 1 : 0 : 0;
	my $pairsvr = $c_track_firsts ? 2-abs(($p->{'p1'}-$p->{'p2'} <=> 0)  -($o->{'p1'}-$o->{'p2'} <=> 0)) : 0;
# We tried the following at the Toronto Open to see if we could minimize people having to switch rooms, but it didn't help.
# my $dp = $p->Division(); my $sametable = ( $config::tables{$dp->{'name'}}[$p->{'etc'}{'board'}[-1]] != $config::tables{$dp->{'name'}}[$p->{'etc'}{'board'}[-1]]);# die "$config::tables{$dp->{'name'}}[$p->{'etc'}{'board'}[-1]]: $p->{'etc'}{'board'}[-1]\n";

 	Debug 'GRT', 'pref RS1 %d-%d rep=%d prev=%d sc=%d svr=%d rnk=%d(%d,%d,%d)', $pid, $oid, $repeats, $sameopp, $same_class, $pairsvr, $distance, scalar(@{$_[0]}), $_[1], $_[2];
 	pack('NCCCNN', 
#	pack('NCCNCN', 
	  $repeats, # minimize repeats
	  $sameopp, # avoid previous opponent
	  $same_class, # stay in same class
	  $pairsvr, # pair those due to start vs those due to reply
# $sametable, # pair players at same table
	  $distance, # optimize rank
	  $_ # index for GRT to extract
	  );
        },
      # filter permissible opponents for player
      sub {
	# if we care about limiting consecutive repeats
	if (defined $c_swiss_max_consecutive_repeats) {
	  # then perform a slightly expensive calculation
	  my $psp = $_[0];
	  my $p =   $psp->[$_[1]];
	  my $oid = $psp->[$_[2]]->ID();
	  my $b2b = $psp->[$_[1]]->CountBackToBack($r0, $oid);
	  Debug 'SMCR', '%d vs %d: %d ?<= %d', $p->ID(), $oid, $b2b, $c_swiss_max_consecutive_repeats;
	  return $b2b <= $c_swiss_max_consecutive_repeats;
	  # return 0 if $b2b > $c_swiss_max_consecutive_repeats;
	  # and cache the result?
	  # $p->{'xb2b'}[$oid] = $b2b;
	  # return 1;
	  }
      ($exagony ? $_[0][$_[1]]->Team() ne $_[0][$_[2]]->Team() || $_[0][$_[1]]->Team() eq '' : 1)
      and $_[0][$_[1]]->Repeats($_[0][$_[2]]->ID()) <= $repeats
      and ($consecutive_repeats ? $_[0][$_[1]]->ConsecutiveRepeats($_[0][$_[2]]) <= $consecutive_repeats : 1)
        },
      [], # GRT options
      undef, # just checking, no target round
      )) {
      my (@pairings);
      my $debug = '';
      for my $p (@ps) {
	if ($p->ID() < $p->{'opp'}) # should fix use of 'opp'
	  { 
	    push(@pairings, $p, $p->Division->Player($p->{'opp'})); 
	  $debug .= $p->ID() . '-' . $p->{'opp'} . ' ';
	  }
        }
      Debug 'RSw', $debug;
      return @pairings;
      }
    else {
      Debug 'RSw', 'cannot pair group led by %s', $ps[0]->TaggedName();
      return ();
      }
    }
  }

=item ($top_paired, $rest) = RecursiveSwissTop($wgsp, $repeats)

Called by RecursiveSwiss when it wants to pair the top players in $wgsp.

=cut

sub RecursiveSwissTop($$) {
  my $win_groupsp = shift;
  my $repeats = shift;

  Debug 'RSw', 'Top(%d)', scalar(@$win_groupsp);
  # make sure we have an even number of players
  my ($carp, @cdr) = @$win_groupsp;
  my (@car) = (@$carp); # copy so as not to change master copy
  my @cadr;
  unless ($#$carp % 2) {
    # [1] get (copy, so we don't mess things up) the next group
    (@cadr) = (@{shift @cdr});
    # move its top player to top group
    push(@car, shift @cadr);
    # if that didn't empty the next group, put it back
    if (@cadr) { unshift(@cdr, \@cadr); }
    }
  # pair within the group, then keep promoting pairs
  while (1) {
    my (@car_paired) = RecursiveSwiss [\@car], $repeats;
    if (@car_paired) {
      return \@car_paired, \@cdr;
      }
    # did we run out of players?
    last unless @cdr;
    # promote one, see [1] for comments
    (@cadr) = (@{shift @cdr}); 
    push(@car, shift @cadr);
    if (@cadr) { unshift(@cdr, \@cadr); }
    die "Ark error - did you forget to assign a bye?\n" unless @cdr;
    # promote the other, see [1] for comments
    (@cadr) = (@{shift @cdr}); 
    push(@car, shift @cadr);
    if (@cadr) { unshift(@cdr, \@cadr); }
  }
  # ran out of players - d'oh!
  Debug 'RSw', 'failed: no more players to promote';
  return ([], []);
  }

sub Render ($;$) {
  my $this = shift;
  my $optionsp = shift || {};
  my $data = '';
  my $config = $this->Tournament()->Config();
  my $pname_canonicaliserp = $optionsp->{'pname_canonicaliser'};
  my $suppress_bye_p12 = $optionsp->{'suppress_bye_p12'} and $config->Value('track_firsts');

  for my $p (@{$this->{'data'}}) {
    next unless $p and $p->{'id'};
    my %p2 = %$p;
    if ($pname_canonicaliserp) {
      $p2{'name'} = &$pname_canonicaliserp($p->{'name'});
#     warn "$p->{'name'} -> $p2{'name'}";
      }
    if ($suppress_bye_p12) {
      for my $r0 (0..$p->CountOpponents()-1) {
	next if $p->Opponent($r0);
	$p2{'etc'}{'p12'}[$r0] = 0;
	}
      }
    $data .= TFile::FormatLine \%p2;
    }

  return $data;
  }

=item $d->RenumberPlayer($pnold,$pnnew);

Move player from number $pnold to $pnnew in division.

Can throw an error list reference of the form [$code, @args] suitable
to pass to UserMessage for i18n.

=cut

sub RenumberPlayer($$$) {
  my $this = shift;
  my $pnold = shift;
  my $pnnew = shift;
  return if $pnold == $pnnew;
  my $datap = $this->{'data'};
  my $tourney = $this->Tournament();

  die ['erenumpap', $this->{'name'}] if $this->{'maxp'} >= 0;
  die ['erenumpnop', $this->{'name'}, $pnold] if $pnold <= 0 || $pnold > $#$datap;
  die ['erenumpbnp', $this->{'name'}, $pnnew] if $pnnew <= 0 || $pnnew > $#$datap;

  my $pp = splice(@$datap, $pnold, 1);
  splice(@$datap, $pnnew, 0, $pp);
  my ($pnlo, $pnhi) = sort ($pnold, $pnnew);
  for my $pid ($pnlo..$pnhi) {
    $datap->[$pid]->ID($pid);
    }
  $this->Dirty(1);
  return '';
  }

=item @bs = $d->ReservedBoards();

Returns a list of reserved board numbers, for use by pairing systems
(such as InitFontes) that handle their own board assignment.

=cut

sub ReservedBoards ($) {
  my $this = shift;
  my $config = $this->Tournament()->Config();
  my $reserved = $config->Value('reserved');
  $reserved = $reserved->{$this->{'name'}} if $reserved;
  return $reserved ? grep { $_ } @$reserved : ();
  }

=item $pn = $d->RoundSeatPlayer($r0, $seat1);

Return the player number sitting in C<$seat1> in round0 C<$r0>.

=cut

sub RoundSeatPlayer ($$$) {
  my $dp = shift;
  my $r0 = shift;
  my $seat = shift;
# warn "$r0";
  return undef unless $dp->{'round_seat_player'} && $dp->{'round_seat_player'}[$r0];
# warn "$r0 $seat $dp->{'round_seat_player'}[$r0][$seat]";
  return $dp->{'round_seat_player'}[$r0][$seat];
  }

=item $pn = $d->RoundSeatPlayers($r0);

Return a list mapping seat1s to player numbers.

=cut

sub RoundSeatPlayers ($$) {
  my $dp = shift;
  my $r0 = shift;
  return undef unless $dp->{'round_seat_player'} && $dp->{'round_seat_player'}[$r0];
  return $dp->{'round_seat_player'}[$r0];
  }

=item $n = $d->Synch();

Update internal statistics.

=cut

sub Synch ($) { 
  my $this = shift;
  my $datap = $this->{'data'};
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();

  my $pairing_system = $config->Value('pairing_system');

  if (defined $this->DirtyRound()) {
#   Carp::cluck "dirtyround=".$this->DirtyRound()."\n".join(',',@{$datap->[1]{'etc'}{'rrank'}});
    $this->TruncateStats($this->DirtyRound()-1);
#   Carp::cluck "truncated to ".join(',',@{$datap->[1]{'etc'}{'rrank'}});
#   warn "@{$datap->[1]{'etc'}{'rrank'}}";
    $this->{'dirtyround'} = undef;
  }
  else {
#   warn "no dirtyround";
    }
  my $TOO_MANY = 999999;
  my $minpairings = $TOO_MANY;
  my $maxpairings = -1;
  my $minscores = $TOO_MANY;
  my $maxscores = -1;
  my $maxps = -1;
  my $maxps_player = undef;
  my $div_max_round0_played = -1;
  my $mins_player = undef;
  my $maxs_player = undef;
  my $caps = $config->Value('standings_spread_cap');
  my $full_caps = $config->Value('spread_cap');
  my $c_need_sum = $config->Value('sum_before_spread');
  my $c_oppless_spread = $config->Value('oppless_spread');
  my $c_zero_byes_tie = $config->Value('zero_byes_tie');
  my $c_all_byes_tie = $config->Value('all_byes_tie');
  my $c_auto_notes = ($config->Value('notes')||'') =~ /auto/i;
  my $c_seats = $config->Value('seats');
  my $c_split1 = $config->Value('split1');
  my @high_round_win : shared;
  my @round_seat_player : shared; # indexed first by round0, then by seat number
  # currently only calculated if seats
  my @round_byes : shared; # round0-indexed list of references to list of ids of bye players

  # loop over players in division
  for my $i (1..$#$datap) {
    my $p = $datap->[$i];
    my $pairingsp = $p->{'pairings'};
    my $penaltiesp = $p->GetOrSetEtcVector('penalty');
    while (@$pairingsp && !defined $pairingsp->[-1]) { pop @$pairingsp; }
    my $npairings = $#$pairingsp;
    my $contigpairings = -1;
    while (defined $pairingsp->[++$contigpairings]) { }
    $contigpairings--;
    my $scoresp = $p->{'scores'};
    while (@$scoresp && !defined $scoresp->[-1]) { $p->DeleteLastScore(); }
#   my $seatsp = $p->GetOrSetEtcVector('seat');
    my $last_score_r0 = $#$scoresp;
    my $max_round0_played = -1;
    my $spread = 0;
    my @spread : shared;
    my $cspread = 0;
    my @cspread : shared;
    my $sum = 0;
    my @sum : shared;
    my $ratedgames = 0; 
    my $ratedwins = 0; 
    my $nscores = 0;
    my $wins = 0;
    my $losses = 0;
    my @losses : shared;
    my @wins : shared;
    if (my $initial_record = $p->InitialRecord()) {
      ($wins, $losses, $spread, $cspread, $sum) = @$initial_record;
      $cspread ||= 0;
      $sum ||= 0;
      }
    my $left_after_r0 = -1;
    $p->{'ewins1'} = $p->{'ewins2'} = 0;

# print "$p->{id} has $last_score_r0+1 scores.\n" if $last_score_r0 > $maxscores;
# print "$p->{id} has $npairings+1 opponents.\n" if $npairings > $maxpairings;
    my $active = !$p->{'etc'}{'off'};
    $minpairings = $contigpairings if $contigpairings < $minpairings && $active;
    $maxpairings = $npairings if $npairings > $maxpairings && $active;
    if ($last_score_r0 < $minscores && $active) 
      { $minscores = $last_score_r0; $mins_player = $p; }
    if ($last_score_r0 > $maxscores && $active) 
      { $maxscores = $last_score_r0; $maxs_player = $p; }

    my $last_ps = -1;
    # iterate over player's scores
    for my $j (0..$last_score_r0) { # number of scores
      my $oppid = $pairingsp->[$j];
      if ($oppid && $active) { $last_ps = $j; }
      # if allow_gaps in effect, or .t file hand-edited, myscore might be undef
      my $myscore = $p->{'scores'}[$j];
      $nscores++ if defined $myscore;

      # if TSH is being used for a game without pairings, such as Sudoku
      if ($pairing_system eq 'none') { 
	die "capped unpaired spread not yet implemented" if $caps;
	if (defined $myscore) {
	  $max_round0_played = $j; 
	  $spread += $myscore;
	  $sum += $myscore; 
	  push(@spread, $spread); # added 2010-06-07
	  push(@wins, $wins); # added 2010-06-07
	  push(@losses, $losses); # added 2010-06-07
	  push(@sum, $sum) if $c_need_sum;
	  }
	next;
        }

      # if the player is missing pairings for this round
      unless (defined $oppid) { 
	if (defined $myscore) {
	  # we have a score but opp isn't even defined: bad
	  my $name = $p->TaggedName();
	  my $r1 = $j + 1;
	  $tourney->TellUser('esnop', $name, $r1);
	  }
	# make sure that cumulative statistics still make sense
	push(@spread, $spread); # added 2010-06-07
	push(@cspread, $cspread) if $caps; # added 2010-06-07
	push(@wins, $wins); # added 2010-06-07
	push(@losses, $losses); # added 2010-06-07
	push(@sum, $sum) if $c_need_sum;
	next;
        }

      # if the player is missing a score for this round
      unless (defined $myscore) {
	# make sure that cumulative statistics still make sense
	push(@spread, $spread); # added 2010-06-07
	push(@cspread, $cspread) if $caps; # added 2010-06-07
	push(@wins, $wins); # added 2010-06-07
	push(@losses, $losses); # added 2010-06-07
	push(@sum, $sum) if $c_need_sum;
	next;
        }

      # to recap: if we reach here, the game has pairings, and the player
      # has been paired and has a score this round
      
      my $oppscore;
      # don't worry about the following line if you're not Thai
      if ($active && (defined $oppid) && $c_seats) { $left_after_r0 = $j; }
      
      # if the player has an opponent instead of a bye
      if ($oppid and $datap->[$oppid]) {
	$oppscore = $datap->[$oppid]{'scores'}[$j];
	if (defined $oppscore) {
	  $ratedgames++;
	  $max_round0_played = $j; 
	  Debug 'GVC', "Setting \$max_round0_played = $j;  oppid = $oppid;  myscore = $myscore;  oppscore = $oppscore";
#	  $left_after_r0 = $j if $c_seats; # 2012-09-07
	  }
	else {
	  $tourney->TellUser('enoos', $p->TaggedName(), $j+1, $oppid);
	  $oppscore = 0;
	  }
	}
      # if the player has a bye
      else {
	$oppscore = 0;
#	if ((defined $oppid) && ($myscore||0) > 0) {
#	  $left_after_r0 = $j if $c_seats; # 2012-09-07
#	  }
	}

      my $thisSpread = $myscore;
      $thisSpread -= $oppscore unless $c_oppless_spread;
      # if full spread caps are in effect, no uncapped spread is recorded
      if ($full_caps) {
	my $this_full_caps = ref($full_caps) 
	  ? $j <= $#$full_caps ? $full_caps->[$j] : $full_caps->[-1]
	  : $full_caps;
#	warn "$thisSpread $this_full_caps" if $i == 5;
	if ($thisSpread > $this_full_caps) {
	  $thisSpread = $this_full_caps;
	  }
	elsif ($thisSpread < -$this_full_caps) {
	  $thisSpread = -$this_full_caps;
	  }
	$cspread += $thisSpread;
	push(@cspread, $cspread);
	}
      $thisSpread += ($penaltiesp->[$j]||0) if $penaltiesp;
      $spread += $thisSpread;
      push(@spread, $spread);
      if ($c_need_sum) {
        $sum += $myscore;
        push(@sum, $sum);
        }
      # if partial spread caps are in effect, rspread contains uncapped spread, rcspread capped spread
      # (this could be rewritten more clearly)
      if ($caps && !$full_caps) {
	my $cappedSpread = $thisSpread;
	my $this_caps = ref($caps) 
	  ? $j <= $#$caps ? $caps->[$j] : $caps->[-1]
	  : $caps;
	if ($cappedSpread > $this_caps) {
	  $cappedSpread = $this_caps;
	  }
	elsif ($cappedSpread < -$this_caps) {
	  $cappedSpread = -$this_caps;
	  }
	$cspread += $cappedSpread;
	push(@cspread, $cspread);
	}
      my $result = (1 + ($myscore <=> $oppscore))/2;
      if ($oppid || $thisSpread || $c_zero_byes_tie) {
	$wins += $result;
	$losses += 1 - $result; 
	}
      if ((!$oppid) && $c_all_byes_tie && $thisSpread > 0) {
	$wins -= 1/2;
	$losses += 1/2;
	}
      if ($oppid) {
	$ratedwins += $result;
	$p->{$j < $c_split1 ? 'ewins1' : 'ewins2'} += $result; # TODO: what is this used for?
	}
      push(@losses, $losses);
      push(@wins, $wins);
      if ($c_auto_notes) {
	if ($result == 1) {
	  if ((!defined $high_round_win[$j]) || $myscore > $high_round_win[$j][0]) {
	    my @data : shared;
	    $data[1] = $i;
	    $data[0] = $myscore;
	    $high_round_win[$j] = \@data;
	    }
	  elsif ($myscore == $high_round_win[$j][0]) {
	    push(@{$high_round_win[$j]}, $i);
	    }
	  }
        }
      } # for $j (loop over rounds)
    if ($last_ps > $maxps) { 
      $maxps = $last_ps;
      $maxps_player = $p;
      }
#    if ($seatsp) {
#      for my $r0 (0..$#$seatsp) {
#	my $seat = $seatsp->[$r0];
#	unless ($round_seat_player[$r0]) {
#	  $round_seat_player[$r0] = &share([]);
#	  }
#	if (my $p2id = $round_seat_player[$r0][$seat]) {
#	  $tourney->TellUser('etwoseat', $seat, $r0+1, $datap->[$p2id]->Name(),
#	    $p->Name());
#	  }
#	else {
#	  $round_seat_player[$r0][$seat] = $i;
#	  }
#        }
#      }
    if ($c_seats) {
      for my $r0 (0..$#$pairingsp) { # not $npairings, because we want to include trailing byes
	if (my $seat = $p->Seat($r0)) {
	  unless ($round_seat_player[$r0]) {
	    $round_seat_player[$r0] = &share([]);
	    }
	  if (my $p2id = $round_seat_player[$r0][$seat]) {
	    $tourney->TellUser('etwoseat', $seat, $r0+1, $datap->[$p2id]->TaggedName(),
	      $p->TaggedName());
	    }
	  else {
#	    warn "setting: r0=$r0 seat=$seat pid=$i" if $i <= 12;
	    $round_seat_player[$r0][$seat] = $i;
	    }
	  }
	elsif ($p->Active()) {
	  my $oid = $p->OpponentID($r0);
	  if (defined $oid) {
	    unless ($round_byes[$r0]) {
	      $round_byes[$r0] = &share([]);
	      }
	    push(@{$round_byes[$r0]}, $i);
	    }
	  }
        }
      }
    $p->{'losses'} = $losses;
    $p->{'max_round0_played'} = $max_round0_played;
    if ( $p->{'max_round0_played'} > $div_max_round0_played )
    {
      $div_max_round0_played = $p->{'max_round0_played'};
    }
    $p->{'nscores'} = $nscores;
    $p->{'noscores'} = $this->{'maxr'}+1 - $nscores if defined $this->{'maxr'};
    $p->{'ratedgames'} = $ratedgames;
    $p->{'ratedwins'} = $ratedwins;
    $p->{'rlosses'} = \@losses;
#   warn "@cspread" if $i == 5;
    $p->{'rcspread'} = \@cspread;
    $p->{'rspread'} = \@spread;
    $p->{'rwins'} = \@wins;
    $p->{'cspread'} = $cspread;
    $p->{'spread'} = $spread;
    $p->{'left_after'} = $left_after_r0 if $c_seats;
#   warn "$left_after_r0 $p->{'id'} $p->{'name'}";
    if ($c_need_sum) {
      $p->{'sum'} = $sum;
      $p->{'rsum'} = \@sum;
      }
    $p->{'wins'} = $wins;

    { 
      my @repeats : shared;
      push(@repeats, (0) x @$datap);
      for my $j (@$pairingsp) { $repeats[$j]++ if $j; }
      $p->{'repeats'} = \@repeats;
    }

    }

  if ($c_seats) {
    for my $r0 (0..$maxscores) {
      if ($round_byes[$r0] && @{$round_byes[$r0]}) {
	unless ($round_seat_player[$r0]) {
	  $round_seat_player[$r0] = &share([]);
	  }
	my @players_at_boards;
	for my $pi (@{$round_byes[$r0]}) {
	  if (my $board = $datap->[$pi]->Board($r0)) {
	    my $pabp = $players_at_boards[$board] ||= [];
	    push(@$pabp, $pi);
	    my $nplayers_at_board = scalar(@$pabp);
	    my $seat = $nplayers_at_board == 1 ? 2 * $board - 1 : 2 * $board;
	    if ($nplayers_at_board > 2) {
	      $tourney->TellUser('etwoseat', $seat, $r0+1,
		$datap->[$pabp->[-2]]->TaggedName(),
		$datap->[$pabp->[-1]]->TaggedName(),
		);
	      }
	    else {
	      $round_seat_player[$r0][$seat] = $pi;
	      }
	    }
	  else {
#	    push(@{$round_seat_player[$r0]}, @{$round_byes[$r0]});
 	    push(@{$round_seat_player[$r0]}, $pi);
	    }
	  }
        }
      }
    }

  $this->{'mins'} = $minscores == $TOO_MANY ? -1: $minscores;
  $this->{'mins_player'} = $mins_player;
  $this->{'maxps'} = $maxps;
  $this->{'maxps_player'} = $maxps_player;
  $this->{'maxrp'} = $div_max_round0_played;
  $this->{'maxs'} = $maxscores;
  $this->{'maxs_player'} = $maxs_player;
  $this->{'maxp'} = $maxpairings;
  $this->{'minp'} = $minpairings == $TOO_MANY ? -1: $minpairings;
  $this->{'round_seat_player'} = \@round_seat_player;
# warn "@{$round_seat_player[0]}";

  if ($config->Value('track_firsts')) { # must come after maxp computation
    $this->SynchFirsts();
    }
# if ($config->Value('track_teams')) { # must come after maxp computation
#   $this->SynchTeams();
#   }
  if ($c_auto_notes) {
    my %notes : shared;
    $notes{'high_round_win'} = \@high_round_win;
    $this->{'notes'} = \%notes;
    }
  }

=item $n = $d->SynchFirsts();

Make sure that firsts and seconds as recorded in 
$p->{'etc'}{'p12'} are consistent, and make any
possible inferences.  Firsts and seconds are encoded as follows:

  0: bye
  1: first
  2: second
  3: must draw
  4: indeterminate pending prior draws

Recalculate $p->{'p1'},...,$p->{'p4'}

=cut

sub SynchFirsts ($) {
  my $this = shift;
  my $datap = $this->{'data'};
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  my $bye_firsts = $config->Value('bye_firsts');
  my $lastr0 = (defined $this->{'maxr'}) ? $this->{'maxr'} : undef;
  my $final_round_normal = !$config->Value('final_draw');

  # TODO: should be calling TSH::Player::Firsts, etc.
  for my $p (@$datap[1..$#$datap]) {
    $p->{'p1'} = $p->{'p2'} = $p->{'p3'} = $p->{'p4'} = 0;
    unless (exists $p->{'etc'}{'p12'}) {
      $p->{'etc'}{'p12'} = &share([]);
      }
    }
  # If we are tracking but not assigning firsts we should recalculate
  # inferred future firsts in case past firsts have been edited.
  # We force this to happen by truncating firsts back to the last 
  # entered score.
  if (!$config->Value('assign_firsts')) {
    for my $p (@$datap[1..$#$datap]) {
      my $scoresp = $p->{'scores'};
      my $p12p = $p->{'etc'}{'p12'};
      if ($#$p12p > $#$scoresp) {
#       $#$p12p = $#$scoresp; # splices are not thread-safe
	my @p12 : shared = @$p12p[0..$#$scoresp];
	$p->{'etc'}{'p12'} = \@p12;
#	print "Truncating starts/replies for ", $p->TaggedName(), "\n";
        }
      }
    }

  # check consistency of firsts, see if we can make future inferences
  my @bye_count;
  for my $round0 (0..$this->{'maxp'}) {
    my $o12;
    my $oppp;
    my $p12;
    my $i = 0;
    for my $p (@$datap[1..$#$datap]) {
      $i++;
      my $oppid = $p->{'pairings'}[$round0];
      if ($oppid && $oppid > $#$datap) {
	$tourney->TellUser('ebadopp', $oppid, $p->TaggedName());
	next;
        }
#     warn "$p->{'name'} $i $oppid\n";
      unless (defined $oppid) {
	$p12 = 4;
	next;
        }
      my $p12p = $p->{'etc'}{'p12'};
      if ($oppid == 0) { 
	$p12 = 0; 
	$oppp = undef; 
	# NSA rules in effect as of NSC 2008
	if ($bye_firsts eq 'alternate' && ($p->Score($round0)||0) < 0) {
	  $p12 = ++$bye_count[$i] % 2 ? 1 : 2;
	  }
	next; 
        }
      $oppp = undef;
      $p12 = $p12p->[$round0];
      if ($oppid < $p->{'id'}) { # in theory, we already did this one
	# if the pairings are inconsistent, though...
	if (!defined $p12p->[$round0]) {
	  $tourney->TellUser('enoop', $p->TaggedName(), $round0+1)
	    unless $config->Value('allow_gaps');
	  $p12 = 4;
	  }
	next;
        }
      $oppp = $datap->[$oppid];
      my $o12p = $oppp->{'etc'}{'p12'};
      my $exists = 1;
      $o12 = $o12p->[$round0];
      my $p12known = $p12 && $p12 < 4;
      my $o12known = $o12 && $o12 < 4;
      if ($p12known) {
	if ($o12known) { # both set: check for consistency
	  if ($o12 != (0,2,1,3)[$p12]) {
	    $tourney->TellUser('edivbad12', 
              (TSH::Utility::TaggedName $p),
              (TSH::Utility::TaggedName $oppp),
	      $round0+1);
	    }
	  }
	else # we are set but opp is not: set opp
	  { $o12 = $o12p->[$round0] = (0, 2, 1, 3)[$p12]; }
        }
      else {
        if ($o12known) {
	  # opp is set but we are not: set us
	  $p12 = $p12p->[$round0] = (0, 2, 1, 3)[$o12];
	  }
	else { $exists = 0; }
        }
      if ($exists) { 
#	$p->{"p$p12p->[$round0]"}++;
#	print qq($p->{'name'} {p$p12p->[$round0]}++, now $p->{"p$p12p->[$round0]"}\n) if $p->{'name'} =~ /Piro/;
#	$oppp->{"p$o12p->[$round0]"}++;
#	print qq($oppp->{'name'} {p$o12p->[$round0]}++, now $oppp->{"p$o12p->[$round0]"}\n) if $oppp->{'name'} =~ /Piro/;
 	next;
        }
      # otherwise, see if we can deduce first/second
      my $ofuzz = $oppp->{'p3'} + $oppp->{'p4'};
      my $pfuzz = $p->{'p3'} + $p->{'p4'};
#     warn "deducing\n";
      if ($pfuzz + $ofuzz == 0 || $round0 == 0) {
	my $which = 1 +
	  ($p->{'p1'} <=> $oppp->{'p1'} || $oppp->{'p2'} <=> $p->{'p2'});
#         warn "$p->{'name'} $p->{'p1'} $p->{'p2'} $oppp->{'name'} $oppp->{'p1'} $oppp->{'p2'} $which\n";
	if ($which == 1 && $config->Value('assign_firsts')) {
          if ($config->Value('account_for_h2h_sr') && $p->SRDiff( $round0 ) ) {
	    $which = 1 + ($p->SRDiff( $round0 ) <=> 0);
            Debug 'H2H', "setting which to $which based on SRDiff";
	  }
	  elsif ($config->Value('avoid_sr_runs') && $round0 > 0) {
	    # try to assign start/reply to minimize runs
	    for (my $roundi0 = $round0-1; $roundi0 >= 0; $roundi0--) {
	      my $lastp12 = $p12p->[$roundi0];
	      my $lasto12 = $o12p->[$roundi0];
	      next if $lastp12 == $lasto12;
	      if ($lastp12 != $lasto12) {
		$which = $lastp12 == 1 ? 2 : 0;
		last;
		}
	      }
	    }
	  if ($which == 1) {
	    if ($final_round_normal || (defined $lastr0) && $round0 != $lastr0) {
#	      warn "$round0 $lastr0 $p->{'name'} random";
	      $which = 2 * int(rand(2));
	      }
	    }
	  }
        $p12 = (1, 3, 2)[$which];
        $o12 = (2, 3, 1)[$which];
        }
      # else there's fuzz, so we could get 4s
      else {
	my $diff1 = $p->{'p1'} - $oppp->{'p1'};
	my $diff2 = $p->{'p2'} - $oppp->{'p2'};
	if (($diff1 <=> $ofuzz || -$diff2 <=> $pfuzz) > 0) 
	  { $p12 = 2; $o12 = 1; }
	elsif ((-$diff1 <=> $pfuzz || $diff2 <=> $ofuzz) > 0) 
  	  { $p12 = 1; $o12 = 2; }
	elsif ($config->Value('assign_firsts')) {
	  if (rand(1) > 0.5) { $p12 = 1; $o12 = 2; }
	  else { $p12 = 2; $o12 = 1; }
	  }
	else 
	  { $p12 = $o12 = 4; } 
        }
      }
    continue
      {
      $p12 = 4 unless defined $p12;
      $p->{'etc'}{'p12'}[$round0] = $p12;
#     warn "p=$p name=$p->{'name'} p12=$p12\n" unless defined $p12;
      $p->{"p$p12"}++;
#     warn qq(Rd0 $round0 i=$i p: $p->{'name'} vs ).($oppp ? $oppp->{'name'} : "nobody").qq({p$p12}++, now $p->{"p$p12"}\n) if $p->{'name'} =~ /Fifteen/;
#     die "$p->{'id'} > $oppp->{'id'}" if $p->{'id'} > $oppp->{'id'};
      if ($oppp) {
	$oppp->{'etc'}{'p12'}[$round0] = $o12;
#	$oppp->{"p$o12"}++;
#	print qq(Rd0 $round0 i=$i o: $p->{'name'} vs $oppp->{'name'} {p$o12}++, now $oppp->{"p$o12"}\n) if $oppp->{'name'} =~ /Fifteen/;
        }
      }
    }
  }

# =item $n = $d->SynchTeams();
# 
# Make sure that team data is up to date.
# 
# =cut
# 
# sub SynchTeams ($) {
#   my $this = shift;
#   my $datap = $this->{'data'};
#   my $tourney = $this->{'tournament'};
#   my $config = $tourney->Config();
#   }

=item $t = $d->Tournament();
=item $d->Tournament($t);

Get/set a division's associated tournament.

=cut

sub Tournament ($;$) { TSH::Utility::GetOrSet('tournament', @_); }

=item $d->Truncate($r0);

Truncate tournament data to $r0 rounds.

=cut

sub Truncate ($$) { 
  my $dp = shift;
  my $r0 = shift;
  my $datap = $dp->{'data'};
  my $changed = 0;

  for my $p (@$datap[1..$#$datap]) {
#   unless (TSH::Utility::IsASafely($p, 'TSH::Player')) { die join(';', %$p); }
    $changed++ if $p->Truncate($r0); 
    }
  if ($changed) {
    $dp->PurgeReportsByRound0( $r0 );
    $dp->Dirty(1);
    $dp->Synch();
    }
  }

=item $d->TruncateScores($r0);

Truncate tournament score data to $r0 rounds.

=cut

sub TruncateScores ($$) { 
  my $dp = shift;
  my $r0 = shift;
  my $datap = $dp->{'data'};
  my $changed = 0;

  for my $p (@$datap[1..$#$datap]) {
#   unless (TSH::Utility::IsASafely($p, 'TSH::Player')) { die join(';', %$p); }
    $changed++ if $p->TruncateScores($r0); 
    }
  if ($changed) {
    $dp->PurgeReportsByRound0( $r0 );
    $dp->Dirty(1);
    $dp->Synch();
    }
  }

=item $d->TruncateStats($r0);

Remove secondary statistics after round $r0.

=cut

sub TruncateStats ($$) { 
  my $dp = shift;
  my $r0 = shift;
  my $datap = $dp->{'data'};

  for my $key (qw(first_out_of_the_money)) {
    my $ip = $dp->{$key};
    if ($ip && $#$ip > $r0) { 
      my @truncated : shared = @$ip[0..$r0];
      $dp->{$key} = \@truncated;
      }
    }

  for my $p (@$datap[1..$#$datap]) {
    $p->TruncateStats($r0); 
    }
  }

=item $d->Update();

$d->Synch(), then $d->Write().
You should use TSH::Processor::Flush() instead, unless you have good reason not to.

=cut

sub Update ($) { 
  my $this = shift;
  return unless $this->Dirty();
  $this->Synch();
  $this->Write();
  $this->Dirty(0);
  }

=item $d->Write();

Save changes to disk.

=cut

sub Write ($) { 
  my $this = shift;
  my $fn = $this->File();
# Carp::cluck 'saving';
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  return if $config->ReadOnly();

  my $backup_fn = $config->MakeBackupPath("$fn.".time);
  my $main_fn = $config->MakeRootPath($fn);
  copy($main_fn, $backup_fn)
    or $tourney->TellUser('edivupdbak', $backup_fn, $!)
    if -f $main_fn;
  $tourney->TellUser('idivupdok', $fn);
  my $data = $this->Render();
  TSH::Utility::ReplaceFile($main_fn, $data, { 'encoding' => $config->TFileEncoding()})
    or $tourney->TellUser('edivwrite', $main_fn, $!);
  &MacPerl::SetFileInfo('McPL', 'TEXT', $main_fn)
    if defined &MacPerl::SetFileInfo; # a harmless relic of the good old days
  for my $path (@{$config->Value('mirror_directories')}) {
    my $mirror_fn = File::Spec->catfile($path, $fn);
    unless (eval { TSH::Utility::ReplaceFile($mirror_fn, $data) }) {
      $tourney->TellUser('edivwrite', $mirror_fn, $@ ? $@ : $!);
      }
    }
  if (($config->Value('notes')||'') =~ /auto/i) {
    $this->WriteNotes();
    }
  }

sub WriteNotes ($) {
  my $this = shift;
  my $tourney = $this->{'tournament'};
  my $config = $tourney->Config();
  my $data = '';
  my $notesp = $this->{'notes'};
  my $hrwsp = $notesp->{'high_round_win'};
  for my $r1 (1..$this->{'maxr'}) {
    my $hrwp = $hrwsp->[$r1-1];
    if (defined $hrwp) {
      my $score = $hrwp->[0];
      $data .= "t=hrw\nr=$r1\nps=$score\npn=".join(',',@$hrwp[1..$#$hrwp])."\n\n";
      }
    }
  my $fn = $config->MakeHTMLPath($this->{'name'} .'-notes.txt');
  TSH::Utility::ReplaceFile($fn, $data)
    or $tourney->TellUser('efilewrite', $fn, $!);
  }


=item $d->Write(\%options);

Export data to a CSV file.

Options:

C<csv_encoding> (optional): text encoding for source data, defaults to $config->TFileEncoding();

C<data> (required for type string): reference to target data string

C<filename> (required for type file): target filename

C<type> (required): permitted values: 'file', 'string'

CSV Column Names: See C<ReadFromCSV>.

=cut

sub WriteCSV ($$) {
  my $this = shift;
  my $options = shift;
  my $tourney = $this->Tournament();
  my $config = $tourney->Config();
  my (@rows) = ([]);
  my $maxp0 = $this->{'maxp'};
  my $maxs0 = $this->{'maxs'};
  my $c_member_separator = $config->Value('member_separator');

  my $datap = $this->{'data'};
  push(@{$rows[0]}, qw(name));
  push(@{$rows[0]}, qw(member1 member2)) if $c_member_separator;
  push(@{$rows[0]}, qw(rating boards pairings scores team wins losses spread wp rank));
  for my $r0 (0..$maxp0) { push(@{$rows[0]}, 'board' . ($r0+1)); }
  for my $r0 (0..$maxp0) { push(@{$rows[0]}, 'pairing' . ($r0+1)); }
  for my $r0 (0..$maxs0) { push(@{$rows[0]}, 'score' . ($r0+1)); }
  
  if ($maxs0 >= 0) { $this->ComputeRanks($maxs0); }
  for my $id (1..$#$datap) {
    my @row;
    my $p = $datap->[$id];
    (@row) = (
      $p->Name(),
      );
    if ($c_member_separator) {
      my (@members) = split(/$c_member_separator/, $p->Name());
      for my $i (0..1) {
	my $member = $members[$i];
	$member = '' unless defined $member;
	$member =~ s/^\s+//;
	$member =~ s/\s+$//;
	push(@row, $member);
        }
      }
    push(@row, 
      $p->Rating(),
      join(' ', @{$p->Boards()||[]}),
      join(' ', @{$p->OpponentIDs()||[]}),
      join(' ', @{$p->Scores()||[]}),
      $p->Team(),
      $p->Wins(),
      $p->Losses(),
      $p->Spread(),
      $p->Wins()*2,
      $p->RoundRank($maxs0 == -1 ? -1 : -2),
      );
    # store CSV info
    for my $r0 (0..$maxp0) { push(@row, $p->Board($r0)); }
    for my $r0 (0..$maxp0) { push(@row, $p->OpponentID($r0)); }
    for my $r0 (0..$maxs0) { push(@row, $p->Score($r0)); }
    push(@rows, \@row);
    }
  &::Use('TSH::Utility::CSV');
  my $csv = TSH::Utility::CSV::Encode(\@rows);
  if ($options->{'type'} eq 'string') {
    ${$options->{'data'}} = $csv;
    }
  else { # file
    my $encoding = $config->Value('csv_encoding') || 'isolatin1';
    my $fh = TSH::Utility::OpenFile(">:encoding($encoding)",
      $options->{'filename'}) or do {
      $tourney->TellUser('efilecre', $options->{'filename'}, $!);
      return 0;
      };
    print $fh $csv or do {
      $tourney->TellUser('efilewrite', $options->{'filename'}, $!);
      };
    close $fh;
    }
  return 1;
  }

=back

=cut

=head1 BUGS

RecursiveSwiss can sometimes take pathologically long to run,
and needs to be improved.

RecursiveSwiss makes illegal use of the 'opp' field in Player.pm

RecursiveSwiss should make use of firsts/seconds when in use.

It might be a good idea for RecursiveSwiss to keep track of what
FIDE calls upfloats and downfloats and to try to avoid repeating
them in consecutive rounds.

Should check for when corrupt .t files have one score from a game but not 
the other.

Should not rely on TSH::Player private functions.

In some unusual circumstances, assigning the bye according to official
rules can be unfair.  For example, if there are 2N+1 players playing
2N rounds, it is possible that a top contender may get a final-round
bye; in this case, it is arguable that a second bye should go to the
bottom player.

=cut

1;
