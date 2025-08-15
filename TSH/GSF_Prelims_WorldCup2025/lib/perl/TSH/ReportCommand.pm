#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ReportCommand;

use strict;
use warnings;
use threads::shared;
use TSH::Log;
use TSH::Utility;
use Carp;
use TSH::Command;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::ReportCommand - common code for commands that generate standard reports

=head1 SYNOPSIS

This subclass supports features common to commands that generate standard
reports, e.g., high wins, tuff luck.  Standard reports list extreme items
(currently players or games) found in a division according to the criteria
that define their extremity.
  
=head1 ABSTRACT

my $setupp = $rc->SetupReport(%options);
$rc->SetupColumns(@column_codes);
$rc->WriteData(@column_codes);

$rc->SetupColumns(@column_codes);
$rc->SetOption($key, $value);
$rc->AddRows(\@entries); 

=cut

=head1 DESCRIPTION

=over 4

=item $command->SetupColumns(@column_codes);

=cut

# See lib/perl/TSH/Division/FindExtremeGames.pm for the arguments to the 
# subs in this table for extreme game commands (currently p-score, 
# opp-score, p, opp, r0, p-rating, o-rating)

my (%gColumnTypes) = (
  'combined-score' => [qw(score CombinedS Combined_Score), sub { $_[0][0]+$_[0][1] } ],
  'p-average' => [qw(score AverageS Average_Score), sub { sprintf("%7.2f", $_[0][0]) } ],
  'o-average' => [qw(score AverageS OAverage_Score), sub { sprintf("%7.2f", $_[0][0]) } ],
  'p-class' => [qw(class Class Class), sub { $_[0][1]->Class() } ],
  'p-losses' => [qw(scores LosingSs Losing_Spreads), sub { join(' ', @{$_[0][0][1]}) } ],
  'p-name' => [qw(name Player Player), sub { $_[0][1]->TaggedName({'localise'=>1}) }, sub { $_[0][1]->TaggedHTMLName({'localise'=>1, 'style'=>'print'})} ],
  'p-new-rating' => [qw(rating New_R New_Rating), sub { $_[0][1]->NewRating(-1) } ],
  'p-old-rating' => [qw(rating Old_R Old_Rating), sub { $_[0][1]->Rating() } ],
  'p-opptotal' => [qw(score TotalOppS Total_Opp_Score), sub { $_[0][0] } ],
  'p-rating-change' => [qw(rating RatingDiff RatingDifference), sub { sprintf("%+d", $_[0][1]->NewRating(-1)-$_[0][1]->Rating()) } ],
  'p-spread' => [qw(spread Sprd Spread), sub { sprintf("%+d", $_[0][1]->Spread()) } ],
  'p-total' => [qw(score TotalS Total_Score), sub { $_[0][0] } ],
  'p-tuff' => [qw(score TuffL Tuff_Luck), sub { $_[0][0][0] } ],
  'p-stiff' => [qw(score LuckyS Lucky_Stiff), sub { $_[0][0][0] } ],
  'p-wins' => [qw(scores WinningSs Winning_Spreads), sub { join(' ', @{$_[0][0][1]}) } ],
  'p-wl' => [qw(wl W_L W_L), sub { sprintf("%4.1f-%4.1f", $_[0][1]->Wins(), $_[0][1]->Losses()) } ],
  'p1-class' => [qw(class Class Class), sub { $_[0][2]->Class() } ],
  'p1-loser' => [qw(name Loser Loser), sub { $_[0][2]->TaggedName({'localise'=>1}) }, sub { $_[0][2]->TaggedHTMLName({'localise'=>1, 'style'=>'print'})} ],
  'p1-losing-score' => [qw(score LosingS Losing_Score), 0],
  'p1-winner' => [qw(name Winner Winner), sub { $_[0][2]->TaggedName({'localise'=>1}) }, sub { $_[0][2]->TaggedHTMLName({'localise'=>1, 'style'=>'print'})} ],
  'p1-winner-rating' => [qw(rating WinnerR WinnerRating), sub { $_[0][5] } ],
  'p1-winning-score' => [qw(score WinningS Winning_Score), 0],
  'p2-class' => [qw(class Class Class), sub { $_[0][3]->Class() } ],
  'p2-loser' => [qw(name Loser Loser), sub { $_[0][3]->TaggedName({'localise'=>1}) }, sub { $_[0][3]->TaggedHTMLName({'localise'=>1, 'style'=>'print'})} ],
  'p2-loser-rating' => [qw(rating LoserR LoserRating), sub { $_[0][6] } ],
  'p2-losing-score' => [qw(score LosingS Losing_Score), 1],
  'p2-rating-advantage' => [qw(rating RatingDiff RatingDifference), sub { $_[0][6]-$_[0][5] } ],
  'p2-winner' => [qw(name Winner Winner), sub { $_[0][3]->TaggedName({'localise'=>1}) }, sub { $_[0][3]->TaggedHTMLName({'localise'=>1, 'style'=>'print'})} ],
  'p2-winning-score' => [qw(score WinningS Winning_Score), 1],
  'rank' => [qw(rank Rnk Rank), sub { $_[1]->{'rc_rank'} } ],
  'round' => [qw(round Rnd Round), sub { $_[0][4]+1 } ],
  'spread' => [qw(score Sprd Spread), sub { $_[0][0]-$_[0][1] } ],
  );

