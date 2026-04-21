#!/usr/bin/perl

# Copyright (C) 2005-2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ABSPgrid;

use strict;
use warnings;

use Ratings;
use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ABSPgrid - implement the C<tsh> ABSPgrid command

=head1 SYNOPSIS

  my $command = new TSH::Command::ABSPgrid;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ABSPgrid is a subclass of TSH::Command.

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
Use this command to create a ratings grid for submitting scores
to the ABSP Ratings Officer.
EOF
  $this->{'names'} = [qw(absp abspgrid)];
  $this->{'argtypes'} = [qw(OptionalDivisions)];
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
  my $config = $tournament->Config();
  my $save_ntf = $config->Value('no_text_files');
  my $rating_list = $config->Value('rating_list') || '';
  $config->Value('no_text_files', 0);
  my (@origargs) = @_;
  my (@divisions) = @_ ? @_ : $tournament->Divisions();
  my $logp = new TSH::Log($tournament, @origargs == 1 ? $origargs[0] : undef,
    @origargs == 1 ? 'grid' : 'abspgrid', '', {'notitle' => 1, 'noconsole' => 1});
  my $offset = 0;
  my $mostrounds = 0;
  my $leastrounds = 1E10;
  for my $dp (@divisions) {
    my $nr = $dp->MostScores();
    $mostrounds = $nr if $mostrounds < $nr;
    $nr = $dp->LeastScores();
    $leastrounds = $nr if $leastrounds > $nr;
    }
  if ($mostrounds != $leastrounds) {
    $tournament->TellUser('eabspr', $mostrounds);
    }
  my $nrounds = $mostrounds;
  $logp->Write('','<tr class=top1>');
  my $s = sprintf("Results grid after round %d\n\nName              |",
    $nrounds);
  $logp->Write($s, "<td><pre>\n$s");
  my $hrule = '-' x 18 . '|';
  for my $r (1..$nrounds) {
    $s = sprintf("Rnd%2d|", $r);
    $logp->Write($s, $s);
    $hrule .= '-----|';
    }
  $hrule .= "\n";
  $s = "\n$hrule";
  $logp->Write($s, $s);
  
  for my $dp (@divisions) {
    my $rating_system = $dp->RatingSystem();
    my $nplayers = 0;
    for my $p ($dp->Players()) {
      next unless defined $p;
      $nplayers++;
      my ($surname, $given) = split(/, */, ($rating_system->CanonicaliseName($rating_list, $p->Name()))[0], 2);
      if (!defined $given) {
	TSH::Utility::Error "Can't find a comma separating surname from given name: $p->{'name'}\n";
	return 0;
        }
      my $line1 = sprintf("%3d: %-13.13s", $p->ID()+$offset, $given);
      my $line2 = sprintf("%4g %-13.13s", $p->Wins(), $surname);
      for my $r (1..$nrounds) {
	my $r0 = $r - 1;
	$line1 .= '|'; $line2 .= '|';
	{
	  my $p12 = $p->First($r0);
	  $line1 .= $p12 == 1 ? 'S' : $p12 == 2 ? 'R' : ' ';
	}
        my $oppid = $p->OpponentID($r0);
	if ($oppid) {
	  my $opp = $p->Opponent($r0);
	  my $os = $p->OpponentScore($r0);
	  my $ms = $p->Score($r0);
	  if ((defined $ms) && defined $os) {
	    my $thisSpread = $ms - $os;
	    if ($thisSpread) {
	      $line1 .= sprintf("%+4d", $thisSpread);
	      $line2 .= $thisSpread > 0 ? '+ ' : '- ';
	      }
	    else {
	      $line1 .= '   =';
	      $line2 .= '= ';
	      }
	    }
	  else { # don't have both $ms and $os
	    $line1 .= '    ';
	    $line2 .= '= ';
	    }
	  $line2 .= sprintf("%3d", $oppid+$offset);
	  }
	else { # no $oppid
	  $line1 .= "   =";
	  $line2 .= "=   X";
	  }
        } # for $r0
      $s = "$line1|\n$line2|\n$hrule";
      $logp->Write($s, $s);
      } # for my $p
    $offset += $nplayers;
    }
  $logp->Write('', "</pre></td>");
  $logp->Close();
  $tournament->TellUser('iabspok');
  $config->Value('no_text_files', $save_ntf);
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
