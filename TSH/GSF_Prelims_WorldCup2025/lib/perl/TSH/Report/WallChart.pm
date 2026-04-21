#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Report::WallChart;

use strict;
use warnings;
use Carp;
use TSH::Log;

=pod

=head1 NAME

TSH::Report::WallChart - code for generating a wall chart

=head1 SYNOPSIS

  $c = new TSH::Report::WallChart('players' => $players, 'first_round0' => $r0,
    'type' => 'rankedwallchart');
  ($text, $html) = $c->GetBoth(\%options);
  $s = $c->GetHTML(\%options);
  $s = $c->GetText(\%options);

=head1 ABSTRACT

This Perl module is used to render a wall chart.
Note that all of the C<Get*()> methods generate printable
files and emit console output as a side effect.

=head1 DESCRIPTION

The following member functions are currently defined.

=over 4

=cut

sub Compose ($);
sub GetBoth ($);
sub GetHTML ($);
sub GetText ($);
sub new ($$);

=item $logp = $csc->Compose();

Store wall chart in a TSH::Log object in preparation for rendering it as
text and/or HTML.   Should not be called with empty player list.

=cut

sub Compose ($) {
  my $this = shift;
  my (%options) = %{$this->{'options'}};
  my $psp = $options{'players'};

  my $config;
  my $dp;
  my $tournament;
  if (@$psp) {
    $dp = $psp->[0]->Division();
    $tournament = $dp->Tournament();
    $config = $tournament->Config();
    }

  my $logp = new TSH::Log(
    $tournament,
    $dp,
    'wallchart', 
    $options{'first_round0'} == 0 ? undef : $options{'first_round0'}+1,
    {
      'titlename' => $options{'type'}||'wallchart',
      'refresh'   => $config->Value('wallchart_refresh'),
#     'htmltitle' => '',
#     'texttitle' => $this->RenderTextTitle(),
#     'noconsole' => 1,
#     'nohtml' => 1,
#     'notext' => 1,
#     'nowrapper' => 1,
#     'notitle' => 1,
#     'notop' => 1,
    });

  my $from = $options{'first_round0'};
  my $from1 = $from + 1;
  my (@classes) = qw(name);
  my (@html_title) = ($config->Terminology('Player'));
  my $max_rounds = $dp->MaxRound0();
  if (defined $max_rounds) { $max_rounds++; }
  else { $max_rounds = $dp->LastPairedRound0()+1; }
  for my $r ($from1..$max_rounds) {
    push(@html_title, $config->Terminology('Round') . " $r");
    push(@classes, 'round');
    }
  push(@classes, qw(name));
  $logp->ColumnClasses(\@classes);
  $logp->ColumnTitles( {
    'text' => [],
    'html' => \@html_title,
    });
  
  my $show_teams = $config->Value('show_teams');
  for my $p (@{$options{'players'}}) {
    my (@classes2) = @classes = qw(name);
    my (@classesh) = qw(name);
    my $pname = $p->PrettyName($config);
    my (@html) = ($p->ID() . '. ' . $pname);
    $html[-1] .= '<br>&nbsp;&nbsp;&nbsp;' . $p->Team() .'' if $show_teams;
    my (@text) = ($pname);
    my (@text2) = ('');
    my $spread = 0;
    my $wins = 0;
    my $losses = 0;
    my $cols = 0;
    my $id = $p->ID();
    my $lastr1 = $p->CountOpponents();
    for my $r (1..$lastr1) {
      my $r0 = $r - 1;
      my $oppid = $p->OpponentID($r0);
      my $opp = $p->Opponent($r0);
      my $os = $p->OpponentScore($r0);
      my $ms = $p->Score($r0);
      my $thisSpread = $p->RoundSpread($r0);
      $thisSpread -= $p->RoundSpread($r0-1) if $r0;
      $spread += $thisSpread;
      my $thisWin = 0;
      if (defined $ms) {
	my $new_wins =  $p->RoundWins($r0);
	$thisWin = $new_wins - $wins;
	$wins = $new_wins;
	$losses = $p->RoundLosses($r0);
	}
      if ($r0 >= $from) {
	push(@classes, 'wins');
	push(@classes2, 'spread');

	my $oppinfo = (defined $oppid) 
	  ? $dp->FormatPairing($r0, $id, 'brief') : '';
	if (!defined $oppid) {
	  $oppinfo = qq(<div class=empty>$oppinfo</div>);
	  }
	elsif ($oppid) { 
	  $oppinfo = qq(<div class=opp><a href="#$oppid.$r" name="$id.$r">$oppinfo</a></div>); 
	  }
	else {
	  $oppinfo = qq(<div class=bye>$oppinfo</div>);
	  }
	push(@classesh, (defined $oppid) ? $oppid ? $thisWin == 1 ? 'win' :
	  $thisWin == 0 ? 'loss' : 'tie' : 'bye' : 'empty');
	if (defined $ms) {
	  push(@text, sprintf("%.1f", $wins));
	  push(@text2, sprintf("%+d", $spread));
	  push(@html, sprintf(qq(<div class=score>%s</div><div class=pair>%s</div><div class=record>%.1f-%.1f</div><div class=spread>%+d = %+d</div>),
	    ($oppid ? sprintf("%s-%s", $ms, ((defined $os) ? $os : ''))
	      : sprintf("%+d", $ms)),
	    $oppinfo,
	    $wins, $losses,
	    $thisSpread, $spread,
	    ));
	  }
	else {
	  push(@text, '');
	  push(@text2, '');
	  push(@html, sprintf(qq(<div class=score>-</div><div class=pair>%s</div><div class=record>-</div><div class=spread>=</div>),
	    $oppinfo,
	    ));
	  }
	}
      unless ((1+$cols-$from) % 10) {
	if ($r0 >= $from) {
	  $logp->ColumnClasses(\@classes);
	  $logp->WriteRow(\@text, []);
	  $logp->ColumnClasses(\@classes2);
	  $logp->WriteRow(\@text2, []);
	  @text = ('');
	  @text2= ('');
	  @classes = @classes2 = qw(name);
	  }
	}
      $cols++;
      } # for $r0
    push(@html, $p->ID() . '. ' . $pname)
      if $lastr1-$from > 8;
    if (@text > 1) {
      $logp->ColumnClasses(\@classes);
      $logp->WriteRow(\@text, []);
      $logp->ColumnClasses(\@classes2);
      $logp->WriteRow(\@text2, []);
      }
    $logp->ColumnClasses(\@classesh);
    $logp->WriteRow([], \@html);
    } # for my $p
  $logp->Close();
  return $logp;
  }

=item my ($text, $html) = $csc->GetBoth();

Return text and HTML rendering of the CSC.

=cut

sub GetBoth ($) {
  my $this = shift;
  my $logp = $this->Compose();
  return ($logp->RenderText(), $logp->RenderHTML());
  }

=item $html = $csc->GetHTML();

Return HTML rendering of the CSC as the rows of a table.

=cut

sub GetHTML ($) {
  my $this = shift;
  return $this->Compose()->RenderHTML();
  }

=item $html = $csc->GetText();

Return text rendering of the CSC.

=cut

sub GetText ($) {
  my $this = shift;
  return $this->Compose()->RenderText();
  }

sub initialise ($@) {
  my $this = shift;
  my (%options) = @_;
  $this->{'options'} = \%options;
  }

sub new ($$) { return TSH::Utility::new(@_); }

=back

=cut

1;
