#!/usr/bin/perl

# Copyright (C) 2008-2013 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::Addscore;

use strict;
use warnings;

use TSH::Utility;
use TSH::Tournament;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::Addscore - implement the C<tsh> Addscore command

=head1 SYNOPSIS

  my $command = new TSH::Command::Addscore;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::Addscore is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

# How many member subs will we get to before this gets rewritten with classes?
my (%gEntrySystemData) = (
  'board' => { 
    'field_keys' => [qw(bd pn1 ps1 pn2 ps2 spread)],
    'has_both' => 1,
    'has_tags' => 0,
    'player_word_index_sum' => 4,
    'players_in_game' => 2,
    'prompt_key' => 'bd',
    'sub_confirm' => \&ConfirmScores,
    'sub_input' => \&InputGameBoard,
    },
  'both' => { 
    'field_keys' => [qw(pn1 ps1 pn2 ps2 spread)],
    'has_both' => 1,
    'has_tags' => 0,
    'player_word_index_sum' => 2,
    'players_in_game' => 2,
    'prompt_key' => 'bt',
    'sub_confirm' => \&ConfirmScores,
    'sub_input' => \&InputGameBoth,
    },
  'scores' => { 
    'field_keys' => [qw(pn1 ps1 pn2 ps2)],
    'has_both' => 0,
    'has_tags' => 0,
    'player_word_index_sum' => 2,
    'players_in_game' => 2,
    'prompt_key' => 'sc',
    'sub_confirm' => \&ConfirmScores,
    'sub_input' => \&InputGameScores,
    },
  'spread' => { 
    'field_keys' => [qw(pn1 pn2 spread)],
    'has_both' => 0,
    'has_tags' => 0,
    'player_word_index_sum' => 1,
    'players_in_game' => 2,
    'prompt_key' => 'sp',
    'sub_confirm' => \&ConfirmSpread,
    'sub_input' => \&InputGameSpread,
    },
  'sudoku' => { 
    'field_keys' => [qw(pn1 ps1)],
    'has_both' => 0,
    'has_tags' => 0,
    'player_word_index_sum' => 0,
    'players_in_game' => 1,
    'prompt_key' => 'sc',
    'sub_confirm' => \&ConfirmSudoku,
    'sub_input' => \&InputGameSudoku,
    },
  'tagged' => { 
    'field_keys' => [qw(pn1 ps1 pn2 ps2 spread tag)],
    'has_both' => 1,
    'has_tags' => 1,
    'player_word_index_sum' => 2,
    'players_in_game' => 2,
    'prompt_key' => 'tg',
    'sub_confirm' => \&ConfirmTagged,
    'sub_input' => \&InputGameTagged,
    },
  );

sub CheckPairing ($$);
sub CheckRoundNumber ($$);
sub CheckScores ($$);
sub CheckSpread ($$);
sub Confirm ($$);
sub ConfirmScores ($$$$$$);
sub ConfirmSpread ($$$$$$);
sub ConfirmSudoku ($$$$$);
sub DivisionRound ($$);
sub EscapeCommand ($$);
sub Flush ($$);
sub initialise ($$$$);
sub InputBye ($$);
sub InputGame ($$);
sub InputGameBoard ($$);
sub InputGameBoth ($$);
sub InputGameScores ($$);
sub InputGameSpread ($$);
sub InputGameSudoku ($$);
sub InputGameTagged ($$);
sub new ($);
sub Override ($$$);
sub ProcessNames ($$$);
sub ReadPromptedLine ($$$);
sub Run ($$@);
sub ScoreBye ($$$);
sub StoreScores ($$);

=item $ok = $parserp->CheckPairing($rundatap)

Returns true unless the entered players were scheduled not
to play each other (or entry_pairing permits an override).

=cut

sub CheckPairing ($$) {
  my $this = shift;
  my $rundatap = shift;
  my $dp = $rundatap->{'dp'};
  my $round0 = $rundatap->{'round0'};
  my $tournament = $rundatap->{'tournament'};
  my (@pn) = @$rundatap{qw(pn1 pn2)};
  my (@pp) = map { $dp->Player($_) } @pn;
  my (@oppn) = map { $_ ? $_->OpponentID($round0) : undef } @pp;

  # previous pairings match current ones: accept 
  if (($oppn[0]||0) == $pn[1] && ($oppn[1]||0) == $pn[0]) {
    return 1;
    }
  # allow pairing to be implied by data entry
  if ($rundatap->{'config'}->Value('entry_pairing')) {
    # no previous pairings, accept them as entered
    if ((!defined $oppn[0]) && !defined $oppn[1]) {
      $dp->Pair($pn[0], $pn[1], $round0, 0);
      if (my $bd = $rundatap->{'bd'}) {
	$pp[0]->Board($round0, $bd);
	}
      return 1;
      }
    $this->Override($rundatap, $pp[0]); # verbosely report on un-pairing 1st player
    $this->Override($rundatap, $pp[1]); # verbosely report on un-pairing 2nd player
    $dp->Pair($pn[0], $pn[1], $round0, 0);
    return 1;
    }

  # otherwise there were past pairings which disagree
  for my $i (0..1) {
    if ($pp[$i]) {
      push(@pp, $pp[$i]->Opponent($round0));
      }
    else {
      push(@pp, undef);
      $tournament->TellUser('ebadp', $pn[$i]);
      }
    }
  my (@pname) = map { ((!defined $_) || ref($_) eq 'HASH') ? 'nobody' : $_->TaggedName() } @pp;
  $tournament->TellUser('eanotopp', $pname[0], $pname[1], $round0+1, $pname[0], $pname[2], $pname[1], $pname[3]);
  return 0;
  }

