#!/usr/bin/perl

# Copyright (C) 2005-2016 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::EditScore;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::EditScore - implement the C<tsh> EditScore command

=head1 SYNOPSIS

  my $command = new TSH::Command::EditScore;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::EditScore is a subclass of TSH::Command.

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
Use this command to edit player scores that have already been
entered.  Specify the division, player number and round number whose
scores you want to change.  The command displays the player's
scorecard and prompts you for a change.  You may enter '?' at the
prompt for a review of your choices.  
EOF
  $this->{'names'} = [qw(es editscore)];
  $this->{'modal'} = 1; # See Command::IsModal();
  $this->{'argtypes'} = [qw(Division Player Round0)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($dp, $id, $round) = @_;
  my $datap = $dp->{'data'};
  my $p = $dp->Player($id);
  my $config = $tournament->Config();
  my $c_spread_entry = $config->Value('entry') eq 'spread';
  my $c_track_firsts = $config->Value('track_firsts');
# my $c_seats = $config->Value('seats');
  unless (defined $p) { 
    $tournament->TellUser('ebadp', $id);
    return 0;
    }
  my $round0 = $round-1;
  if ($round) {
    unless (defined $p->Score($round0)) {
      $tournament->TellUser('esnos', $p->TaggedName(), $round);
      }
    unless (defined $p->OpponentID($round0)) {
      $tournament->TellUser('esnopp', $p->TaggedName(), $round);
      return 0;
      }
    }
      
  my $quiet = 0;
  while (1) {
    $this->Processor()->Process("sc ".$dp->Name()." $id") unless $quiet;
    $quiet = 0;
    my ($opp, $ms, $os);
    if ($round) {
      my $oppid = $p->OpponentID($round0);
      $opp = $p->Opponent($round0);
      if (!defined $oppid) {
	# should never happen
	$tournament->TellUser('esnop', $p->TaggedName(), $round);
	last;
	}
      $ms = $p->Score($round0);
      $os = $p->OpponentScore($round0);
      }

    # prompt for input
    {
      my $prompt = '';
      $prompt .= $p->TaggedName() . " R$round ";
      if ($round) {
	$prompt .= '[';
	if ($opp) {
	  my $vs = $dp->FormatPairing($round0, $id, 'half');
	  if ($c_spread_entry) {
	    if ((defined $ms) && defined $os) {
	      $prompt .= sprintf("%+d %s", $ms-$os, $vs);
	      }
	      else {
	      $prompt .= $vs;
	      }
	    }
	  else {
	    if ((defined $ms) && defined $os) {
	      $prompt .= "$ms $os $vs";
	      }
	    else {
	      $prompt .= $vs;
	      }
	    }
	  }
	elsif (defined $ms) { $prompt .= "bye scoring $ms"; }
	else { $prompt .= "unscored bye"; }
	$prompt .= "] ";
	}
      $prompt .= "(? for help)";
      TSH::Utility::Prompt $prompt;
    }
    # parse input
#   local($_) = lc $config->DecodeConsoleInput(scalar(<STDIN>));
    local($_) = scalar(<STDIN>);
    last unless defined $_;
    s/^\s+//; s/\s+$//;
    if (/^\?$/) {
      print "EditScores Command Summary\n\n";
      print "Change focus with D div, R round, P player, or change data with:\n";
      print "  BO(ARD) number\n";
      print "  CL(ASS) class\n";
      print "  FIRST, SECOND\n" if $round && $c_track_firsts;
      print "  GA(MES) lifetime-games-played\n";
      print "  NAME player-name\n";
      print $p->Active() ? "  OFF spread\n" : "  ON\n";
      print "  PASS(WORD) password\n" if $config->Value('port');
      print "  PEN(ALTY) points\n";
      print "  RA(TING) n\n";
#     print " S(EAT) number," if $round && $c_seats;
      if (defined $p->Score($round0)) {
	if (defined $opp) {
	  if ($c_spread_entry) {
	    print "  [+-]score\n";
	    }
	  else {
	    print "  my-score opp-score\n";
	    }
	  }
	else {
	    print "  bye-spread\n";
	  }
        }
      $quiet = 1;
      }
    elsif (/^d\s+(\S+)$/i) {
      my $newdp = $tournament->GetDivisionByName($1);
      if (defined $newdp) { 
        $dp = $newdp;
        $datap = $dp->{'data'};
        $p = $dp->Player($id);
	$p = $dp->Player($id=1) unless defined $p;
	my $dname = $dp->Name();
	if ($round && !defined $p->Score($round0)) {
	  TSH::Utility::Error "No corresponding scores in division $dname\n";
	  return 0;
	  }
        }
      else {
	$tournament->TellUser('ebaddiv', $1);
        }
      }
    elsif (/^r\s+([1-9]\d*)$/i) {
      my $newround = $1;
      my $newround0 = $newround - 1;
      unless (exists $p->{'pairings'}[$newround0]) {
	TSH::Utility::Error "Player does not yet have an opponent in round $newround.\n";
        }
      else {
	$round = $newround;
	$round0 = $newround0;
        }
      }
    elsif (/^p\s+([1-9]\d*)$/i) {
      my $newid = $1;
      my $newp = $datap->[$newid];
      if (!defined $newp) {
	$tournament->TellUser('ebadp', $newid);
        }
      elsif ($round && !defined $newp->Score($round0)) {
	TSH::Utility::Error "Player has no scores in round $round.\n";
        }
      else {
        $p = $newp;
        $id = $newid;
        }
      }
    elsif ($round && /^(first|second)$/i && $c_track_firsts) {
      unless ($opp) {
	TSH::Utility::Error "Player had a bye, went neither first nor second.\n";
	next;
        }
      if ($#{$p->FirstVector()} < $round0) {
	TSH::Utility::Error "Please record earlier firsts and seconds first.\n";
	next;
	}
      if ($#{$opp->FirstVector()} < $round0) {
	TSH::Utility::Error "Please record earlier firsts and seconds first.\n";
	next;
        }
      if (/^first$/i) {
	$p->First($round0, 1);
	$opp->First($round0, 2);
        }
      else {
	$p->First($round0, 2);
	$opp->First($round0, 1);
        }
      $dp->Dirty(1);
      }
    elsif ((exists $p->{'etc'}{'off'}) && /^on$/i) {
      # have to Synch() here just in case the player was just turned off
      $dp->Synch();
      $p->Activate();
      }
    elsif (/^off\s+([-+]?\d+)$/i) {
      $p->Deactivate(0+$1);
      }
    elsif ($opp && exists $p->{'scores'}[$round0] && 
      ($c_spread_entry ? /^([-+]?\d+)$/ : /^(-?\d+)\s+(-?\d+)$/)) {
      my $ms = $1;
      my $os = $2;
      if ($c_spread_entry) {
	if ($1 < 0) {
	  $p->Score($round0, 0);
	  $opp->Score($round0, 0 - $ms);
	  }
	else {
	  $p->Score($round0, 0 + $ms);
	  $opp->Score($round0, 0);
	  }
	}
      else {
        $p->Score($round0, $ms);
        $opp->Score($round0, $os);
        }
      $dp->Dirty(1);
      $dp->DirtyRound($round0);
      }
    elsif ((!$opp) && exists $p->{'scores'}[$round0] && /^([-+]?\d+)$/) {
      $p->Score($round0, 0 + $1);
      $dp->Dirty(1);
      $dp->DirtyRound($round0);
      }
    elsif (/^bo(?:a(?:r(?:d?)?)?)?\s+(\d+)$/i && $round0 >= 0) {
      $p->Board($round0, $1);
      $opp->Board($round0, $1);
      $dp->Dirty(1);
      }
    elsif (/^cl(?:a(?:s(?:s)?)?)?\s+([,\w]+)$/i) {
      $p->Class(uc $1);
      $dp->Dirty(1);
      }
    elsif (/^ga(?:m(?:e(?:s)?)?)?\s+(\d+)$/) {
      $p->LifeGames($1);
      $dp->Dirty(1);
      $dp->DirtyRound(-1);
      }
    elsif (/^name\s+(\S+.*?)\s*$/) {
      $p->Name($1);
      $dp->Dirty(1);
      }
    elsif (/^pass(?:word)?\s+(\w+)$/) {
      $config->SetPassword($p, $1);
      }
    elsif (/^pen(?:a(?:l(?:t(?:y)?)?)?)?\s+(-?\d+)$/i && $round0 >= 0) {
      $p->Penalty($round0, $1);
      $dp->Dirty(1);
      $dp->DirtyRound($round0);
      }
    elsif (/^ra(?:t(?:i(?:n(?:g)?)?)?)?\s+(\d+)$/i) {
      $p->Rating($1);
      $dp->Dirty(1);
      $dp->DirtyRound(-1);
      }
    elsif (/^s(?:e(?:a(?:t?)?)?)?\s+(\d+)$/i && $round0 >= 0) {
      $p->Seat($round0, $1);
      $dp->Dirty(1);
      }
    elsif (/\S/) {
      $tournament->TellUser('eeshuh');
      }
    else {
      last;
      }
    }
  continue { $this->Processor()->Flush() unless $quiet; }
  $this->Processor()->Flush();
  0;
  }

=back

=cut

=head1 BUGS

Should use a subprocessor rather than an event loop.

=cut

1;
