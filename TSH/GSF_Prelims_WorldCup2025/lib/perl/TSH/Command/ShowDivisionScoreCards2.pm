#!/usr/bin/perl

# Copyright (C) 2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::ShowDivisionScoreCards2;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use TSH::Report::CSC;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ShowDivisionScoreCards2 - implement the C<tsh> ShowDivisionScoreCards2 command

=head1 SYNOPSIS

  my $command = new TSH::Command::ShowDivisionScoreCards2;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ShowDivisionScoreCards2 is a subclass of TSH::Command.
It generates all scorecards for a division, but in a 2-page per sheet imposition for each scorecard.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to generate a file containing an electronic version
of all the player
scorecards in a division.
Unlike the basic SDSC command, this one renders to halves of each scorecard side-by-side on
one page intended to be displayed in a landscape orientation.
As a side effect, it will assign boards for all rounds which have pairings.
Specify the name of the division whose scorecards you wish to list.
EOF
  $this->{'names'} = [qw(sdsc2 showdivisionscorecards2)];
  $this->{'argtypes'} = [qw(Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($dp) = @_;
  my $config = $tournament->Config();
  my @text;
  my @html;
  my $sr0 = $dp->MostScores()-1;
  for my $r0 (0..$dp->LastPairedRound0()) {
    $dp->ComputeBoards($sr0, $r0);
    }
  $this->Processor()->Flush(); # save any new board assignments
  for my $p ($dp->Players()) {
    my $csc = new TSH::Report::CSC($p);
    my ($text, $html) = $csc->GetBoth({'imposition'=>2});
    push(@text, $text);
    push(@html, $html);
    }
  my $logp = new TSH::Log($tournament, $dp, 'scorecard', '', {
      'title' => "Division Scorecards",
      'notitle' => 1,
      'noconsole' => 1 ,
      'refresh' => $config->Value('scorecards_refresh'),
      'html_page_break_top' => $config->Value('html_page_break_top'),
#     'notop' => 1,
    });
  my $html_top = $config->Value('html_top') || '';
  my $html_bottom = $logp->GetBlurb();
  $logp->Write(join("\f", @text), 
    join(qq(</table>$html_bottom<div style="page-break-after:always">&nbsp;</div>$html_top<table class=scorecard border=0 align=center cellspacing=0>), @html)
    );
  $logp->Close();
  print "Generated all scorecards for division " . $dp->Name() . ".\n";
  }

=back

=cut

=head1 BUGS

Should use the newer Log::PageBreak method.

=cut

1;