=item $rc->AddRows(\@gamesp); 

Add additional rows to the list to be displayed, if the selection
criteria are too complex for the current version of this module.
See HighRoundWins for an example.

=cut

sub AddRows ($$) {
  my $this = shift;
  my $entriesp = shift;
  $this->{'rcopt'} ||= &share({});
  $this->{'rcopt'}{'entries'} ||= &share([]);
  push(@{$this->{'rcopt'}{'entries'}}, @$entriesp);
  }

=item $command->SetupColumns(@column_codes);

=cut

sub SetupColumns($@) {
  my $this = shift;
  my $config = $this->{'rcopt'}{'config'};
  my @classes;
  my @html_titles;
  my @text_titles;
  for my $column_type (@_) {
    if (my $ctdata = $gColumnTypes{$column_type}) {
      push(@classes, $ctdata->[0]);
      push(@text_titles, $config->Terminology($ctdata->[1]));
      push(@html_titles, $config->Terminology($ctdata->[2]));
      }
    else {
      warn "Unknown column type: $column_type";
      }
    }
  my $logp = $this->{'rcopt'}{'log'};
  $logp->ColumnClasses(\@classes);
  $logp->ColumnTitles(
    {
    'text' => \@text_titles,
    'html' => \@html_titles,
    }
    );
  }

sub SetOption ($$$) {
  my $this = shift;
  my $key = shift;
  my $value = shift;
  $this->{'rcopt'}{$key} = $value;
  }

=item $setupp = $command->SetupReport(%options);

Supported options:

comparator (input) orders entries according to their extremity

evaluator (input) evaluates items to create entries

config (output) point to TSH::Config object

dp (input) pointer to division of interest

entries (output) pointer to list of extreme entries

has_classes (output) true if data has player classes

log (output) pointer to TSH::Log object

max_entries (input) number of extreme entries to list

postfilter (input) filter to select evaluated entries of interest

rounds (input) round numbers to pass to TSH::Log

selector (input) filter to select entries of interest

type (input) name of type of extreme entries, a terminology key

=cut

sub SetupReport($@) {
  my $this = shift;
  if (@_ % 2) { warn "Assertion failed"; return {}; }
  my (%options) = @_;
  my $dp = $options{'dp'};
  my $tournament = $dp->Tournament();
  my $config = $options{'config'} = $tournament->Config();
  $options{'has_classes'} = $dp->Classes() ||
    ($dp->Player(1) && defined $dp->Player(1)->Class());
  $options{'max_entries'} ||= 20;
  $options{'log'} = new TSH::Log( 
    $tournament,
    $dp, 
    $options{'type'}, 
    $options{'rounds'},
    {'titlename' => $config->Terminology($options{'type'})},
    );
  $this->{'rcopt'} = \%options;
  if ($options{'selector'}) {
    $this->FindEntries();
    }
  else {
    my @entries: shared;
    $this->{'rcopt'}{'entries'} = \@entries;
    }
  $this->{'rc_rank'} = 0;
  $this->{'rc_rownum'} = 0;
  return \%options;
  }

sub WriteData ($@) {
  my $this = shift;
  my (@types) = @_;
  $this->WriteDataNoClose(@types);
  $this->{'rcopt'}{'log'}->Close();
  }

sub WriteDataNoClose ($@) {
  my $this = shift;
  my (@types) = @_;

  my $logp = $this->{'rcopt'}{'log'};
  my $even = 0;
  my $comparator = $this->{'rcopt'}{'comparator'};
  my $last = undef;
  for my $entry (@{$this->{'rcopt'}{'entries'}}) {
    my (@html, @text);
    $this->{'rc_rownum'}++;
    if ((!defined $last) || &$comparator($last, $entry)) {
      $this->{'rc_rank'} = $this->{'rc_rownum'};
      $last = $entry;
      }
    for my $type (@types) {
      my $text = $gColumnTypes{$type}[3];
      if (ref($text) eq 'CODE') {
	$text = &$text($entry, $this);
        }
      elsif (defined $text) { $text = $entry->[$text]; }
      else { $text = '?'; }
      push(@text, $text);
      if (my $html = $gColumnTypes{$type}[4]) {
	if (ref($html) eq 'CODE') {
	  $html = &$html($entry, $this);
	  }
	elsif (defined $html) { $html = $entry->[$html]; }
	else { $html = '?'; }
	push(@html, $html);
        }
      else { push(@html, $text); }
      }
    $logp->ToggleRowParity($even);
    $logp->WriteRow(\@text, \@html);
    }
  }

=back

=cut

=head1 BUGS

=cut


