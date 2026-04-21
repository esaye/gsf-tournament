#!/usr/bin/perl

# Copyright (C) 2005-2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Report::CSC;

use strict;
use warnings;
use Carp;
use TSH::Log;
use TSH::Utility qw(FormatHTMLHalfInteger FormatHTMLInteger FormatHTMLSignedInteger);

=pod

=head1 NAME

TSH::Report::CSC - utility for generating a contestant scorecard

=head1 SYNOPSIS

  $c = new TSH::Report::CSC($player);
  ($text, $html) = $c->GetBoth(\%options);
  $s = $c->GetHTML(\%options);
  $s = $c->GetText(\%options);

=head1 ABSTRACT

This Perl module is used to create contestant scorecards.
Note that all of the C<Get*()> methods generate printable
files as a side effect.

=head1 DESCRIPTION

A CSC has (at least) the following member fields, none of which
ought to be accessed directly from outside the class.

  player  reference to TSH::Player object

The following member functions are currently defined.

=over 4

=cut

sub GetBoth ($$);
sub GetHTML ($$);
sub GetText ($$);
sub RenderTextTitle ($);
sub Compose ($);
sub new ($$);

=item $logp = $csc->Compose(\%options);

Store CSC in a TSH::Log object in preparation for rendering it as
text and/or HTML.  Options:

  imposition: a number defaulting to 1 indicating how many CSC pages
  should be printed horizontally across a physical sheet

No options are currently supported.

=cut

