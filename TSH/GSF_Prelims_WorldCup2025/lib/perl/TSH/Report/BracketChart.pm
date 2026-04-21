#!/usr/bin/perl

# Copyright (C) 2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Report::BracketChart;

use strict;
use warnings;
use Carp;
use TSH::Log;
use TSH::Division::Pairing::Bracket qw(MakeBracket MakePhaseStartRound0s);

=pod

=head1 NAME

TSH::Report::BracketChart - code for generating a bracket chart

=head1 SYNOPSIS

  $c = new TSH::Report::BracketChart('dp' => $dp, 'last_round0' => $r0);
  $c->Compose();
  ($text, $html) = $c->GetBoth(\%options);
  $s = $c->GetHTML(\%options);
  $s = $c->GetText(\%options);

=head1 ABSTRACT

This Perl module is used to render a bracket chart.
Note that all of the C<Get*()> methods generate printable
files and emit console output as a side effect.

=head1 DESCRIPTION

The following member functions are currently defined.

=over 4

=cut

sub BracketToTable ($);
sub Compose ($);
sub GetBoth ($);
sub GetHTML ($);
sub GetText ($);
sub new ($$);

=item $tablep = BracketToTable($bracket);

Used internally to convert the bracket data structure from 
treelike to tabular.

table : [ column-count, row-count, rows ]
row : [ cells ]
cell : [ cell-data ]
cell-data : [ row-span, TSH::Player or undef 
column-count, row-count, row-span: integer

=cut

sub BracketToTable($) {
  my $bracket = shift;

  my ($seed, $p, $n1, $n2) = @$bracket;
# warn "@$bracket";
  $n1 = BracketToTable($n1) if $n1;
  $n2 = BracketToTable($n2) if $n2;

  my (@rows) = (
    ($n1 ? @{$n1->[2]} : ()),
    ($n2 ? @{$n2->[2]} : ()),
    );
  my $columnCount = 0;
  $columnCount = $n1->[0] if $n1;
  $columnCount = $n2->[0] if $n2 and $n2->[0] > $columnCount;
  $columnCount++;

  if ($n1 and $n2) {
    if (my $indent = $n1->[0] - $n2->[0]) {
      if ($indent > 0) {
	unshift(@{$rows[$n1->[1]]}, [$n2->[1], undef]);
        }
      else {
	unshift(@{$rows[0]}, [$n1->[1], undef]);
        }
      }
    }
  push(@{$rows[0]}, [scalar(@rows), $p]);
  return [$columnCount, scalar(@rows), \@rows];
  }


=item $logp = $csc->Compose();

Store data for a bracket chart in a TSH::Log object.
As a side effect, create text and/or HTML files.

=cut

sub Compose ($) {
  my $this = shift;
  my (%options) = %{$this->{'options'}};
  my $dp = $options{'dp'};

  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $prelims = $dp->GetConfigValue('bracket_prelims') || 0;
  my $has_photos = $dp->GetConfigValue('player_photos');

  # Can't show chart without initial bracket assignments
  if ($dp->LastPairedRound0() < 0) {
    $tournament->TellUser('ebrackneedpr');
    return undef;
    }

  my (@ps) = grep { $_->GetOrSetEtcVector('bracketseed') } $dp->Players();
  @ps = $dp->Players() unless @ps;

  my $logp = new TSH::Log(
    $tournament,
    $dp,
    'bracketchart', 
    $options{'last_round0'} == 0 ? undef : $options{'last_round0'}+1,
    {
      'titlename' => $options{'type'}||'bracketchart',
      'refresh'   => $config->Value('bracketchart_refresh'),
#     'htmltitle' => '',
#     'texttitle' => $this->RenderTextTitle(),
#     'noconsole' => 1,
#     'nohtml' => 1,
#     'notext' => 1,
#     'nowrapper' => 1,
#     'notitle' => 1,
#     'notop' => 1,
    });

  my $bracket = MakeBracket \@ps;
# die TSH::Division::Pairing::Bracket::DumpBracket($bracket);
  my $table = BracketToTable $bracket;
# use Data::Dumper; $Data::Dumper::Maxdepth = 5; die Dumper($table);
  for my $inRow (@{$table->[2]}) {
    my (@html, @text, @attr);
    my $phaseStartRound0sp = MakePhaseStartRound0s($dp);
    for my $phi (0..$#$inRow) {
      my $cell = $inRow->[$phi];
      my ($rowSpan, $p) = @$cell;
      my $attr = $rowSpan == 1 ? '' : "rowspan=$rowSpan";
      $attr .= qq( class="l$phi r) . ($table->[0]-$phi-1) . qq(");
      push(@attr, $attr);
      if (TSH::Utility::IsASafely($p, 'TSH::Player')) {
	my $text = $p->TaggedName();
	my $html = '';
	$html .= qq(<div class=photo><img src=") . $p->PhotoURL() 
	  . qq("></div>) if $has_photos;
	$html .= "<div class=name>" . $p->TaggedHTMLName() . "</div>";
	my (@results);
	for my $r0 ($phaseStartRound0sp->[$phi]
	  ..$phaseStartRound0sp->[$phi+1]-1) {
	  if (my $opp = $p->Opponent($r0)) {
	    my $ps = $p->Score($r0);
	    my $os = $opp->Score($r0);
	    if ((defined $ps) and defined $os) {
	      push(@results, [(qw(T W L))[$ps<=>$os],"$ps-$os"]);
	      }
	    }
	  }
	if (@results) {
	  $text = join('', map { $_->[0] } @results) . ' ' . $text;
	  $html .= "<div class=phs>" . join('', map { 
	    qq(<div class="ph $_->[0]">$_->[1]</div>)
	    } @results) . "</div>";
	  }
	push(@text, $text);
	push(@html, $html);
        }
      elsif ($p) {
	push(@text, "Not a player: $p");
	push(@html, "Not a player: $p");
        }
      else {
	push(@text, '_____');
	push(@html, '?');
        }
      }
    $logp->ColumnAttributes(\@attr);
    $logp->WriteRow(\@text, \@html);
    }
  $logp->Close();

#  my $from = $options{'first_round0'};
#  my $from1 = $from + 1;
#  my (@classes) = qw(name);
#  my (@html_title) = ($config->Terminology('Player'));
#  my $max_rounds = $dp->MaxRound0();
#  if (defined $max_rounds) { $max_rounds++; }
#  else { $max_rounds = $dp->LastPairedRound0()+1; }
#  for my $r ($from1..$max_rounds) {
#    push(@html_title, $config->Terminology('Round') . " $r");
#    push(@classes, 'round');
#    }
#  push(@classes, qw(name));
#  $logp->ColumnClasses(\@classes);
#  $logp->ColumnTitles( {
#    'text' => [],
#    'html' => \@html_title,
#    });
#  
#  my $show_teams = $config->Value('show_teams');
#  for my $p (@{$options{'players'}}) {
#    my (@classes2) = @classes = qw(name);
#    my (@classesh) = qw(name);
#    my $pname = $p->PrettyName($config);
#    my (@html) = ($p->ID() . '. ' . $pname);
#    $html[-1] .= '<br>&nbsp;&nbsp;&nbsp;' . $p->Team() .'' if $show_teams;
#    my (@text) = ($pname);
#    my (@text2) = ('');
#    my $spread = 0;
#    my $wins = 0;
#    my $losses = 0;
#    my $cols = 0;
#    my $id = $p->ID();
#    my $lastr1 = $p->CountOpponents();
#    push(@html, $p->ID() . '. ' . $pname)
#      if $lastr1-$from > 8;
#    if (@text > 1) {
#      $logp->ColumnClasses(\@classes);
#      $logp->WriteRow(\@text, []);
#      $logp->ColumnClasses(\@classes2);
#      $logp->WriteRow(\@text2, []);
#      }
#    $logp->ColumnClasses(\@classesh);
#    $logp->WriteRow([], \@html);
#    } # for my $p
#  $logp->Close();
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
