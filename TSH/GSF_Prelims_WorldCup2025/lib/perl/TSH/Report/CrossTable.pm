#!/usr/bin/perl

# Copyright (C) 2008-2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Report::CrossTable;

use strict;
use warnings;
use Carp;
use TSH::Log;
use TSH::Utility qw(FormatHTMLHalfInteger FormatHTMLSignedInteger);
use Ratings::Elo;

=pod

=head1 NAME

TSH::Report::CrossTable - utility for generating an event cross-table.

=head1 SYNOPSIS

  $c = new TSH::Report::CrossTable($tourney);
  ($text, $html) = $c->GetBoth(\%options);
  $s = $c->GetHTML(\%options);
  (@s) = $c->GetText(\%options);

=head1 ABSTRACT

This Perl module is used to generate event cross-tables, the
traditional publication format of NASPA (formerly NSA) tournament
results.  Results are formatted in two different ways.  Text results
consist of one long text string per event ratings segment, plus one
string giving an event summary for long events that are split for
ratings purposes into two or three segments.  HTML results consist
of one long HTML string which combines all of this information.

=head1 DESCRIPTION

A CrossTable has (at least) the following member fields, none of which
ought to be accessed directly from outside the class.

  rating_system  reference to Ratings object
  tournament     reference to TSH::Tournament object

The following member functions are currently defined.

=over 4

=cut

sub ComposeHTML ($);
sub ComposeHTMLDivision ($$$);
sub ComposeSummary ($$$);
sub ComposeText ($);
sub ComposeTextTable ($$$$$$);
sub DivisionRatingSystems ($$);
sub GetBoth ($$);
sub GetHTML ($$);
sub GetText ($$);
sub MeasureDivision ($$);
sub new ($$);
sub RankPlayers ($$);
sub RenderHTMLRating ($@);
sub RenderHTMLRows ($$$);
sub RenderHTMLTableTop ($$$$);
sub RenderHTMLTitle ($$);
sub RenderTextHalfInteger ($$);
sub RenderTextRows ($$$$$$);
sub RenderTextSignedInteger ($$);
sub RenderTextSummaryRows ($$$);
sub RenderTextTitle ($$$);
sub SetupTextSummaryTable ($$$$);
sub SetupTextTable ($$$$$$);

=item $division_logs_p = $ct->ComposeHTML(\%options);

Store event cross-tables in a TSH::Log object in preparation for rendering them as
HTML.  No options are currently supported.

=cut

sub ComposeHTML ($) {
  my $this = shift;
  my $optionsp = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();

  my @logs;
  my $isfirst = 1;
  for my $dp ($tournament->Divisions()) {
    push(@logs, $this->ComposeHTMLDivision($dp, $isfirst));
    $isfirst = 0;
    }
  return \@logs;
  }

=item $division_logs_p = $ct->ComposeHTMLDivision($dp, $isfirst);

Store a division cross-table in a TSH::Log object in preparation for rendering it as
text.  No options are currently supported.

=cut

sub ComposeHTMLDivision ($$$) {
  my $this = shift;
  my $dp = shift;
  my $isfirst = shift;
  $this->MeasureDivision($dp);
  my $logp = $this->SetupHTMLLog($dp, $isfirst);
  $this->RenderHTMLRows($logp, $dp);
  return $logp;
  }

=item $session_logss_p = $ct->ComposeText(\%options);

Store event cross-tables in a TSH::Log object in preparation for rendering them as
text.  No options are currently supported.

=cut

sub ComposeText ($) {
  my $this = shift;
  my $optionsp = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();

  my @segment_logss;
  my @summary_logs;

  my $dn = 1;
  for my $dp ($tournament->Divisions()) {
    $this->MeasureDivision($dp);
    my (@splits) = @{$this->{'splits'}};
    for my $i (0..$#splits) {
      my $split = $splits[$i];
      my ($first0, $last0) = @$split;
      $segment_logss[$i] = [] unless $segment_logss[$i];
      push(@{$segment_logss[$i]}, 
	$this->ComposeTextTable($dp, $dn, $first0, $last0, $i+1));
      }
    if (@splits > 1) {
      push(@summary_logs, $this->ComposeSummary($dp, $dn));
      }
    $dn++;
    }
  push(@segment_logss, \@summary_logs) if @summary_logs;
  return \@segment_logss;
  }