sub Compose ($) {
  my $this = shift;
  my $optionsp = shift;
  my $p = $this->{'player'};
  my $dp = $p->Division();
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $tables = $config->Value('tables');
  my $noboards = $config->Value('no_boards');
  my $seats = $config->Value('seats');
  my $page_break = $config->Value('scorecard_page_break') || 16;
  my $tagged_games = $config->Value('entry') eq 'tagged';
  $tables = $tables->{$dp->Name()} if $tables;
  my $has_rating = $dp->RatingSystemName() ne 'none';
  my $t = $config->Terminology({
    map { $_ => [] } qw(cumulative Rating_colon)
    });
  my $imposition = $optionsp->{'imposition'} || 1;

  my @html_cells1;
  my @html_cells2;
  my @text_cells;
  my $logp = new TSH::Log($tournament, $dp, 'scorecard', 
    'p' . $p->ID(), {
      'title' => "Contestant Scorecard",
      'htmltitle' => '',
      'texttitle' => $this->RenderTextTitle(),
      # no file I/O, request rendered string
      'noconsole' => 1,
      'nohtml' => 1,
      'notext' => 1,
      'nowrapper' => 1,
#     'notitle' => 1,
      'notop' => 1,
    });

  # HTML banner head
  {
    $logp->ColumnAttributes([(@{$this->{'html_attributes'}[0]}) x $imposition]);
    $logp->ColumnClasses([(@{$this->{'html_classes'}[0]}) x $imposition], 'top1');
    my @html_cells0 = (
      $p->FullID(), 
      '<a name="'.$p->ID().'"><span class="label">Name:</span></a> ' 
        . $p->PrettyName({'use_pname'=>1}),
      $has_rating ? qq(<span class="label">$t->{"Rating_colon"}</span> ) . $p->Rating() : '',
      ) x $imposition;
    $logp->WriteTitle([], \@html_cells0);
  }

  # column titles
  $logp->ColumnClasses([(@{$this->{'text_classes'}}) x $imposition]);
  $logp->WriteTitle([(@{$this->{'text_titles'}}) x $imposition], []);
  $logp->ColumnAttributes([]);
  $logp->ColumnClasses([(@{$this->{'html_classes'}[1]}) x $imposition], 'top2');
  $logp->WriteTitle([], [(@{$this->{'html_titles'}}) x $imposition]);
  
  # emit one line for each paired, played or seated round
  my $max_round0 = $dp->MaxRound0();
  my $maxround1 = (defined $max_round0) 
    ? $max_round0 + 1
    : ($p->CountOpponents() > $p->CountScores() 
    ? $p->CountOpponents() 
    : $p->CountScores());
  # untested generalized provisional score mechanism
  my $canProvisional;
  if ($p->can('CountProvisionalScores')) {
    $canProvisional = 1;
    my $nps = $p->CountProvisionalScores();
    $maxround1 = $nps if $nps and $maxround1 < $nps;
    }
  # SPC2022, DD2023 provisional scores
  my $provsp = $p->GetOrSetEtcVector('rprov');
  if ($provsp and @$provsp and $provsp->[-3] > $maxround1) {
# warn "MAXROUND=$maxround1";
    $maxround1 = $provsp->[-3];
    }

# while ($p->Seat($maxround1)) { $maxround1++; }

  my $nrows = int(($maxround1 + $imposition - 1) / $imposition);
  for my $rowno (1..$nrows) {
    for (my $r1 = $rowno; $r1 <= $maxround1; $r1 += $nrows) {
      push(@html_cells1, $r1);

      my $p12_offset = scalar(@html_cells2);
      push(@html_cells2, '1st 2nd');
      push(@html_cells2, qq(<span class="label">$t->{"cumulative"}</span>))
	unless $this->{'spread_entry'};
      push(@html_cells2, '<span class="strut">&nbsp;</span>');

      my $r0 = $r1 - 1;
      my $oid = $p->OpponentID($r0);
      my $seat = $seats ? $p->Seat($r0) || '' : '';
      if ($seats) {
	$seat = $p->Seat($r0);
	if (!defined $seat) { $seat = '?'; }
	elsif ($seat eq '00') { $seat = ''; }
	elsif (!$seat) { $seat = '-'; }
	}
      unless (defined $oid) {
	push(@html_cells1, '') if $tables || !$noboards;
	push(@html_cells1, $seat) if $seats;
	push(@html_cells1, ''); # oppno
	push(@html_cells1, '') if $seats;
	push(@html_cells1, '') if $has_rating;
	push(@html_cells1, '', '', ''); # opponent won lost
	push(@html_cells1, '', '') unless $this->{'spread_entry'};
	push(@html_cells1, '');
	push(@text_cells, $r1, '', $seat) if $seats;
	next;
	}
      push(@text_cells, $r1);
      my $opp = $p->Opponent($r0);
      if ($oid && !$opp) {
	$dp->Tournament()->TellUser('ebadtpn', $p->ID(), $oid);
	return;
	}
      my $score = $p->Score($r0);
      my $p12 = $p->First($r0);
      my (@provisional);
      # untested new provisional score code
      if ((!defined $score) and $canProvisional) {
	@provisional = $p->GetProvisionalScores($r0);
#	print "PROV @{[$r0+1]}: @provisional\n";
	}
      # SPC 2022, DD 2023 provisional score code
      if ($provsp and @$provsp) {
	for (my $i = 0; $i<$#$provsp; $i+=3) {
	  if ($provsp->[$i] == $r0+1) {
	    (@provisional) = @$provsp[$i+1, $i+2];
#	    print "RPROV: @provisional\n";
	    }
	  }
	}
      if ($this->{'track_firsts'}) {
	if (defined $p12) {
	  push(@text_cells, ' '.('-',"$p12","$p12",'?', '??')[$p12]);
	  $html_cells2[$p12_offset] = ('-','1st&nbsp;&nbsp;&nbsp;&nbsp;',
	    '&nbsp;&nbsp;&nbsp;&nbsp;2nd','1st 2nd','1st 2nd')[$p12];
	  }
	else {
	  push(@text_cells, '');
	  }
	}
      if ($tables || !$noboards) {
	my $bort = $p->Board($r0) || '';
	if ($bort && $tables) { $bort = $tables->[$bort-1]; }
	$bort ||= $oid ? '?' : '-';
	push(@text_cells, $bort);
	push(@html_cells1, $bort);
	}
      if ($seats) {
	push(@text_cells, $seat);
	push(@html_cells1, $seat);
	}
      if ($oid) {
	my $repeats = $p->CountRoundRepeats($opp, $r0);
	$repeats = $repeats > 1 ? "*$repeats" : '';
	my $oname = $opp->PrettyName({'use_pname'=>1}) . $repeats;
	my @seats;
	if ($seats) {
	  my $seat = $opp->Seat($r0) || '';
	  push(@seats, $seat);
	  }
	push(@text_cells, $opp->ID());
	push(@text_cells, $opp->Rating()) if $has_rating;
	push(@text_cells, @seats, $oname);
	push(@html_cells1, $opp->ID());
	push(@html_cells1, $opp->Rating()) if $has_rating;
	push(@html_cells1, @seats, $oname);
	}
      else {
	if ($seats) {
  #	push(@text_cells, '-');
  #	push(@html_cells1, '-');
	  }
	push(@text_cells, '-'); # ID
	push(@html_cells1, '-');
	if ($has_rating) {
	  push(@text_cells, '-'); # opponent rating
	  push(@html_cells1, '-');
	  }
	push(@text_cells, 'bye');
	push(@html_cells1, 'bye');
	}
      if (defined $score) {
	my $oscore = $p->OpponentScore($r0) || 0;
	my $wins = $p->RoundWins($r0);
	my $losses = $p->RoundLosses($r0);
	push(@text_cells, sprintf("%.1f-%.1f", $wins, $losses));
	push(@html_cells1, FormatHTMLHalfInteger($wins), FormatHTMLHalfInteger($losses));
	unless ($this->{'spread_entry'}) {
	  push(@text_cells, $score, $oscore);
	  push(@html_cells1, FormatHTMLInteger($score), FormatHTMLInteger($oscore));
	  }
	my $spread = sprintf("%+d", $p->RoundGameSpread($r0));
	if (my $penalty = $p->Penalty($r0)) {
	  $spread = sprintf("%+d%+d", $spread-$penalty, $penalty);
	  }
	my $cume = sprintf("%+d", $p->RoundSpread($r0));
	if ($tagged_games) {
	  $spread .= ' ' . ($p->GameTag($r0)||'');
	  }
	push(@text_cells, $spread, $cume);
	push(@html_cells1, FormatHTMLSignedInteger $spread);
	$html_cells2[-1] .= FormatHTMLSignedInteger $cume;
	}
      elsif (@provisional && defined $provisional[1]) {
	# TODO: add opponent's version of provisional scores if available
	push(@text_cells, ''); # W-L
	push(@html_cells1, '', '');
	unless ($this->{'spread_entry'}) {
	  push(@text_cells, map { "$_?" } @provisional[0,1]); # provisional scores
	  push(@html_cells1, FormatHTMLInteger($provisional[0]) . '?',
	    FormatHTMLInteger($provisional[1]) . '?');
	  }
	my $spread = $provisional[0] - $provisional[1];
	push(@text_cells, $spread, '');
	push(@html_cells1, FormatHTMLSignedInteger $spread);
	}
      else {
	push(@html_cells1, '', '');
	push(@html_cells1, '', '') unless $this->{'spread_entry'};
	push(@html_cells1, '');
	}
      } # for $r1
    } # for $rowno
  continue {
    $logp->ColumnClasses([(@{$this->{'text_classes'}}) x $imposition]);
    $logp->WriteRow(\@text_cells, []);
    $logp->ColumnAttributes([(@{$this->{'html_attributes'}[1]}) x $imposition]);
#   warn "@{$this->{'html_attributes'}[1]}";
    $logp->ColumnClasses([(@{$this->{'html_classes'}[1]}) x $imposition], 'round1');
#   (@html_cells1) = map { '<div style="page-break-inside:avoid">' . $_ . '</div>' } @html_cells1;
    $logp->WriteRow([], \@html_cells1);
    $logp->ColumnAttributes([(@{$this->{'html_attributes'}[2]}) x $imposition]);
    $logp->ColumnClasses([(@{$this->{'html_classes'}[2]}) x $imposition], 'round2');
#   (@html_cells2) = map { '<div style="page-break-inside:avoid">' . $_ . '</div>' } @html_cells2;
    $logp->WriteRow([], \@html_cells2);
    @text_cells = ();
    @html_cells1 = ();
    @html_cells2 = ();
    if (1 && $page_break && $rowno < $nrows && ($rowno % $page_break) == 0) {
      $logp->PageBreak();
      }
    }

  my $ncolumns = 9;
  $ncolumns++ unless $this->{'spread_entry'};
  $ncolumns += 2 if $seats;
  $logp->ColumnAttributes(["colspan=$ncolumns"]);
  $logp->ColumnClasses([],'bottom');
  $logp->WriteRow([], ['&nbsp;']);
  return $logp;
  }