=item $ok = $parserp->CheckRoundNumber($rundatap)

Returns true if $rundatap->{'round0'} is currently a valid zero-based
round number for data entry in the current division.

=cut

sub CheckRoundNumber ($$) {
  my $this = shift;
  my $rundatap = shift;
  my $dp = $rundatap->{'dp'};

  # If gaps are being allowed, anything goes
  return 1 if $rundatap->{'config'}->Value('allow_gaps');

  my $round0 = $rundatap->{'round0'};
  my $least_scores = $dp->LeastScores();

  # too early, round must already be complete
  if ($round0 <= $least_scores - 1) {
    $rundatap->{'tournament'}->TellUser('eallsin', $dp->Name(), $round0+1);
    return 0;
    }
  # too late, must do earlier rounds first
  if ($round0 > $least_scores) {
    $rundatap->{'tournament'}->TellUser('emisss', $dp->Name(),
      $dp->{'mins'}+2, $dp->LeastScoresPlayer()->TaggedName());
    return 0;
    }
  return 1;
  }

=item $ok = $parserp->CheckScores($rundatap)

Returns true if the scores have just been entered are valid.

=cut

sub CheckScores ($$) {
  my $this = shift;
  my $rundatap = shift;

  my $dp = $rundatap->{'dp'};
  my $round0 = $rundatap->{'round0'};
  my $tournament = $rundatap->{'tournament'};
  my (@pn) = @$rundatap{qw(pn1 pn2)};
  my (@ps) = @$rundatap{qw(ps1 ps2)};
  my ($toohigh, $toolow, $lowish) = @$rundatap{qw(too_high too_low lowish)};
  my (@pp) = map { $dp->Player($_) } @pn;
  my $seats = $rundatap->{'config'}->Value('seats');
  my $dsize = $dp->CountPlayers();
  my $bd = $rundatap->{'bd'};
  
  return 0 if $rundatap->{'players_in_game'} > 1 and !$this->CheckPairing($rundatap);
  return 0 if $rundatap->{'entry_data'}{'has_both'} and !$this->CheckSpread($rundatap);

  if ((defined $bd) && $seats) { # check seats
    if ($pp[0]->Board($round0) != $bd) {
      if ($round0 == 0) {
	warn "That's not where I had them playing, but that's okay, we'll move them.\n";
        $pp[0]->Board($round0, $bd);
        }
      # if at an adjacent board, likely at the same table (should we require that?), try moving them
      elsif (abs($pp[0]->Board($round0) - $bd) == 1) {
	# see if it looks safe
	my $can_move = 1;
	my $neighbour_pn1 = $dp->RoundSeatPlayer($round0, 2*$bd-1);
	my $neighbour_pn2 = $dp->RoundSeatPlayer($round0, 2*$bd);
	my $neighbour_pp1 = $neighbour_pn1 && $dp->Player($neighbour_pn1);
	my $neighbour_pp2 = $neighbour_pn1 && $dp->Player($neighbour_pn2);
	warn "That's not where they were supposed to play. Let's see if it's safe to move them.\n";
	if ($neighbour_pp1 && defined $neighbour_pp1->Score($round0)) {
	  warn "... No, it's not.  ".$neighbour_pp1->TaggedName()." already played a game there.\n";
	  $can_move = 0;
	  }
	elsif ($neighbour_pp2 && defined $neighbour_pp2->Score($round0)) {
	  warn "... No, it's not.  ".$neighbour_pp2->TaggedName()." already played a game there.\n";
	  $can_move = 0;
	  }
	warn "It looks safe, I'll move them.\n";
        my $old_bd = $pp[0]->Board($round0, $bd);
	if ($neighbour_pp1 && $neighbour_pp2) {
	  $neighbour_pp1->Board($round0, $old_bd);
	  }
        }
      else {
	warn "That's not where they should be playing.  If that's really where they are, use BoardPAIR to move them before entering their score.\n";
	return 0;
        }
      }
    } # done checking seats
  my $check_firsts = ($rundatap->{'config'}->Value('track_firsts') 
    && !$rundatap->{'config'}->Value('assign_firsts'));
  # check each player's data
  if ($rundatap->{'entry'} !~ /^(?:spread|sudoku)$/ && (
      ($ps[0] == 0 && $ps[1] == $rundatap->{'config'}->Value('bye_spread'))
    || ($ps[1] == 0 && $ps[0] == $rundatap->{'config'}->Value('bye_spread')))) {
    # should be reentered as bye
#   warn $rundatap->{'config'}->Value('bye_spread');
    $tournament->TellUser('eabbye', $ps[0], $ps[1]);
    return 0;
    }
  for my $i (0..$rundatap->{'entry_data'}{'players_in_game'}-1) {
    my $pn = $pn[$i];
    my $ps = $ps[$i];
    my $pp = $pp[$i];
    # bad player number
    if ($pn < 1 || $pn > $dsize) {
      $tournament->TellUser('enosuchp', $pn);
      return 0;
      }
    # bad score
    if ($ps !~ /^[-+]?\d+$/ || ($rundatap->{'entry'} ne 'spread' && $ps < $toolow)|| $ps > $toohigh) {
      $tournament->TellUser('ebadscore', $ps);
      return 0;
      }
    # suspicious score
    if ($ps < $lowish) {
      $tournament->TellUser('wlowscore', $ps);
      }
    # duplicate score
    if (defined $pp->Score($round0)) {
      my $olds = $pp->Score($round0);
      if ($olds == $ps) {
	if ($i == 1) {
	  $tournament->TellUser('whass', $pp->TaggedName(), $pp->Score($round0));
	  return 0;
	  }
        }
      else {
	$tournament->TellUser('ehass', $pp->TaggedName(), $pp->Score($round0));
	return 0;
        }
      }
    # wrong player went first
    if ($check_firsts) {
      my $old = $pp->First($round0);
      if ($old && $old == 2 - $i) { # 2, 1
	$tournament->TellUser('easbad12', $pp->TaggedName(), 
	  (qw(second first))[$i]); 
        }
      $pp->First($round0, 1 + $i); # 1, 2
      }
    }
  return 1;
  }