=item $logp = $ct->ComposeSummary($dp, $dn);

Compose summary table for a division into a TSH::Log.

=cut

sub ComposeSummary ($$$) {
  my $this = shift;
  my $dp = shift;
  my $dn = shift;

  my $tournament = $this->{'tournament'};
  my $logp = new TSH::Log($tournament, undef, 'crosstable', undef, {
    'title' => "Cross Table",
#     'htmltitle' => '',
    'texttitle' => $dn == 1 ? $this->RenderTextTitle('(Final)', 0) : '',
    # no file I/O, request rendered string
    'noconsole' => 1, 'nohtml' => 1, 'notext' => 1, 'nowrapper' => 1, 'notop' => 1,
    });
  $this->MeasureDivision($dp);
  $this->SetupTextSummaryTable($logp, $dp, $dn);
  $this->RenderTextSummaryRows($logp, $dp);
  return $logp;
}

=item $logp = $ct->ComposeTextTable($dp, $dn, $first0, $last0, $spliti1);

Compose one segment cross-table for a division into a TSH::Log.

=cut

sub ComposeTextTable ($$$$$$) {
  my $this = shift;
  my $dp = shift;
  my $dn = shift;
  my $first0 = shift;
  my $last0 = shift;
  my $spliti1 = shift;
  my $nsplits = $this->{'nsplits'};

  my $tournament = $this->{'tournament'};
  my $logp = new TSH::Log($tournament, undef, 'crosstable', 
    undef, {
      'title' => "Cross Table",
      'htmltitle' => '',
      'texttitle' => $dn == 1 ? $this->RenderTextTitle(
        $nsplits > 1 ? "(Rounds ".($first0+1)."-".($last0+1)." of ".($this->{'splits'}[-1][1]+1).")" : '', 1) : '',
      # no file I/O, request rendered string
      'noconsole' => 1, 'nohtml' => 1, 'notext' => 1, 'nowrapper' => 1, 'notop' => 1,
    });
  $this->MeasureDivision($dp);
  $this->SetupTextTable($logp, $dp, $dn, $first0, $last0);
  $this->RenderTextRows($logp, $dp, $spliti1, $first0, $last0);
  return $logp;
  }

=item $rsp = $ct->DivisionRatingSystems($dp);

Return a reference to a list of rating systems to be used to rate division C<$dp>.

=cut

sub DivisionRatingSystems($$) {
  my $this = shift;
  my $dp = shift;
  if (my $rsp = $this->{'rating_systems'}) {
    return $rsp;
    }
  else {
    return [$dp->RatingSystem()];
    }
  }

=item ($textsp, $html) = $ct->GetBoth(\%options);

Return text and HTML renderings of the cross-table.
No options are currently supported.

=cut

sub GetBoth ($$) {
  my $this = shift;
  my $optionsp = shift;
  return ($this->GetText(), $this->GetHTML());
  }

=item $html = $ct->GetHTML(\%options);

Return HTML rendering of the cross-table as the rows of a table.
No options are currently supported.

=cut

sub GetHTML ($$) {
  my $this = shift;
  my $optionsp = shift;
  my $division_logs_p = $this->ComposeHTML($optionsp);
  my $html = '';
  for my $division_log_p (@$division_logs_p) {
    $html .= $division_log_p->RenderHTML();
    }
  return $html;
  }

=item $textp = $ct->GetText(\%options);

Return a reference to a list of text renderings of the cross-table.
If a cross-table has more than one segment, more than one text string is returned
in the list.
No options are currently supported.