=item my ($text, $html) = $csc->GetBoth(\%options);

Return text and HTML rendering of the CSC.
No options are currently supported.

=cut

sub GetBoth ($$) {
  my $this = shift;
  my $optionsp = shift;
  my $logp = $this->Compose($optionsp);
  return ($logp->RenderText(), $logp->RenderHTML());
  }

=item $html = $csc->GetHTML(\%options);

Return HTML rendering of the CSC as the rows of a table.
No options are currently supported.

=cut

sub GetHTML ($$) {
  my $this = shift;
  my $optionsp = shift;
  return $this->Compose($optionsp)->RenderHTML();
  }

=item $html = $csc->GetText(\%options);

Return text rendering of the CSC.
No options are currently supported.

=cut

sub GetText ($$) {
  my $this = shift;
  my $optionsp = shift;
  return $this->Compose($optionsp)->RenderText();
  }

sub initialise ($$) {
  my $this = shift;
  my $p = shift;
  my $dp = $p->Division();
  my $config = $dp->Tournament()->Config();
  my $has_rating = $dp->RatingSystemName() ne 'none';
  # TODO: should cache the above value
  my $noboards = $config->Value('no_boards');
  my $tables = $config->Value('tables');
  my $seats = $config->Value('seats');
  # store some configuration variables to avoid possible future race conditions
  $tables = $tables->{$dp->Name()} if $tables;
  $this->{'tables'} = $tables;
  $this->{'spread_entry'} = $config->Value('entry') eq 'spread';
  $this->{'track_firsts'} = $config->Value('track_firsts');
  $this->{'player'} = $p;
  # set up and store table layout variables
  my @html_attributes0; # banner at top of CSC
  my @html_attributes1; # column headings
  my @html_attributes2; # second line of data rows
  my @html_classes0; # banner at top of CSC
  my @html_classes1; # column headings
  my @html_classes2; # second line of data rows
  my @html_titles; # column headings
  my @text_classes;
  my @text_titles;

  my $t = $config->Terminology({
    map { $_ => [] } qw(Agn Bd Board Cumul cumulative For Lost Opp OppNo OpponentName Opponent_Score Player_Score Rating Rnd Round Rtng Seat Sprd Spread St Table Tbl W_L Won)
    });
  push(@html_attributes0, $has_rating ? 'colspan=3' : 'colspan=2');
  push(@html_classes0, qw(number name rating));

  push(@text_classes, q(round));
  push(@text_titles, $t->{'Rnd'});
  push(@html_titles, $t->{'Round'});
  push(@html_attributes1, 'rowspan=1');
  push(@html_classes1, qw(round));
  push(@html_classes2, qw(p12));

  if ($this->{'track_firsts'}) {
    push(@text_classes, q(p12));
    push(@text_titles, q(1/2));
    }

  if ($tables) {
    push(@text_classes, 'table');
    push(@text_titles, $t->{'Tbl'});
    push(@html_titles, $config->Value('table_title') || $t->{'Table'});
    push(@html_attributes1, 'rowspan=2');
    push(@html_classes1, qw(table));
    }
  elsif (!$noboards) {
    push(@text_classes, 'board');
    push(@text_titles, $t->{'Bd'});
    push(@html_titles, $t->{'Board'});
    push(@html_attributes1, 'rowspan=2');
    push(@html_classes1, qw(board));
    }
  if ($seats) {
    push(@text_classes, 'seat');
    push(@text_titles, $t->{'St'});
    push(@html_titles, $t->{'Seat'});
    push(@html_attributes1, 'rowspan=2');
    push(@html_classes1, qw(seat));
    }

  push(@text_classes, qw(onum));
  push(@text_classes, qw(orat)) if $has_rating;
  push(@text_titles, $t->{'Opp'});
  push(@text_titles, $t->{'Rtng'}) if $has_rating;
  push(@html_classes1, qw(onum));
  push(@html_classes1, qw(orat)) if $has_rating;
  push(@html_titles, $t->{'OppNo'});
  push(@html_titles, $t->{'Rating'}) if $has_rating;
  if ($seats) {
    push(@text_classes, 'seat');
    push(@text_titles, $t->{'St'});
    push(@html_titles, $t->{'Seat'});
    push(@html_attributes1, 'rowspan=2');
    push(@html_classes1, qw(seat));
    }
  push(@text_classes, qw(onam wl));
  push(@text_titles, $t->{'OpponentName'}, $t->{'W_L'});
  push(@html_titles, @$t{qw(OpponentName Won Lost)});
  push(@html_attributes1, ('rowspan=2') x (4 + ($has_rating ? 1 : 0)));
  push(@html_classes1, qw(onam won lost));

  my $seat_ncolumns = $seats ? 2 : 0;
  if ($this->{'spread_entry'}) {
    push(@html_attributes0, "colspan=".(3+$seat_ncolumns));
    push(@html_classes2, qw(cume2));
    }
  else {
    push(@text_titles, @$t{qw(For Agn)});
    push(@text_classes, qw(score score));
    push(@html_attributes0, "colspan=".(5+$seat_ncolumns));
    push(@html_attributes1, 'rowspan=2', 'rowspan=1');
    push(@html_classes1, qw(for against));
    push(@html_titles, @$t{qw(Player_Score Opponent_Score)});
    push(@html_classes2, qw(cumelabel cume));
    }

  push(@text_titles, @$t{qw(Sprd Cumul)});
  push(@text_classes, qw(spread spread));
  push(@html_attributes0, 'colspan=2');
  push(@html_attributes1, 'rowspan=1');
  push(@html_classes1, qw(spread));
  push(@html_titles, $t->{'Spread'});

  $this->{'html_attributes'} 
    = [\@html_attributes0, \@html_attributes1, \@html_attributes2];
  $this->{'html_classes'} 
    = [\@html_classes0, \@html_classes1, \@html_classes2];;
  $this->{'html_titles'} = \@html_titles;
  $this->{'text_classes'} = \@text_classes;
  $this->{'text_titles'} = \@text_titles;
  }

