#!/usr/bin/perl

# Copyright (C) 2005-2017 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::ShowPairings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn OpenFile Ordinal);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ShowPairings - implement the C<tsh> ShowPairings command

=head1 SYNOPSIS

  my $command = new TSH::Command::ShowPairings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ShowPairings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub FormatRepeats ($$$$$);
sub initialise ($@);
sub new ($);
sub RenderBye ($$$);
sub RenderPair ($$$$;$);
sub Run ($$@);
sub ShowAlphaPairings ($$$);
sub ShowRankedPairings ($$$);
sub ShowTeamPairings ($$$);

=item $s = FormatRepeats($config, $p, $opp, $r0, $html);

Return a string describing the number of times two players have played each other.

=cut

sub FormatRepeats ($$$$$) {
  my $config = shift;
  my $p = shift;
  my $opp = shift;
  my $r0 = shift;
  my $html = shift;
  my $repeat = $p->CountRoundRepeats($opp, $r0);
  my $s = $repeat <= 1 ? '' 
    : $repeat == 2 ? $config->Terminology('repeat') 
    : $config->Terminology('npeat', $repeat);
  $s = "<span class=repeat>$s</span>" if $html && $s;
  $s = " $s" if $s;
  return $s;
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($@) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to display the pairings for the specified round
and division.
EOF
  $this->{'names'} = [qw(sp showpairings)];
  $this->{'argtypes'} = [qw(Round Division)];

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub RenderBye ($$$) {
  my $this = shift;
  my $p = shift;
  my $round = shift;
  my $style = shift;
  my $round0 = $round - 1;
  my $dp = $p->Division();
  my $config = $dp->Tournament()->Config();
# my $oppid = $p->OpponentID($round0, 'undef for unpaired'); # what was this about?
  my $oppid = $p->OpponentID($round0);
  warn "Assertion failed" if $oppid;
  my $type = (defined $oppid) ? 'Bye' : 'Unpaired';
  my $bye_term = $config->Terminology($type);
  my $seats = $config->Value('seats');

  my @text_cells;
  my @html_cells;

  my $noboards = $config->Value('no_boards');
  if ($dp->HasTables()) {
    push(@text_cells, '');
    push(@html_cells, '&nbsp;');
    if ((defined $noboards) && $noboards == 0) {
      push(@text_cells, '');
      push(@html_cells, '&nbsp;');
      }
    }
  elsif (!$noboards) {
    push(@text_cells, '');
    push(@html_cells, '&nbsp;');
    }
  if ($style eq 'combined') {
    push(@text_cells, $p->TaggedName({'localise'=>1}) . ": $bye_term" . '.');
    push(@html_cells, $p->TaggedHTMLName({'localise'=>1,'style'=>'print'}) . ": <span class=\L$type>$bye_term</span>."); # might contain non-console characters
    }
  elsif ($style eq 'separate') {
    push(@html_cells, '') if $seats;
    push(@text_cells, $p->TaggedName({'localise'=>1}));
    push(@html_cells, $p->TaggedHTMLName({'localise'=>1,'style'=>'print'})); # might contain non-console characters
    if ($config->Value('player_photos')) {
      push(@text_cells, '&nbsp;');
      push(@html_cells, '&nbsp;');
      }
    push(@text_cells, $bye_term);
    push(@html_cells, '&nbsp;') if $seats;
    push(@html_cells, "<span class=\L$type>$bye_term</span>");
    }
  else { warn "assertion failed"; }

  return (\@text_cells, \@html_cells);
  }

sub RenderPair ($$$$;$) {
  my $this = shift;
  my $p1 = shift;
  my $round = shift;
  my $style = shift;
  my $headlessp = shift;
  my $round0 = $round - 1;
  my $p2 = $p1->Opponent($round0);
  my $p2id = $p1->OpponentID($round0);
  my $dp = $p1->Division();
  my $config = $dp->Tournament()->Config();
  my $thai_team_hack = $config->Value('thai_team_hack');
  my $track_firsts = $config->Value('track_firsts');
  my @text_cells;
  my @html_cells;
  my $board = $p1->Board($round0);
  my $seats = $config->Value('seats');
  if (!$p2id) {
    return $this->RenderBye($p1, $round, $style);
    }
  # TODO: find a way to make this a call to TSH::Player::RenderLocation
  my $noboards = $config->Value('no_boards');
  if ($dp->HasTables()) {
    my $table = $dp->BoardTable($board);
    push(@text_cells, sprintf($config::table_format, $table) . ' ');
    push(@html_cells, $table);
    if ((defined $noboards) && $noboards == 0) {
      push(@text_cells, "$board ");
      push(@html_cells, $board);
      }
    }
  elsif (!$noboards) {
    push(@text_cells, "$board ");
    push(@html_cells, $board);
    }
  if ($style eq 'combined') {
    my $vs = $dp->FormatPairing($round0, $p1->ID(), {'localise'=>1});
    if (!$vs) { warn "assertion failed"; }
    my $vshtml = $dp->FormatPairing($round0, $p1->ID(), {'localise'=>1,'namestyle'=>'print','html' => 1});
    if (!$vshtml) { warn "assertion failed"; }
    if ($track_firsts) {
      $vshtml =~ s!^(.*)(\*(?:.*?)\*)(.*)$!<span class=p1>$1</span><span class=starts>$2<\/span><span class=p2>$3</span>!;
      }
#   else { $vshtml =~ s/\s*\*(?:starts|draws)\*\s*/ /; $vs =~ s/\s*\*(?:starts|draws)\*\s*/ /; }
    push(@text_cells, $vs . (FormatRepeats $config, $p1, $p2, $round0, 0) . '.');
    push(@html_cells, $vshtml . (FormatRepeats $config, $p1, $p2, $round0, 1));
    }
  elsif ($style eq 'separate') {
    my (@seats);
    my ($p1_12, $p2_12) = $dp->FormatPairing($round0, $p1->ID(), 
      {'style' => 'balanced', 'localise' => 1});
    push(@seats, $p1->Seat($round0)) if $seats;
    my $team = $thai_team_hack ? ' <' . substr($p1->Team(), 0, 8) . '>' : '';
    push(@text_cells, @seats, $p1->TaggedName({'localise'=>1}) . $p1_12);
    push(@html_cells, @seats, $p1->TaggedHTMLName({'localise'=>1, 'style' => 'print'}) . $team . $p1_12);
    if ($config->Value('player_photos')) {
      if (my $url = $p2->PhotoURL()) {
	my $aspect = $config->Value('player_photo_aspect_ratio') || 1;
	my $width = int(0.5+$aspect * 36);
	push(@text_cells, '');
	push(@html_cells, qq(<img align=left height=36 width=$width src="$url">));
	if ($url =~ /unknown_player/) {
	  push(@$headlessp, $p2);
	  }
	}
      else {
	push(@$headlessp, $p2);
	push(@text_cells, '');
	push(@html_cells, '&nbsp;');
	}
      }
    @seats = ();
    push(@seats, $p2->Seat($round0)) if $seats;
    $team = $thai_team_hack ? ' <' . substr($p2->Team(), 0, 8) . '>' : '';
    push(@text_cells, @seats, $p2->TaggedName({'localise'=>1}) . $p2_12 .
      (FormatRepeats $config, $p1, $p2, $round0, 0));
    push(@html_cells, @seats, '<span class=opp>'
      . $p2->TaggedHTMLName({'localise'=>1, 'style' => 'print'}) 
      . $team . $p2_12 .
      (FormatRepeats $config, $p1, $p2, $round0, 1)
      . '</span>');
    }
  else { warn "assertion failed"; }
  return (\@text_cells, \@html_cells);
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($round, $dp) = @_;
  my $config = $tournament->Config();

# my $opt_p = 0;
# if (@$argvp && $argvp->[0] eq '-p') { shift @$argvp; $opt_p = 1; }
  my $round0 = $round-1;

  my $changed = $dp->CheckAutoPair($this->Processor(), $round);
  if ($round0 > $dp->LastPairedRound0()) {
    $tournament->TellUser('enopryet', $dp->Name(), $round);
    return;
    }
# # a kludge formerly used with make-rr.pl
# if ($opt_p) {
#   print '[';
#   print join(',', map { $_->{'pairings'}[$round0]-1 } @$datap[1..$#$datap]);
#   print "]\n";
#   return 0;
#   }
  {
    my $sr0 = $dp->LeastScores() - 1;
    $sr0 = $round - 1 if $sr0 > $round - 1;
    $sr0 = 0 if $sr0 < 0;
    # shouldn't this be MostScores() - 1?  does it matter? see SMP.pm too.
    $sr0 = $dp->MostScores() if $sr0 > $dp->MostScores()-1;
    # if seats are used, do not auto-assign boards except at the start of a session
    my $no_compute_boards = 
      $config->Value('seats') 
	&& $config->Value('session_breaks')
	&& ($config->FindSession($round-1))[0] != $round-1; 
#   printf STDERR "%s %s %s ncb=%d\n", $round, ($config->FindSession($round-1))[0], $round-1, $no_compute_boards; 
    # DO NOT uncomment the following line.  Bad Things happen if a
    # player does not have a board (ranked pairings fail), even if
    # we are not configured to show them.
#   $no_compute_boards = 1 if $config->Value('no_boards') and not $dp->HasTables();
    $dp->ComputeBoards($sr0, $round0) unless $no_compute_boards;
    if ($config->Value('no_pairings_output')) { return; }
    $this->{'sp_ranked'} = [TSH::Player::SortByStanding $sr0, $dp->Players()];
  }

  $this->ShowTallySlips($dp, $round);
  $this->ShowTeamPairings($tournament, $round) if $config->Value('show_teams') or $config->Value('show_team_pairings') or $config->Value('squads');
  $this->ShowRankedPairings($dp, $round);
  $this->ShowAlphaPairings($dp, $round);
  if (my $processor = $this->Processor()) { 
    $processor->Flush(); # in case table numbers were changed
    if ($changed) {
      if (my $cmds = $config->Value('hook_autopair')) {
	$processor->RunHook('hook_autopair', $cmds,
	  { 'nohistory' => 1,
	    'noconsole' => $config->Value('quiet_hooks') },
	  {'r' => $round, 'd' => $dp->Name(), 'dp' => $dp->Name() },
	  );
	}
      }
    }
  }

=item ($logp, $headingsp) = $cmd->SetupOutput($order, $tournament, $dp, $round, $ncolumns);

Set up a TSH::Log object to receive the output of this command.

=cut

sub SetupOutput ($$$$$) {
  my $this = shift;
  my $order = shift;
  my $tournament = shift;
  my $dp = shift;
  my $round = shift;
  my $ncolumns = shift;

  my $config = $tournament->Config();
  my $noboards = $config->Value('no_boards');
  my $seats = $config->Value('seats');
  my $c_numeric = $config->Value('numeric_pairing_display');
  # see also default code below
  my $c_no_run_together = $config->Value('columnar_pairings');

  my $filename;
  my %options;
  if ($order eq 'alpha') {
    $filename = 'alpha-pairings';
    $options{'titlename'} = $config->Terminology($c_numeric ? 'Numeric_Pairings' : 'Alphabetic_Pairings');
    $options{'noconsole'} = 1;
    }
  elsif ($order eq 'team') {
    $filename = 'team-pairings';
    $options{'titlename'} = $config->Terminology($c_numeric ? 'Numeric_Team_Pairings' : 'Alphabetic_Team_Pairings');
    $options{'noconsole'} = 1;
    }
  elsif ($order eq 'ranked') {
    $filename = 'pairings';
    $options{'titlename'} = $config->Terminology('Ranked_Pairings');
    if ($config->Value('no_ranked_pairings')) { # still need to display them on the console
      $options{'notext'} = 1;
      $options{'nohtml'} = 1;
      }
    $options{'noconsole'} = 1 if $this->{'noconsole'}; # unless noconsole
    }
  else { warn 'assertion failed'; }

  # if numeric, it's usually because the players are in a script
  # (Thai) that is hard to alphabetize, so we would rather have
  # them in two separate columns to make it easier to visually scan
  if (!defined $c_no_run_together) {
    $c_no_run_together = ($order ne 'ranked') || $c_numeric;
    }

  $options{'refresh'} = $config->Value('pairings_refresh');

  my $logp = new TSH::Log($tournament, $dp, $filename, $round, \%options);
  my (@headings);
  my (@classes);
  my $left = 1; # is at left margin
  if ($dp ? $dp->HasTables() : ($tournament->Divisions)[0]->HasTables()) {
    push(@headings, $config->Value('table_title') 
      || $config->Terminology('Table'));
    push(@classes, 'table left');
    if ((defined $noboards) && $noboards == 0) {
      push(@headings, $config->Terminology('Board'));
      push(@classes, 'board');
      $left = 0;
      }
    $left = 0;
    }
  elsif (!$noboards) {
    push(@headings, $config->Terminology('Board'));
    push(@classes, 'board left');
    $left = 0;
    }
  if (!$c_no_run_together) {
    push(@headings, $config->Terminology('Who_Plays_Whom'));
    push(@classes, 'name');
    }
  else { # not run together
    if ($seats) {
      push(@headings, $config->Terminology('Seat'));
      push(@classes, 'seat left');
      $left = 0;
      }
    push(@headings, $config->Terminology('Player'));
    push(@classes, $left ? 'name left' : 'name');
    if ($seats) {
      push(@headings, $config->Terminology('Seat'));
      push(@classes, 'seat left');
      $left = 0;
      }
    if ($config->Value('player_photos')) {
      push(@headings, '');
      push(@classes, 'oppphoto');
      }
    push(@headings, $config->Terminology('Opponent'));
    push(@classes, 'name right');
    }

  if ($ncolumns == 2) {
    push(@classes, @classes);
    push(@headings, @headings);
    $classes[@classes/2-1] =~ s/ right/ midright/;
    $classes[@classes/2] =~ s/ left/ midleft/;
    $logp->RowClass('top1 double');
    }
  $logp->ColumnClasses(\@classes);
  $logp->WriteTitle(\@headings, \@headings);
  $logp->RowClass('double') if $ncolumns == 2;
  return ($logp, \@headings);
  }

=item ShowAlphaPairings;

Create an HTML file listing pairings in alphabetical order by player name.

=cut

sub ShowAlphaPairings ($$$) {
  my $this = shift;
  my $dp = shift;
  my $round = shift;
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $hasphotos = $config->Value('player_photos');
  my $page_break = $config->Value('alpha_pair_page_break');
  my $first_page_break = $config->Value('alpha_pair_first_page_break') || $page_break;
  my $thai_team_hack = $config->Value('thai_team_hack');
  # if true, "alpha pairings" are actually "player number order pairings"
  my $c_numeric = $config->Value('numeric_pairing_display');
  my $c_columnar_pairings = $config->Value('columnar_pairings');
  my $pair_rendering_style = ($c_columnar_pairings or $c_numeric) ? 'separate' : 'combined';

  my @html_entries;
  my @text_entries;
  my @headless;
  my $page_number = 1;

  for my $p ($c_numeric
      ? $dp->Players() 
      : TSH::Player::SortByName($dp->Players())) 
    {
    next unless $p->Active();
    my ($text_cellsp, $html_cellsp) = $this->RenderPair($p, $round, 'separate', \@headless);
    push(@text_entries, $text_cellsp);
    push(@html_entries, $html_cellsp);
    }
  $this->WriteHeadless($dp, $round, \@headless) if $hasphotos && @headless;
  my $ncolumns = (
    (!$hasphotos) 
    && ($first_page_break && @html_entries > $first_page_break) 
    && ! $config->Value('alpha_pair_single_column')
    ) ? 2 : 1;
  my ($logp, $headingsp) = $this->SetupOutput('alpha', $tournament, $dp, $round, $ncolumns);
  my $current_page_break = $first_page_break;
  my $even = 0;
  if ($ncolumns == 2) {
    push(@text_entries, ['']) if @text_entries % 2;
    push(@html_entries, ['']) if @html_entries % 2;
    my $half = @html_entries / 2;
    for my $i (0..$half-1) {
      $logp->ToggleRowParity($even);
      $this->WriteRowWithClasses($logp,
	[@{$text_entries[$i]}, @{$text_entries[$i+$half]}],
	[@{$html_entries[$i]}, @{$html_entries[$i+$half]}],
        );
      if ($current_page_break && ($i+1) % $current_page_break == 0 && $i != $half-1) {
	$current_page_break = $page_break;
	$even = 0;
        $logp->PageBreak();
#       $logp->RowClass('top1 double'); # 20180105
#	$logp->WriteTitle($headingsp, $headingsp); # 20180105
        }
      }
    }
  else {
    for my $i (0..$#html_entries) {
      $logp->ToggleRowParity($even);
      $this->WriteRowWithClasses($logp,
        $text_entries[$i], $html_entries[$i]);
      if ($current_page_break && ($i+1) % $current_page_break == 0 && $i != $#html_entries) {
	$current_page_break = $page_break;
	$even = 0;
        $logp->PageBreak();
#       $logp->RowClass('top1'); # 20180105
#	$logp->WriteTitle($headingsp, $headingsp);
        }
      }
    }
  $logp->Close();
  }

=item ShowRankedPairings;

Report on pairings in order by current rankings.

=cut

sub ShowRankedPairings ($$$) {
  my $this = shift;
  my $dp = shift;
  my $round = shift;
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $c_numeric = $config->Value('numeric_pairing_display');
  my $c_caption = $config->Value('pairing_caption_pipe');
  my $c_columnar_pairings = $config->Value('columnar_pairings');
  my $pair_rendering_style = ($c_columnar_pairings or $c_numeric) ? 'separate' : 'combined';

  my $round0 = $round - 1;
  my ($logp, $headingsp) = $this->SetupOutput('ranked', $tournament, $dp, $round, 1);

  my @boards;
  my %done;
  my $pipe;
  my $sortedp = $this->{'sp_ranked'};
  # scan the list of players, display byes right away, queue unpaired
  # players for display after this loop
  my @unpaired;
  my $even = 0;
  for my $p (@$sortedp) {
    next unless $p->Active();
    my $oppid = $p->OpponentID($round0);
    my $pid = $p->ID();
    if (!defined $oppid) {
      push(@unpaired, $p);
      }
    elsif ($oppid == 0) {
      $logp->ToggleRowParity($even);
      $this->WriteRowWithClasses($logp,
        $this->RenderBye($p, $round, $pair_rendering_style));
      }
    elsif (!$done{$pid}++) {
      my $opp = $dp->Player($oppid);
      if ($pid != $opp->OpponentID($round0)) {
	my $ooid = $opp->OpponentID($round0);
	my $oppoppname = $ooid ? $opp->Opponent($round0)->Name() : 'bye';
	$tournament->TellUser('ebadpair', 
	  $pid, $p->PrettyName(),
	  $oppid, $opp->PrettyName(),
	  $ooid, $oppoppname);
	}
      elsif ($pid == $oppid) {
	$tournament->TellUser('eselpair', $pid, $p->PrettyName());
	}
      else {
	$done{$oppid}++;
	my $ob = $opp->Board($round0) || 0;
	my $pb = $p->Board($round0) || 0;
	if ($ob != $pb) {
	  $tournament->TellUser('eboarddiff', $p->PrettyName(), $opp->PrettyName());
	  }
	$boards[$pb] = [$p, $opp];
	}
      }
    } # for $p
  # display the queued up unpaired players
  for my $p (@unpaired) {
    $logp->ToggleRowParity($even);
    $this->WriteRowWithClasses($logp,
      $this->RenderBye($p, $round, $pair_rendering_style));
    }
  # display who's at each board
  open $pipe, "|$c_caption" if $c_caption;
  for my $board1 (1..$#boards) {
    my $boardp = $boards[$board1];
    # a board might be empty if a pairing was deactivated after
    # boards were assigned, or if all seating is reserved
    next unless $boardp; 
    my ($p1, $p2) = @$boardp;
    if ($p1->Board($round0)) {
      $p2->Board($round0, $p1->Board($round0)); # just in case
      }
    else { # also just in case?!
      $p1->Board($round0, $board1);
      $p2->Board($round0, $board1);
      }
    if ($c_numeric) {
      if ($p2->First($round0) == 1) { 
	($p1, $p2) = ($p2, $p1);
	}
      }
    $logp->ToggleRowParity($even);
#   warn join("\n***", @{$this->RenderPair($p1, $round, $pair_rendering_style)});
    $this->WriteRowWithClasses($logp,
      $this->RenderPair($p1, $round,
      $c_numeric ? 'separate' : $pair_rendering_style));
    if ($pipe) {
      my $s = '[' . 
        $p1->PrettyName({'surname_last'=>1}) .
	'] vs. [' .
	$p2->PrettyName({'surname_last'=>1}) .
	'] at Board ' .
	$board1;
      $s =~ s/'/'"'"'/g;
      print $pipe "exiftool -Description='$s' -Caption-Abstract='$s'\n";
      }
    }
  close $pipe if $pipe;
  $logp->Close();
  }

sub ShowRankedSeparatePairings ($$$) {
  my $this = shift;
  my $dp = shift;
  my $round = shift;
  }

=item $cmd->ShowTeamPairings($tournament, $round1);

Create an HTML file listing pairings in alphabetical order by player name,
but grouped by team, typically for handing out to coaches at a school event.
For this reason, unlike the other pairing formats, this one combines divisions.

=cut

sub ShowTeamPairings ($$$) {
  my $this = shift;
  my $tournament = shift;
  my $round = shift;
  my $config = $tournament->Config();
  my $hasphotos = $config->Value('player_photos');
  my $page_break = $config->Value('team_pair_page_break');
  my $first_page_break = $config->Value('team_pair_first_page_break') || $page_break;
  my $thai_team_hack = $config->Value('thai_team_hack');
  # if true, "team pairings" are actually "player number order pairings"
  my $c_numeric = $config->Value('numeric_pairing_display');
  my $c_always_break = $config->Value('team_pair_always_break');

  my @html_entries;
  my @text_entries;
  my @headless;
  my $page_number = 1;

  my (@teams);
  my (%team_sizes);
  my (@players);
  if ($c_numeric) {
    for my $dp ($tournament->Divisions()) {
      push(@players, $dp->Players());
      }
    }
  else {
    for my $dp ($tournament->Divisions()) {
      push(@players, TSH::Player::SortByName($dp->Players()));
      }
    }
  for my $p (sort { $a->Team() cmp $b->Team() } @players) {
    my ($text_cellsp, $html_cellsp) = $this->RenderPair($p, $round, 'separate', \@headless);
    push(@text_entries, $text_cellsp);
    push(@html_entries, $html_cellsp);
    my $team = $p->Team();
    push(@teams, $team);
    $team_sizes{$team}++;
    }
  my $ncolumns = (
    (!$hasphotos) 
    && ($first_page_break && @html_entries > $first_page_break) 
    && ! $config->Value('team_pair_single_column')
    ) ? 2 : 1;
  my ($logp, $headingsp) = $this->SetupOutput('team', $tournament, undef, $round, $ncolumns);
  my $current_page_break = $first_page_break;
  my $even = 0;
  if ($ncolumns == 2) {
    push(@text_entries, ['']) if @text_entries % 2;
    push(@html_entries, ['']) if @html_entries % 2;
    my $half = @html_entries / 2;
    for my $i (0..$half-1) {
      $logp->ToggleRowParity($even);
      $this->WriteRowWithClasses($logp,
	[@{$text_entries[$i]}, @{$text_entries[$i+$half]}],
	[@{$html_entries[$i]}, @{$html_entries[$i+$half]}],
        );
      if ($current_page_break && ($i+1) % $current_page_break == 0 && $i != $half-1) {
	$current_page_break = $page_break;
	$even = 0;
        $logp->PageBreak();
#       $logp->RowClass('top1 double'); # 20180105
#	$logp->WriteTitle($headingsp, $headingsp); # 20180105
        }
      }
    }
  else {
    my $last_team = $teams[0];
    my $page_row = 0;
    for my $i (0..$#html_entries) {
      $page_row++;
      my $team = $teams[$i];
      $team_sizes{$team}--;
      if ($team ne $last_team) {
	$last_team = $team;
	if (($current_page_break # page breaks in effect
	  and $page_row > 1 # not at top of page
	  and $team_sizes{$team} + 1 + $page_row > $current_page_break
          ) or $c_always_break
          ) { # team won't fit
	  # start a new page
	  $current_page_break = $page_break;
	  $logp->PageBreak();
	  $page_row = 1;
	  }
	$even = 0;
	$logp->RowClass('top1');
	$logp->WriteTitle($headingsp, $headingsp, {'inline'=>1});
	}
      elsif ($current_page_break # page breaks in effect
	and $page_row > $current_page_break) { # page is overfull
        # start a new page
	$current_page_break = $page_break;
	$even = 0;
        $logp->PageBreak();
        $logp->RowClass('top1');
	$logp->WriteTitle($headingsp, $headingsp);
	$page_row = 1;
        }
      $logp->ToggleRowParity($even);
      $this->WriteRowWithClasses($logp,
        $text_entries[$i], $html_entries[$i]);
      }
    }
  $logp->Close();
  }

=item ShowTallySlips

Generate prefilled tally slips for this round.

=cut

sub ShowTallySlips ($$$) {
  my $this = shift;
  my $dp = shift;
  my $round = shift;
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $noboards = $config->Value('no_boards');
  my $sum_before_spread = $config->Value('sum_before_spread');
  my $track_firsts = $config->Value('track_firsts');
  my $page_break = $config->Value('tally_slips_page_break') || 9;
  my $blanks = $config->Value('tally_slips_blanks');
  my $challenges = $config->Value('tally_slips_challenges');
  my $no_spread = $config->Value('tally_slips_no_spread');
  my $termsp = $config->Terminology({map { $_ => [] } qw(1st 2nd Blanks_colon Board Division Initials Round Score Spread Table Words_challenged_colon)});

# die join(',',%$termsp);
  my $round0 = $round - 1;
  my $has_tables = $dp->HasTables();
  my %options;
  $options{'noconsole'} = 1;
  $options{'notitle'} = 1;
  $options{'notop'} = 1;
  my $logp = new TSH::Log($tournament, $dp, 'tally-slips', $round, \%options);
  $logp->Write('', '<tr><td>');

  my %done;
  my $sortedp = [sort { ($a->Board($round0)||0) <=> ($b->Board($round0)||0) } @{$this->{'sp_ranked'}}];
  my @head;
  push(@head, '<span class=division>' . $termsp->{'Division'} . ' ' . $dp->Name() . '</span>')
    if $tournament->CountDivisions() > 1;
  push(@head, '<span class=round>' . $termsp->{'Round'} . ' ' . $round . '</span>');
  my $i = 0;
  for my $p (@$sortedp) {
    next unless $p->Active();
    my $oppid = $p->OpponentID($round0);
    my $pid = $p->ID();
    my $opp = $p->Opponent($round0);
    next unless defined $oppid;
    next if $done{$pid}++;
    $done{$oppid}++;
    if ($track_firsts && $opp && $p->First($round0) == 2) {
      ($pid, $oppid) = ($oppid, $pid);
      ($p, $opp) = ($opp, $p);
      }
    my $board = $p->Board($round0);
    my $table = '';
    if ($board) {
      if ($has_tables) {
	$table = "<span class=table>$termsp->{'Table'} " . $dp->BoardTable($board) . '</span>';
	if ((defined $noboards) && $noboards == 0) {
	  $board = "<span class=board>$termsp->{'Board'} $board</span>";
	  }
	}
      $board = $noboards ? '' : "<span class=board>$termsp->{'Board'} $board</span>";
      }
    else { $board = ''; }
    if ($i) {
      if ($page_break && $i % $page_break == 0) { 
	$logp->PageBreak(); 
	}
      else 
        { $logp->Write('', '</table><hr>' . $logp->RenderOpenTable('')); }
      }
    $logp->Write('', <<EOF );
<tr class=row1><td class=ident colspan=2>@head $table $board</td>
<th class=score>$termsp->{'Score'}</th>
<th class=initials>$termsp->{'Initials'}</th>
<th class=skip colspan=3>&nbsp;</th>
EOF
    if ($opp) {
      $logp->Write('', <<EOF );
<th class=score>$termsp->{'Score'}</th>
<th class=initials>$termsp->{'Initials'}</th>
<th class=skip>&nbsp;</th>
EOF
      $logp->Write('', "<th class=spread>$termsp->{'Spread'}</th>\n") unless $no_spread;
      $logp->Write('', "</tr>\n");
      }
    else {
      $logp->Write('', <<EOF );
<th class=skip style="width:50%">&nbsp;</th>
</tr>
EOF
      }
    $logp->Write('', '<tr class=row2>');
    $logp->Write('', '<td class=p12>' . (($track_firsts && $p->First($round0) == 1) ? $termsp->{'1st'} : '&nbsp;') . '</td>');
    $logp->Write('', '<td class=player>' . $p->TaggedHTMLName({'localise'=>1, 'style' => 'print'}) 
      . '<br>'
      . TSH::Utility::FormatHTMLHalfInteger($p->RoundWins($round0-1)) 
        . '&ndash;' . TSH::Utility::FormatHTMLHalfInteger($p->RoundLosses($round0-1)) 
	. ($sum_before_spread ? ', ' . $p->RoundSum($round0-1) : '')
	. '&nbsp;' . TSH::Utility::FormatHTMLSignedInteger($p->RoundSpread($round0-1))
	. ($track_firsts
	  ? sprintf(" (%s:%d, %s:%d)",
	    $termsp->{'1st'}, $p->RoundFirsts($round0-1)||0,
	    $termsp->{'2nd'}, $p->RoundSeconds($round0-1)||0)
	  : ''
	  )
      . '</td>');
    $logp->Write('', '<td class=score>&nbsp;</td><td class=initials>&nbsp;</td><td class=skip>&nbsp;</td>');
    if ($opp) {
      $logp->Write('', '<td class=p12>' . (($track_firsts && $opp->First($round0) == 2) ? '2nd' : '&nbsp;') . '</td>');
      $logp->Write('', '<td class=player>' . $opp->TaggedHTMLName({'localise'=>1, 'style' => 'print'})
      . '<br>'
      . TSH::Utility::FormatHTMLHalfInteger($opp->RoundWins($round0-1)) 
        . '&ndash;' . TSH::Utility::FormatHTMLHalfInteger($opp->RoundLosses($round0-1)) 
	. ($sum_before_spread ? ', ' . $opp->RoundSum($round0-1) : '')
	. '&nbsp;' . TSH::Utility::FormatHTMLSignedInteger($opp->RoundSpread($round0-1))
	. ($track_firsts
	  ? sprintf(" (%s:%d, %s:%d)", 
	    $termsp->{'1st'}, $opp->RoundFirsts($round0-1)||0,
	    $termsp->{'2nd'}, $opp->RoundSeconds($round0-1)||0)
	  : ''
	  )
      . '</td>');
      $logp->Write('', '<td class=score>&nbsp;</td><td class=initials>&nbsp;</td>');
      $logp->Write('', '<td class=skip>&nbsp;</td><td class=spread>&nbsp;</td>') unless $no_spread;
      }
    $logp->Write('', '</tr>');
    if ($blanks) {
      my $alphabet = join(' ', 'A'..'Z');
      $logp->Write('', "<tr><td colspan=9><div class=blanks><span class=label>$termsp->{'Blanks_colon'} </span>".join('<span class=spacer>&nbsp;&nbsp;</span>',map { "<span class=alphabet$_>$alphabet</span>" } (1..2)).'</div></td></tr>');
      }
    if ($challenges) {
      $logp->Write('', "<tr class=challenges><td colspan=9>$termsp->{'Words_challenged_colon'}</td></tr>");
      }
    $i++;
    }
  $logp->Close();
  }

sub WriteHeadless ($$) {
  my $this = shift;
  my $dp = shift;
  my $round = shift;
  my $headlessp = shift;

  my $config = $dp->Tournament()->Config();
  my $noboards = $config->Value('no_boards');
  my $r0 = $round - 1;
  my $has_tables = $dp->HasTables();

  my $fn = $config->MakeRootPath($dp->Name() . '-headless.txt');
  if (my $fh = OpenFile('>:encoding(utf8)', $fn)) {
    if ($noboards) {
      print $fh map { $_->Name() 
        . ($_->Opponent($r0) ? " vs. " . $_->Opponent($r0)->Name() : '')
	. "\n" } 
	sort { $a->Name() cmp $b->Name() } @$headlessp;
      }
    elsif ($has_tables) {
      print $fh map { 
        $dp->BoardTable($_->Board($r0)) 
	. ' ' . $_->Name() 
        . ($_->Opponent($r0) ? " vs. " . $_->Opponent($r0)->Name() : '')
	. "\n" 
	} 
	sort { $a->Board($r0) cmp $b->Board($r0) } @$headlessp;
      }
    else {
      print $fh map {
        $_->Board($r0) 
	. ' ' 
	. $_->Name() 
        . ($_->Opponent($r0) ? " vs. " . $_->Opponent($r0)->Name() : '')
	. "\n" 
	} 
	sort { $a->Board($r0) cmp $b->Board($r0) } @$headlessp;
      }
    close $fh; }
  }

sub WriteRowWithClasses ($$$$) {
  my $this = shift;
  my $logp = shift;
  my $textsp = shift;
  my $htmlsp = shift;

  if (grep { /class=opp/ } @$htmlsp) { $logp->RowClassAdd('pair'); }
  else { $logp->RowClassRemove('pair'); }
  if (grep { /class=bye/ } @$htmlsp) { $logp->RowClassAdd('bye'); }
  else { $logp->RowClassRemove('bye'); }
  if (grep { /class=unpaired/ } @$htmlsp) { $logp->RowClassAdd('unpaired'); }
  else { $logp->RowClassRemove('unpaired'); }
  $logp->WriteRow($textsp, $htmlsp);
  }

=back

=cut

=head1 BUGS

A reasonable guess should be made when there are not enough tables
configured to accommodate the boards needed.

enopryet should be reported even when only inactive players are paired

Should use new TSH::Log table code.

Should use TSH::Division::BoardTable() and TSH::Division::HasTables().

=cut

1;