=cut

sub GetText ($$) {
  my $this = shift;
  my $optionsp = shift;
  my $segment_logss_p = $this->ComposeText($optionsp);
  my @text;
  for my $segment_logs_p (@$segment_logss_p) {
    my $text = '';
    for my $division_logp (@$segment_logs_p) {
      $text .= $division_logp->RenderText();
      }
    push(@text, $text);
    }
  return \@text;
  }

sub initialise ($$) {
  my $this = shift;
  my %options;
  if (@_ == 1) {
    $options{'tournament'} = shift;
    }
  else {
    %options = @_;
    }
  for my $optional (qw(
    rating_systems
    strip_names
    tournament
    )) {
    if (exists $options{$optional}) {
      $this->{$optional} = $options{$optional};
      delete $options{$optional};
      }
    }
  if (%options) {
    die "Unknown options: " . join(', ', keys %options);
    }
  my $config = $this->{'tournament'}->Config();
  # TODO: should cache the above value
  # store some configuration variables to avoid possible future race conditions
  $this->{'spread_entry'} = $config->Value('entry') eq 'spread';
  $this->{'track_firsts'} = $config->Value('track_firsts');
  }

=item $ct->MeasureDivision($dp);

Used internally to set some division-related parameters:
ax_round0 (0-based index of last round in cross-table),
pnwidth (width in characters of player numbers),
nrounds,
splits,
nsplits.

=cut

sub MeasureDivision ($$) {
  my $this = shift;
  my $dp = shift;

  my $pnwidth = length($dp->CountPlayers());
  $pnwidth = 2 if $pnwidth < 2;
  $this->{'pnwidth'} = $pnwidth;
# my $max_round0 = $dp->MaxRound0() || die;
  # MaxRound0 might not be correct if .tsh was generated automatically
  # and divisions differ in round length
  $this->{'nrounds'} = $dp->MostScores();
  $this->{'max_round0'} = $this->{'nrounds'}-1;
  $this->{'splits'} = [Ratings::MakeSplits({'use_split_ratings' => 1}, $this->{'nrounds'})];
  $this->{'nsplits'} = scalar(@{$this->{'splits'}});
  }

sub new ($$) { return TSH::Utility::new(@_); }

=item @players = $ct->RankPlayers($dp);

Used internally to sort players by overall standing and assign their C<xrank> field
accordingly.

=cut

sub RankPlayers ($$) {
  my $this = shift;
  my $dp = shift;
  my (@players) = grep { $_->GamesPlayed(); } $dp->Players();
  TSH::Utility::DoRanked(
    \@players,
    sub ($$) { # comparator
      $_[1]->Wins() <=> $_[0]->Wins() ||
      $_[0]->Losses() <=> $_[1]->Losses() ||
      $_[1]->Spread() <=> $_[0]->Spread();
      },
    sub ($) { my $p = shift; return ($p->Wins(), $p->Losses(), $p->Spread()); },
    sub { # actor
      $_[0]{'xrank'} = $_[1];
      }
    );
  return @players;
  }

=item ($cell1, $cell2) = $ct->RenderHTMLRating($pp, $rating_system, $oldkey, $perfkey, $newkey)

Render a player's old rating, new rating, performance rating and rating change
as a pair of table cells in HTML.

=cut

sub RenderHTMLRating ($@) {
  my $this = shift;
  my $pp = shift;
  my $rs = shift;
  my $oldkey = shift;
  my $perfkey = shift;
  my $newkey = shift;

  my $rsname = $rs->Name();
  my $old = $pp->SupplementaryRatingsData($rsname, $oldkey);
  my $perf = $pp->SupplementaryRatingsData($rsname, $perfkey);
  $perf = '' unless defined $perf;
  my $new = $pp->SupplementaryRatingsData($rsname, $newkey);
  my $change;
  if ($old) { 
    # must do the change first
    $change = $rs->RenderRatingDifference($new, $old, {'style' => 'html'}); 
    $old = $rs->RenderRating($old, {'style' => 'html'});
    $new = $rs->RenderRating($new, {'style' => 'html'});
    }
  else {
    $old = '';
    $change = '';
    $new = $rs->RenderRating($new, {'style' => 'html'});
    }
  return (
    "$old<br><span class=perf>$perf</span>",
    "$new<br><span class=change>$change</span>",
    );
  }