sub new ($$) { return TSH::Utility::new(@_); }

=item $text = $this->RenderTextTitle();

Used internally to render the title area in text mode.

=cut

sub RenderTextTitle ($) {
  my $this = shift;
  my $p = $this->{'player'};
  my $config = $p->Division()->Tournament()->Config();
  my $has_rating = $config->Value('rating_system') ne 'none';
  my $text_title = $config->Terminology('Player_Scorecard_colon') . ' ' . $p->TaggedName()
    . ($has_rating ? " (" . $p->Rating() . ")" : '');
  if ($this->{'track_firsts'}) {
    my $firsts = $p->Firsts()|| 0;
    my $seconds = $p->Seconds() || 0;
    $text_title .= " (S${firsts}:R$seconds)";
    }
  if (my $lifeg = $p->LifeGames()) {
    $text_title .= " (LG$lifeg)";
    }
  if (!$p->Active()) {
    my $spread = $p->OffSpread();
    $spread = -$config->Value('bye_spread') unless defined $spread;
    $text_title .= " INACTIVE";
    $text_title .= "[$spread]" unless $spread == -$config->Value('bye_spread');
    }
  $text_title .= "\n";
  # etc/time could exist but be of empty length after a RESETEVERYTHING
  if ($p->{'etc'}{'time'} && $p->{'etc'}{'time'}[0]) {
    my $age = int((time - $p->{'etc'}{'time'}[0])/60);
    if ($age < 200) {
      my $s = $age == 1 ? '' : 's';
      $text_title .= $config->Terminology(
        $age == 1 ? 'Last_score_entered_1' : 'Last_score_entered_n', 
	$age) . "\n";
      }
    }
  return $text_title;
  }

=back

=cut

1;