=item $ok = $parserp->CheckSpread($rundatap)

Returns true if the entered spread is consistent with scores.

=cut

sub CheckSpread ($$) {
  my $this = shift;
  my $rundatap = shift; 

  if ($rundatap->{'ps1'} - $rundatap->{'ps2'} != $rundatap->{'spread'}) {
    $rundatap->{'tournament'}->TellUser('easa', $rundatap->{'ps1'}, $rundatap->{'ps2'}, $rundatap->{'ps1'}-$rundatap->{'ps2'}, $rundatap->{'spread'});
    return 0;
    }
  return 1;
  }

=item $parserp->Confirm($rundatap)

Confirms to the user what was just entered.

=cut

sub Confirm ($$) {
  my $this = shift;
  my $rundatap = shift; 

  my $dp = $rundatap->{'dp'};
  my $spread = $rundatap->{'ps1'} - ($rundatap->{'ps2'}||0);
  &{$rundatap->{'entry_data'}{'sub_confirm'}}(
    $this,
    $rundatap,
    $spread,
    (($spread <=> 0) + 1) / 2, # wlt
    $dp->Player($rundatap->{'pn1'}), #pp1
    $dp->Player($rundatap->{'pn2'}), #pp2
    );
  return;
  }

=item $parserp->ConfirmScores($rundatap, $spread, $wlt, $pp1, $pp2)

Confirms to the user what was just entered, when in scores or both mode.

=cut

sub ConfirmScores ($$$$$$) {
  my $this = shift;
  my $rundatap = shift; 
  my $spread = shift;
  my $wlt = shift;
  my $pp1 = shift;
  my $pp2 = shift;

  printf "#%d %s %d (%.1f %+d) - #%d %s %d (%.1f %+d): %+d.\n",
    $pp1->ID(), 
    $pp1->Name(), 
    $rundatap->{'ps1'},
    $pp1->Wins() + $wlt,
    $pp1->Spread() + $spread,
    $pp2->ID(), 
    $pp2->Name(), 
    $rundatap->{'ps2'},
    $pp2->Wins() + 1 - $wlt,
    $pp2->Spread() - $spread,
    $spread,
    ;
  }

=item $parserp->ConfirmSpread($rundatap, $spread, $wlt, $pp1, $pp2)

Confirms to the user what was just entered, when in spread mode.

=cut

sub ConfirmSpread ($$$$$$) {
  my $this = shift;
  my $rundatap = shift; 
  my $spread = shift;
  my $wlt = shift;
  my $pp1 = shift;
  my $pp2 = shift;

  printf "#%d %s (%.1f %+d) - #%d %s (%.1f %+d).\n",
    $pp1->ID(), 
    $pp1->Name(), 
    $pp1->Wins() + $wlt,
    $pp1->Spread() + $spread,
    $pp2->ID(), 
    $pp2->Name(), 
    $pp2->Wins() + 1 - $wlt,
    $pp2->Spread() - $spread,
    ;
  }

sub ConfirmSudoku ($$$$$) {
  my $this = shift;
  my $rundatap = shift; 
  my $score = shift;
  my $wlt = shift;
  my $pp1 = shift;

  printf "#%d %s %+d = %d.\n",
    $pp1->ID(), 
    $pp1->Name(), 
    $score,
    $pp1->Spread() + $score,
    ;
  }

=item $parserp->ConfirmTagged($rundatap, $spread, $wlt, $pp1, $pp2)

Confirms to the user what was just entered, when in tagged mode.

=cut

