#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::FinalReport;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::FinalReport - implement the C<tsh> FinalReport command

=head1 SYNOPSIS

  my $command = new TSH::Command::FinalReport;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::FinalReport is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub DoABSPRatings ($$);
sub DoNSARatings ($$);
sub initialise ($$$$);
sub new ($);
sub RenderTable ($$$);
sub Run ($$@);

=item DoABSPRatings($dp, $r0)

Display ratings estimates as calculated by the Association of
British Scrabble Players.

=cut

sub DoABSPRatings ($$) {
  my $dp = shift;
  my $r0 = shift;

  RenderTable($dp, $r0,
    {
      'oldrh'=>'Input<br>Rating',
      'newrh'=>'Tourn.<br>Rating',
      'oldrt'=>'InR',
      'newrt'=>'ToR',
    });
  0;
  }

=item DoNSARatings($dp, $r0)

Display ratings estimates as calculated by the National Scrabble
Association.

=cut

sub DoNSARatings ($$) {
  my $dp = shift;
  my $r0 = shift;
  my $tournament = $dp->Tournament();

  RenderTable($dp, $r0, {});
  0;
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
Use this command to prepare a final report suitable for posting
to an electronic mailing list.
EOF
  $this->{'names'} = [qw(fr finalreport)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item RenderTable($dp, $r0, $termsp)

Render the rows of the ratings table. This code is independent of
rating system.

=cut

sub RenderTable ($$$) {
  my $dp = shift;
  my $r0 = shift;
  my $terms = shift;
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $noshowlast = $config->Value('no_show_last') || $r0 < 0;
  my $showlastplayername = $config->Value('show_last_player_name');
  my $spreadentry = $config->Value('entry') eq 'spread';
  my $trackfirsts = $config->Value('track_firsts');
  my $is_capped = $config->HasSpreadCaps();

  my $has_classes = $dp->Classes() || defined $dp->Player(1)->Class();
  my $logp = new TSH::Log($tournament, $dp, 'ratings', $r0+1);
  my (@classes) = qw(rank wl spread rating rating rating);
  my (@html_titles) = (qw(Rank Won-Lost Spread),
    ($terms->{'oldrh'} || 'Old<br>Rating'),
    ($terms->{'newrh'} || 'New<br>Rating'),
    qw(Rating<br>Change));
  my (@text_titles) = (qw(Rnk Won-Lost Spread),
    ($terms->{'oldrt'} || 'OldR'),
    ($terms->{'newrt'} || 'NewR'),
    qw(+-R));
  if ($has_classes) {
    push(@classes, 'pclass');
    push(@html_titles, 'Class');
    push(@text_titles, 'C');
    }
  push(@classes, 'name');
  push(@html_titles, 'Player');
  push(@text_titles, 'Player');
  unless ($noshowlast) {
    push(@classes, qw(last));
    push(@html_titles, 'Last');
    push(@text_titles, 'Last');
    }
  if ($dp->LastPairedRound0() > $r0) {
    push(@classes, 'name');
    push(@html_titles, 'Next');
#   push(@text_titles, 'Next Opponent'); # too wide
    }
  $logp->ColumnClasses(\@classes);
  $logp->ColumnTitles(
    {
    'text' => \@text_titles,
    'html' => \@html_titles,
    }
    );
  my @ps;
  if ($is_capped) {
    $dp->ComputeCappedRanks($r0);
    @ps = TSH::Player::SortByCappedStanding($r0, $dp->Players());
    }
  else {
    $dp->ComputeRanks($r0);
    @ps = TSH::Player::SortByStanding($r0, $dp->Players());
    }
  my $i = 0;
  for my $p (@ps) {
    next unless $p->Active();
#   if ($config::pair_page_break && $i && ($i) % $config::pair_page_break == 0) { $logp->Write('',qq(</table><table class=ratings align=center cellspacing=0 style="page-break-before:always"><tr>$headings</tr>)); }
    my $rating = $p->Rating();
    my $newr = $p->NewRating($r0);
    $newr = 0 unless defined $newr;
    $i++;
    my $rank = $is_capped ? $p->RoundCappedRank($r0) : $p->RoundRank($r0);
    my (@fields) = (
      $rank,
      sprintf("%.1f-%.1f", $p->RoundWins($r0), $p->RoundLosses($r0)),
      sprintf("%+d ", $is_capped ? $p->RoundCappedSpread($r0) : $p->RoundSpread($r0)),
      $rating,
      $newr,
      $rating ? sprintf("%+d", $newr-$rating) : ''
      );
    push(@fields, $p->Class()) if $has_classes;
    push(@fields, $p->TaggedName());
    my (@text_fields) = @fields;
    unless ($noshowlast) {
      my $s = '';
      my $opp = $p->Opponent($r0);
      if ($opp) {
	my $oname = $showlastplayername ? $opp->TaggedName() : $opp->FullID();
	my $ms = $p->Score($r0);
	if (defined $ms) {
	  my $os = $p->OpponentScore($r0);
	  $os = 0 unless defined $os; # possible if pairing data bad
	  my $p12 = $p->First($r0);
	  $s = 
	    ($trackfirsts ? substr('B12??', $p12,1) : '')
	    .($spreadentry ? '' : ($ms > $os ? 'W' : $ms < $os ? 'L' : 'T'));
	  $s .= ':' if $s;
	  $s .=($spreadentry ? sprintf("%+d", $ms-$os) : "$ms-$os")
	    .':'
	    . $oname;
	  }
	else {
	  $s = 'pending:' . $oname;
	  }
        }
      else {
	if (defined $p->OpponentID($r0)) {
	  $s = 'bye';
	  }
	else {
	  $s = 'unpaired';
	  }
        }
      push(@fields, $s);
      push(@text_fields, $s);
      }
    # next round
    if (my $opp = $p->Opponent($r0+1)) {
      push(@fields, $opp ? $opp->FullID() : 'bye');
      }
    $logp->WriteRow(\@text_fields, \@fields);
    }
  $logp->Close();
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();

  my $logp = new TSH::Log($tournament, undef, 'final', {'title' => 'Final Report'});
  my (@standing_classes) = qw(rank rank player wl spread sopew rating rating rating score score score);
  my (%standing_titles) = (
    'html' => [qw(Rank Seed Name Won-Lost Spread SOpEW Old<br>Rating New<br>Rating Rating<br>Change Average<br>For Average<br>Against High<br>Score)],
    'text' => [qw(Rank Seed Name Won-Lost Cumul SOpEW OldR NewR Chng For Agn Hi)],
    );
  my $max_rounds = $config->Value('max_rounds');
  if (!defined $max_rounds) {
    $tournament->TellUser('eneed_max_rounds');
    return;
    }
  my $max_rounds0 = $max_rounds - 1;
  for my $dp ($tournament->Divisions()) {
    $dp->ComputeRatings($max_rounds0);
    my $dname = $dp->Name();
    $logp->Write("Division $dname\n\n", "<h2>Division $dname</h2>\n");
    $logp->WritePartialWarning(12) unless $dp->IsComplete();
    $logp->ColumnClasses(\@standing_classes);
    $logp->WriteTitle($standing_titles{'text'}, $standing_titles{'html'});
    if ($dp->RatingSystemName() =~ /absp/) {
      DoABSPRatings($dp, 0);
      }
    else {
      DoNSARatings($dp, 0);
      }
    }
  $logp->Close();
  return 0;
  }

=back

=cut

1;
