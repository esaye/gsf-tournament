#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::COMMentary;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility qw(Debug DebugOn Ordinal);
use TSH::Command::PRiZes;

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::COMMentary - implement the C<tsh> COMMentary command

=head1 SYNOPSIS

  my $command = new TSH::Command::COMMentary;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::COMMentary is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

sub FindPlayers ($$$$) {
  my $this = shift;
  my $tournament = shift;
  my $dp = shift;
  my $prize = shift;
  my (@players);
  if ($prize->{'memberfile'}) {
    (@players) = $this->LoadPlayersFromFile($tournament, $dp, $prize);
    }
  elsif ($prize->{'members'}) {
    if ($dp) {
      (@players) = grep { defined $_ } 
	map { $dp->Player($_) } @{eval $prize->{'members'}};
      }
    else {
      (@players) = $this->LoadPlayersFromList($tournament, $prize);
      }
    }
  elsif ($dp) {
    @players = $dp->Players();
    }
  else {
    for my $dp1 ($tournament->Divisions()) {
      push(@players, $dp1->Players());
      }
    }
  if (my $class = $prize->{'class'}) {
    my $had_members = scalar(@players);
    @players = grep { ($_->Class()||'noclass') eq $class} @players;
    if ($had_members and !@players) {
      $tournament->TellUser('eclassemp', $dp->Name(), $class);
      }
    }
#     die "@$members" if ref($prize->{'members'}) eq 'ARRAY';
  return @players;
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
Use this command to generate commentary suitable for an event website.
EOF
  $this->{'names'} = [qw(comm commentary)];
  $this->{'argtypes'} = [qw(Round Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub CreateFile ($$$$) {
  my $this = shift;
  my $directory = shift;
  my $r1 = shift;
  my $dp = shift;
  my $dname = $dp->Name();

  $r1 += 0;
  mkdir File::Spec->join($directory, $r1); # just in case
  return TSH::Utility::OpenFile('>', $directory, $r1, "tshcomm-$dname.txt");
  }

sub RandomString ($@) {
  my $this = shift;
  return $_[int rand scalar @_];
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $r1 = shift;
  my $dp = shift;
  my $config = $tournament->Config();

# my $style = $config->Value('commentary_style');
  my $directory = $config->Value('commentary_directory');
  unless ($directory) {
    $tournament->TellUser('ecfgreq', 'commentary_directory');
    return 0;
    }

  my $fh = $this->CreateFile($directory, $r1, $dp);
  if (!$fh) {
    $tournament->TellUser('ecfgdnf', $!);
    return 0;
    }
  if (1 ==$tournament->CountDivisions()) {
    print $fh "<h2>Round $r1 Auto-Commentary</h2>\n\n";
    print $fh $this->RenderCommentary($dp, $r1);
    }
  else { 
    my $dname = $dp->Name();
    print $fh "<h2>Division $dname Round $r1 Auto-Commentary</h2>\n\n";
    print $fh $this->RenderCommentary($dp, $r1);
    print $fh "\n";
    }
  $tournament->TellUser('icommented');
  close $fh;
  return 0;
  }

sub RenderCommentary ($$$) {
  my $this = shift;
  my $dp = shift;
  my $r1 = shift;

  my (@classes) = $dp->ClassList();
  my $s = '';
  $s .= $this->RenderLeaders($dp, $r1);
  if (@classes > 1) {
    for my $class (@classes) {
      next if $class eq 'A' or $class eq '1';
      $s .= $this->RenderLeaders($dp, $r1, $class);
      }
    }
  $s .= $this->RenderExtremeGames($dp, $r1);
  }

sub RenderExtremeGames ($$$) {
  my $this = shift;
  my $dp = shift;
  my $r1 = shift;
  my $r0 = $r1 - 1;

  my $s = '';
  my (@players) = $dp->Players();

  # TODO: need to substantially generalize this 
  my $compare = $TSH::Command::PRiZes::gPrizeData{'highwin'}{'compare'};
  my $filter = $TSH::Command::PRiZes::gPrizeData{'highwin'}{'filter'};
  my $entriesp = [sort $compare grep { &$filter($_, {'first' => $r1, 'last' => $r1}) } @players];
  if (@$entriesp) { my $nhw = 1; my $s0 = $entriesp->[0]->Score($r0);
    if (@$entriesp > 1) { for (; $entriesp->[$nhw]->Score($r0) == $s0; $nhw++) { } }
    $s .= ($nhw == 1 ? "High Win: " : "High Wins: ") . join('; ', map { 
      $this->RenderPlayer($_) . ' ' . $_->Score($r0) . '-' . $_->OpponentScore($r0) . " vs. " . $this->RenderPlayer($_->Opponent($r0)); } @$entriesp[0..$nhw-1]) . ".\n";
  }

  if (@$entriesp) { my $nlw = 1; my $s0 = $entriesp->[-1]->Score($r0);
    if (@$entriesp > 1) { for (; $entriesp->[-1-$nlw]->Score($r0) == $s0; $nlw++) { } }
    $s .= ($nlw == 1 ? "Low Win: " : "Low Wins: ") . join('; ', map { $this->RenderPlayer($_) . ' ' . $_->Score($r0) . '-' . $_->OpponentScore($r0) . " vs. " . $this->RenderPlayer($_->Opponent($r0)); } @$entriesp[-$nlw..-1]) . ".\n";
  }

  $compare = $TSH::Command::PRiZes::gPrizeData{'highloss'}{'compare'};
  $filter = $TSH::Command::PRiZes::gPrizeData{'highloss'}{'filter'};
  $entriesp = [sort $compare grep { &$filter($_, {'first' => $r1, 'last' => $r1}) } @players];
  if (@$entriesp) { my $nhw = 1; my $s0 = $entriesp->[0]->Score($r0);
    if (@$entriesp > 1) { for (; $entriesp->[$nhw] && $entriesp->[$nhw]->Score($r0) == $s0; $nhw++) { } }
    $s .= ($nhw == 1 ? "High Loss: " : "High Losses: ") . join('; ', map { 
      $this->RenderPlayer($_) . ' ' . $_->Score($r0) . '-' . $_->OpponentScore($r0) . " vs. " . $this->RenderPlayer($_->Opponent($r0)); } @$entriesp[0..$nhw-1]) . ".\n";
  }

  if (@$entriesp) { my $nll = 1; my $s0 = $entriesp->[-1]->Score($r0);
    if (@$entriesp > 1) { for (; $entriesp->[-1-$nll] && $entriesp->[-1-$nll]->Score($r0) == $s0; $nll++) { } }
    $s .= ($nll == 1 ? "Low Loss: " : "Low Losses: ") . join('; ', map { $this->RenderPlayer($_) . ' ' . $_->Score($r0) . '-' . $_->OpponentScore($r0) . " vs. " . $this->RenderPlayer($_->Opponent($r0)); } @$entriesp[-$nll..-1]) . ".\n";
  }
  }

sub RenderLeaders ($$$;$) {
  my $this = shift;
  my $dp = shift;
  my $r1 = shift;
  my $r0 = $r1 - 1;
  my $class = shift;

  my $s = '';
  my (@players) = TSH::Player::SortByStanding($r0, grep { $_->Active() } $dp->Players());
  if (defined $class) {
    (@players) = grep { ($_->Class() || '') =~ /\b$class\b/ } @players;
    $s .= "In Class $class: ";
    }

  my $comparator = TSH::Player::MakeStandingComparator($r0, $dp);
  my $nplayers = scalar(@players);
  my $np_limit = int($nplayers/2);
  $np_limit = 10 if 10 < $np_limit;
  my $rank = 1;
  my $win_group_number = 0;
  my $last_wins_behind = -1;
  my $last_spread;

  $dp->ComputeRanks($r0) if $r1 >= 1;
  $dp->ComputeRanks($r0-1) if $r1 >= 2;
  my $max_r0 = $dp->MaxRound0();
  my $at_end = ((defined $max_r0) and ($max_r0 == $r0));

  TSH::Utility::DoRanked(
    # data list
    \@players, 
    # comparator function
    $comparator,
    # selector
    sub { $_[0]->RoundWins($r0); },
    # actor
    sub { 
      my $p = shift;
      my $wins_behind = shift;
      $win_group_number++ if $last_wins_behind != $wins_behind;
      return if $rank > $np_limit or $win_group_number > 3;
      my $this_spread = $p->RoundSpread($r0);
      my $this_rank = $p->RoundRank($r0);
      my $prev_rank = $r1 >= 2 ? $p->RoundRank($r0-1) : 0;
      if ($rank == 1) {
	$last_spread = $p->RoundSpread($r0);
	my $run = $this->CountRankStreak($p, $r0);
	my $losses = $p->RoundLosses($r0);
	my $wins = $p->RoundWins($r0);
	if ($at_end) {
	  my $event = $this->RandomString('competition','event','tourney','tournament');
	  my $verb = "ends the $event in the lead";
	  if (!defined $class) {
	    $verb = $prev_rank 
	      ? $prev_rank > 1 
		? $this->RandomString('takes','seizes','claims','captures','climbs into').' '.
		  $this->RandomString('the lead', 'first place') .' '.
		  $this->RandomString('in the last round', 'in the end', 'in the very end')
		: $this->RandomString('remains in', 'stays in', 'is still in', 'holds onto') .' '.
		  $this->RandomString('the lead', 'first place') .
		  ($run > 2 ? " for the ".(TSH::Utility::Ordinal $run)." consecutive round" : '') .' '.
		  $this->RandomString('to', 'through', 'through to') .' '.
		  $this->RandomString('the last round', 'the end', 'the very end')
	      : $this->RandomString('takes', 'seizes', 'claims').' '.
		  $this->RandomString('the lead', 'first place');
	    }
	  $s .= $this->RenderPlayer($p) 
	    . " $verb"
	    . ($losses < 1 and $wins > 2 ? ', ' . $this->RandomString('undefeated', 'still undefeated', 'remaining undefeated') : '')
	    . ', ' . $p->RoundWins($r0)
	    . "-$losses" . sprintf(" %+d", $this_spread) . 
	    $this->RenderStreak($p, $r0) . 
	    ".\n";
	  }
	else {
	  my $verb = 'is in';
	  if (!defined $class) {
	    $verb = $prev_rank 
	      ? $prev_rank > 1 
		? $this->RandomString('takes','seizes','claims','captures','climbs into') 
		: $this->RandomString('remains in', 'stays in', 'is still in', 'holds onto') 
	      : $this->RandomString('takes', 'seizes', 'claims')
	    }
	  $s .= $this->RenderPlayer($p) 
	    . " $verb the lead"
	    . ($run > 2 ? " for the ".(TSH::Utility::Ordinal $run)." consecutive round" : '')
	    . ($losses < 1 and $wins > 2 ? ', ' . $this->RandomString('undefeated', 'still undefeated', 'remaining undefeated') : '')
	    . ', ' . $p->RoundWins($r0)
	    . "-$losses" . sprintf(" %+d", $this_spread) . 
	    $this->RenderStreak($p, $r0) . 
	    ".\n";
	  }
	}
      elsif ($win_group_number == 0) {
	if ($this_spread == $last_spread) {
	  $s .= $this->RenderPlayer($p) 
	    . (((!defined $class) && $prev_rank && $prev_rank > 1) ? ' takes a shared' : ' is exactly tied for the')
	    . ' lead'
	    . $this->RenderStreak($p, $r0) . ".\n";
	  }
	else { # same number of wins as leader, but trailing on spread
	  $s .= $this->RenderPlayer($p) . sprintf(" is %d spread points behind at %+d%s%s.\n",
	    $last_spread - $this_spread, $this_spread, 
	    $this->RenderStreak($p, $r0),
	    $this->RenderRankChange($p, $prev_rank, $this_rank, $r0),
	    );
	  }
        }
      elsif ($last_wins_behind != $wins_behind) {
	my $games_behind = $players[0]->RoundWins($r0) - $p->RoundWins($r0);
	$s .= $this->RenderPlayer($p) . sprintf(" is %g game%s behind %sat %g-%g %+d%s%s.\n",
	  $games_behind, 
	  $games_behind == 1 ? '' : 's',
	  $win_group_number == 2 ? '' : 'the leader ',
	  $p->RoundWins($r0),
	  $p->RoundLosses($r0),
	  $this_spread,
	  $this->RenderStreak($p, $r0),
	  $this->RenderRankChange($p, $prev_rank, $this_rank, $r0),
	  );
	}
      else {
	$s .= $this->RenderPlayer($p) . sprintf(" is %+d%s%s.\n",
	  $this_spread,
	  $this->RenderStreak($p, $r0),
	  $this->RenderRankChange($p, $prev_rank, $this_rank, $r0),
	  );
	}
      $rank++;
      $last_wins_behind = $wins_behind;
      }
    );

  $s .= "\n";
  return $s;
  }

sub RenderPlayer ($$) {
  my $this = shift;
  my $p = shift;
  return '[' . $p->PrettyName({'surname_last' => 1}) . ']';
  }

sub RenderRankChange ($$$$$) {
  my $this = shift;
  my $p = shift;
  my $oldr = shift;
  my $newr = shift;
  my $newr0 = shift;

  if ($newr0 == 0) { return ''; }
  if ($oldr < $newr) {
    if ($newr-$oldr > 9) {
      return (", #$newr " . $this->RandomString('plummeting from', 'dropping like a stone from', 'whizzing down from', 'collapsing from', 'tumbling from') . " #$oldr");
      }
    if ($newr-$oldr > 4) {
      return (", #$newr " . $this->RandomString('tumbling from', 'jumping down from', 'dropping from', 'down from') . " #$oldr");
      }
    return (", #$newr " . $this->RandomString('down from','dropping from','falling from','slipping from','sliding from') . " #$oldr");
    }
  elsif ($oldr > $newr) {
    if ($oldr-$newr > 9) {
      return (", #$newr " . $this->RandomString('soaring from', 'hurtling up from', 'zooming up from', 'rocketing up from', 'whizzing up from', 'leapfrogging up from') . " #$oldr");
      }
    if ($oldr-$newr > 4) {
      return (", #$newr " . $this->RandomString('leaping up from', 'jumping up from', 'climbing from', 'rising from', 'up from') . " #$oldr");
      }
    return (", #$newr " . $this->RandomString('up from','rising from','climbing from', 'improving from') . " #$oldr");
    }

  my $run = $this->CountRankStreak($p, $newr0);
  return (", " . $this->RandomString('unchanged at', 'steady at', 'remaining steady at', 'remaining unchanged at', 'still at', 'hovering at') . " #$oldr" . ($run > 2 ? " for $run rounds" : ''));
  }

sub CountRankStreak ($$$) {
  my $this = shift;
  my $p = shift;
  my $startr0 = shift;
  my $oldr = $p->RoundRank($startr0, undef, 1);

  my $run = 1;
  for (my $r0 = $startr0-1; $r0>=0; $r0--) {
    my $rank = $p->RoundRank($r0, undef, 1);
    if (!$rank) {
      $p->Division()->ComputeRanks($r0);
      $rank = $p->RoundRank($r0, undef, 1);
      }
#   warn $p->Name() . " $r0+1 " . $rank;
    if ($rank == $oldr) { $run++; }
    else { last; }
    }
  return $run;
  }

sub RenderStreak ($$) {
  my $this = shift;
  my $p = shift;
  my $r0 = shift;
  
  my ($type, $streak) = $p->CountStreak($r0);
  return '' if $streak < 3;

  my $n = $streak =~ /^8|^18(?:..|(?:...)*)$/ ? 'n' : '';
  return ", on a$n $streak-game " . ('tie', 'winning', 'losing')[$type] . " streak";
  }

=back

=cut

=head1 BUGS

None known yet.

=cut

1;