sub ConfirmTagged ($$$$$$) {
  my $this = shift;
  my $rundatap = shift; 
  my $spread = shift;
  my $wlt = shift;
  my $pp1 = shift;
  my $pp2 = shift;

  printf "#%d %s %d (%.1f %+d) - #%d %s %d (%.1f %+d): %+d (%s).\n",
    $pp1->ID(), 
    $pp1->Name(), 
    $rundatap->{'ps1'},
    $pp1->Wins() + $wlt,
    $pp1->Spread() + $spread,
    $pp2->ID(), 
    $pp2->Name(), 
    $rundatap->{'ps2'},
    $pp2->Wins() + 1 - $wlt,
    $pp2->Spread() - $spread,
    $spread,
    $rundatap->{'tag'},
    ;
  }

=item $s = $parserp->DivisionRound($rundatap);

Return a string showing the current division name (if there's more
than one division) and round number, for use in a prompt.

=cut

sub DivisionRound ($$) {
  my $this = shift;
  my $rundatap = shift; 

  my $dp = $rundatap->{'dp'};
  my $round = $rundatap->{'round0'} + 1;
  my $tournament = $dp->Tournament();
  my $s = '';
  if ($tournament->CountDivisions() > 1) {
    $s .= $dp->Name();
    }
  $s .= $round;
  return $s;
  }

=item $ran = $parserp->EscapeCommand($rundatap)

If input data is a valid escape command, run it and return true.

=cut

sub EscapeCommand ($$) {
  my $this = shift;
  my $rundatap = shift; 
  local($_) = $rundatap->{'input'};

  my $dp = $rundatap->{'dp'};
  my $round = $rundatap->{'round0'} + 1;
  if (/^(?:m|miss|missing)(\s+\S+)?$/i) {
    my $div = $1;
    $div = '' unless defined $div;
    $this->Flush($rundatap);
    $this->Processor()->Process("missing $round$div");
    $rundatap->{'no_completion_hook'} = 1;
    }
  elsif (/^(?:es|editscore)$/i) {
    my $dname = $dp->Name();
    my $lastpn1 = $rundatap->{'lastpn1'};
    my $round = $rundatap->{'round0'}+1;
    $this->Flush($rundatap);
    $this->Processor()->Process("editscore $dname $lastpn1 $round");
    $rundatap->{'no_completion_hook'} = 1;
    }
  elsif (/^(?:l|look)\s+([a-z]+[a-z\s]*)$/i) {
    $this->Processor()->Process("look $1");
    $rundatap->{'no_completion_hook'} = 1;
    }
  else {
    $rundatap->{'no_completion_hook'} = 0;
    }
  return $rundatap->{'no_completion_hook'};
  }

=item $command->Flush($rundatap)

Used internally to flush division data and reset the private count.

=cut