=item $text = $this->RenderHTMLRows($logp, $dp);

Used internally to render the data rows in HTML.

=cut

sub RenderHTMLRows ($$$) {
  my $this = shift;
  my $logp = shift;
  my $dp = shift;

  my $config = $dp->Tournament()->Config();

  my (@players) = $this->RankPlayers($dp);
  my $dformat = '%0'.$this->{'pnwidth'}.'d';
  my $sformat = '%'.$this->{'pnwidth'}.'s';
  my @html_cells;
  for my $pp (sort { $a->{'xrank'} <=> $b->{'xrank'} 
    || $a->{'name'} cmp $b->{'name'} } @players) {
# printf STDERR "%s: %s\n", $pp->StrippedName(), $config->PhotoPath(uc($pp->StrippedName()));
    next unless $pp->GamesPlayed();
    push(@html_cells, $pp->{'xrank'}+1);
    push(@html_cells, qq(<img src="/players/)
      . ($pp->PhotoURL() || 'u/unknown_player.gif')
      . qq(" alt="[photo]" height=48 width=48>));
    {
      my $name = $this->{'strip_names'} ? $pp->StrippedName() : $pp->Name();
      $name =~ s/^(.*?)\s*&\s*(.*?)$/$1<br>&amp; $2/i
      || $name =~ s/^(.*), (.*?),? (JR|SR|II|III|IV|V|VI|VII|VIII|IX)$/$2<br>$1 $3/i 
      || $name =~ s/(.*), (.*)/$2<br>$1/ 
      || $name =~ s/(D AMBROSIO|VAN ALEN) (.*)/$2<br>$1/i
      || $name =~ s/(.*?) (.*)/$2<br>$1/;
      push(@html_cells, $name);
    }
    {
      my $wins = FormatHTMLHalfInteger($pp->Wins());
      my $losses = FormatHTMLHalfInteger($pp->Losses());
      push(@html_cells, "$wins&ndash;$losses");
    }
    {
      my $spread = FormatHTMLSignedInteger($pp->Spread());
      push(@html_cells, $spread);
    }
    for my $rs (@{$this->{'rating_systems'}}) {
#     die join(',', %{$pp->{'etc'}});
#     warn join(',', @{$pp->{'etc'}{'rating_nsa2008'}});
      my @fieldss = (
	undef,
	[[qw(old perf new)]],
	[[qw(old perf1 mid1)], [qw(mid1 perf new)]],
	[[qw(old perf1 mid1)], [qw(mid1 perf2 mid2)], [qw(mid2 perf new)]],
        );
      for my $fields (@{$fieldss[$this->{'nsplits'}]}) {
	push(@html_cells, $this->RenderHTMLRating($pp, $rs,  @$fields));
        }
      }
    for my $r0 (0..$this->{'max_round0'}) {
      my $ms = $pp->Score($r0);
      my $os = $pp->OpponentScore($r0);
      my $opp = $pp->Opponent($r0);
      unless (defined $ms) {
	# die;
	$ms = 0;
        }
      my $wltb = $pp->OpponentID($r0) ? (qw(T W L))[$ms<=>$os] : 'B';
      my $result = qq(<div class="result $wltb">\n);
      if ($wltb ne 'B') {
	my $oname = $this->{'strip_names'} ? $opp->StrippedName() : $opp->Name();
	push(@html_cells, qq(<img src="/players/)
          . ($opp->PhotoURL() || 'u/unknown_player.gif')
	  . qq(" alt="[photo]" height=48 width=48 title="$oname">));
	$result .= qq(<div class=wlos>);
	$result .= qq(<div class=wlo><span class=wl>$wltb</span><span class=o>)
	  . ($opp->{'xrank'}+1)
	  . "</span></div>\n";
	if ($ms + $os != 2) { # unlikely to really happen, no great loss if it does
	  $result .= "<div class=ms>$ms</div>"
	  . "<div class=os>$os</div>\n"
	  };
	$result .= "</div>\n";
	}
      else {
	push(@html_cells, ''); # no photo for bye
	$result .= qq(<div class=wlos>);
	$result .= qq(<div class=wlo><span class=wl>B</span></div>\n)
	  . "<div class=ms>" . sprintf("%+d", $ms) . "</div>\n";
	$result .= "</div>\n";
	}
      $result .= "</div>\n";
      push(@html_cells, $result);
      }
    }
  continue {
    $logp->WriteRow([], \@html_cells) if @html_cells;
    @html_cells = ();
    }
#   $logp->Flush();
  }

sub RenderHTMLTableTop ($$$$) {
  my $this = shift;
  my $logp = shift;
  my $dp = shift;
  my $isfirst = shift;

  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my (@rating_systems) = @{$this->DivisionRatingSystems($dp)};
  my (%system_names) = (
    'nsa' => 'Traditional<br>Rating',
    'nsa lct' => 'Traditional<br>Rating',
    'nsa2008' => @rating_systems > 1 ? '2008 Revised<br>Rating' : 'Rating',
    'nsa2008 lct' => @rating_systems > 1 ? '2008 Revised<br>Rating' : 'Rating',
    'naspa-csw' => @rating_systems > 1 ? 'CSW<br>Rating' : 'Rating',
    'naspa-csw lct' => @rating_systems > 1 ? 'CSW<br>Rating' : 'Rating',
    );
  my @html_attributes0; # banner at top of cross-table
  my @html_attributes1; # spanned headings
  my @html_attributes2; # regular columns
  my @html_classes0; # banner at top of cross-table
  my @html_classes1; # first row of column headings
  my @html_classes2; # second row of column headings
  my @html_classes3; # data rows
  my @html_titles1; # spanned headings
  my @html_titles2; # column headings
  my $ncolumns = 0;

  # fixed columns
  push(@html_classes1, 'span');
  push(@html_titles1, '');
  push(@html_attributes1, '');
  #
  push(@html_classes2, qw(rank photo player wins spread));
  push(@html_classes3, @html_classes2);
  push(@html_titles2, 'Rank', '', 'Name', 'W&ndash;L', 'Spread');
  $ncolumns = scalar(@html_titles2);
  push(@html_attributes2, ('') x $ncolumns);
  $html_attributes1[-1] = "colspan=".($ncolumns);

  # variable number of columns for rating systems
  my $nsplits = $this->{'nsplits'};
  my $splits = $this->{'splits'};
  for my $rs (@{$this->{'rating_systems'}}) {
    push(@html_attributes1, 'colspan='.(2*$nsplits));
    my $rsname = $rs->Name();
    push(@html_titles1, @rating_systems > 1 ? $system_names{$rsname} : 'Rating');
    push(@html_classes1, 'rating b');
    push(@html_attributes2, ('', '') x $nsplits);
    for my $si (0..$nsplits-1) {
      push(@html_titles2, (
	($si > 0 ? "Rd.".($splits->[$si][0]) : 'Old')
	  .'<br><span class=perf>Perf</span>',
	($si < $nsplits-1 ? "Rd.".($splits->[$si][1]+1) : 'New')
	  .'<br><span class=change>+/&minus;</span>'
	));
      }
    push(@html_classes2, ('rating', 'rating b') x $nsplits);
    push(@html_classes3, ('rating', 'rating b') x $nsplits);
    $ncolumns += 3;
    }

  # variable number of columns for results
  push(@html_classes2, 'results');
  push(@html_titles2, 'Round-by-Round Results');
  {
    my $nrounds = $this->{'nrounds'};
    $nrounds++;
    push(@html_classes3, (qw(opic result)) x $nrounds);
    my $nrounds2 = $nrounds * 2;
    $ncolumns += $nrounds2 - 1;
    push(@html_attributes2, "colspan=$nrounds2");
  }

  push(@html_attributes0, "colspan=$ncolumns");
  push(@html_classes0, qw(event_name));

  if ($isfirst) {
    $logp->ColumnAttributes(\@html_attributes0);
    $logp->ColumnClasses(\@html_classes0, 'top0');
    $logp->WriteTitle([], [$config->Value('event_name')]);
    $logp->WriteTitle([], [$config->Value('event_date')]);
    }
  if ($tournament->CountDivisions() > 1) {
    $logp->ColumnAttributes(\@html_attributes0);
    $logp->ColumnClasses(['division'], 'top0');
    $logp->WriteTitle([],["Division ".$dp->Name()]);
    }
  # column titles
  $logp->ColumnAttributes(\@html_attributes1);
  $logp->ColumnClasses(\@html_classes1, 'top1');
  $logp->WriteTitle([], \@html_titles1);
  $logp->ColumnAttributes(\@html_attributes2);
  $logp->ColumnClasses(\@html_classes2, 'top2');
  $logp->WriteTitle([], \@html_titles2);
  $logp->ColumnAttributes([]);
  $logp->ColumnClasses(\@html_classes3);
  }

=item $text = $this->RenderHTMLTitle($suffix);

Used internally to render the title area in html mode.

=cut

sub RenderHTMLTitle ($$) {
  my $this = shift;
  my $suffix = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  return '';
  }

=item $text = $ct->RenderTextSignedInteger($n);

Used internally to render a signed integer as text.

=cut

sub RenderTextSignedInteger ($$) {
  my $this = shift;
  my $n = shift;
  $n = '+'.(0+$n) if $n >= 0;
  return $n;
  }

=item $text = $ct->RenderTextSummaryRows($logp, $dp);

Used internally to render the data rows in text.

=cut

sub RenderTextSummaryRows ($$$) {
  my $this = shift;
  my $logp = shift;
  my $dp = shift;

  my (@players) = $this->RankPlayers($dp);
  for my $pp (sort { $a->{'xrank'} <=> $b->{'xrank'} 
    || $a->{'name'} cmp $b->{'name'} } @players) {
    $logp->WriteRow([
      ($pp->{'xrank'}+1) . '.',
      uc($this->{'strip_names'} ? $pp->StrippedName() : $pp->Name()),
      $this->RenderTextHalfInteger($pp->Wins()),
      $this->RenderTextSignedInteger($pp->Spread()),
      ], []);
    }
  }

=item $text = $ct->RenderTextHalfInteger($n);

Used internally to render a half integer as text.

=cut

sub RenderTextHalfInteger ($$) {
  my $this = shift;
  my $n = shift;
  $n =~ s/\.5$/+/ or $n .= ' ';
  return $n;
  }

=item $text = $this->RenderTextRows($logp, $dp, $spliti1, $first0, $last0);

Used internally to render the data rows in text.

=cut

sub RenderTextRows ($$$$$$) {
  my $this = shift;
  my $logp = shift;
  my $dp = shift;
  my $spliti1 = shift;
  my $first0 = shift;
  my $last0 = shift;

# $dp->ComputeRatings($max_round0);
  $dp->CountByes();
  my $rs = $this->{'rating_systems'}[0];
  my $rsname = $rs->Name();

  my (@players) = $dp->Players();
  if ($first0 == 0) {
    for my $p (@players) {
      $p->{'xw'} = $p->RoundWins($last0);
      $p->{'xl'} = $p->RoundLosses($last0);
      $p->{'xs'} = $p->GetOrSetEtcScalar('cume') || $p->RoundSpread($last0);
      }
    }
  else {
    for my $p (@players) {
      $p->{'xw'} = $p->RoundWins($last0) - $p->RoundWins($first0-1);
      $p->{'xl'} = $p->RoundLosses($last0) - $p->RoundLosses($first0-1);
      $p->{'xs'} = $p->GetOrSetEtcScalar('cume')
        || $p->RoundSpread($last0) - $p->RoundSpread($first0-1);
      }
    }
  @players = grep { $_->{'xw'}+$_->{'xl'} } @players;
  TSH::Utility::DoRanked(
    \@players,
    sub ($$) { # comparator
      $_[1]->{'xw'} <=> $_[0]->{'xw'}
        || $_[0]->{'xl'} <=> $_[1]->{'xl'}
	|| $_[1]->{'xs'} <=> $_[0]->{'xs'};
      }, sub { # selector
      @{$_[0]}{qw(xw xl xs)}
      },
    sub { # actor
      $_[0]{'xrank'} = $_[1];
      }
    );
    
  my $dformat = '%0'.$this->{'pnwidth'}.'d';
  my $sformat = '%'.$this->{'pnwidth'}.'s';
  my @text_cells;
  my $nsplits = $this->{'nsplits'};
  my $oldr_key = $spliti1 > 1 ? 'mid'.($spliti1-1): 'old';
  my $newr_key = $spliti1 < $nsplits ? 'mid'.($spliti1): 'new';
  my $perf_key = $spliti1 < $nsplits ? 'perf'.($spliti1): 'perf';
  for my $pp (sort { $a->{'xrank'} <=> $b->{'xrank'} 
    || $a->{'name'} cmp $b->{'name'} } @players) {
    next unless $pp->GamesPlayed();
    my $rating = $pp->SupplementaryRatingsData($rsname, $oldr_key);
    push(@text_cells,
      sprintf("%3d.", $pp->{'xrank'}+1),
      sprintf("%-23s", uc($this->{'strip_names'} ? $pp->StrippedName() : $pp->Name())),
      $rs->RenderRating($rating).' '
      );
    my @text;
    my $sum_oppr = 0;
    my $max_oppr = 0;
    my $n_opps = 0;
    my $n_earned_wins = 0;
    for my $r0 ($first0..$last0) {
      my $result;
      my $ms = $pp->Score($r0);
      my $os = $pp->OpponentScore($r0);
      my $opp = $pp->Opponent($r0);
#     warn "no score for $pp->{'name'} in round $r0+1" unless defined $ms;
      if ((defined $ms) && $pp->OpponentID($r0)) {
	$result = (qw(T W L))[$ms<=>$os]
	  . '-'
	  . sprintf($dformat, $opp->{'xrank'}+1);
#	$n_opps++;
#	my $oppr = $opp->Rating() || $opp->NewRating($r0);
#	$sum_oppr += $oppr;
#	$max_oppr = $oppr if $max_oppr < $oppr;
#	$n_earned_wins += (($ms<=>$os)+1)/2;
	}
      else {
	$result = ' -' . sprintf($sformat, '');
	}
      push(@text, $result);
      }
    push(@text_cells, join(' ', @text));
    push(@text_cells, $this->RenderTextHalfInteger($pp->{'xw'}));
    push(@text_cells, $this->RenderTextSignedInteger($pp->{'xs'}) . ' ');
    push(@text_cells, $rating 
      ? $rs->RenderPerformanceRating(
	  $pp->SupplementaryRatingsData($rsname, $perf_key),
	  {'oldr'=>$pp->SupplementaryRatingsData($rsname, $oldr_key)},
	  ) . ' ' 
      : '');
    push(@text_cells, $rs->RenderRating($pp->SupplementaryRatingsData($rsname, $newr_key)) . ' ');
    }
  continue {
    $logp->ColumnClasses($this->{'text_classes'});
    $logp->WriteRow(\@text_cells, []);
    @text_cells = ();
    }
#   $logp->Flush();
  }

=item $this->RenderHTMLTableTop($logp, $dp, $isfirst);

Used internally to render the title area in html mode.

=cut

=item $text = $this->RenderTextTitle($suffix, $centre);

Used internally to render the title area in text mode.

=cut

sub RenderTextTitle ($$$) {
  my $this = shift;
  my $suffix = shift;
  my $centre = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $s = uc(join(' ', $config->Value('event_name').',', $config->Value('event_date'), $suffix));
  $s = (' 'x((94-length($s))/2)) . $s if $centre;
  $s .= "\n";
  return $s;
  }

=item $division_log_p = $this->SetupHTMLLog($dp, $isfirst);

Used internally to open a TSH::Log object for an HTML composition run.

=cut

sub SetupHTMLLog ($$$) {
  my $this = shift;
  my $dp = shift;
  my $isfirst = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $logp = new TSH::Log($tournament, undef, 'crosstable', undef, {
    'title' => "Cross Table",
    'htmltitle' => $this->RenderHTMLTitle(''),
    'texttitle' => '',
    # no file I/O, request rendered string
    'noconsole' => 1, 'nohtml' => 1, 'notext' => 1, 'nowrapper' => 1, 'notop' => 1,
    });
  $this->RenderHTMLTableTop($logp, $dp, $isfirst);
  return $logp;
  }

=item $ct->SetupTextSummaryTable($logp, $dp, $dn);

Set up a division's cross-table log object.

=cut

sub SetupTextSummaryTable ($$$$) {
  my $this = shift;
  my $logp = shift;
  my $dp = shift;
  my $dn = shift;

  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();

  if ($dn == 1) {
    $logp->ColumnClasses(['event_name']);
    $logp->WriteTitle([], [$config->Value('event_name')]);
    $logp->WriteTitle([], [$config->Value('event_date')]);
    }
  if ($tournament->CountDivisions() > 1) {
    $logp->WriteTitle(['',"DIVISION $dn"], []);
    }
  $logp->ColumnClasses([qw(rank player wins spread)]);
  $logp->WriteTitle(['','NAME','WINS','SPREAD'], []);
  }

=item $this->SetupTextTable($logp, $dp, $is_first, $first0, $last0);

Set up a division's cross-table log object.

=cut

sub SetupTextTable ($$$$$$) {
  my $this = shift;
  my $logp = shift;
  my $dp = shift;
  my $dn = shift;
  my $first0 = shift;
  my $last0 = shift;

  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $maxround1 = $this->{'max_round0'} + 1;

  my (@rating_systems) = @{$this->DivisionRatingSystems($dp)};
  die "@rating_systems" if @rating_systems != 1;

  my @text_classes;
  my @text_titles1; # first row of column titles
  my @text_titles2; # second row of column titles

  push(@text_classes, qw(rank player rating results wins spread rating rating));
  push(@text_titles1, '', '', 'OLD  ', '', '', '', 'PERF ', 'NEW ');
  push(@text_titles2, '', 'NAME', 'RATING', 'RESULTS', 'WINS', '  SPR ', 'RATING', 'RATING');

  if ($dn == 1) {
    $logp->ColumnClasses(['event_name']);
    $logp->WriteTitle([], [$config->Value('event_name')]);
    $logp->WriteTitle([], [$config->Value('event_date')]);
    }
  $logp->ColumnClasses(\@text_classes);
  $logp->WriteTitle(\@text_titles1, []);
  # column titles
  {
    my $title = 'RESULTS';
    if ($tournament->CountDivisions() > 1) {
      $title = "DIVISION $dn RESULTS";
      }
    $text_titles2[3] = 
      (' ' x ((($this->{'pnwidth'}+3)*($last0-$first0+1)+2-length($title))/2)).$title;
  }
  $logp->WriteTitle(\@text_titles2, []);
  }

=back

=cut

1;