sub Flush ($$) {
  my $this = shift;
  my $rundatap = shift; 

  if ($rundatap->{'changed'}) {
    $this->Processor()->Flush();
    $rundatap->{'changed'} = 0;
    if (my $cmds = $rundatap->{'config'}->Value('hook_addscore_flush')) {
      $this->Processor()->RunHook('hook_addscore_flush', $cmds,
	{ 'nohistory' => 1,
	  'noconsole' => $rundatap->{'config'}->Value('quiet_hooks') },
	  { 'd' => $rundatap->{dp}->Name(), 'r' => $rundatap->{round0} + 1 },
        );
      }
    }
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to enter player scores.  You must pair the round
(e.g. by autopairing or using the pm command) before you can enter
any scores.  Begin by specifying the round and division that you
are entering.  At the prompt, enter the first player's number and
score, then the second player's number and score, all on one line.
For a bye or forfeit, enter the player's number and the spread
adjustment.  If you don't know a player's number, try entering
part-of-their-last-name,part-of-their-first-name.  You may enter a
division name to switch divisions, or 'm' to see what scores are
still missing.  To correct a mistake in the game you just entered,
enter 'es'.  If you enter anything else, you will exit the command
and return to the main prompt.
EOF
  $this->{'names'} = [qw(a addscore)];
  $this->{'modal'} = 1; # See Command::IsModal();
  $this->{'argtypes'} = [qw(Round Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

=item $success = $command->InputBye($rundatap)

Try to parse input data for a bye.  Return success if the input resembled
bye data sufficiently that either it was processed or an error message was emitted,
but in either case no further parsing is required.

=cut

sub InputBye ($$) {
  my $this = shift;
  my $rundatap = shift; 

  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 2;
  my $tournament = $rundatap->{'tournament'};
  my $dp = $rundatap->{'dp'};
  my $round0 = $rundatap->{'round0'};
  my $round = $round0 + 1;
  my ($pn1, $ps1) = @words;
  if ($pn1 < 1 || $pn1 > $dp->CountPlayers()) {
    $tournament->TellUser('enosuchp', $pn1);
    return 1;
    }
  my $pp1 = $dp->Player($pn1);
  my $opp1 = $pp1->OpponentID($round0);
  unless ((defined $opp1) && $opp1 == 0) {
    $tournament->TellUser('enotabye', $pp1->TaggedName(), $round);
    return 1;
    }
  if (my $s = $pp1->Score($round0)) {
    $tournament->TellUser($s == $ps1 ? 'whass' : 'ehass', $pp1->TaggedName(), $s);
    return 1;
    }
  {
    my $wlt = $ps1 > 0 ? 1 : 0;
    printf "#%d %s %+d (%.1f %+d).\n",
      $pp1->ID(),
      $pp1->Name(),
      $ps1,
      $pp1->Wins() + $wlt,
      $pp1->Spread() + $ps1,
      ;
  }
  $rundatap->{'lastpn1'} = $pn1;
  $dp->Dirty(1);
  $dp->DirtyRound($round0);
  $rundatap->{'changed'}++;
  $pp1->Time(time);
  $pp1->Score($round0, $ps1);
  return 1;
  }

=item $success = $command->InputGame($rundatap)

Try to parse input data for a game.  Return success if we think we
read things that looked like scores. 

Return 0 if we failed and want to tell the user so.

Return undef if we failed and took care of telling the user already.

As a side effect, update range-checking bounds for scores.

=cut

sub InputGame ($$) {
  my $this = shift;
  my $rundatap = shift; 
  $rundatap->{'bd'} = undef;
  $rundatap->{'pn1'} = $rundatap->{'ps1'} =
  $rundatap->{'pn2'} = $rundatap->{'ps2'} = undef;
  $rundatap->{'too_high'} = $rundatap->{'config'}->Value('max_score') || 1499;
  $rundatap->{'too_low'} = -149;
  $rundatap->{'lowish'} = 100;
  return &{$rundatap->{'entry_data'}{'sub_input'}}($this, $rundatap);
  }

=item $success = $command->InputGameBoard($rundatap)

Try to parse input data for a game when board, spread and scores are all
being entered.  Return success if we think we read things that looked
like scores.

=cut

sub InputGameBoard ($$) {
  my $this = shift;
  my $rundatap = shift; 

  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 6;
  @$rundatap{qw(bd pn1 ps1 pn2 ps2 spread)} = @words;
  # this input mode is used for some low-scoring school tournaments
  $rundatap->{'too_low'} = 25;
  $rundatap->{'lowish'} = -1;
  return 1;
  }

=item $success = $command->InputGameBoth($rundatap)

Try to parse input data for a game when both spread and scores are
being entered.  Return success if we think we read things that looked
like scores.

=cut

sub InputGameBoth ($$) {
  my $this = shift;
  my $rundatap = shift;

  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 5;
  @$rundatap{qw(pn1 ps1 pn2 ps2 spread)} = @words;
  return 1;
  }

=item $success = $command->InputGameScores($rundatap)

Try to parse input data for a game when only scores are being
entered.  Return success if we think we read things that looked
like scores.

=cut

sub InputGameScores ($$) {
  my $this = shift;
  my $rundatap = shift;

  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 4;
  @$rundatap{qw(pn1 ps1 pn2 ps2)} = @words;
  return 1;
  }

=item $success = $command->InputGameSpread($rundatap)

Try to parse input data for a game when only spread is being entered.
Return success if we think we read things that looked like scores.
As a side effect, update range-checking bounds for scores.

=cut

sub InputGameSpread ($$) {
  my $this = shift;
  my $rundatap = shift;

  my $tournament = $rundatap->{'tournament'};
  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 3;
  @$rundatap{qw(pn1 pn2 ps1)} = @words;
  $rundatap->{'ps2'} = 0;
  $rundatap->{'too_low'} = 0;
  $rundatap->{'lowish'} = -1;
  $rundatap->{'too_high'} = $rundatap->{'config'}->Value('max_score') || 999;
  return 1;
  }

sub InputGameSudoku ($$) {
  my $this = shift;
  my $rundatap = shift;

  my $tournament = $rundatap->{'tournament'};
  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 2;
  @$rundatap{qw(pn1 ps1)} = @words;
  $rundatap->{'pn2'} = 0;
  $rundatap->{'ps2'} = 0;
  $rundatap->{'too_low'} = 0;
  $rundatap->{'lowish'} = -1;
  $rundatap->{'too_high'} = $rundatap->{'config'}->Value('max_score') || 999;
  return 1;
  }

=item $success = $command->InputGameTagged($rundatap)

Try to parse input data for a game when spread, scores and a
(typically lexicon-indicating) tag are being entered.  
Return success if we think we read things correctly.
Return 0 if input looked garbled.
Return undef if input was okay except for a bad tag that has been reported to the user.

=cut

sub InputGameTagged ($$) {
  my $this = shift;
  my $rundatap = shift;

  my (@words) = @{$rundatap->{'words'}};
  return 0 unless @words == 6;
  my $config = $rundatap->{'config'};
  @$rundatap{qw(pn1 ps1 pn2 ps2 spread tag)} = @words;
  $rundatap->{'tag'} = lc $rundatap->{'tag'};
  if (my $entry_tagsp = $config->Value('entry_tags')) {
    my $canon = $entry_tagsp->{$rundatap->{'tag'}};
    unless (defined $canon) {
      $rundatap->{'tournament'}->TellUser('eabtag', $rundatap->{'tag'}, join(', ', sort keys %$entry_tagsp));
      return undef; # do not add eahuh on return
      }
    $rundatap->{'tag'} = $canon;
    }
  return 1;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $parserp->Override($rundatap, $p)

If the player was paired in the current round, tell the user that a different
pairing has been entered for them, that this is an anomalous condition, and
they should look for the other score slip that lists this user to fix it.
Then make sure the player is left unpaired, so that they can be repaired.

=cut

sub Override ($$$) {
  my $this = shift;
  my $rundatap = shift;
  my $p = shift || return;
  my $round0 = $rundatap->{'round0'};
  my $tournament = $rundatap->{'tournament'};

  if (my $opp = $p->Opponent($round0)) {
    $tournament->TellUser('iaor', $p->TaggedName(), $p->Score($round0),
      $opp->Score($round0), $opp->TaggedName());
    }
  $p->UnpairRound($round0);
  }

=item $success = $command->ProcessNames($rundatap, $bye)

Convert input player names to player numbers.  Return success if all
necessary nonnumerics converted successfully.

=cut

sub ProcessNames ($$$) {
  my $this = shift;
  my $rundatap = shift;
  my $is_bye = shift;

  my $tag = undef;
  my $line = $rundatap->{'input'};
  $line =~ s/^\s+//;
  my (@words) = split(/\s+/, $line);
  $tag = pop @words if $rundatap->{'entry_data'}{'has_tags'};
  my @unresolved;
  # iterate over indices of command-line arguments
  for my $wi (0..$#words) {
    my $word = $words[$wi];
    # if a word is pure numeric, it needs no processing
    next if $word !~ /\D/;
    my $fksp = $rundatap->{'entry_data'}{'field_keys'};
    # if the caller thinks it looks like a bye, 
    # the only name will be the first word, so ignore the rest
    last if $is_bye and $wi > 0;
    # ignore words that have no field type, or whose field type is not player#
    next if $wi > $#$fksp or $fksp->[$wi] !~ /^pn\d+$/;
    my ($last, $first) = split(/,/, $word);
    $first = '' unless defined $first;
    # ask the tournament to search for string matches on players
    my $matchdatap = $rundatap->{'tournament'}->FindPlayer($last, $first, $rundatap->{'dp'}, 'detailed');
    my $matchesp = $matchdatap->{'matches'};
    # best-case scenario: unique match
    if (@$matchesp == 1) { $words[$wi] = $matchesp->[0]->ID(); next; }
    my $dname = $matchdatap->{'otherdiv'};
    # good for us, bad for user: no match
    if (@$matchesp == 0) {
      $rundatap->{'tournament'}->TellUser((defined $dname) ? 'enomatch2' : 'enomatch', "$last,$first", $dname);
      return 0;
      }
    # otherwise: ambiguous multiple matches
    push(@unresolved, {'wi' => $wi, 'ps' => $matchesp});
    }
  # if one word is unresolved, find known opponent among matched names
  if (@unresolved == 1) {
    if (@words == 1) {
      $rundatap->{'tournament'}->TellUser('ebaddiv', $words[0]);
      return 0;
      }
    my $owi; # index of opponent ID in entered words
    my $pwis = $rundatap->{'entry_data'}{'player_word_index_sum'};
    $owi = $pwis - $unresolved[0]{'wi'} if $pwis;
    my $oid; # opponent ID of unresolved player
    $oid = $words[$owi] if defined $owi;
    if (defined $oid) {
      my $p1;
      for my $p (@{$unresolved[0]{'ps'}}) { # iterate over possible match identities
	if (($p->OpponentID($rundatap->{'round0'})||0) == $oid) {
	  # if we find one who played the known opponent, that's them
	  if ($p1) { $p1 = undef; last; } # in case pairings are corrupt
	  $p1 = $p;
	  }
	}
      if ($p1) { 
	$words[$unresolved[0]{'wi'}] = $p1->ID(); 
	@unresolved = ();
        }
      }
    if (@unresolved) {
      if (defined $oid) {
	my $opp = $rundatap->{'dp'}->Player($oid);
	if ($opp) {
	  my $oppopp = $opp->Opponent($rundatap->{'round0'});
	  $rundatap->{'tournament'}->TellUser('enomatcho',
	    $opp->TaggedName(), 
	    $oppopp ? $oppopp->TaggedName() : 'nobody',
	    $words[$unresolved[0]{'wi'}],
	    );
	  }
	else {
	  $rundatap->{'tournament'}->TellUser('enosuchp', $oid);
	  }
        }
      elsif ($is_bye) {
	$rundatap->{'tournament'}->TellUser('enomatchb',
	  $words[$unresolved[0]{'wi'}],
	  );
        }
      else {
	# TODO: check to see if this branch can ever be followed.
	$rundatap->{'tournament'}->TellUser('enomatcho',
	  '(undefined)',
	  '(undefined)',
	  $words[$unresolved[0]{'wi'}],
	  );
        }
      $rundatap->{'no_completion_hook'} = 1;
      return 0;
      }
    }
  # if two words are unresolved, look for a unique pairing match
  # between the two sets of matched names
  elsif (@unresolved == 2) {
    my @pair;
    p1loop:for my $p1 (@{$unresolved[0]{'ps'}}) {
      for my $p2 (@{$unresolved[1]{'ps'}}) {
	if (($p1->OpponentID($rundatap->{'round0'})||0) == $p2->ID()) {
	  if (@pair) { @pair = (); last p1loop; }
	  @pair = ($p1, $p2);
	  }
        }
      }
    if (@pair) {
      $words[$unresolved[0]{'wi'}] = $pair[0]->ID();
      $words[$unresolved[1]{'wi'}] = $pair[1]->ID();
      @unresolved = ();
      }
    if (@unresolved) {
      my $matchesp = $unresolved[0]{'ps'};
      my $word = $words[$unresolved[0]{'wi'}];
      if (@$matchesp <= 10) {
	$rundatap->{'tournament'}->TellUser('emultmatch', $word,
	  join('; ', map { $_->TaggedName() } @$matchesp));
        }
      else { $rundatap->{'tournament'}->TellUser('emanymatch', $word); }
      $rundatap->{'no_completion_hook'} = 1;
      return 0;
      }
    }


  if ("@words" =~ /[^-.+\d\s]/) { 
    $rundatap->{'no_completion_hook'} = 1;
    $rundatap->{'tournament'}->TellUser('eahuh');
    return 0;
    }
  push(@words, $tag) if defined $tag;
  $rundatap->{'input'} = "@words";
  return 1;
  }


=item $command->ReadPromptedLine($rundatap)

Prompt for and read one line of input for Addscore.

=cut

sub ReadPromptedLine ($$$) {
  my $this = shift;
  my $rundatap = shift;

  my $round0 = $rundatap->{'round0'};
  my $dp = $rundatap->{'dp'};
# for my $p ($dp->Players()) { print join(';', $p->Name(), $p->Active(), $p->Score($round0), defined $p->Score($round0)), "\n" }
  my (@left) = grep { ($_->Active()) && !defined $_->Score($round0) }
    $dp->Players();
  my $left = scalar(@left);
  if (@left % 2) {
    $this->ScoreBye($rundatap, \@left);
    $left = scalar(@left);
    }
  if ($left == 0) {
    if (my $cmds = $rundatap->{'config'}->Value('hook_division_complete')->{$dp->Name()}) {
      $this->Flush($rundatap);
      $this->Processor()->Process($cmds, 
	{ 'nohistory' => 1,
	  'noconsole' => $rundatap->{'config'}->Value('quiet_hooks') },
        { 'r' => $round0+1,
	  'd' => $dp->Name(),
	}) unless $rundatap->{'no_completion_hook'};
      }
    }
  my $divrd = $this->DivisionRound($rundatap);
  my $prompt;
  if (($rundatap->{'config'}->Value('addscore_prompt')||'') eq 'games') {
    $left /= 2;
    $prompt = $rundatap->{'config'}->Terminology(
      'ap_games_terse'.($left=~/^[01]$/?$left:2), $divrd, $left);
    }
  else {
    $prompt = $rundatap->{'config'}->Terminology(
      "ap_$rundatap->{'entry_data'}{'prompt_key'}".($left>1 ? 2 : $left), $divrd, $left);
    }
  my $score_data;
  if (-t STDIN) {
    $score_data = $rundatap->{'config'}->DecodeConsoleInput(TSH::Utility::ReadLine('Addscore', $prompt));
    }
  else {
    TSH::Utility::Prompt($prompt);
    $score_data = $rundatap->{'config'}->DecodeConsoleInput(scalar(<STDIN>));
  }
# local($_) = scalar(<STDIN>);
  return '' unless defined $score_data;
  $score_data =~ s/^\s+//; $score_data =~ s/\s+$//;
  return $score_data;
  }

=item $command->ReportStats($count, $elapsed)

Record a run of $count scores entered in $elapsed seconds, then 
report statistics to an interactive user.

=cut

sub ReportStats ($$$) {
  my $this = shift;
  my $count = shift;
  my $elapsed = shift;

  my $old_cume = $this->{'cume_count'};
  $this->{'cume_count'} += $count;
  $this->{'cume_time'} += $elapsed;

  if (-t STDIN) {
    printf "%d game%s entered in %f second%s = %f games/minute", $count, ($count == 1 ? '' : 's'), $elapsed, ($elapsed == 1 ? '' : 's'),  $count/(($elapsed||1)/60);
    printf " (cume %d g, %d s, %f g/min)", $this->{'cume_count'}, $this->{'cume_time'}, $this->{'cume_count'}/(($this->{'cume_time'}||1)/60) if $old_cume;
    print "\n";
    }
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my %rundata;
  $rundata{'tournament'} = shift;
  my $round = shift;
  $rundata{'round0'} = $round - 1;
  $rundata{'dp'} = shift;
  my $config = $rundata{'config'} = $rundata{'tournament'}->Config();
  my $entry = $rundata{'entry'} = $rundata{'config'}->Value('entry');
  $rundata{'entry_data'} = $gEntrySystemData{$entry} or
    die "Assertion failed: unknown entry system '$entry'";

  return unless $this->CheckRoundNumber(\%rundata);

# my $save_interval = ($config->Value('save_interval') || 10);
  my $save_interval = ($config->Value('save_interval') || 1);
  $rundata{'lastpn1'} = 1;
  $rundata{'changed'} = 0;
  $rundata{'no_completion_hook'} = 0;
  $rundata{'players_in_game'} = $rundata{'entry_data'}{'players_in_game'};

  my $elapsed = TSH::Utility::Time();
  my $count = 0;
  # main input loop
prompt:while (1) {
    $rundata{'input'} = $this->ReadPromptedLine(\%rundata);
    last if $rundata{'input'} =~ /^$/; # exit on empty input
    # if input is a division name, change divisions
    if (my $newdp = $rundata{'tournament'}->GetDivisionByName($rundata{'input'})) {
      $rundata{'dp'} = $newdp;
      # exit if division data is complete
      # TODO - see if we are editing
      last unless $this->CheckRoundNumber(\%rundata);
      $rundata{'no_completion_hook'} = 1;
      next;
      }
    next if $this->EscapeCommand(\%rundata); # handle other non-data commands
    $rundata{'input'} =~ s/(?<=\d)\.(\d)/ $1/g; # keypad users prefer . to space
    my $looks_like_bye = $rundata{'input'} =~ /^\s*\S+\s+\S+\s*$/;
    # replace player names with #s
    next unless $this->ProcessNames(\%rundata, $looks_like_bye);
    $rundata{'words'} = [split(/\s+/, $rundata{'input'})];
    # user entered spread for a bye
    if ($rundata{'players_in_game'} > 1 && $this->InputBye(\%rundata)) {
      $count++;
      next;
      }
    # user entered data for a game played
    unless (my $huh = $this->InputGame(\%rundata)) { # sets all the $rundatap values
      $rundata{'tournament'}->TellUser('eahuh') if defined $huh;
      $rundata{'no_completion_hook'} = 1;
      next;
      }
#   if ($rundata{'pn1'} =~ /\D/ 
#     or ($rundata{'players_in_game'} > 1 and $rundata{'pn2'} =~ /\D/)) {
#     # I think this part predates ProcessNames()
#     warn "Assertion failed, please contact John Chew.\nAborting";
#     next;
#     }
    next unless $this->CheckScores(\%rundata); # range-check scores
    $count++;
    $this->Confirm(\%rundata);
    $this->StoreScores(\%rundata);
    }
  continue {
    $this->Flush(\%rundata) if $rundata{'changed'} >= $save_interval;
    }
  $elapsed = TSH::Utility::Time() - $elapsed;
  $this->ReportStats($count, $elapsed) if $count;
  $this->Flush(\%rundata);
  }

sub ScoreBye ($$$) {
  my $this = shift;
  my $rundatap = shift;
  my $leftp = shift;

  my $tournament = $rundatap->{'tournament'};
  my $dp = $rundatap->{'dp'};
  my $round0 = $rundatap->{'round0'};
  # If there is more than one active unpaired opponent, we don't know who gets
  # forfeit wins and losses.
  my (@unpaired) = grep { $_->Active() && !$_->Opponent($round0) } $dp->Players();
  return unless @unpaired == 1;
  # If there is not exactly one unscored unpaired opponent, don't do anything
  my (@need_bye_indices) = grep { ! $leftp->[$_]->Opponent($round0) } 0..$#$leftp;
  return unless @need_bye_indices == 1;
  my $i = $need_bye_indices[0];
  my $p = $leftp->[$i];
  my $bye_spread = $rundatap->{'config'}->Value('bye_spread');
  $p->Score($round0, $bye_spread);
  splice(@$leftp, $i, 1);
  $tournament->TellUser('iscoredbye', $p->TaggedName(), $bye_spread);
  $dp->Dirty(1);
  $rundatap->{'changed'}++;
  }

=item $this->StoreScores($rundatap)

Store the entered scores, which are assumed by this point to be valid.

=cut

sub StoreScores ($$) {
  my $this = shift;
  my $rundatap = shift;

  my $round0 = $rundatap->{'round0'};
  my $dp = $rundatap->{'dp'};
  $rundatap->{'lastpn1'} = $rundatap->{'pn1'};
  $dp->Dirty(1);
  $rundatap->{'changed'}++;
  my $pp1 = $dp->Player($rundatap->{'pn1'});
  my $pp2 = $dp->Player($rundatap->{'pn2'});
  {
    my $now = time;
    $pp1->Time($now);
    $pp2->Time($now) if $rundatap->{'players_in_game'} > 1;
  }
  $pp1->Score($round0, $rundatap->{'ps1'});
  $dp->Pair($rundatap->{'pn1'}, 0, $round0) 
    if $rundatap->{'players_in_game'} == 1;
  $pp2->Score($round0, $rundatap->{'ps2'}) 
    if $rundatap->{'players_in_game'} > 1;
  if ($rundatap->{'entry_data'}{'has_tags'}) {
    $pp1->GameTag($round0, $rundatap->{'tag'});
    $pp2->GameTag($round0, $rundatap->{'tag'}) 
      if $rundatap->{'players_in_game'} > 1;
    }
  }

=back

=cut

=head1 BUGS

Should use a subprocessor rather than an event loop.

=cut

1;

